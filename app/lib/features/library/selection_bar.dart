import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../widgets/backup_state.dart';
import 'date_dialogs.dart';
import 'library_controller.dart';

final _summaryProvider = FutureProvider.autoDispose.family<SelectionSummary, Set<int>>(
  (ref, ids) => ref.watch(libraryBackendProvider).summarize(ids),
);

/// Barra fixa da seleção: "523 itens · 4,2 GB · 612 arquivos" + situação de
/// backup e ações em massa (spec §3.1/§10).
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);
    final c = ref.read(libraryControllerProvider.notifier);
    final sel = state.selection;
    final theme = Theme.of(context);
    final summary = ref.watch(_summaryProvider(sel)).value;
    final backend = ref.read(libraryBackendProvider);
    return Material(
      key: const ValueKey('selection-bar'),
      elevation: 3,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              summary == null
                  ? plural(sel.length, 'item marcado', 'itens marcados')
                  : '${plural(summary.items, 'item', 'itens')} · ${formatBytes(summary.bytes)} · '
                        '${plural(summary.files, 'arquivo', 'arquivos')}',
              key: const ValueKey('selection-summary'),
              style: theme.textTheme.titleSmall,
            ),
            if (summary != null)
              for (final s in [BackupState.single, BackupState.verified, BackupState.independent])
                if ((summary.backup[s] ?? 0) > 0) BackupStateBadge(s, count: summary.backup[s]),
            TextButton(
              key: const ValueKey('select-all'),
              onPressed: c.selectAll,
              child: Text('Selecionar todos os resultados (${formatInt(state.index.length)})'),
            ),
            TextButton(onPressed: c.invert, child: const Text('Inverter')),
            PopupMenuButton<LibraryFilter>(
              tooltip: 'Tirar da seleção por critério',
              onSelected: (f) async {
                final n = await c.removeFromSelection(f);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('${plural(n, 'item saiu', 'itens saíram')} da seleção.')));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: LibraryFilter([FilterCondition(FilterKind.toConfirm)]),
                  child: Text('Tirar os com hora a confirmar'),
                ),
                PopupMenuItem(
                  value: LibraryFilter([
                    FilterCondition(FilterKind.types, values: ['video']),
                  ]),
                  child: Text('Tirar os vídeos'),
                ),
                PopupMenuItem(
                  value: LibraryFilter([
                    FilterCondition(FilterKind.types, values: ['photo', 'raw']),
                  ]),
                  child: Text('Tirar as fotos'),
                ),
                PopupMenuItem(
                  value: LibraryFilter([
                    FilterCondition(FilterKind.backup, values: ['independent']),
                  ]),
                  child: Text('Tirar os que já têm backup em disco independente'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('Tirar da seleção…'),
              ),
            ),
            OutlinedButton(
              key: const ValueKey('confirm-selection'),
              onPressed: () async {
                final n = await backend.confirmDates(sel);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hora confirmada em ${plural(n, 'item', 'itens')} (só no catálogo).')),
                  );
                }
              },
              child: const Text('A hora está certa'),
            ),
            OutlinedButton(
              onPressed: () => showManualDateDialog(context, ref, sel.toList()),
              child: const Text('Corrigir a hora…'),
            ),
            const Tooltip(
              message: 'A cópia segura chega na Fase 5.',
              child: FilledButton(onPressed: null, child: Text('Copiar para…')),
            ),
            IconButton(tooltip: 'Limpar seleção (Esc)', onPressed: c.clearSelection, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}
