import 'package:fotoatlas_core/fotoatlas_core.dart';

/// O que a interface precisa do core. A implementação real só repassa para
/// [FotoAtlasCore]; os testes de widget usam uma versão falsa.
abstract interface class AppBackend {
  Stream<List<SourceView>> watchSources();

  /// Progresso de todos os scans (o app filtra por fonte).
  Stream<ScanProgress> get scanProgress;

  /// Último progresso dos scans em andamento (para quem abre a tela depois).
  Map<int, ScanProgress> get runningScans;

  /// Volumes vistos na última verificação (para "Adicionar unidade").
  List<VolumeInfo> get volumes;

  Future<AddSourceResult> addPath(String path, {String? name});
  Future<void> rename(String sourceId, String name);
  Future<void> forget(String sourceId);
  Future<void> confirmVolume(String sourceId, String guidPath);
  Future<int> startScan(String sourceId);
  Future<void> pauseScan(int scanId);
  Future<void> cancelScan(int scanId);
  Future<void> refreshDevices();
}

class CoreBackend implements AppBackend {
  CoreBackend(this.core);
  final FotoAtlasCore core;

  @override
  Stream<List<SourceView>> watchSources() => core.sources.watch();

  @override
  Stream<ScanProgress> get scanProgress => core.scans.progress;

  @override
  Map<int, ScanProgress> get runningScans => core.scans.runningProgress;

  @override
  List<VolumeInfo> get volumes => core.sources.lastVolumes;

  @override
  Future<AddSourceResult> addPath(String path, {String? name}) => core.sources.addPath(path, name: name);

  @override
  Future<void> rename(String sourceId, String name) => core.sources.rename(sourceId, name);

  @override
  Future<void> forget(String sourceId) => core.sources.forget(sourceId);

  @override
  Future<void> confirmVolume(String sourceId, String guidPath) => core.sources.confirmVolume(sourceId, guidPath);

  @override
  Future<int> startScan(String sourceId) => core.scans.start(sourceId);

  @override
  Future<void> pauseScan(int scanId) => core.scans.pause(scanId);

  @override
  Future<void> cancelScan(int scanId) => core.scans.cancel(scanId);

  @override
  Future<void> refreshDevices() => core.sources.refreshConnectivity();
}
