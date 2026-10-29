import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../catalog/catalog.dart';
import '../catalog/catalog_database.dart';
import '../scan/scan_service.dart';
import '../sources/sources_service.dart';
import 'hash_engine.dart';

/// Situação da conferência de conteúdo (fila de hash), para a interface.
class HashStatus {
  const HashStatus({
    this.running = false,
    this.paused = false,
    this.filesDone = 0,
    this.bytesDone = 0,
    this.filesTotal = 0,
    this.bytesTotal = 0,
    this.errors = 0,
    this.changed = 0,
    this.startedAt,
    this.perSource = const {},
    this.message,
  });

  final bool running;

  /// O usuário pausou: a conferência automática não recomeça sozinha.
  final bool paused;
  final int filesDone;
  final int bytesDone;

  /// Pendentes quando esta rodada começou (+ os que entraram depois).
  final int filesTotal;
  final int bytesTotal;
  final int errors;
  final int changed;
  final DateTime? startedAt;

  /// Por fonte: (feitos, total) nesta rodada.
  final Map<String, ({int done, int total})> perSource;
  final String? message;

  /// Estimativa de tempo restante pela vazão desta rodada.
  Duration? get remaining {
    final start = startedAt;
    if (!running || start == null || bytesDone == 0) return null;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed < 2000) return null;
    final rate = bytesDone / elapsed; // bytes/ms
    return Duration(milliseconds: ((bytesTotal - bytesDone) / rate).round());
  }

  HashStatus copyWith({
    bool? running,
    bool? paused,
    int? filesDone,
    int? bytesDone,
    int? filesTotal,
    int? bytesTotal,
    int? errors,
    int? changed,
    DateTime? startedAt,
    Map<String, ({int done, int total})>? perSource,
    String? message,
  }) => HashStatus(
    running: running ?? this.running,
    paused: paused ?? this.paused,
    filesDone: filesDone ?? this.filesDone,
    bytesDone: bytesDone ?? this.bytesDone,
    filesTotal: filesTotal ?? this.filesTotal,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    errors: errors ?? this.errors,
    changed: changed ?? this.changed,
    startedAt: startedAt ?? this.startedAt,
    perSource: perSource ?? this.perSource,
    message: message ?? this.message,
  );
}

class _WorkerArgs {
  _WorkerArgs(this.connectPort, this.events, this.targets, this.priority, this.chunkSize);
  final SendPort connectPort;
  final SendPort events;
  final List<HashTarget> targets;
  final List<HashPriority> priority;
  final int chunkSize;
}

Future<void> _hashWorkerMain(_WorkerArgs args) async {
  var stop = false;
  final control = ReceivePort()..listen((_) => stop = true);
  args.events.send(control.sendPort);
  final db = await Catalog.connectWorker(args.connectPort);
  try {
    final done = await HashEngine(
      db,
      targets: args.targets,
      priority: args.priority,
      chunkSize: args.chunkSize,
    ).run(stopRequested: () => stop, onFile: args.events.send);
    args.events.send(done);
  } catch (e) {
    args.events.send(HashWorkerDone(message: 'Erro inesperado na conferência: $e'));
  } finally {
    await db.close();
    control.close();
  }
}

class _Worker {
  _Worker(this.key, this.sourceIds);
  final String key;
  final Set<String> sourceIds;
  final done = Completer<void>();
  SendPort? control;
  bool stopRequested = false;
  void stop() {
    stopRequested = true;
    control?.send(true);
  }
}

/// Fila de conferência de conteúdo (SHA-256): um worker por disco físico
/// (L9), em isolates próprios, gravando pelo escritor único do catálogo.
///
/// Todo o estado fica no banco (`hash_status = pending`): pausar é só parar
/// os workers, e continuar recomeça dos pendentes. Arquivos de fontes
/// desconectadas ficam pendentes até a fonte voltar (regra 9).
class HashService {
  HashService(this.catalog, this.sources, this.scans, {this.useIsolate = true, this.chunkSize = 1 << 20});

  final Catalog catalog;
  final SourcesService sources;
  final ScanService scans;

  /// `false` roda no isolate atual (testes unitários).
  final bool useIsolate;
  final int chunkSize;

  /// Gancho de teste (só no mesmo isolate).
  AfterFirstChunk? debugAfterFirstChunk;

  CatalogDatabase get db => catalog.db;
  final _status = StreamController<HashStatus>.broadcast();
  final Map<String, _Worker> _workers = {};
  List<HashPriority> _priority = const [];
  HashStatus _current = const HashStatus();
  StreamSubscription<Object?>? _autoScan;
  StreamSubscription<Object?>? _autoSources;
  bool _disposed = false;

