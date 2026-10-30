import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../tasks/tasks_page.dart' show exportOperationReport;

/// Situação de uma reorganização (ou de um Desfazer), em palavras simples.
String reorgStatusLabel(OperationView o) => switch (o.status) {
  OpStatus.confirmed => 'Na fila',
  OpStatus.running => o.kind == OpKind.undo ? 'Devolvendo' : 'Movendo',
  OpStatus.paused => 'Pausada',
  OpStatus.completed when o.kind == OpKind.undo => 'Concluído — tudo devolvido ao lugar de antes',
  OpStatus.completed when o.undone > 0 && o.undone == o.totalItems => 'Desfeita — tudo voltou ao lugar de antes',
  OpStatus.completed => 'Concluída — tudo movido',
  OpStatus.completedWithErrors => 'Concluída, com arquivos que não foram movidos',
  OpStatus.cancelled when o.undone > 0 => 'Desfeita',
  OpStatus.cancelled => 'Cancelada',
  OpStatus.needsAttention => 'Precisa da sua decisão',
  _ => o.status,
};

/// Cartão de uma reorganização ou de um Desfazer na tela Tarefas.
class ReorgOperationCard extends ConsumerStatefulWidget {
  const ReorgOperationCard({super.key, required this.op, required this.all});
  final OperationView op;

  /// Todas as operações (para saber se já há um Desfazer em andamento).
  final List<OperationView> all;

  @override
  ConsumerState<ReorgOperationCard> createState() => _ReorgOperationCardState();
}

