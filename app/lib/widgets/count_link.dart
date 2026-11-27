import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../app/providers.dart';
import '../app/shell.dart' show dedupeDestination, libraryDestination, tasksDestination;
import '../features/dedupe/dedupe_page.dart' show dedupeSourceProvider;
import '../features/library/library_controller.dart';

/// Dica dos números clicáveis (cartões dos dispositivos e Início).
const countLinkTooltip = 'Ver estes arquivos';

/// Um número clicável: cursor de mão e a dica "Ver estes arquivos".
class CountLink extends StatelessWidget {
  const CountLink({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: countLinkTooltip,
    child: InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(4),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1), child: child),
    ),
  );
}

/// Abre a Biblioteca já filtrada pela situação de backup [state] (como nos
/// cartões) e, com [sourceId], só daquele dispositivo. "Possivelmente
/// corrompido" abre Tarefas, onde fica "Ver e restaurar".
void openCoverageFiltered(WidgetRef ref, BackupState state, {String? sourceId}) {
  final navigation = ref.read(navigationIndexProvider.notifier);
  if (state == BackupState.corrupt) {
    navigation.select(tasksDestination);
    return;
  }
  ref
      .read(libraryControllerProvider.notifier)
      .setFilter(
        LibraryFilter([
          if (sourceId != null) FilterCondition(FilterKind.sources, values: [sourceId]),
          FilterCondition(FilterKind.coverage, values: [state.name]),
        ]),
      );
  navigation.select(libraryDestination);
}

/// Abre "Limpar repetidos" já no dispositivo [sourceId].
void openDedupeFor(WidgetRef ref, String sourceId) {
  ref.read(dedupeSourceProvider.notifier).select(sourceId);
  ref.read(navigationIndexProvider.notifier).select(dedupeDestination);
}
