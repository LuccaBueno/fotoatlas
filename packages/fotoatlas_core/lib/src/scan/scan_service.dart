import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../catalog/catalog.dart';
import '../catalog/catalog_database.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import 'scan_engine.dart';
import 'scan_listers.dart';

class _WorkerArgs {
  _WorkerArgs({
    required this.connectPort,
    required this.events,
    required this.scanId,
    required this.sourceId,
    required this.accessRoot,
    required this.isVolumeRoot,
  });
  final SendPort connectPort;
  final SendPort events;
  final int scanId;
  final String sourceId;
  final String accessRoot;
  final bool isVolumeRoot;
}

/// Ponto de entrada do isolate de scan: enumera com FFI e grava pelo escritor
/// único do catálogo. O isolate da interface só recebe progresso.
Future<void> _scanWorkerMain(_WorkerArgs args) async {
  ScanStop? stop;
  final control = ReceivePort()..listen((m) => stop = m as ScanStop);
  args.events.send(control.sendPort);
  final db = await Catalog.connectWorker(args.connectPort);
  try {
    final result = await ScanEngine(
      db,
      scanId: args.scanId,
      sourceId: args.sourceId,
      lister: Win32ScanLister(args.accessRoot, isVolumeRoot: args.isVolumeRoot),
    ).run(stopRequested: () => stop, onProgress: args.events.send);
    args.events.send(result);
  } catch (e) {
    await db.customUpdate(
      "UPDATE scans SET status = 'interrupted' WHERE id = ? AND status = 'running'",
      variables: [Variable.withInt(args.scanId)],
      updates: {db.scans},
    );
    args.events.send(await readScanProgress(db, args.scanId, message: 'Erro inesperado: $e'));
  } finally {
    await db.close();
    control.close();
  }
}

class _RunningScan {
  _RunningScan(this.scanId, this.sourceId);
  final int scanId;
  final String sourceId;
  final done = Completer<ScanProgress>();
  SendPort? control;
  ScanStop? pendingStop;
  ScanProgress? last;
}

/// Inicia, pausa, retoma e cancela scans de listagem.
class ScanService {
  ScanService(this.catalog, this.sources, {this.useIsolate = true});

  final Catalog catalog;
  final SourcesService sources;

  /// `false` roda no isolate atual (só para testes unitários).
  final bool useIsolate;

  CatalogDatabase get db => catalog.db;
  final _progress = StreamController<ScanProgress>.broadcast();
  final Map<int, _RunningScan> _running = {};

  Stream<ScanProgress> get progress => _progress.stream;

  /// Último progresso conhecido dos scans em andamento.
  Map<int, ScanProgress> get runningProgress => {
    for (final r in _running.values)
      if (r.last != null) r.scanId: r.last!,
  };

  bool isRunning(String sourceId) => _running.values.any((r) => r.sourceId == sourceId);

  /// Scans que estavam rodando quando o processo morreu ficam `interrupted`.
  Future<void> init() async {
    await db.customUpdate("UPDATE scans SET status = 'interrupted' WHERE status = 'running'", updates: {db.scans});
  }

