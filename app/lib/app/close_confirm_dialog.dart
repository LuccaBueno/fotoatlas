import 'package:flutter/material.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../l10n/format.dart';
import 'demo_mode.dart';

/// "Há tarefas em andamento…" ao fechar. "Continuar trabalhando" é o padrão
/// (foco, Esc e clique fora); devolve `true` só em "Fechar mesmo assim".
class CloseConfirmDialog extends StatelessWidget {
  const CloseConfirmDialog({super.key, required this.tasks, this.demoMode = DemoMode.off});
  final List<RunningTask> tasks;
  final DemoMode demoMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('close-confirm'),
      title: const Text('Fechar o FotoAtlas?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Há tarefas em andamento:'),
            const SizedBox(height: 8),
            for (final t in tasks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(t.kind), size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(runningTaskLabel(t))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(demoMode.closeMessage),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('close-anyway'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Fechar mesmo assim'),
        ),
        FilledButton(
          key: const ValueKey('keep-working'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Continuar trabalhando'),
        ),
      ],
    );
  }

  static IconData _icon(RunningTaskKind kind) => switch (kind) {
    RunningTaskKind.scan => Icons.search,
    RunningTaskKind.hash => Icons.fact_check_outlined,
    RunningTaskKind.backup => Icons.backup_outlined,
  };
}

/// "Escaneando "Pixel" — 1.234 arquivos encontrados",
/// "Conferindo o conteúdo — 120 de 6.596 arquivos (1%)", "Backup do catálogo".
String runningTaskLabel(RunningTask t) => switch (t.kind) {
  RunningTaskKind.scan =>
    'Escaneando "${t.sourceName ?? 'dispositivo'}" — '
        '${plural(t.done, 'arquivo encontrado', 'arquivos encontrados')} até agora',
  RunningTaskKind.hash when t.total > 0 =>
    'Conferindo o conteúdo — ${formatInt(t.done)} de ${plural(t.total, 'arquivo', 'arquivos')} '
        '(${(t.done * 100 ~/ t.total)}%)',
  RunningTaskKind.hash => 'Conferindo o conteúdo — ${plural(t.done, 'arquivo conferido', 'arquivos conferidos')}',
  RunningTaskKind.backup => 'Fazendo o backup do catálogo',
};
