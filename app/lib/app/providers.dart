import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'backend.dart';

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

/// Destino selecionado na navegação lateral.
final navigationIndexProvider = NotifierProvider<NavigationIndex, int>(NavigationIndex.new);

class NavigationIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}
