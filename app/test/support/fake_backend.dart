import 'dart:async';

import 'package:fotoatlas/app/backend.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

/// Backend falso para testes de widget: guarda as chamadas e emite o que o
/// teste mandar.
class FakeBackend implements AppBackend {
  FakeBackend([List<SourceView> initial = const []]) : _sources = List.of(initial);

  List<SourceView> _sources;
  final _sourcesController = StreamController<List<SourceView>>.broadcast();
  final _progress = StreamController<ScanProgress>.broadcast();
  final calls = <String>[];
  List<(VolumeInfo, String?)> fakeDrives = const [];
  Map<String, List<String>> liveFolders = const {};
  Map<String, FolderStats> stats = const {};
  List<(DeviceInfo, String?)> fakeDevices = const [];

  void emitSources(List<SourceView> list) {
    _sources = List.of(list);
    _sourcesController.add(_sources);
  }

  void emitProgress(ScanProgress p) => _progress.add(p);

  @override
  Stream<List<SourceView>> watchSources() async* {
    yield _sources;
    yield* _sourcesController.stream;
  }

  @override
  Stream<ScanProgress> get scanProgress => _progress.stream;

  @override
  Map<int, ScanProgress> get runningScans => const {};

  @override
  Future<List<(VolumeInfo, String?)>> listDrives() async => fakeDrives;

  @override
  Future<AddSourceResult> addPath(String path, {String? name}) async {
    calls.add('add:$path');
    return const AddSourceResult('novo', []);
  }

  @override
  Future<List<(DeviceInfo, String?)>> listDevices() async => fakeDevices;

  @override
  Future<AddSourceResult> addPhone(String deviceId, {String? name}) async {
    calls.add('addPhone:$deviceId');
    return const AddSourceResult('celular', []);
  }

  @override
  Future<void> rename(String sourceId, String name) async => calls.add('rename:$sourceId:$name');

  @override
  Future<void> forget(String sourceId) async => calls.add('forget:$sourceId');

  @override
  Future<void> confirmVolume(String sourceId, String guidPath) async => calls.add('confirm:$sourceId');

  @override
  Future<int> startScan(String sourceId, {List<String>? folders}) async {
    calls.add(folders == null || folders.isEmpty ? 'scan:$sourceId' : 'scan:$sourceId:${folders.join('+')}');
    return 1;
  }

  @override
  Future<int> resumeScan(int scanId) async {
    calls.add('resume:$scanId');
    return scanId;
  }

  @override
  Future<List<String>> listFolders(String sourceId, String relPath) async =>
      liveFolders['$sourceId:$relPath'] ?? const [];

  @override
  Future<Map<String, FolderStats>> folderStats(String sourceId, List<String> relPaths) async => {
    for (final r in relPaths)
      if (stats['$sourceId:$r'] != null) r: stats['$sourceId:$r']!,
  };

  @override
  Future<void> pauseScan(int scanId) async => calls.add('pause:$scanId');

  @override
  Future<void> cancelScan(int scanId) async => calls.add('cancel:$scanId');

  // --- Fase 2 ---------------------------------------------------------------

  Map<String, List<String>> folders = const {};
  HashStatus fakeHashStatus = const HashStatus();
  final _hash = StreamController<HashStatus>.broadcast();
  CoverageReport? coverage;
  CompareSummary? compareResult;
  Map<CompareList, List<CompareItem>> compareLists = const {};
  final savedScopes = <SavedScope>[];
  final _scopes = StreamController<List<SavedScope>>.broadcast();
  List<CatalogBackupInfo> backups = const [];

  void emitHash(HashStatus s) {
    fakeHashStatus = s;
    _hash.add(s);
  }

  @override
  Future<List<String>> childFolders(String sourceId, String relPath) async => folders['$sourceId:$relPath'] ?? const [];

  @override
  HashStatus get hashStatus => fakeHashStatus;

  @override
  Stream<HashStatus> watchHashStatus() => _hash.stream;

  @override
  Future<void> startHash({List<HashPriority>? priority}) async =>
      calls.add('hash:${priority?.map((p) => '${p.sourceId}:${p.relPath}').join(',') ?? ''}');

  @override
  Future<void> pauseHash() async => calls.add('hash-pause');

  @override
  Future<int> retryFailedHashes() async {
    calls.add('hash-retry');
    return 0;
  }

  @override
  Stream<CoverageReport> watchCoverage() async* {
    if (coverage != null) yield coverage!;
  }

  @override
  Future<CompareSummary> compare(Scope a, Scope b) async {
    calls.add('compare:${a.entries.join('+')}|${b.entries.join('+')}|${a.types?.map((t) => t.name).join(',') ?? ''}');
    return compareResult!;
  }