  /// Escaneia a fonte: retoma um scan pausado/interrompido ou cria um novo.
  ///
  /// [folders] (relativas à fonte, ex.: `Armazenamento interno/DCIM/Camera`)
  /// escaneia só essas pastas e as subpastas; o scan fica `partial` e só
  /// confirma ausências dentro delas. Vazia ou `null` = a fonte inteira.
  Future<int> start(String sourceId, {List<String>? folders}) async {
    final roots = normalizeScanRoots(folders);
    for (final r in _running.values) {
      if (r.sourceId == sourceId) return r.scanId;
    }
    final unfinished =
        await (db.select(db.scans)
              ..where((s) => s.sourceId.equals(sourceId) & s.status.isIn(['paused', 'interrupted']))
              ..orderBy([(s) => OrderingTerm.desc(s.id)])
              ..limit(1))
            .getSingleOrNull();
    if (unfinished != null) {
      final unfinishedRoots = await scanRoots(db, unfinished.id);
      String key(List<String> l) => (l.map((r) => r.toLowerCase()).toList()..sort()).join('\n');
      if (key(unfinishedRoots) != key(roots)) {
        final what = unfinishedRoots.first.isEmpty
            ? 'da fonte inteira'
            : 'de ${unfinishedRoots.map((r) => '"$r"').join(', ')}';
        throw SourceException(
          'Há um escaneamento $what por terminar (#${unfinished.id}). Retome ou cancele esse antes.',
        );
      }
      return resume(unfinished.id);
    }

    final source = await _connectedSource(sourceId);
    final hasCompleted =
        await (db.select(db.scans)
              ..where((s) => s.sourceId.equals(sourceId) & s.status.equals('completed'))
              ..limit(1))
            .getSingleOrNull();
    final scanId = await db.transaction(() async {
      final id = await db
          .into(db.scans)
          .insert(
            ScansCompanion.insert(
              sourceId: sourceId,
              kind: hasCompleted == null ? 'full' : 'incremental',
              status: 'running',
              startedAt: nowMs(),
              mountPathUsed: Value(source.row.lastMountPath),
            ),
          );
      for (final root in roots) {
        await db.into(db.scanDirs).insert(ScanDirsCompanion.insert(scanId: id, relPath: root, status: 'pending'));
      }
      return id;
    });
    _launch(scanId, source.row, source.root);
    return scanId;
  }

