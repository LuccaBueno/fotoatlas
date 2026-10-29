import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../l10n/format.dart';
import '../l10n/strings.dart';

IconData backupStateIcon(BackupState s) => switch (s) {
  BackupState.single => Icons.error_outline,
  BackupState.probable => Icons.hourglass_top,
  BackupState.verified => Icons.check_circle_outline,
  BackupState.independent => Icons.verified_user_outlined,
  BackupState.unknown => Icons.help_outline,
};

Color backupStateColor(BuildContext context, BackupState s) {
  final c = StatusColors.of(context);
  return switch (s) {
    BackupState.single => c.single,
    BackupState.probable => c.probable,
    BackupState.verified => c.verified,
    BackupState.independent => c.independent,
    BackupState.unknown => c.unknown,
  };
}

/// Cor + ícone + texto (nunca só cor).
class BackupStateBadge extends StatelessWidget {
  const BackupStateBadge(this.state, {super.key, this.count});
  final BackupState state;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = backupStateColor(context, state);
    return Tooltip(
      message: backupStateHint(state),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(backupStateIcon(state), size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              count == null ? backupStateLabel(state) : backupStateCount(state, count!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de progresso da conferência de conteúdo, com pausar/continuar.
class HashProgressBar extends ConsumerWidget {
  const HashProgressBar({super.key, this.sourceId});

  /// Só o progresso desta fonte (cartão de Dispositivos).
  final String? sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hashStatusProvider).value;
    if (status == null) return const SizedBox.shrink();
    final backend = ref.read(backendProvider);
    final theme = Theme.of(context);
    final per = sourceId == null ? null : status.perSource[sourceId];
    if (sourceId != null && (per == null || !status.running || per.done >= per.total)) {
      return const SizedBox.shrink();
    }
    if (sourceId == null && !status.running && !status.paused) return const SizedBox.shrink();
    final done = per?.done ?? status.filesDone;
    final total = per?.total ?? status.filesTotal;
    final remaining = status.remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: total == 0 ? null : done / total),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                status.paused
                    ? 'Conferência de conteúdo pausada (${formatInt(done)} de ${formatInt(total)}).'
                    : 'Conferindo conteúdo… ${formatInt(done)} de ${plural(total, 'arquivo', 'arquivos')}'
                          '${remaining == null || sourceId != null ? '' : ' · faltam ${formatDuration(remaining)}'}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (sourceId == null)
              TextButton(
                onPressed: status.paused ? () => backend.startHash() : () => backend.pauseHash(),
                child: Text(status.paused ? 'Continuar' : 'Pausar'),
              ),
          ],
        ),
      ],
    );
  }
}