  @override
  Future<List<CompareItem>> compareItems(Scope a, Scope b, CompareList list, {int offset = 0, int limit = 200}) async =>
      offset == 0 ? (compareLists[list] ?? const []) : const [];

  @override
  Stream<List<SavedScope>> watchSavedScopes() async* {
    yield List.of(savedScopes);
    yield* _scopes.stream;
  }

  @override
  Future<SavedScope> saveScope(String name, Scope scope, {bool replace = false}) async {
    calls.add('save-scope:$name');
    final saved = SavedScope(id: savedScopes.length + 1, name: name, scope: scope, updatedAt: DateTime.utc(2026));
    savedScopes.add(saved);
    _scopes.add(List.of(savedScopes));
    return saved;
  }

  @override
  Future<void> renameScope(int id, String name) async => calls.add('rename-scope:$id:$name');

  @override
  Future<void> removeScope(int id) async => calls.add('remove-scope:$id');

  final helperStatus = StreamController<HelperStatus>.broadcast();

  @override
  Stream<HelperStatus> watchHelperStatus() => helperStatus.stream;

  @override
  List<CatalogBackupInfo> catalogBackups() => backups;

  @override
  Future<CatalogBackupInfo> backupCatalogNow() async {
    calls.add('backup');
    return CatalogBackupInfo('x', DateTime.utc(2026), 1024);
  }

  // Cópia segura.
  List<int> missingIds = const [];
  CopyPreview Function(CopyRequest request)? onPreview;
  CopyRequest? lastRequest;
  List<OperationView> operations = [];
  Map<String, List<OperationItemView>> opItems = {};
  final _operations = StreamController<List<OperationView>>.broadcast();
  final copyProgressController = StreamController<CopyProgress>.broadcast();
  List<TempLeftover>? leftovers = const [];

  void emitOperations(List<OperationView> list) {
    operations = List.of(list);
    _operations.add(operations);
  }

  @override
  Future<List<int>> compareMissingContentIds(Scope a, Scope b) async => missingIds;

  @override
  Future<CopyPreview> previewCopy(CopyRequest request) async {
    lastRequest = request;
    calls.add('preview:${request.contentIds.length}:${request.destSourceId}:${request.destFolder}:${request.template}');
    return onPreview!(request);
  }

  @override
  Future<String> startCopy(CopyPreview preview) async {
    calls.add('start-copy:${preview.items.length}');
    return 'op1';
  }

  @override
  Stream<List<OperationView>> watchOperations() async* {
    yield operations;
    yield* _operations.stream;
  }

  @override
  Stream<CopyProgress> get copyProgress => copyProgressController.stream;

  @override
  CopyProgress? currentCopy;

  @override
  Future<void> pauseCopy(String operationId) async => calls.add('pause-copy:$operationId');

  @override
  Future<void> resumeCopy(String operationId) async => calls.add('resume-copy:$operationId');

  @override
  Future<void> cancelCopy(String operationId) async => calls.add('cancel-copy:$operationId');

  @override
  Future<int> retryFailedCopies(String operationId) async {
    calls.add('retry-copy:$operationId');
    return 1;
  }

  @override
  Future<void> resolveConflict(int itemId, {required bool rename}) async =>
      calls.add('conflict:$itemId:${rename ? 'rename' : 'skip'}');

  @override
  Future<List<OperationItemView>> operationItems(String operationId, {Set<String>? states}) async => [
    for (final i in opItems[operationId] ?? const <OperationItemView>[])
      if (states == null || states.contains(i.state)) i,
  ];

  @override
  Future<String> exportOperation(String operationId) async => 'item;estado\n1;published\n';

  @override
  Future<List<TempLeftover>?> tempLeftovers(String destSourceId) async => leftovers;

  bool guideDone = true;

  @override
  Future<bool> isFirstRunGuideDone() async => guideDone;

  @override
  Future<void> setFirstRunGuideDone() async {
    calls.add('guide-done');
    guideDone = true;
  }
}

ScanRow completedScan({int id = 1, String sourceId = 's1', String coverage = 'complete', int errors = 0}) => ScanRow(
  id: id,
  sourceId: sourceId,
  kind: 'full',
  status: 'completed',
  coverage: coverage,
  startedAt: DateTime.utc(2026, 10, 1, 12).millisecondsSinceEpoch,
  finishedAt: DateTime.utc(2026, 10, 1, 12, 5).millisecondsSinceEpoch,
  dirsDone: 10,
  filesSeen: 1500,
  bytesSeen: 5 * 1024 * 1024 * 1024,
  errorCount: errors,
);