  /// Subpastas de [relPath] lidas agora do dispositivo (não do catálogo), para
  /// escolher o que escanear. Só lista: nada é gravado no catálogo nem na fonte.
  /// Pastas que o scan sempre ignora (lixeira, miniaturas…) não aparecem.
  Future<List<String>> listFolders(String sourceId, [String relPath = '']) async {
    final source = await _connectedSource(sourceId);
    final ListedDir listed;
    try {
      if (source.row.kind == 'phone') {
        listed = await PhoneScanLister(sources.devices!, source.root).list(relPath);
      } else {
        final root = source.root;
        final isVolumeRoot = source.row.rootRelPath.isEmpty;
        // Pasta com muitos arquivos: lê fora do isolate da interface.
        listed = await Isolate.run(() => Win32ScanLister(root, isVolumeRoot: isVolumeRoot).list(relPath));
      }
    } on SourceGone catch (e) {
      throw SourceException(e.message);
    }
    if (listed.isError) {
      throw SourceException('Não foi possível ler esta pasta (${listed.errorMessage ?? listed.errorKind}).');
    }
    return listed.childDirs..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Retoma um scan `paused` ou `interrupted` de onde parou.
  Future<int> resume(int scanId) async {
    if (_running.containsKey(scanId)) return scanId;
    final scan = await (db.select(db.scans)..where((s) => s.id.equals(scanId))).getSingle();
    if (scan.status != 'paused' && scan.status != 'interrupted') {
      throw SourceException('Este escaneamento não pode ser retomado (situação: ${scan.status}).');
    }
    final source = await _connectedSource(scan.sourceId);
    _launch(scanId, source.row, source.root);
    return scanId;
  }

  Future<void> pause(int scanId) => _requestStop(scanId, ScanStop.pause);

  /// Cancela: o que já foi catalogado fica; nenhuma ausência é confirmada.
  Future<void> cancel(int scanId) async {
    if (_running.containsKey(scanId)) return _requestStop(scanId, ScanStop.cancel);
    await db.customUpdate(
      "UPDATE scans SET status = 'cancelled', finished_at = ? WHERE id = ? AND status IN ('paused', 'interrupted')",
      variables: [Variable.withInt(nowMs()), Variable.withInt(scanId)],
      updates: {db.scans},
    );
  }

  /// Espera o fim (ou a pausa) de um scan em andamento.
  Future<ScanProgress> wait(int scanId) async {
    final running = _running[scanId];
    if (running != null) return running.done.future;
    return readScanProgress(db, scanId);
  }

  Future<void> _requestStop(int scanId, ScanStop stop) async {
    final running = _running[scanId];
    if (running == null) return;
    final control = running.control;
    if (control == null) {
      running.pendingStop = stop;
    } else {
      control.send(stop);
    }
  }

  Future<({SourceRow row, String root})> _connectedSource(String sourceId) async {
    final row = await sources.byId(sourceId);
    if (row == null) throw SourceException('Fonte não encontrada.');
    if (row.kind == 'phone') {
      var device = sources.deviceFor(row.id);
      if (device == null) {
        await sources.refreshConnectivity();
        device = sources.deviceFor(row.id);
      }
      if (device == null || sources.devices == null) {
        throw SourceException('"${row.name}" está desconectado. Conecte o celular pelo cabo USB para escanear.');
      }
      final notReady = phoneStatusMessage(device);
      if (notReady != null) throw SourceException(notReady);
      // Para o celular, a "raiz" é o ID do dispositivo.
      return (row: row, root: device.deviceId);
    }
    var root = sources.accessRoot(row);
    if (root == null) {
      await sources.refreshConnectivity();
      root = sources.accessRoot(row);
    }
    if (root == null) {
      throw SourceException(
        sources.stateOf(sourceId) == SourceState.ambiguous
            ? 'Confirme qual unidade é "${row.name}" antes de escanear.'
            : '"${row.name}" está desconectada. Conecte o dispositivo para escanear.',
      );
    }
    return (row: row, root: root);
  }

  void _launch(int scanId, SourceRow source, String root) {
    final running = _running[scanId] = _RunningScan(scanId, source.id);
    final isVolumeRoot = source.rootRelPath.isEmpty;

    void onProgress(ScanProgress p) {
      running.last = p;
      if (!_progress.isClosed) _progress.add(p);
      if (p.isFinal) {
        _running.remove(scanId);
        if (!running.done.isCompleted) running.done.complete(p);
      }
    }

    // Celular: quem lê é o helper (outro processo); aqui só chegam lotes de
    // JSON, então o scan roda no isolate atual sem travar a interface.
    final phone = source.kind == 'phone';
    if (!useIsolate || phone) {
      ScanEngine(
            db,
            scanId: scanId,
            sourceId: source.id,
            lister: phone ? PhoneScanLister(sources.devices!, root) : Win32ScanLister(root, isVolumeRoot: isVolumeRoot),
          )
          .run(stopRequested: () => running.pendingStop, onProgress: onProgress)
          .then(
            onProgress,
            // Fechando o app: o catálogo pode já estar fechado; o scan fica
            // `running` e vira `interrupted` na próxima abertura.
            onError: (Object e, StackTrace st) {
              if (!_disposing) Error.throwWithStackTrace(e, st);
            },
          );
      return;
    }

    final events = ReceivePort();
    final exit = ReceivePort();
    events.listen((message) {
      if (message is SendPort) {
        running.control = message;
        final pending = running.pendingStop;
        if (pending != null) message.send(pending);
      } else if (message is ScanProgress) {
        onProgress(message);
        if (message.isFinal) events.close();
      }
    });
    exit.listen((_) async {
      exit.close();
      events.close();
      if (!running.done.isCompleted && !_disposing) {
        // O worker morreu sem relatar o fim: o scan pode ser retomado.
        await db.customUpdate(
          "UPDATE scans SET status = 'interrupted' WHERE id = ? AND status = 'running'",
          variables: [Variable.withInt(scanId)],
          updates: {db.scans},
        );
        onProgress(await readScanProgress(db, scanId));
      }
    });
    Isolate.spawn(
      _scanWorkerMain,
      _WorkerArgs(
        connectPort: catalog.connectPort,
        events: events.sendPort,
        scanId: scanId,
        sourceId: source.id,
        accessRoot: root,
        isVolumeRoot: isVolumeRoot,
      ),
      onExit: exit.sendPort,
      debugName: 'scan-$scanId',
    );
  }

  /// Pausa os scans em andamento (o ponto de parada fica no banco a cada
  /// lote) e espera no máximo [timeout]. Um scan que não parar a tempo fica
  /// `running` no banco e vira `interrupted` ao abrir de novo ([init]):
  /// retoma das pastas pendentes, sem confirmar ausências.
  /// Devolve `false` se algum scan não parou a tempo.
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposing = true;
    final running = _running.values.toList();
    for (final r in running) {
      await _requestStop(r.scanId, ScanStop.pause);
    }
    final stopped = await Future.wait([for (final r in running) r.done.future])
        .then((_) => true)
        .timeout(timeout, onTimeout: () => false);
    // Sem `await`: um ouvinte pausado faria o close() nunca terminar.
    unawaited(_progress.close());
    return stopped;
  }

  bool _disposing = false;
}
