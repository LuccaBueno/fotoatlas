import 'package:fotoatlas_core/fotoatlas_core.dart';

/// O que a tela "Parecidas" precisa do core (Fase 9). Separado de
/// [AppBackend] para os testes antigos não precisarem implementar.
abstract interface class SimilarBackend {
  SimilarStatus get status;
  Stream<SimilarStatus> watchStatus();

  /// Impressões novas ou sugestões descartadas/restauradas.
  Stream<void> changes();
  Future<SimilarOverview> overview();
  Future<List<SimilarGroup>> groups(SimilarLevel minLevel);
  Future<void> start();
  Future<void> pause();

  /// "Não são parecidas" (só catálogo). Devolve os pares para o Desfazer.
  Future<List<(int, int)>> dismiss(List<int> contentIds);

  /// "Tirar do grupo" (só catálogo).
  Future<List<(int, int)>> dismissFrom(int contentId, List<int> others);
  Future<void> undoDismiss(List<(int, int)> pairs);
  Future<int> restoreAllDismissed();
}

class CoreSimilarBackend implements SimilarBackend {
  CoreSimilarBackend(this.core);
  final FotoAtlasCore core;

  @override
  SimilarStatus get status => core.similar.current;

  @override
  Stream<SimilarStatus> watchStatus() => core.similar.status;

  @override
  Stream<void> changes() => core.similar.changes;

  @override
  Future<SimilarOverview> overview() => core.similar.overview();

  @override
  Future<List<SimilarGroup>> groups(SimilarLevel minLevel) => core.similar.groups(minLevel: minLevel);

  @override
  Future<void> start() => core.similar.start();

  @override
  Future<void> pause() => core.similar.pause();

  @override
  Future<List<(int, int)>> dismiss(List<int> contentIds) => core.similar.dismiss(contentIds);

  @override
  Future<List<(int, int)>> dismissFrom(int contentId, List<int> others) => core.similar.dismissFrom(contentId, others);

  @override
  Future<void> undoDismiss(List<(int, int)> pairs) => core.similar.undoDismiss(pairs);

  @override
  Future<int> restoreAllDismissed() => core.similar.restoreAllDismissed();
}
