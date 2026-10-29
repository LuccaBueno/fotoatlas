import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import 'library_strings.dart';

/// Hora definida à mão para um ou mais itens (só no catálogo).
Future<void> showManualDateDialog(BuildContext context, WidgetRef ref, List<int> ids, {DateTime? initial}) async {
  final result = await showDialog<DateTime>(
    context: context,
    builder: (_) => _ManualDateDialog(count: ids.length, initial: initial),
  );
  if (result == null) return;
  await ref.read(libraryBackendProvider).setManualDate(ids, result);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Hora de ${plural(ids.length, 'item', 'itens')} definida para ${formatWallDateTime(result)}. '
          'Só o catálogo mudou; os arquivos ficam como estão.',
        ),
      ),
    );
  }
}

class _ManualDateDialog extends StatefulWidget {
  const _ManualDateDialog({required this.count, this.initial});
  final int count;
  final DateTime? initial;

  @override
  State<_ManualDateDialog> createState() => _ManualDateDialogState();
}

class _ManualDateDialogState extends State<_ManualDateDialog> {
  late final _text = TextEditingController(text: widget.initial == null ? '' : formatWallDateTime(widget.initial!));
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.count == 1 ? 'Corrigir a hora' : 'Corrigir a hora de ${plural(widget.count, 'item', 'itens')}',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('manual-date'),
              controller: _text,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Data e hora (dd/mm/aaaa hh:mm:ss)', errorText: _error),
            ),
            const SizedBox(height: 8),
            Text(
              'A hora fica guardada só no catálogo do FotoAtlas e vale acima de todas as outras. '
              'Os arquivos não são alterados, e dá para voltar à hora original quando quiser.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.count > 1)
              Text(
                'Todos os itens marcados ficam com esta mesma hora. Para adiantar ou atrasar um dispositivo '
                'inteiro, use "Corrigir o relógio de um dispositivo".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('manual-date-save'),
          onPressed: () {
            final d = parseBrDateTime(_text.text);
            if (d == null) {
              setState(() => _error = 'Use o formato 01/05/2024 14:03:12.');
              return;
            }
            Navigator.pop(context, d);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Ações de um momento (cabeçalho na linha do tempo).
Future<void> showMomentMenu(
  BuildContext context,
  WidgetRef ref,
  MomentView moment, {
  required RelativeRect position,
  MomentView? next,
  int? splitAtContentId,
}) async {
  final backend = ref.read(libraryBackendProvider);
  final action = await showMenu<String>(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 'rename', child: Text('Dar nome…')),
      if (next != null) const PopupMenuItem(value: 'merge', child: Text('Juntar com o próximo momento')),
      if (splitAtContentId != null)
        const PopupMenuItem(value: 'split', child: Text('Separar a partir do item selecionado')),
      if (moment.edited) const PopupMenuItem(value: 'reset', child: Text('Voltar ao agrupamento automático')),
    ],
  );
  if (!context.mounted) return;
  try {
    switch (action) {
      case 'rename':
        final name = await _askMomentName(context, moment);
        if (name != null) await backend.renameMoment(moment.id, name.isEmpty ? null : name);
      case 'merge':
        await backend.mergeMoments([moment.id, next!.id]);
      case 'split':
        await backend.splitMoment(moment.id, splitAtContentId!);
      case 'reset':
        await backend.resetMoment(moment.id);
    }
  } on StateError catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<String?> _askMomentName(BuildContext context, MomentView m) {
  final controller = TextEditingController(text: m.name ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nome do momento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(momentTitle(m), style: Theme.of(context).textTheme.bodySmall),
          TextField(
            key: const ValueKey('moment-name'),
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Ex.: Aniversário da Ana'),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          const SizedBox(height: 8),
          Text(
            'Um momento com nome fica fixo: novos agrupamentos não o desfazem. Só muda o catálogo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('moment-name-save'),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// "01/05/2024 14:03:12" ou "01/05/2024 14:03" → hora de relógio; `null` se inválida.
DateTime? parseBrDateTime(String s) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(s.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i) ?? '0');
  if (g(4) > 23 || g(5) > 59 || g(6) > 59) return null;
  final d = DateTime.utc(g(3), g(2), g(1), g(4), g(5), g(6));
  if (d.day != g(1) || d.month != g(2)) return null;
  return d;
}
