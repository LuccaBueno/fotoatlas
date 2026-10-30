import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../reorg/reorg_card.dart';

/// Situação de uma operação, em palavras simples.
String operationStatusLabel(String status) => switch (status) {
  OpStatus.confirmed => 'Na fila',
  OpStatus.running => 'Copiando',
  OpStatus.paused => 'Pausada',
  OpStatus.completed => 'Concluída — tudo conferido',
  OpStatus.completedWithErrors => 'Concluída, com arquivos que não foram copiados',
  OpStatus.cancelled => 'Cancelada',
  OpStatus.needsAttention => 'Precisa da sua decisão',
  _ => status,
};

/// Situação de um arquivo da cópia.
String itemStateLabel(String state) => switch (state) {
  ItemState.published => 'Copiado e conferido',
  ItemState.skippedIdentical => 'Não copiado: já estava no destino (ou você escolheu não copiar)',
  ItemState.failed => 'Não copiado',
  ItemState.needsAttention => 'Esperando a sua decisão',
  ItemState.pending => 'Na fila',
  _ => 'Em andamento',
};

/// Tela Tarefas (spec §3.2): cópias em andamento, o que precisa de decisão e o
/// histórico de tudo o que foi gravado.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ops = ref.watch(operationsProvider);
    return Scaffold(
      body: ops.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar as tarefas: $e')),
        data: (list) {
          final open = list.where((o) => o.isOpen).toList();
          final done = list.where((o) => !o.isOpen).toList();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Tarefas', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Cópias e reorganizações em andamento e o histórico de tudo o que o FotoAtlas gravou ou moveu. Toda '
                'cópia é conferida pelo conteúdo antes de aparecer no destino; nada é sobrescrito nem apagado, e uma '
                'reorganização pode ser desfeita.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma tarefa ainda. Para copiar o que falta, use "Copiar para B…" em Comparar ou '
                      '"Copiar para…" com itens marcados na Biblioteca. Para organizar as pastas de um disco, use '
                      '"Reorganizar…" no cartão dele em Dispositivos.',
                      key: ValueKey('tasks-empty'),
                    ),
                  ),
                ),
              if (open.isNotEmpty) ...[
                Text('Em andamento ou esperando você', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final o in open) _card(o, list),
                const SizedBox(height: 16),
              ],
              if (done.isNotEmpty) ...[
                Text('Histórico', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final o in done) _card(o, list),
              ],
            ],
          );
        },
      ),
    );
  }
}

Widget _card(OperationView o, List<OperationView> all) => o.kind == 'copy'
    ? OperationCard(key: ValueKey('op-${o.id}'), op: o)
    : ReorgOperationCard(key: ValueKey('op-${o.id}'), op: o, all: all);

class OperationCard extends ConsumerStatefulWidget {
  const OperationCard({super.key, required this.op});
  final OperationView op;

  @override
  ConsumerState<OperationCard> createState() => _OperationCardState();
}