class _ReorgOperationCardState extends ConsumerState<ReorgOperationCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.op.needsAttention > 0 && widget.op.isOpen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final o = widget.op;
    final isUndo = o.kind == OpKind.undo;
    final backend = ref.read(backendProvider);
    final progress = ref.watch(reorgProgressProvider).value;
    final live = progress != null && progress.operationId == o.id && progress.running ? progress : null;
    final (icon, color) = switch (o.status) {
      OpStatus.completed => (isUndo ? Icons.undo : Icons.check_circle, colors.verified),
      OpStatus.running || OpStatus.confirmed => (Icons.sync, theme.colorScheme.primary),
      OpStatus.paused => (Icons.pause_circle, colors.attention),
      OpStatus.needsAttention || OpStatus.completedWithErrors => (Icons.error_outline, colors.attention),
      _ => (Icons.cancel_outlined, colors.unknown),
    };
    final where = o.destFolder.isEmpty ? o.destName : '${o.destName} › ${folderLabel(o.destFolder)}';
    final openUndo = widget.all.any((u) => u.undoOf == o.id && u.isOpen);
    final running = o.status == OpStatus.running || o.status == OpStatus.confirmed;
    final canUndo = !isUndo && !running && !openUndo && o.published > 0;
    final total = o.totalItems == 0 ? 1 : o.totalItems;
    final fraction = live != null && live.itemsTotal > 0
        ? live.itemsDone / live.itemsTotal
        : (total - o.remaining) / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUndo ? 'Desfazer a reorganização de "$where"' : 'Reorganização de "$where"',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${reorgStatusLabel(o)} · ${formatDateTime(o.createdAt)} · '
                        '${plural(o.totalItems, 'arquivo', 'arquivos')}'
                        '${!isUndo && o.template != null ? ' · ${_templateLabel(o.template!)}' : ''}',
                        key: ValueKey('op-status-${o.id}'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (o.isOpen) ...[LinearProgressIndicator(value: fraction.clamp(0.0, 1.0)), const SizedBox(height: 6)],
            Text(
              [
                plural(o.published, isUndo ? 'devolvido' : 'movido', isUndo ? 'devolvidos' : 'movidos'),
                if (o.undone > 0) '${formatInt(o.undone)} já ${o.undone == 1 ? 'voltou' : 'voltaram'} (Desfazer)',
                if (o.skipped > 0) plural(o.skipped, 'deixado onde estava', 'deixados onde estavam'),
                if (o.failed > 0)
                  plural(o.failed, isUndo ? 'não devolvido' : 'não movido', isUndo ? 'não devolvidos' : 'não movidos'),
                if (o.needsAttention > 0) '${formatInt(o.needsAttention)} esperando a sua decisão',
                if (o.remaining > 0) o.remaining == 1 ? 'falta 1' : 'faltam ${formatInt(o.remaining)}',
              ].join(' · '),
              key: ValueKey('op-counts-${o.id}'),
            ),
            if (o.status == OpStatus.paused)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  o.pauseReason ?? 'Pausada por você. O que já foi movido está registrado; o resto espera "Continuar".',
                  key: ValueKey('op-reason-${o.id}'),
                  style: TextStyle(color: o.pauseReason == null ? null : colors.attention),
                ),
              ),
            if (openUndo)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Há um Desfazer desta reorganização em andamento (veja abaixo).',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (running)
                  OutlinedButton.icon(
                    key: ValueKey('op-pause-${o.id}'),
                    onPressed: () => backend.pauseReorg(o.id),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  ),
                if (o.status == OpStatus.paused || (o.status == OpStatus.needsAttention && o.remaining > 0))
                  FilledButton.icon(
                    key: ValueKey('op-resume-${o.id}'),
                    onPressed: () => backend.resumeReorg(o.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                if (o.isOpen)
                  TextButton(
                    key: ValueKey('op-cancel-${o.id}'),
                    onPressed: () => backend.cancelReorg(o.id),
                    child: Text(isUndo ? 'Parar de devolver' : 'Não mover o que falta'),
                  ),
                if (o.failed > 0)
                  OutlinedButton.icon(
                    key: ValueKey('op-retry-${o.id}'),
                    onPressed: () => backend.retryFailedReorg(o.id),
                    icon: const Icon(Icons.refresh),
                    label: Text(isUndo ? 'Tentar de novo os não devolvidos' : 'Tentar de novo os não movidos'),
                  ),
                if (canUndo)
                  Tooltip(
                    message:
                        'Devolve cada arquivo ao lugar exato de antes. Mostra antes o que vai acontecer; arquivo que '
                        'mudou desde a reorganização só volta se você confirmar.',
                    child: FilledButton.tonalIcon(
                      key: ValueKey('op-undo-${o.id}'),
                      onPressed: () => _undo(context, o),
                      icon: const Icon(Icons.undo),
                      label: const Text('Desfazer…'),
                    ),
                  ),
                if (!o.isOpen && (o.published > 0 || o.undone > 0))
                  Tooltip(
                    message: 'Lista as pastas que ficaram vazias. Você escolhe quais remover; nada sai sem confirmar.',
                    child: TextButton.icon(
                      key: ValueKey('op-empty-${o.id}'),
                      onPressed: () => _emptyFolders(context, o),
                      icon: const Icon(Icons.folder_off_outlined),
                      label: const Text('Remover pastas vazias…'),
                    ),
                  ),
                TextButton.icon(
                  key: ValueKey('op-details-${o.id}'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? 'Esconder detalhes' : 'Detalhes'),
                ),
                TextButton.icon(
                  key: ValueKey('op-export-${o.id}'),
                  onPressed: () => exportOperationReport(context, ref, o),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar relatório…'),
                ),
              ],
            ),
            if (_expanded) _ReorgDetails(op: o),
          ],
        ),
      ),
    );
  }

  static String _templateLabel(String pattern) =>
      FolderTemplate.byPattern(pattern)?.label.split(' (').first ?? 'modelo "$pattern"';

  Future<void> _undo(BuildContext context, OperationView o) async {
    final backend = ref.read(backendProvider);
    final messenger = ScaffoldMessenger.of(context);
    final check = await backend.undoPreview(o.id);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => UndoConfirmDialog(check: check),
    );
    if (ok != true) return;
    try {
      await backend.undoReorg(o.id);
      messenger.showSnackBar(const SnackBar(content: Text('Desfazendo. Acompanhe aqui em Tarefas.')));
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _emptyFolders(BuildContext context, OperationView o) async {
    final backend = ref.read(backendProvider);
    final messenger = ScaffoldMessenger.of(context);
    final folders = await backend.emptyFolders(o.id);
    if (!context.mounted) return;
    final chosen = await showDialog<List<String>>(
      context: context,
      builder: (_) => EmptyFoldersDialog(sourceName: o.destName, folders: folders),
    );
    if (chosen == null || chosen.isEmpty) return;
    final n = await backend.removeEmptyFolders(o.id, chosen);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n == chosen.length
              ? '${plural(n, 'pasta vazia removida', 'pastas vazias removidas')}.'
              : '${plural(n, 'pasta removida', 'pastas removidas')}; '
                    '${plural(chosen.length - n, 'não estava', 'não estavam')} mais vazia${chosen.length - n == 1 ? '' : 's'} '
                    'e ${chosen.length - n == 1 ? 'ficou' : 'ficaram'}.',
        ),
      ),
    );
  }
}

