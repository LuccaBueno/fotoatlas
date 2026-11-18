import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../widgets/task_notice.dart';

/// "Extrair zip do Google Takeout…": escolhe os zips e o destino, mostra a
/// prévia e só então extrai pela cópia segura. Os zips só são lidos.
Future<void> takeoutExtractFlow(BuildContext context, WidgetRef ref, SourceView source) async {
  final backend = ref.read(takeoutBackendProvider);
  final zips = await backend.find(source.id);
  if (!context.mounted) return;
  if (zips.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nenhum zip do Google Takeout'),
        content: Text(
          'Não há arquivos "takeout-….zip" em "${source.name}". Baixe o Takeout do Google Fotos, ponha os zips '
          'numa pasta deste dispositivo e escaneie de novo.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }
  final id = await showDialog<String>(
    context: context,
    builder: (_) => _TakeoutDialog(source: source, zips: zips),
  );
  if (id == null || !context.mounted) return;
  showTaskStartedNotice(
    ScaffoldMessenger.of(context),
    ref,
    'Extração iniciada. Acompanhe em Tarefas.',
    key: const ValueKey('takeout-started'),
  );
}

class _TakeoutDialog extends ConsumerStatefulWidget {
  const _TakeoutDialog({required this.source, required this.zips});
  final SourceView source;
  final List<TakeoutZip> zips;

  @override
  ConsumerState<_TakeoutDialog> createState() => _TakeoutDialogState();
}

class _TakeoutDialogState extends ConsumerState<_TakeoutDialog> {
  late final Set<int> _chosen = {for (final z in widget.zips) z.instanceId};
  String? _dest;
  final _folder = TextEditingController(text: TakeoutZips.defaultFolder);
  CopyPreview? _preview;
  bool _busy = false;
  String? _error;

  Future<void> _loadPreview() async {
    final dest = _dest;
    if (dest == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref
          .read(takeoutBackendProvider)
          .preview(
            [
              for (final z in widget.zips)
                if (_chosen.contains(z.instanceId)) z,
            ],
            destSourceId: dest,
            destFolder: _folder.text,
          );
      if (mounted) setState(() => _preview = p);
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível montar a prévia: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final p = _preview!;
    setState(() => _busy = true);
    try {
      final id = await ref.read(backendProvider).startCopy(p);
      if (mounted) Navigator.pop(context, id);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Não foi possível começar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = [
      for (final s in ref.watch(sourcesProvider).value ?? const <SourceView>[])
        if (!s.isPhone && s.isConnected) s,
    ];
    _dest ??= ref.read(primarySourceProvider).value ?? targets.firstOrNull?.id;
    final p = _preview;
    Widget line(IconData icon, String text, {Color? color, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, key: key)),
        ],
      ),
    );

    final List<Widget> body;
    if (p == null) {
      body = [
        const Text(
          'Os zips só são lidos: nada dentro deles muda e eles não são apagados. As fotos, os vídeos e os .json '
          'são copiados para uma pasta, com conferência. As datas e os locais dos .json ficam só no catálogo.',
        ),
        const SizedBox(height: 12),
        Text('Zips', style: theme.textTheme.titleSmall),
        for (final z in widget.zips)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _chosen.contains(z.instanceId),
            onChanged: (v) => setState(() => v == true ? _chosen.add(z.instanceId) : _chosen.remove(z.instanceId)),
            title: Text(z.name),
            subtitle: Text(formatBytes(z.size)),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('takeout-dest'),
          initialValue: targets.any((s) => s.id == _dest) ? _dest : null,
          decoration: const InputDecoration(labelText: 'Para onde'),
          items: [for (final s in targets) DropdownMenuItem(value: s.id, child: Text(s.name))],
          onChanged: (v) => setState(() => _dest = v),
        ),
        TextField(
          controller: _folder,
          decoration: const InputDecoration(labelText: 'Pasta dentro do destino'),
        ),
      ];
    } else {
      final kinds = TakeoutZips.countKinds(p);
      final free = p.freeBytes;
      body = [
        if (p.blocker != null) line(Icons.block, p.blocker!, color: theme.colorScheme.error),
        line(
          Icons.unarchive_outlined,
          'Vai extrair ${plural(p.items.length, 'arquivo', 'arquivos')} (${formatBytes(p.totalBytes)}) para '
          '${p.destDisplay ?? '"${p.destName}"'}: ${plural(kinds.media, 'foto ou vídeo', 'fotos e vídeos')}, '
          '${plural(kinds.json, '.json com data e local', '.json com datas e locais')}'
          '${kinds.other > 0 ? ' e ${plural(kinds.other, 'outro arquivo', 'outros arquivos')}' : ''}.',
          key: const ValueKey('takeout-summary'),
        ),
        line(
          Icons.lock_outline,
          'Os zips só são lidos. Cada arquivo é conferido (CRC do zip e SHA-256) antes de aparecer.',
        ),
        if (p.renamedForConflict > 0)
          line(
            Icons.drive_file_rename_outline,
            '${plural(p.renamedForConflict, 'arquivo tem', 'arquivos têm')} um nome que já existe no destino: '
            '${p.renamedForConflict == 1 ? 'vai' : 'vão'} ganhar _1, _2… no fim do nome. Nada é sobrescrito.',
          ),
        if (p.unavailable.isNotEmpty)
          line(
            Icons.link_off,
            '${plural(p.unavailable.length, 'zip ficou', 'zips ficaram')} de fora: ${p.unavailable.first.reason}',
            color: theme.colorScheme.error,
          ),
        if (p.tooLargeForFat32.isNotEmpty)
          line(
            Icons.block,
            '${plural(p.tooLargeForFat32.length, 'arquivo fica', 'arquivos ficam')} de fora: mais de 4 GB num disco FAT32.',
          ),
        if (free != null)
          line(
            Icons.storage,
            p.enoughSpace
                ? 'Espaço livre no destino: ${formatBytes(free)}.'
                : 'Falta espaço: precisa de ${formatBytes(p.totalBytes + p.reserveBytes)} e o destino tem '
                      '${formatBytes(free)}.',
            color: p.enoughSpace ? null : theme.colorScheme.error,
          ),
      ];
    }
    return AlertDialog(
      title: const Text('Extrair zip do Google Takeout'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...body,
              if (_error != null) line(Icons.error_outline, _error!, color: theme.colorScheme.error),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        if (p != null)
          TextButton(onPressed: _busy ? null : () => setState(() => _preview = null), child: const Text('Voltar')),
        if (p == null)
          FilledButton(
            key: const ValueKey('takeout-preview'),
            onPressed: _busy || _dest == null || _chosen.isEmpty ? null : _loadPreview,
            child: const Text('Ver prévia'),
          )
        else
          FilledButton(
            key: const ValueKey('takeout-start'),
            onPressed: _busy || !p.canStart ? null : _start,
            child: const Text('Extrair'),
          ),
      ],
    );
  }
}