class _OperationCardState extends ConsumerState<OperationCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // O que precisa de decisão já aparece aberto.
    _expanded = widget.op.needsAttention > 0 && widget.op.isOpen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final o = widget.op;
    final backend = ref.read(backendProvider);
    final progress = ref.watch(copyProgressProvider).value;
    final live = progress != null && progress.operationId == o.id && progress.running ? progress : null;
    final (icon, color) = switch (o.status) {
      OpStatus.completed => (Icons.check_circle, colors.verified),
      OpStatus.running || OpStatus.confirmed => (Icons.sync, theme.colorScheme.primary),
      OpStatus.paused => (Icons.pause_circle, colors.attention),
      OpStatus.needsAttention || OpStatus.completedWithErrors => (Icons.error_outline, colors.attention),
      _ => (Icons.cancel_outlined, colors.unknown),
    };
    final where = o.destFolder.isEmpty ? o.destName : '${o.destName} › ${folderLabel(o.destFolder)}';
    final done = o.published + o.skipped;
    final fraction = live != null && live.bytesTotal > 0
        ? (live.bytesDone + live.currentBytes) / live.bytesTotal
        : o.totalBytes > 0
        ? o.doneBytes / o.totalBytes
        : 0.0;

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
                      Text('Cópia para "$where"', style: theme.textTheme.titleMedium),
                      Text(
                        '${operationStatusLabel(o.status)} · ${formatDateTime(o.createdAt)} · '
                        '${plural(o.totalItems, 'arquivo', 'arquivos')} (${formatBytes(o.totalBytes)})',
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
                plural(o.published, 'copiado e conferido', 'copiados e conferidos'),
                if (o.skipped > 0) '${formatInt(o.skipped)} já estavam lá',
                if (o.failed > 0) plural(o.failed, 'não copiado', 'não copiados'),
                if (o.needsAttention > 0) '${formatInt(o.needsAttention)} esperando a sua decisão',
                if (o.remaining > 0) o.remaining == 1 ? 'falta 1' : 'faltam ${formatInt(o.remaining)}',
              ].join(' · '),
              key: ValueKey('op-counts-${o.id}'),
            ),
            if (live?.currentName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${live!.step == 'verifying' ? 'Conferindo' : 'Copiando'} "${live.currentName}" '
                  '(${formatBytes(live.currentBytes)} de ${formatBytes(live.currentSize)})',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (o.status == OpStatus.paused && o.pauseReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  o.pauseReason!,
                  key: ValueKey('op-reason-${o.id}'),
                  style: TextStyle(color: colors.attention),
                ),
              ),
            if (o.status == OpStatus.paused && o.pauseReason == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Pausada por você. O que já foi copiado está conferido; o resto espera "Continuar".'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (o.status == OpStatus.running || o.status == OpStatus.confirmed)
                  OutlinedButton.icon(
                    key: ValueKey('op-pause-${o.id}'),
                    onPressed: () => backend.pauseCopy(o.id),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  ),
                if (o.status == OpStatus.paused || (o.status == OpStatus.needsAttention && o.remaining > 0))
                  FilledButton.icon(
                    key: ValueKey('op-resume-${o.id}'),
                    onPressed: () => backend.resumeCopy(o.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                if (o.isOpen)
                  TextButton(
                    key: ValueKey('op-cancel-${o.id}'),
                    onPressed: () => _confirmCancel(context, o),
                    child: const Text('Cancelar o que falta'),
                  ),
                if (o.failed > 0)
                  OutlinedButton.icon(
                    key: ValueKey('op-retry-${o.id}'),
                    onPressed: () async {
                      final n = await backend.retryFailedCopies(o.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${plural(n, 'arquivo voltou', 'arquivos voltaram')} para a fila.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar de novo os que não foram copiados'),
                  ),
                TextButton.icon(
                  key: ValueKey('op-details-${o.id}'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? 'Esconder detalhes' : 'Detalhes'),
                ),
                TextButton.icon(
                  key: ValueKey('op-export-${o.id}'),
                  onPressed: () => _export(context, o),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar relatório…'),
                ),
              ],
            ),
            if (_expanded) _Details(op: o, done: done),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, OperationView o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar o que falta?'),
        content: const Text(
          'Os arquivos que ainda não foram copiados ficam de fora. O que já foi copiado e conferido continua no '
          'destino (nada é apagado).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(
            key: const ValueKey('op-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar o que falta'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(backendProvider).cancelCopy(o.id);
  }

  Future<void> _export(BuildContext context, OperationView o) => exportOperationReport(context, ref, o);
}

/// Salva o relatório (CSV) de uma operação num arquivo novo escolhido pela pessoa.
Future<void> exportOperationReport(BuildContext context, WidgetRef ref, OperationView o) async {
  final messenger = ScaffoldMessenger.of(context);
  final csv = await ref.read(backendProvider).exportOperation(o.id);
  final stamp = o.createdAt.toLocal().toIso8601String().substring(0, 16).replaceAll(RegExp('[-:T]'), '');
  final kind = switch (o.kind) {
    'reorganize_move' => 'reorganizacao',
    'undo' => 'desfazer',
    _ => 'copia',
  };
  final location = await getSaveLocation(
    suggestedName: 'fotoatlas-$kind-$stamp.csv',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Planilha (CSV)', extensions: ['csv']),
    ],
  );
  if (location == null) return;
  try {
    // Nunca sobrescreve (regra 5): o arquivo precisa ser novo.
    final file = File(location.path);
    await file.create(exclusive: true);
    await file.writeAsString(csv, flush: true);
    messenger.showSnackBar(SnackBar(content: Text('Relatório salvo em ${location.path}')));
  } on FileSystemException {
    messenger.showSnackBar(
      const SnackBar(content: Text('Já existe um arquivo com esse nome. Escolha outro nome (nada foi sobrescrito).')),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.op, required this.done});
  final OperationView op;
  final int done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backend = ref.read(backendProvider);
    // Recarrega quando a lista de operações muda.
    ref.watch(operationsProvider);
    final colors = StatusColors.of(context);
    return FutureBuilder(
      future: Future.wait([
        backend.operationItems(op.id, limit: _detailsLimit),
        if (op.destSourceId != null) backend.tempLeftovers(op.destSourceId!),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
        final items = snap.data![0] as List<OperationItemView>;
        final leftovers = snap.data!.length > 1 ? snap.data![1] as List<TempLeftover>? : null;
        final problems = items.where((i) => i.state == ItemState.needsAttention).toList();
        final notCopied = items
            .where((i) => i.state == ItemState.failed || i.state == ItemState.skippedIdentical)
            .toList();
        final published = items.where((i) => i.state == ItemState.published).toList();
        final renamed = published.where((i) => i.renamedForConflict || i.originalName != null).toList();
        Widget heading(String text, Key key) => Padding(
          key: key,
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(text, style: theme.textTheme.titleSmall),
        );
        Widget row(OperationItemView i, IconData icon, String text, {Color? color, String? prefix}) => Padding(
          key: ValueKey('${prefix ?? 'op-file'}-${i.id}'),
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
            if (problems.isEmpty && notCopied.isEmpty)
              Text(
                done == op.totalItems
                    ? 'Todos os arquivos foram copiados e conferidos (ou já estavam no destino).'
                    : 'Nenhum problema até agora.',
              ),
            if (problems.isNotEmpty) heading('Esperando a sua decisão', const ValueKey('op-problems-heading')),
            for (final i in problems)
              ListTile(
                key: ValueKey('op-item-${i.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: Text(folderLabel(i.srcRelPath)),
                subtitle: Text(
                  '${itemStateLabel(i.state)}${i.errorMessage == null ? '' : ': ${i.errorMessage}'}'
                  '\nDestino: ${folderLabel(i.dstRelPath)}',
                ),
                trailing: i.errorCode == 'name_conflict'
                    ? Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            key: ValueKey('conflict-rename-${i.id}'),
                            onPressed: () => backend.resolveConflict(i.id, rename: true),
                            child: const Text('Copiar com outro nome'),
                          ),
                          TextButton(
                            key: ValueKey('conflict-skip-${i.id}'),
                            onPressed: () => backend.resolveConflict(i.id, rename: false),
                            child: const Text('Não copiar'),
                          ),
                        ],
                      )
                    : null,
              ),
            if (renamed.isNotEmpty) ...[
              heading(
                '${plural(renamed.length, 'arquivo salvo', 'arquivos salvos')} com outro nome',
                const ValueKey('op-renamed-heading'),
              ),
              for (final i in renamed)
                row(i, Icons.drive_file_rename_outline, _renamedText(i), color: colors.attention, prefix: 'op-renamed'),
            ],
            if (notCopied.isNotEmpty) ...[
              heading('Não copiados (${formatInt(notCopied.length)})', const ValueKey('op-not-copied-heading')),
              for (final i in notCopied)
                i.state == ItemState.failed
                    ? row(i, Icons.error_outline, _failedText(i), color: colors.single, prefix: 'op-item')
                    : row(i, Icons.remove_circle_outline, _skippedText(i), prefix: 'op-skipped'),
            ],
            if (published.isNotEmpty) ...[
              heading(
                plural(published.length, 'copiado e conferido', 'copiados e conferidos'),
                const ValueKey('op-copied-heading'),
              ),
              for (final i in published.take(_copiedShown))
                row(
                  i,
                  Icons.check,
                  '${i.srcName} → ${folderLabel(i.dstRelPath)}',
                  color: i.renamedForConflict ? colors.attention : null,
                  prefix: 'op-copied',
                ),
              if (published.length > _copiedShown)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    'e mais ${plural(published.length - _copiedShown, 'arquivo', 'arquivos')}. '
                    'A lista completa está no relatório (Exportar relatório…).',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (items.length >= _detailsLimit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Mostrando os primeiros ${formatInt(_detailsLimit)} arquivos da cópia. '
                  'Use "Exportar relatório…" para ver todos.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (leftovers != null && leftovers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Arquivos na pasta temporária do destino', style: theme.textTheme.titleSmall),
              Text(
                'Estes arquivos estão na pasta ".fotoatlas-tmp" de "${op.destName}" e não pertencem a nenhuma cópia em '
                'andamento. O FotoAtlas nunca os apaga sozinho: confira e, se não precisar, apague você mesmo.',
                style: theme.textTheme.bodySmall,
              ),
              for (final l in leftovers)
                Padding(
                  key: ValueKey('leftover-${l.name}'),
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    '${l.name} — ${formatBytes(l.size)}, ${formatDateTime(l.modified)}${l.note == null ? '' : ' (${l.note})'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Quantos itens os detalhes carregam (o relatório tem todos).
  static const _detailsLimit = 2000;

  /// Quantos "copiados" aparecem antes do "e mais N".
  static const _copiedShown = 200;

  /// "IMG.jpg → salvo como IMG_1.jpg (em 2024 › 05) porque o nome já existia na pasta."
  static String _renamedText(OperationItemView i) {
    final why = [
      if (i.originalName != null) 'o Windows não aceita alguns caracteres do nome original',
      if (i.renamedForConflict) 'o nome já existia na pasta (o arquivo que já estava lá não foi mexido)',
    ].join(' e ');
    final slash = i.dstRelPath.lastIndexOf('/');
    final dir = slash < 0 ? '' : ' (em ${folderLabel(i.dstRelPath.substring(0, slash))})';
    return '${i.srcName} → salvo como ${i.dstName}$dir porque $why.';
  }

  static String _skippedText(OperationItemView i) => i.errorCode == 'skipped_by_user'
      ? '${i.srcName}: você escolheu não copiar (já existia outro arquivo com esse nome no destino).'
      : '${i.srcName}: o destino já tinha este arquivo, idêntico (${folderLabel(i.dstRelPath)}).';

  static String _failedText(OperationItemView i) =>
      '${folderLabel(i.srcRelPath)}: ${i.errorMessage ?? 'não deu certo (sem detalhe)'}';
}