/// Confirmação do Desfazer, com o que vai acontecer arquivo por arquivo.
class UndoConfirmDialog extends StatelessWidget {
  const UndoConfirmDialog({super.key, required this.check});
  final UndoPreview check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final c = check;
    Widget section(String key, IconData icon, Color? color, String text, List<String> paths) => Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: TextStyle(color: color)),
              ),
            ],
          ),
          for (final p in paths.take(8))
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(folderLabel(p), style: theme.textTheme.bodySmall),
            ),
          if (paths.length > 8)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text('e mais ${paths.length - 8}', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
    return AlertDialog(
      key: const ValueKey('undo-dialog'),
      title: const Text('Desfazer a reorganização?'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.blocker != null)
                Text(c.blocker!, style: TextStyle(color: colors.attention))
              else ...[
                Text(
                  c.ready == 0
                      ? 'Nenhum arquivo pode voltar sozinho agora.'
                      : '${plural(c.ready, 'arquivo volta', 'arquivos voltam')} para o lugar exato de antes.',
                  key: const ValueKey('undo-ready'),
                ),
                if (c.changed.isNotEmpty)
                  section(
                    'undo-changed',
                    Icons.warning_amber,
                    colors.single,
                    '${plural(c.changed.length, 'arquivo mudou', 'arquivos mudaram')} depois da reorganização (tamanho '
                        'ou data diferente, talvez editado em outro programa). ${c.changed.length == 1 ? 'Ele não volta' : 'Eles não voltam'} '
                        'sem a sua confirmação: ${c.changed.length == 1 ? 'vai' : 'vão'} esperar a sua decisão em Tarefas.',
                    c.changed,
                  ),
                if (c.occupied.isNotEmpty)
                  section(
                    'undo-occupied',
                    Icons.help_outline,
                    colors.attention,
                    '${plural(c.occupied.length, 'lugar de antes já tem', 'lugares de antes já têm')} outro arquivo: '
                        'nada é sobrescrito; ${c.occupied.length == 1 ? 'o arquivo espera' : 'os arquivos esperam'} a sua decisão.',
                    c.occupied,
                  ),
                if (c.missing.isNotEmpty)
                  section(
                    'undo-missing',
                    Icons.link_off,
                    colors.attention,
                    '${plural(c.missing.length, 'arquivo não está', 'arquivos não estão')} mais onde a reorganização '
                        '${c.missing.length == 1 ? 'o deixou' : 'os deixou'} (movido ou apagado depois): nada a devolver.',
                    c.missing,
                  ),
                const SizedBox(height: 12),
                Text(
                  'As pastas que a reorganização criou ficam (vazias). Depois, "Remover pastas vazias…" mostra cada '
                  'uma para você decidir.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton.icon(
          key: const ValueKey('undo-confirm'),
          onPressed: c.canStart ? () => Navigator.pop(context, true) : null,
          icon: const Icon(Icons.undo),
          label: const Text('Desfazer'),
        ),
      ],
    );
  }
}

/// Lista cada pasta vazia para a pessoa escolher; devolve as escolhidas.
class EmptyFoldersDialog extends StatefulWidget {
  const EmptyFoldersDialog({super.key, required this.sourceName, required this.folders});
  final String sourceName;
  final List<EmptyFolder> folders;

  @override
  State<EmptyFoldersDialog> createState() => _EmptyFoldersDialogState();
}

class _EmptyFoldersDialogState extends State<EmptyFoldersDialog> {
  late final Set<String> _chosen = {
    for (final f in widget.folders)
      if (f.empty) f.relPath,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = widget.folders.where((f) => f.empty).toList();
    final hidden = widget.folders.where((f) => !f.empty).toList();
    return AlertDialog(
      key: const ValueKey('empty-folders-dialog'),
      title: const Text('Remover pastas vazias'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                empty.isEmpty
                    ? 'Nenhuma pasta vazia: nada a remover.'
                    : 'Estas pastas de "${widget.sourceName}" estão vazias (sem nenhum arquivo, nem oculto). Só as '
                          'marcadas são removidas, e cada uma é conferida de novo na hora: se aparecer algo dentro, ela fica.',
              ),
              const SizedBox(height: 8),
              for (final f in empty)
                CheckboxListTile(
                  key: ValueKey('empty-${f.relPath}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _chosen.contains(f.relPath),
                  title: Text(folderLabel(f.relPath)),
                  onChanged: (v) => setState(() => v == true ? _chosen.add(f.relPath) : _chosen.remove(f.relPath)),
                ),
              if (hidden.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${plural(hidden.length, 'pasta parece vazia, mas tem', 'pastas parecem vazias, mas têm')} arquivos '
                  'ocultos ou de sistema (ex.: Thumbs.db): ${hidden.length == 1 ? 'fica' : 'ficam'}.',
                  style: theme.textTheme.bodySmall,
                ),
                for (final f in hidden)
                  Padding(
                    key: ValueKey('hidden-${f.relPath}'),
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(folderLabel(f.relPath), style: theme.textTheme.bodySmall),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('empty-confirm'),
          onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, _chosen.toList()),
          child: Text('Remover ${plural(_chosen.length, 'pasta vazia', 'pastas vazias')}'),
        ),
      ],
    );
  }
}

