import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../tasks/tasks_page.dart' show exportOperationReport;

/// Situação de uma limpeza de repetidos, em palavras simples.
String dedupeStatusLabel(OperationView o) => switch (o.status) {
  OpStatus.confirmed => 'Na fila',
  OpStatus.running => 'Conferindo e enviando para a Lixeira',
  OpStatus.paused => 'Pausada',
  OpStatus.completed => 'Concluída — as cópias repetidas foram para a Lixeira',
  OpStatus.completedWithErrors => 'Concluída, com grupos que ficaram como estavam',
  OpStatus.cancelled => 'Cancelada (o que já foi para a Lixeira fica lá)',
  OpStatus.needsAttention => 'Precisa da sua decisão',
  _ => o.status,
};

/// Cartão de uma limpeza de repetidos na tela Tarefas: progresso, o que foi
/// para a Lixeira, os grupos pulados com o motivo e o relatório.
class DedupeOperationCard extends ConsumerStatefulWidget {
  const DedupeOperationCard({super.key, required this.op});
  final OperationView op;

  @override
  ConsumerState<DedupeOperationCard> createState() => _DedupeOperationCardState();
}

class _DedupeOperationCardState extends ConsumerState<DedupeOperationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final o = widget.op;
    final dedupe = ref.read(dedupeBackendProvider);
    final progress = ref.watch(dedupeProgressProvider).value;
    final live = progress != null && progress.operationId == o.id && progress.running ? progress : null;
    final (icon, color) = switch (o.status) {
      OpStatus.completed => (Icons.check_circle, colors.verified),
      OpStatus.running || OpStatus.confirmed => (Icons.sync, theme.colorScheme.primary),
      OpStatus.paused => (Icons.pause_circle, colors.attention),
      OpStatus.needsAttention || OpStatus.completedWithErrors => (Icons.error_outline, colors.attention),
      _ => (Icons.cancel_outlined, colors.unknown),
    };
    final running = o.status == OpStatus.running || o.status == OpStatus.confirmed;
    final done = o.published + o.failed;
    final recycledBytes = o.doneBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Limpeza de repetidos em "${o.destName}"', style: theme.textTheme.titleMedium),
                      Text(
                        '${dedupeStatusLabel(o)} · ${formatDateTime(o.createdAt)}',
                        key: ValueKey('dedupe-op-status-${o.id}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (running && o.totalItems > 0) ...[
              LinearProgressIndicator(value: done / o.totalItems),
              const SizedBox(height: 4),
              Text(
                live?.currentName == null
                    ? '${formatInt(done)} de ${plural(o.totalItems, 'arquivo', 'arquivos')}'
                    : '${live!.step == 'checking' ? 'Conferindo' : 'Enviando para a Lixeira'}: ${live.currentName}',
              ),
            ],
            Text(
              key: ValueKey('dedupe-op-counts-${o.id}'),
              '${plural(o.published, 'arquivo foi', 'arquivos foram')} para a Lixeira '
              '(${formatBytes(recycledBytes)})'
              '${o.failed > 0 ? ' · ${plural(o.failed, 'arquivo ficou', 'arquivos ficaram')} no lugar' : ''}'
              '${o.remaining > 0 ? ' · ${plural(o.remaining, 'falta', 'faltam')}' : ''}.',
            ),
            if (o.pauseReason != null) Text(o.pauseReason!, style: TextStyle(color: colors.attention)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (running)
                  OutlinedButton.icon(
                    key: ValueKey('dedupe-op-pause-${o.id}'),
                    onPressed: () => dedupe.pause(o.id),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  ),
                if (o.status == OpStatus.paused)
                  FilledButton.icon(
                    key: ValueKey('dedupe-op-resume-${o.id}'),
                    onPressed: () => dedupe.resume(o.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                if (o.isOpen)
                  TextButton.icon(
                    key: ValueKey('dedupe-op-cancel-${o.id}'),
                    onPressed: () => dedupe.cancel(o.id),
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancelar o resto'),
                  ),
                if (!o.isOpen && o.failed > 0)
                  OutlinedButton.icon(
                    key: ValueKey('dedupe-op-retry-${o.id}'),
                    onPressed: () => dedupe.retryFailed(o.id),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar de novo os que ficaram'),
                  ),
                OutlinedButton.icon(
                  key: ValueKey('dedupe-op-export-${o.id}'),
                  onPressed: () => exportOperationReport(context, ref, o),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar relatório (CSV)'),
                ),
                TextButton.icon(
                  key: ValueKey('dedupe-op-details-${o.id}'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? 'Esconder os arquivos' : 'Ver os arquivos'),
                ),
              ],
            ),
            if (_expanded) _Items(op: o),
          ],
        ),
      ),
    );
  }
}

class _Items extends ConsumerWidget {
  const _Items({required this.op});
  final OperationView op;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    ref.watch(operationsProvider);
    return FutureBuilder<List<OperationItemView>>(
      future: ref.read(backendProvider).operationItems(op.id),
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) return const LinearProgressIndicator();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in items)
              ListTile(
                key: ValueKey('dedupe-item-${i.id}'),
                dense: true,
                leading: Icon(switch (i.state) {
                  ItemState.published => Icons.delete_outline,
                  ItemState.failed => Icons.do_not_disturb_on_outlined,
                  _ => Icons.schedule,
                }, color: i.state == ItemState.failed ? colors.attention : null),
                title: Text(i.srcRelPath.replaceAll('/', ' › ')),
                subtitle: Text(
                  [
                    switch (i.state) {
                      ItemState.published => 'Foi para a Lixeira',
                      ItemState.failed => 'Ficou onde estava',
                      ItemState.publishing => 'Indo para a Lixeira',
                      _ => 'Na fila',
                    },
                    'fica: ${i.dstRelPath.replaceAll('/', ' › ')}',
                    if (i.errorMessage != null && i.state == ItemState.failed) i.errorMessage!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}
