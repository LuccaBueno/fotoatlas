import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'backend.dart';
import 'library_backend.dart';

/// Backend do app. Sobrescrito em `main.dart` (core real) e nos testes (falso).
final backendProvider = Provider<AppBackend>((ref) => throw UnimplementedError('backendProvider não configurado'));

/// Fontes cadastradas, reativas.
final sourcesProvider = StreamProvider<List<SourceView>>((ref) => ref.watch(backendProvider).watchSources());

/// Progresso dos scans em andamento, por id de fonte.
final scanProgressProvider = StreamProvider<Map<String, ScanProgress>>((ref) {
  final backend = ref.watch(backendProvider);
  final controller = StreamController<Map<String, ScanProgress>>();
  final bySource = <String, ScanProgress>{for (final p in backend.runningScans.values) p.sourceId: p};
  controller.add(Map.of(bySource));
  final sub = backend.scanProgress.listen((p) {
    if (p.isFinal) {
      bySource.remove(p.sourceId);
    } else {
      bySource[p.sourceId] = p;
    }
    controller.add(Map.of(bySource));
  });
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Situação da conferência de conteúdo (começa pelo valor atual).
final hashStatusProvider = StreamProvider<HashStatus>((ref) async* {
  final backend = ref.watch(backendProvider);
  yield backend.hashStatus;
  yield* backend.watchHashStatus();
});

/// Cobertura de backup (fotos e vídeos), recalculada enquanto o catálogo muda.
final coverageProvider = StreamProvider<CoverageReport>((ref) => ref.watch(backendProvider).watchCoverage());

/// Escopos de comparação salvos.
final savedScopesProvider = StreamProvider<List<SavedScope>>((ref) => ref.watch(backendProvider).watchSavedScopes());

/// Destino selecionado na navegação lateral.
final navigationIndexProvider = NotifierProvider<NavigationIndex, int>(NavigationIndex.new);

class NavigationIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

/// Situação do helper (leitura de dispositivos), para avisar quando ele cai.
final helperStatusProvider = StreamProvider<HelperStatus>((ref) => ref.watch(backendProvider).watchHelperStatus());

/// Biblioteca, momentos e datas (Fase 4). Sobrescrito em `main.dart`.
final libraryBackendProvider = Provider<LibraryBackend>(
  (ref) => throw UnimplementedError('libraryBackendProvider não configurado'),
);

/// Avisos de mudança da Biblioteca, agrupados (no máximo um a cada 700 ms).
final libraryChangesProvider = StreamProvider<int>((ref) {
  final backend = ref.watch(libraryBackendProvider);
  final controller = StreamController<int>();
  var n = 0;
  Timer? timer;
  final sub = backend.changes().listen((_) {
    timer ??= Timer(const Duration(milliseconds: 700), () {
      timer = null;
      controller.add(++n);
    });
  });
  controller.add(n);
  ref.onDispose(() {
    timer?.cancel();
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Situação da leitura de metadados (começa pelo valor atual).
final metadataStatusProvider = StreamProvider<MetadataStatus>((ref) async* {
  final backend = ref.watch(libraryBackendProvider);
  yield backend.metadataStatus;
  yield* backend.watchMetadataStatus();
});

/// Momentos (recarregam quando a Biblioteca muda).
final momentsProvider = FutureProvider<List<MomentView>>((ref) {
  ref.watch(libraryChangesProvider);
  return ref.watch(libraryBackendProvider).moments();
});

/// Contagens para os chips de filtro.
final libraryFacetsProvider = FutureProvider<LibraryFacets>((ref) {
  ref.watch(libraryChangesProvider);
  return ref.watch(libraryBackendProvider).facets();
});

/// Filtros salvos (recarregados com [ref.invalidate] depois de salvar/apagar).
final savedFiltersProvider = FutureProvider<List<SavedFilter>>(
  (ref) => ref.watch(libraryBackendProvider).savedFilters(),
);

/// Operações de cópia (tela Tarefas), reativas.
final operationsProvider = StreamProvider<List<OperationView>>((ref) => ref.watch(backendProvider).watchOperations());

/// Progresso da cópia em andamento (começa pelo valor atual).
final copyProgressProvider = StreamProvider<CopyProgress?>((ref) async* {
  final backend = ref.watch(backendProvider);
  yield backend.currentCopy;
  yield* backend.copyProgress;
});

/// Progresso da reorganização em andamento (ou do Desfazer).
final reorgProgressProvider = StreamProvider<CopyProgress?>((ref) => ref.watch(backendProvider).reorgProgress);

/// Disco principal (destino sugerido nas cópias); recarregado com [ref.invalidate].
final primarySourceProvider = FutureProvider<String?>((ref) => ref.watch(backendProvider).primarySourceId());