  Stream<HashStatus> get status => _status.stream;
  HashStatus get current => _current;
  bool get isRunning => _workers.isNotEmpty;

  /// Conferência automática: depois de cada scan concluído e quando uma fonte
  /// conecta. Respeita a pausa do usuário.
  void enableAuto() {
    _autoScan ??= scans.progress.where((p) => p.status == 'completed').listen((_) => _autoStart());
    _autoSources ??= sources.stateChanges.listen((_) => _autoStart());
    _autoStart();
  }

  void _autoStart() {
    if (_disposed || _current.paused) return;
    start().ignore();
  }

  /// Começa (ou amplia) a conferência das fontes conectadas com pendências.
  ///
  /// [priority] coloca trechos (ex.: os escopos de uma comparação) na frente;
  /// se já houver workers rodando, eles recomeçam com a nova prioridade.
  Future<void> start({List<HashPriority>? priority}) async {
    if (_disposed) return;
    if (_current.paused) _emit(_current.copyWith(paused: false));
    if (priority != null) {
      _priority = priority;
      if (_workers.isNotEmpty) {
        for (final w in _workers.values.toList()) {
          w.stop();
        }
        await Future.wait([for (final w in _workers.values.toList()) w.done.future]);
      }
    }
    final groups = await _groups();
    if (groups.isEmpty) return;
    await _refreshTotals();
    for (final entry in groups.entries) {
      if (_workers.containsKey(entry.key)) continue;
      _launch(entry.key, entry.value);
    }
  }

  /// Pausa: os pendentes continuam pendentes; nada recomeça sozinho até
  /// [start] ser chamado.
  Future<void> pause() async {
    _emit(_current.copyWith(paused: true));
    final running = _workers.values.toList();
    for (final w in running) {
      w.stop();
    }
    await Future.wait([for (final w in running) w.done.future]);
  }

  /// Espera todos os workers terminarem.
  Future<void> waitIdle() async {
    while (_workers.isNotEmpty) {
      await Future.wait([for (final w in _workers.values.toList()) w.done.future]);
    }
  }

  /// Volta para a fila os arquivos com erro ou que mudaram durante a leitura.
  Future<int> retryFailed({String? sourceId}) => db.customUpdate(
    "UPDATE file_instances SET hash_status = 'pending', hash_error = NULL "
    "WHERE hash_status IN ('error', 'changed_during_read') AND availability = 'present'"
    "${sourceId == null ? '' : ' AND source_id = ?'}",
    variables: [if (sourceId != null) Variable.withString(sourceId)],
    updates: {db.fileInstances},
  );

  /// Fontes conectadas com pendências, agrupadas por disco físico.
  Future<Map<String, List<HashTarget>>> _groups() async {
    final rows = await db
        .customSelect(
          '''
          SELECT s.id, s.kind, s.physical_disk_id, s.volume_guid FROM sources s
          WHERE s.forgotten_at IS NULL AND EXISTS (
            SELECT 1 FROM file_instances fi
            WHERE fi.source_id = s.id AND fi.hash_status = 'pending' AND fi.availability = 'present')
          ''',
          readsFrom: {db.sources, db.fileInstances},
        )
        .get();
    final groups = <String, List<HashTarget>>{};
    for (final r in rows) {
      final id = r.read<String>('id');
      if (scans.isRunning(id)) continue; // um leitor por vez: o scan termina antes
      if (r.read<String>('kind') == 'phone') {
        // Celular: um leitor por aparelho, e só desbloqueado e autorizado.
        final device = sources.deviceFor(id);
        if (device == null || !device.isReady || sources.devices == null) continue;
        groups['phone:$id'] = [HashTarget(id, '', deviceId: device.deviceId)];
        continue;
      }
      final row = await sources.byId(id);
      final root = row == null ? null : sources.accessRoot(row);
      if (root == null) continue; // desconectada: fica para depois
      final disk = r.readNullable<int>('physical_disk_id');
      final key = disk != null ? 'disk:$disk' : 'vol:${(r.readNullable<String>('volume_guid') ?? id).toLowerCase()}';
      (groups[key] ??= []).add(HashTarget(id, root));
    }
    return groups;
  }