/// Arquivo por arquivo: o que espera decisão, o que não foi movido e por quê,
/// os renomeados e os movidos.
class _ReorgDetails extends ConsumerWidget {
  const _ReorgDetails({required this.op});
  final OperationView op;

  static const _limit = 2000;
  static const _shown = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final backend = ref.read(backendProvider);
    final isUndo = op.kind == OpKind.undo;
    ref.watch(operationsProvider);
    return FutureBuilder(
      future: backend.operationItems(op.id, limit: _limit),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
        final items = snap.data!;
        final waiting = items.where((i) => i.state == ItemState.needsAttention).toList();
        final notMoved = items
            .where((i) => i.state == ItemState.failed || i.state == ItemState.skippedIdentical)
            .toList();
        final moved = items.where((i) => i.state == ItemState.published || i.state == undoneState).toList();
        final renamed = moved.where((i) => i.renamedForConflict).toList();
        Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(text, style: theme.textTheme.titleSmall),
        );
        Widget row(OperationItemView i, IconData icon, String text, {Color? color, String prefix = 'op-file'}) =>
            Padding(
              key: ValueKey('$prefix-${i.id}'),
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
                  ),
                ],
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            if (waiting.isNotEmpty) heading('Esperando a sua decisão'),
            for (final i in waiting)
              ListTile(
                key: ValueKey('op-item-${i.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i.errorCode == 'changed_since_reorg' ? Icons.warning_amber : Icons.help_outline,
                  color: i.errorCode == 'changed_since_reorg' ? colors.single : colors.attention,
                ),
                title: Text(folderLabel(i.srcRelPath)),
                subtitle: Text(i.errorMessage ?? ''),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (i.errorCode == 'changed_since_reorg')
                      TextButton(
                        key: ValueKey('decide-back-${i.id}'),
                        onPressed: () => backend.resolveReorg(i.id, ReorgDecision.moveAnyway),
                        child: const Text('Devolver mesmo assim'),
                      ),
                    if (i.errorCode == 'name_conflict')
                      TextButton(
                        key: ValueKey('decide-rename-${i.id}'),
                        onPressed: () => backend.resolveReorg(i.id, ReorgDecision.rename),
                        child: const Text('Mover com outro nome'),
                      ),
                    if (i.errorCode == 'recovery_unknown')
                      TextButton(
                        key: ValueKey('decide-retry-${i.id}'),
                        onPressed: () => backend.resolveReorg(i.id, ReorgDecision.retry),
                        child: const Text('Conferir de novo'),
                      ),
                    TextButton(
                      key: ValueKey('decide-leave-${i.id}'),
                      onPressed: () => backend.resolveReorg(i.id, ReorgDecision.leave),
                      child: const Text('Deixar onde está'),
                    ),
                  ],
                ),
              ),
            if (notMoved.isNotEmpty) ...[
              heading(
                isUndo
                    ? 'Não devolvidos (${formatInt(notMoved.length)})'
                    : 'Não movidos (${formatInt(notMoved.length)})',
              ),
              for (final i in notMoved)
                row(
                  i,
                  i.state == ItemState.failed ? Icons.error_outline : Icons.remove_circle_outline,
                  '${folderLabel(i.srcRelPath)}: ${i.errorMessage ?? 'não deu certo (sem detalhe)'}',
                  color: i.state == ItemState.failed ? colors.attention : null,
                  prefix: 'op-not-moved',
                ),
            ],
            if (renamed.isNotEmpty) ...[
              heading('${plural(renamed.length, 'arquivo ficou', 'arquivos ficaram')} com outro nome'),
              for (final i in renamed)
                row(
                  i,
                  Icons.drive_file_rename_outline,
                  '${i.srcName} → ${i.dstName} porque o nome já existia em ${folderLabel(_dir(i.dstRelPath))} '
                  '(o arquivo que já estava lá não foi mexido).',
                  color: colors.attention,
                  prefix: 'op-renamed',
                ),
            ],
            if (moved.isNotEmpty) ...[
              heading(plural(moved.length, isUndo ? 'devolvido' : 'movido', isUndo ? 'devolvidos' : 'movidos')),
              for (final i in moved.take(_shown))
                row(
                  i,
                  i.state == undoneState ? Icons.undo : Icons.check,
                  '${folderLabel(i.srcRelPath)} → ${folderLabel(i.dstRelPath)}'
                  '${i.state == undoneState ? ' (já voltou pelo Desfazer)' : ''}',
                  prefix: 'op-moved',
                ),
              if (moved.length > _shown)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    'e mais ${plural(moved.length - _shown, 'arquivo', 'arquivos')}. A lista completa está no relatório.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  static String _dir(String rel) {
    final i = rel.lastIndexOf('/');
    return i < 0 ? '' : rel.substring(0, i);
  }
}
