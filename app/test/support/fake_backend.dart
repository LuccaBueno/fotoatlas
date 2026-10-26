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
  List<VolumeInfo> fakeVolumes = const [];

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
  List<VolumeInfo> get volumes => fakeVolumes;

  @override
  Future<AddSourceResult> addPath(String path, {String? name}) async {
    calls.add('add:$path');
    return const AddSourceResult('novo', []);
  }

  @override
  Future<void> rename(String sourceId, String name) async => calls.add('rename:$sourceId:$name');

  @override
  Future<void> forget(String sourceId) async => calls.add('forget:$sourceId');

  @override
  Future<void> confirmVolume(String sourceId, String guidPath) async => calls.add('confirm:$sourceId');

  @override
  Future<int> startScan(String sourceId) async {
    calls.add('scan:$sourceId');
    return 1;
  }

  @override
  Future<void> pauseScan(int scanId) async => calls.add('pause:$scanId');

  @override
  Future<void> cancelScan(int scanId) async => calls.add('cancel:$scanId');

  @override
  Future<void> refreshDevices() async => calls.add('refresh');
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
