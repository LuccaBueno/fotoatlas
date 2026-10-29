import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import 'library_controller.dart';

final _devicesProvider = FutureProvider.autoDispose<List<CaptureDevice>>(
  (ref) => ref.watch(libraryBackendProvider).captureDevices(),
);

enum _Kind { shift, year, align }

/// Assistente "Corrigir o relógio de um dispositivo" (spec §8.2): escolher o
/// dispositivo, dizer o erro, ver a prévia "antes → depois" e aplicar. Só no
/// catálogo; desfazer a qualquer momento.
class ClockCorrectionDialog extends ConsumerStatefulWidget {
  const ClockCorrectionDialog({super.key, this.initialDevice, this.referenceIds = const []});

  /// (fabricante, modelo, série) para já vir escolhido.
  final (String?, String?, String?)? initialDevice;

  /// Itens marcados na Biblioteca (para "alinhar com uma foto").
  final List<int> referenceIds;

  @override
  ConsumerState<ClockCorrectionDialog> createState() => _ClockCorrectionDialogState();
}

class _ClockCorrectionDialogState extends ConsumerState<ClockCorrectionDialog> {
  CaptureDevice? _device;
  _Kind _kind = _Kind.shift;
  bool _ahead = true;
  final _h = TextEditingController(text: '0');
  final _m = TextEditingController(text: '0');
  final _s = TextEditingController(text: '0');
  final _yearFrom = TextEditingController();
  final _yearTo = TextEditingController();
  final _periodFrom = TextEditingController();
  final _periodTo = TextEditingController();
  Duration? _aligned;
  String? _alignInfo;
  CorrectionPreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_h, _m, _s, _yearFrom, _yearTo, _periodFrom, _periodTo]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  ClockCorrectionDraft? _draft() {
    final d = _device;
    if (d == null) return null;
    var offset = Duration.zero;
    var years = 0;
    switch (_kind) {
      case _Kind.shift:
        final total = Duration(hours: _int(_h), minutes: _int(_m), seconds: _int(_s));
        // "Estava adiantado" → a hora certa é mais cedo.
        offset = _ahead ? -total : total;
      case _Kind.year:
        final from = int.tryParse(_yearFrom.text.trim()), to = int.tryParse(_yearTo.text.trim());
        if (from == null || to == null) return null;
        years = to - from;
      case _Kind.align:
        if (_aligned == null) return null;
        offset = _aligned!;
    }
    if (offset == Duration.zero && years == 0) return null;
    int? day(TextEditingController c, {bool end = false}) {
      final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(c.text.trim());
      if (m == null) return null;
      final t = DateTime.utc(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
      return (end ? t.add(const Duration(days: 1)) : t).millisecondsSinceEpoch - (end ? 1 : 0);
    }

    return ClockCorrectionDraft(
      make: d.make,
      model: d.model,
      serial: d.serial,
      offset: offset,
      years: years,
      // Folga de 1 dia por causa do fuso (o período é pela data extraída).
      periodStartUtcMs: day(_periodFrom) == null ? null : day(_periodFrom)! - 86400000,
      periodEndUtcMs: day(_periodTo, end: true) == null ? null : day(_periodTo, end: true)! + 86400000,
    );
  }

  Future<void> _align() async {
    final d = _device;
    if (d == null || widget.referenceIds.length != 2) return;
    final cache = ref.read(libraryItemCacheProvider);
    final items = [for (final id in widget.referenceIds) await cache.get(id)];
    bool mine(LibraryItem? i) =>
        i != null && (i.make ?? '').toLowerCase() == (d.make ?? '').toLowerCase() && (i.model ?? '') == (d.model ?? '');
    final cam = items.where(mine).firstOrNull;
    final other = items.where((i) => i != null && !mine(i)).firstOrNull;
    if (cam == null || other == null) {
      setState(() => _alignInfo = 'Das duas fotos marcadas, uma precisa ser deste dispositivo e a outra de outro.');
      return;
    }
    final offset = await ref.read(libraryBackendProvider).offsetBetween(cam.contentId, other.contentId);
    setState(() {
      _aligned = offset;
      _alignInfo = '"${cam.name}" passa a ter a hora de "${other.name}": ${formatShift(offset)}.';
      _preview = null;
    });
  }

  Future<void> _runPreview() async {
    final draft = _draft();
    if (draft == null) {
      setState(() => _error = 'Diga quanto o relógio estava errado.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref.read(libraryBackendProvider).previewCorrection(draft);
      setState(() => _preview = p);
    } on Object catch (e) {
      setState(() => _error = 'Não foi possível calcular a prévia: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final draft = _draft();
    if (draft == null) return;
    setState(() => _busy = true);
    final backend = ref.read(libraryBackendProvider);
    final id = await backend.applyCorrection(draft);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Relógio de ${_device!.label} corrigido em ${plural(_preview?.affected ?? 0, 'item', 'itens')}. '
          'Só o catálogo mudou.',
        ),
        action: SnackBarAction(label: 'Desfazer', onPressed: () => backend.undoCorrection(id)),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  Widget _num(TextEditingController c, String label, {double width = 70}) => SizedBox(
    width: width,
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (_) => setState(() => _preview = null),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = ref.watch(_devicesProvider);
    final list = devices.value ?? const <CaptureDevice>[];
    if (_device == null && list.isNotEmpty && widget.initialDevice != null) {
      final (make, model, serial) = widget.initialDevice!;
      _device =
          list.where((d) => d.make == make && d.model == model && d.serial == serial).firstOrNull ??
          list.where((d) => d.make == make && d.model == model).firstOrNull;
    }
    final preview = _preview;
    return AlertDialog(
      key: const ValueKey('clock-dialog'),
      title: const Text('Corrigir o relógio de um dispositivo'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para câmeras com a data ou a hora erradas. Muda só o catálogo do FotoAtlas: os arquivos ficam '
                'como estão, e dá para desfazer em Configurações.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CaptureDevice>(
                key: const ValueKey('clock-device'),
                initialValue: _device,
                decoration: const InputDecoration(labelText: '1. Dispositivo'),
                items: [
                  for (final d in list)
                    DropdownMenuItem(value: d, child: Text('${d.label} — ${plural(d.items, 'item', 'itens')}')),
                ],
                onChanged: (d) => setState(() {
                  _device = d;
                  _preview = null;
                  _aligned = null;
                }),
              ),
              const SizedBox(height: 16),
              const Text('2. O que estava errado'),
              const SizedBox(height: 6),
              SegmentedButton<_Kind>(
                segments: const [
                  ButtonSegment(value: _Kind.shift, label: Text('A hora')),
                  ButtonSegment(value: _Kind.year, label: Text('O ano')),
                  ButtonSegment(value: _Kind.align, label: Text('Alinhar com outra foto')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _preview = null;
                }),
              ),
              const SizedBox(height: 8),
              switch (_kind) {
                _Kind.shift => Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    DropdownButton<bool>(
                      key: const ValueKey('clock-direction'),
                      value: _ahead,
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Estava adiantado')),
                        DropdownMenuItem(value: false, child: Text('Estava atrasado')),
                      ],
                      onChanged: (v) => setState(() {
                        _ahead = v!;
                        _preview = null;
                      }),
                    ),
                    _num(_h, 'horas'),
                    _num(_m, 'minutos'),
                    _num(_s, 'segundos'),
                  ],
                ),
                _Kind.year => Wrap(
                  spacing: 12,
                  children: [_num(_yearFrom, 'Ano na foto', width: 120), _num(_yearTo, 'Ano certo', width: 120)],
                ),
                _Kind.align => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marque na Biblioteca duas fotos tiradas no mesmo instante: uma deste dispositivo e outra '
                      '(por exemplo, do celular) com a hora certa.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: widget.referenceIds.length == 2 && _device != null ? _align : null,
                      child: Text(
                        widget.referenceIds.length == 2
                            ? 'Calcular pelas 2 fotos marcadas'
                            : 'Marque 2 fotos (${widget.referenceIds.length} marcadas)',
                      ),
                    ),
                    if (_alignInfo != null) Text(_alignInfo!, style: theme.textTheme.bodySmall),
                  ],
                ),
              },
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Só num período (opcional)'),
                children: [
                  Wrap(
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _periodFrom,
                          decoration: const InputDecoration(labelText: 'De (AAAA-MM-DD)', isDense: true),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _periodTo,
                          decoration: const InputDecoration(labelText: 'Até (AAAA-MM-DD)', isDense: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              if (preview != null) ...[
                const Divider(),
                Text(
                  '3. Prévia: ${plural(preview.affected, 'item muda', 'itens mudam')} de hora',
                  style: theme.textTheme.titleSmall,
                  key: const ValueKey('clock-preview'),
                ),
                const SizedBox(height: 6),
                for (final e in preview.examples)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.name}: ${formatWallDateTime(e.before)} → ${formatWallDateTime(e.after)}'),
                        if (e.neighborName != null && e.neighborLocal != null)
                          Text(
                            'fica perto de "${e.neighborName}" (${e.neighborDevice}, ${formatClock(e.neighborLocal!)})',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Momentos com estes itens: ${preview.momentsBefore} antes, ${preview.momentsAfter} depois. '
                  '${plural(preview.itemsChangingMoment, 'item troca', 'itens trocam')} de momento.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        OutlinedButton(
          key: const ValueKey('clock-preview-button'),
          onPressed: _busy || _device == null ? null : _runPreview,
          child: const Text('Ver prévia'),
        ),
        FilledButton(
          key: const ValueKey('clock-apply'),
          onPressed: _busy || preview == null || preview.affected == 0 ? null : _apply,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
