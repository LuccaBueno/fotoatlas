import 'package:fotoatlas_core/fotoatlas_core.dart';

/// O que a interface precisa do core. A implementação real só repassa para
/// [FotoAtlasCore]; os testes de widget usam uma versão falsa.
abstract interface class AppBackend {
  Stream<List<SourceView>> watchSources();

  /// Progresso de todos os scans (o app filtra por fonte).
  Stream<ScanProgress> get scanProgress;

  /// Último progresso dos scans em andamento (para quem abre a tela depois).
  Map<int, ScanProgress> get runningScans;

  /// Unidades conectadas agora (HD, SSD, pendrive, cartão), com a fonte já
  /// cadastrada de cada uma.
  Future<List<(VolumeInfo, String?)>> listDrives();

  Future<AddSourceResult> addPath(String path, {String? name});

  /// Celulares conectados agora, com a fonte já cadastrada de cada um.
  Future<List<(DeviceInfo, String?)>> listDevices();
  Future<AddSourceResult> addPhone(String deviceId, {String? name});
  Future<void> rename(String sourceId, String name);
  Future<void> forget(String sourceId);
  Future<void> confirmVolume(String sourceId, String guidPath);

  /// [folders] vazia ou `null` = a fonte inteira.
  Future<int> startScan(String sourceId, {List<String>? folders});
  Future<int> resumeScan(int scanId);
  Future<void> pauseScan(int scanId);
  Future<void> cancelScan(int scanId);

  /// Subpastas lidas agora do dispositivo (escolher o que escanear).
  Future<List<String>> listFolders(String sourceId, String relPath);

  /// Arquivos e bytes já catalogados em cada pasta (estimativa de tamanho).
  Future<Map<String, FolderStats>> folderStats(String sourceId, List<String> relPaths);

  /// Subpastas de uma fonte segundo o catálogo (seletor de escopo).
  Future<List<String>> childFolders(String sourceId, String relPath);

  // Conferência de conteúdo (fila de hash).
  HashStatus get hashStatus;
  Stream<HashStatus> watchHashStatus();
  Future<void> startHash({List<HashPriority>? priority});
  Future<void> pauseHash();
  Future<int> retryFailedHashes();

  // Cobertura e comparação.
  Stream<CoverageReport> watchCoverage();
  Future<CompareSummary> compare(Scope a, Scope b);
  Future<List<CompareItem>> compareItems(Scope a, Scope b, CompareList list, {int offset = 0, int limit = 200});
  Stream<List<SavedScope>> watchSavedScopes();
  Future<SavedScope> saveScope(String name, Scope scope, {bool replace = false});
  Future<void> renameScope(int id, String name);
  Future<void> removeScope(int id);

  /// Situação da leitura de dispositivos (helper): `restarting` = caiu e está
  /// voltando.
  Stream<HelperStatus> watchHelperStatus();

  // Backup do catálogo.
  List<CatalogBackupInfo> catalogBackups();
  Future<CatalogBackupInfo> backupCatalogNow();
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
  Future<List<(VolumeInfo, String?)>> listDrives() => core.sources.listDrives();

  @override
  Future<AddSourceResult> addPath(String path, {String? name}) => core.sources.addPath(path, name: name);

  @override
  Future<List<(DeviceInfo, String?)>> listDevices() => core.sources.listDevices();

  @override
  Future<AddSourceResult> addPhone(String deviceId, {String? name}) => core.sources.addPhone(deviceId, name: name);

  @override
  Future<void> rename(String sourceId, String name) => core.sources.rename(sourceId, name);

  @override
  Future<void> forget(String sourceId) => core.sources.forget(sourceId);

  @override
  Future<void> confirmVolume(String sourceId, String guidPath) => core.sources.confirmVolume(sourceId, guidPath);

  @override
  Future<int> startScan(String sourceId, {List<String>? folders}) => core.scans.start(sourceId, folders: folders);

  @override
  Future<int> resumeScan(int scanId) => core.scans.resume(scanId);

  @override
  Future<List<String>> listFolders(String sourceId, String relPath) => core.scans.listFolders(sourceId, relPath);

  @override
  Future<Map<String, FolderStats>> folderStats(String sourceId, List<String> relPaths) =>
      core.sources.folderStats(sourceId, relPaths);

  @override
  Future<void> pauseScan(int scanId) => core.scans.pause(scanId);

  @override
  Future<void> cancelScan(int scanId) => core.scans.cancel(scanId);

  @override
  Future<List<String>> childFolders(String sourceId, String relPath) => core.sources.childFolders(sourceId, relPath);

  @override
  HashStatus get hashStatus => core.hashes.current;

  @override
  Stream<HashStatus> watchHashStatus() => core.hashes.status;

  @override
  Future<void> startHash({List<HashPriority>? priority}) => core.hashes.start(priority: priority);

  @override
  Future<void> pauseHash() => core.hashes.pause();

  @override
  Future<int> retryFailedHashes() async {
    final n = await core.hashes.retryFailed();
    await core.hashes.start();
    return n;
  }

  @override
  Stream<CoverageReport> watchCoverage() => core.coverage.watch();

  @override
  Future<CompareSummary> compare(Scope a, Scope b) => core.compare.compare(a, b);

  @override
  Future<List<CompareItem>> compareItems(Scope a, Scope b, CompareList list, {int offset = 0, int limit = 200}) =>
      core.compare.items(a, b, list, offset: offset, limit: limit);

  @override
  Stream<List<SavedScope>> watchSavedScopes() => core.compare.watchSavedScopes();

  @override
  Future<SavedScope> saveScope(String name, Scope scope, {bool replace = false}) =>
      core.compare.saveScope(name, scope, replace: replace);

  @override
  Future<void> renameScope(int id, String name) => core.compare.renameScope(id, name);

  @override
  Future<void> removeScope(int id) => core.compare.removeScope(id);

  @override
  Stream<HelperStatus> watchHelperStatus() => core.helperStatus;

  @override
  List<CatalogBackupInfo> catalogBackups() => core.backups.list();

  @override
  Future<CatalogBackupInfo> backupCatalogNow() => core.backups.backupNow();
}