  Future<void> _refreshTotals() async {
    final rows = await db
        .customSelect(
          "SELECT source_id, COUNT(*) AS n, COALESCE(SUM(size_bytes), 0) AS b FROM file_instances "
          "WHERE hash_status = 'pending' AND availability = 'present' GROUP BY source_id",
          readsFrom: {db.fileInstances},
        )
        .get();
    final fresh = !_current.running;
    final per = <String, ({int done, int total})>{};
    var files = 0, bytes = 0;
    for (final r in rows) {
      final id = r.read<String>('source_id');
      final n = r.read<int>('n');
      final done = fresh ? 0 : (_current.perSource[id]?.done ?? 0);
      per[id] = (done: done, total: done + n);
      files += n;
      bytes += r.read<int>('b');
    }
    _emit(
      fresh
          ? HashStatus(running: true, filesTotal: files, bytesTotal: bytes, startedAt: DateTime.now(), perSource: per)
          : _current.copyWith(
              filesTotal: _current.filesDone + files,
              bytesTotal: _current.bytesDone + bytes,
              perSource: per,
            ),
    );
  }

  void _onFile(HashFileEvent e) {
    final per = Map.of(_current.perSource);
    final s = per[e.sourceId];
    if (s != null) per[e.sourceId] = (done: s.done + 1, total: s.total);
    _emit(
      _current.copyWith(
        filesDone: _current.filesDone + 1,
        bytesDone: _current.bytesDone + e.bytes,
        errors: _current.errors + (e.kind == 'error' ? 1 : 0),
        changed: _current.changed + (e.kind == 'changed' ? 1 : 0),
        perSource: per,
      ),
    );
  }

  void _launch(String key, List<HashTarget> targets) {
    final worker = _workers[key] = _Worker(key, {for (final t in targets) t.sourceId});

    void finish(HashWorkerDone done) {
      if (_workers[key] == worker) _workers.remove(key);
      if (!worker.done.isCompleted) worker.done.complete();
      if (_workers.isEmpty) {
        _emit(
          HashStatus(
            paused: _current.paused,
            filesDone: _current.filesDone,
            bytesDone: _current.bytesDone,
            filesTotal: _current.filesTotal,
            bytesTotal: _current.bytesTotal,
            errors: _current.errors,
            changed: _current.changed,
            message: done.message,
          ),
        );
        // Entrou coisa nova (scan terminou) enquanto rodava? Continua.
        if (!worker.stopRequested) _autoStart();
      }
    }

    // Celular: o helper (outro processo) lê e calcula o hash; aqui só chegam
    // as respostas, então roda no isolate atual.
    final phone = targets.any((t) => t.deviceId != null);
    if (!useIsolate || phone) {
      HashEngine(
            db,
            targets: targets,
            priority: _priority,
            chunkSize: chunkSize,
            afterFirstChunk: debugAfterFirstChunk,
            devices: sources.devices,
          )
          .run(stopRequested: () => worker.stopRequested, onFile: _onFile)
          .then(
            finish,
            // Mesmo tratamento do worker em isolate: os pendentes continuam pendentes.
            onError: (Object e) => finish(HashWorkerDone(message: 'Erro inesperado na conferência: $e')),
          );
      return;
    }

    final events = ReceivePort();
    final exit = ReceivePort();
    var reported = false;
    events.listen((message) {
      if (message is SendPort) {
        worker.control = message;
        if (worker.stopRequested) message.send(true);
      } else if (message is HashFileEvent) {
        _onFile(message);
      } else if (message is HashWorkerDone) {
        reported = true;
        events.close();
        finish(message);
      }
    });
    exit.listen((_) {
      exit.close();
      events.close();
      // Worker morreu sem relatar: os pendentes continuam pendentes.
      if (!reported) finish(const HashWorkerDone(message: 'A conferência parou inesperadamente.'));
    });
    Isolate.spawn(
      _hashWorkerMain,
      _WorkerArgs(catalog.connectPort, events.sendPort, targets, _priority, chunkSize),
      onExit: exit.sendPort,
      debugName: 'hash-$key',
    );
  }

  void _emit(HashStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  /// Para os workers e espera no máximo [timeout]. Quem não parar a tempo
  /// (ex.: lendo um arquivo grande pelo USB) é abandonado: o arquivo continua
  /// `pending` no banco e é conferido na próxima vez.
  /// Devolve `false` se algum worker foi abandonado.
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposed = true;
    unawaited(_autoScan?.cancel());
    unawaited(_autoSources?.cancel());
    final running = _workers.values.toList();
    for (final w in running) {
      w.stop();
    }
    final stopped = await Future.wait([for (final w in running) w.done.future])
        .then((_) => true)
        .timeout(timeout, onTimeout: () => false);
    // Sem `await`: um ouvinte pausado faria o close() nunca terminar.
    unawaited(_status.close());
    return stopped;
  }
}
