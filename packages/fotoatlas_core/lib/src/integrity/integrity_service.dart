import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../catalog/catalog.dart';
import '../catalog/catalog_database.dart';
import '../ops/copy_models.dart';
import '../settings/settings_store.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import 'integrity_engine.dart';
import 'integrity_models.dart';

/// Vazão da verificação leve (periódica): ~24 MB/s, uma fração do que um HD
/// USB entrega, para não pesar no uso do computador.
const int lightBytesPerSecond = 24 * 1024 * 1024;

const _scheduleKey = 'integrity.schedule';
const _dayMs = 24 * 60 * 60 * 1000;

class _WorkerArgs {
  _WorkerArgs(this.connectPort, this.events, this.runId, this.targets, this.bytesPerSecond, this.chunkSize);
  final SendPort connectPort;
  final SendPort events;
  final int runId;
  final List<VerifyTarget> targets;
  final int? bytesPerSecond;
  final int chunkSize;
}

Future<void> _verifyWorkerMain(_WorkerArgs args) async {
  var stop = false;
  final control = ReceivePort()..listen((_) => stop = true);
  args.events.send(control.sendPort);
  final db = await Catalog.connectWorker(args.connectPort);
  try {
    final done = await IntegrityEngine(
      db,
      runId: args.runId,
      targets: args.targets,
      bytesPerSecond: args.bytesPerSecond,
      chunkSize: args.chunkSize,
    ).run(stopRequested: () => stop, onFile: args.events.send);
    args.events.send(done);
  } catch (e) {
    args.events.send(VerifyWorkerDone(message: 'Erro inesperado na verificação: $e'));
  } finally {
    await db.close();
    control.close();
  }
}

/// Por que a rodada em andamento parou.
enum _StopReason { none, user, cancel, busy, closing, preempted }

class _Active {
  _Active(this.runId, {required this.scheduled});
  final int runId;

  /// Corrigido ao ler a rodada (uma periódica pode ser continuada pelo usuário).
  bool scheduled;
  final done = Completer<void>();
  _StopReason reason = _StopReason.none;
  SendPort? control;
  bool get stopRequested => reason != _StopReason.none;
  void stop(_StopReason why) {
    if (reason == _StopReason.none) reason = why;
    control?.send(true);
  }
}

/// Verificação periódica de integridade (spec §14, ADR 0018).
///
/// - **Só lê** os arquivos; o resultado vai para o catálogo. Nada é
///   substituído nem apagado; restaurar é uma cópia segura (Fase 5) a partir
///   de outra cópia conferida, com prévia e confirmação ([restoreRequest]).
/// - Uma rodada por vez; pausar, continuar e cancelar a qualquer momento, e
///   fechar o app no meio só deixa a rodada "interrompida".
/// - A periódica é leve: lê devagar, espera quando há outra tarefa
///   (escaneamento, conferência, cópia, reorganização) e nunca inclui
///   celulares.
class IntegrityService {
  IntegrityService(
    this.catalog,
    this.sources, {
    this.useIsolate = true,
    bool Function()? busy,
    this.lightRate = lightBytesPerSecond,
    this.chunkSize = 1 << 20,
  }) : _busy = busy ?? (() => false);

  final Catalog catalog;
  final SourcesService sources;
  final bool useIsolate;

  /// Outra tarefa pesada em andamento (a verificação periódica espera).
  final bool Function() _busy;

  /// Vazão da verificação periódica (bytes/s).
  final int lightRate;
  final int chunkSize;

  CatalogDatabase get db => catalog.db;
  late final SettingsStore _settings = SettingsStore(db);
  final _progress = StreamController<IntegrityProgress>.broadcast();
  IntegrityProgress? _current;
  _Active? _active;
  Future<void>? _executing;
  final List<int> _queue = [];
  Timer? _scheduleTimer;
  Timer? _busyWatch;
  bool _disposed = false;

  Stream<IntegrityProgress> get progress => _progress.stream;
  IntegrityProgress? get current => _current;
  bool get isRunning => _active != null;

  /// Rodadas que ficaram `running` (o app fechou no meio) viram interrompidas.
  Future<void> recover() => db.customUpdate(
    "UPDATE integrity_runs SET status = 'paused', paused_by_user = 0, "
    "message = 'Interrompida quando o FotoAtlas fechou. Continua de onde parou.' WHERE status = 'running'",
    updates: {db.integrityRuns},
  );

  // ---------------------------------------------------------------- seleção

  /// Fontes que podem ser lidas agora: discos conectados e, se [phones],
  /// celulares prontos.
  Future<({List<String> disks, List<String> phones, List<String> offline})> _readable(Iterable<String> ids) async {
    final disks = <String>[], phones = <String>[], offline = <String>[];
    for (final id in ids) {
      final row = await sources.byId(id);
      if (row == null || row.forgottenAt != null) continue;
      if (row.kind == 'phone') {
        final d = sources.deviceFor(id);
        (d != null && d.isReady && sources.devices != null ? phones : offline).add(id);
      } else {
        (sources.accessRoot(row) != null ? disks : offline).add(id);
      }
    }
    return (disks: disks, phones: phones, offline: offline);
  }

  /// Cláusula do escopo pedido sobre `fi` para as fontes em [allowed].
  (String, List<Variable<Object>>) _where(VerifyRequest r, List<String> allowed, {bool onlyConferred = true}) {
    final vars = <Variable<Object>>[];
    final parts = <String>[];
    final allowedSet = allowed.toSet();
    for (final e in r.entries) {
      if (!allowedSet.contains(e.sourceId)) continue;
      if (e.folder.isEmpty) {
        parts.add('fi.source_id = ?');
        vars.add(Variable.withString(e.sourceId));
      } else {
        parts.add('(fi.source_id = ? AND (fi.rel_path = ? OR substr(fi.rel_path, 1, ?) = ?))');
        vars
          ..add(Variable.withString(e.sourceId))
          ..add(Variable.withString(e.folder))
          ..add(Variable.withInt(e.folder.length + 1))
          ..add(Variable.withString('${e.folder}/'));
      }
    }
    if (r.contentIds.isNotEmpty && allowed.isNotEmpty) {
      // Pela Biblioteca: só discos (celular só quando o usuário escolhe o celular).
      parts.add(
        '(fi.content_id IN (SELECT value FROM json_each(?)) '
        "AND fi.source_id IN (${List.filled(allowed.length, '?').join(',')}) "
        "AND (SELECT kind FROM sources WHERE id = fi.source_id) != 'phone')",
      );
      vars
        ..add(Variable.withString(jsonEncode(r.contentIds)))
        ..addAll(allowed.map(Variable.withString));
    }
    if (parts.isEmpty) return ('0', const []);
    final buffer = StringBuffer("fi.availability = 'present' AND (${parts.join(' OR ')})");
    if (onlyConferred) buffer.write(" AND fi.hash_status = 'done' AND fi.content_id IS NOT NULL");
    final days = r.olderThanDays;
    if (days != null) {
      buffer.write(' AND COALESCE(fi.last_verified_at, fi.hashed_at, 0) <= ?');
      vars.add(Variable.withInt(nowMs() - days * _dayMs));
    }
    return (buffer.toString(), vars);
  }

  Set<String> _sourcesOf(VerifyRequest r, Iterable<String> all) => {...r.entries.map((e) => e.sourceId), ...all};

  Future<List<String>> _allDiskSources() async {
    final rows = await db
        .customSelect("SELECT id FROM sources WHERE forgotten_at IS NULL AND kind != 'phone'", readsFrom: {db.sources})
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Quanto [request] vai ler, antes de começar (só consulta o catálogo).
  Future<VerifyEstimate> estimate(VerifyRequest request) async {
    final all = request.contentIds.isEmpty ? const <String>[] : await _allDiskSources();
    final r = await _readable(_sourcesOf(request, all));
    final readable = [...r.disks, ...r.phones];
    Future<(int, int)> sum(List<String> allowed, {bool onlyConferred = true, String extra = ''}) async {
      final (where, vars) = _where(request, allowed, onlyConferred: onlyConferred);
      final row = await db
          .customSelect(
            'SELECT COUNT(*) AS n, COALESCE(SUM(fi.size_bytes), 0) AS b FROM file_instances fi WHERE $where $extra',
            variables: vars,
            readsFrom: {db.fileInstances},
          )
          .getSingle();
      return (row.read<int>('n'), row.read<int>('b'));
    }

    final (files, bytes) = await sum(readable);
    final (phoneFiles, _) = await sum(r.phones);
    final (offline, _) = await sum(r.offline);
    final (pending, _) = await sum(readable, onlyConferred: false, extra: "AND fi.hash_status = 'pending'");
    return VerifyEstimate(
      files: files,
      bytes: bytes,
      phoneFiles: phoneFiles,
      skippedDisconnected: offline,
      notYetConferred: pending,
    );
  }

  // --------------------------------------------------------------- rodadas

  /// Cria a rodada (fixa a lista de arquivos) e começa. Se já houver uma
  /// verificação do usuário em andamento, esta espera na fila; uma periódica
  /// em andamento cede a vez. Devolve o id da rodada, ou `null` se não há
  /// nada a verificar agora.
  Future<int?> start(VerifyRequest request, {bool scheduled = false}) async {
    if (_disposed) return null;
    final all = request.contentIds.isEmpty ? const <String>[] : await _allDiskSources();
    final r = await _readable(_sourcesOf(request, all));
    // Celular nunca entra na periódica (só quando o usuário pede).
    final allowed = [...r.disks, if (!scheduled) ...r.phones];
    final (where, vars) = _where(request, allowed);
    final label = await _label(request);
    final runId = await db.transaction(() async {
      final now = nowMs();
      final id = await db.customInsert(
        'INSERT INTO integrity_runs (run_trigger, status, scope_json, total_files, total_bytes, created_at) '
        "VALUES (?, 'paused', ?, 0, 0, ?)",
        variables: [
          Variable.withString(scheduled ? 'scheduled' : 'manual'),
          Variable.withString(
            jsonEncode({
              'label': label,
              'entries': [for (final e in request.entries) e.toJson()],
              if (request.contentIds.isNotEmpty) 'contents': request.contentIds.length,
              'olderThanDays': ?request.olderThanDays,
              'phone': request.entries.any((e) => r.phones.contains(e.sourceId)) && !scheduled,
            }),
          ),
          Variable.withInt(now),
        ],
        updates: {db.integrityRuns},
      );
      await db.customInsert(
        'INSERT INTO integrity_run_items (run_id, instance_id) SELECT ?, fi.id FROM file_instances fi WHERE $where',
        variables: [Variable.withInt(id), ...vars],
        updates: {db.integrityRunItems},
      );
      await db.customUpdate(
        'UPDATE integrity_runs SET total_files = (SELECT COUNT(*) FROM integrity_run_items WHERE run_id = ?1), '
        'total_bytes = (SELECT COALESCE(SUM(fi.size_bytes), 0) FROM integrity_run_items ri '
        'JOIN file_instances fi ON fi.id = ri.instance_id WHERE ri.run_id = ?1) WHERE id = ?1',
        variables: [Variable.withInt(id)],
        updates: {db.integrityRuns},
      );
      return id;
    });
    final total = await db
        .customSelect('SELECT total_files FROM integrity_runs WHERE id = ?', variables: [Variable.withInt(runId)])
        .getSingle();
    if (total.read<int>('total_files') == 0) {
      await _setStatus(runId, RunStatus.completed, message: 'Nada para verificar agora.', finished: true);
      return null;
    }
    await _enqueue(runId, scheduled: scheduled);
    return runId;
  }

  Future<String> _label(VerifyRequest r) async {
    final names = <String>[];
    for (final e in r.entries) {
      final row = await sources.byId(e.sourceId);
      final name = row?.name ?? '?';
      names.add(e.folder.isEmpty ? name : '$name › ${e.folder.replaceAll('/', ' › ')}');
    }
    if (r.contentIds.isNotEmpty) {
      final n = r.contentIds.length;
      names.add(n == 1 ? '1 item da Biblioteca' : '$n itens da Biblioteca');
    }
    return names.join(', ');
  }

  Future<void> _enqueue(int runId, {required bool scheduled}) async {
    final active = _active;
    if (active != null) {
      if (active.scheduled && !scheduled) {
        // A do usuário passa na frente; a periódica continua depois sozinha.
        active.stop(_StopReason.preempted);
        await _executing;
      } else {
        if (!_queue.contains(runId)) _queue.add(runId);
        await _setStatus(runId, RunStatus.paused, message: 'Na fila: começa quando a verificação atual terminar.');
        return;
      }
    }
    _launch(runId, scheduled: scheduled);
  }

  /// `_active` nasce aqui, antes de qualquer `await`: um "Pausar" logo depois
  /// de "Verificar" sempre encontra a rodada.
  void _launch(int runId, {required bool scheduled}) {
    final active = _active = _Active(runId, scheduled: scheduled);
    _executing = _execute(active);
  }

  /// Continua uma rodada pausada ou interrompida.
  Future<void> resume(int runId) async {
    final run = await _run(runId);
    if (run == null || run.status != RunStatus.paused) return;
    await _enqueue(runId, scheduled: false);
  }

  /// Pausa: nada mais é lido até "Continuar".
  Future<void> pause(int runId) async {
    _queue.remove(runId);
    final active = _active;
    if (active != null && active.runId == runId) {
      active.stop(_StopReason.user);
      await _executing;
      return;
    }
    await db.customUpdate(
      "UPDATE integrity_runs SET status = 'paused', paused_by_user = 1, message = 'Pausada.' "
      "WHERE id = ? AND status IN ('running', 'paused')",
      variables: [Variable.withInt(runId)],
      updates: {db.integrityRuns},
    );
  }

  /// Cancela o que falta (o que já foi verificado fica no histórico).
  Future<void> cancel(int runId) async {
    _queue.remove(runId);
    final active = _active;
    if (active != null && active.runId == runId) {
      active.stop(_StopReason.cancel);
      await _executing;
      return;
    }
    await _setStatus(runId, RunStatus.cancelled, finished: true);
  }

  /// Espera a rodada atual e a fila terminarem (testes e CLI).
  Future<void> waitIdle() async {
    while (_executing != null) {
      await _executing;
    }
  }

  Future<void> _execute(_Active active) async {
    try {
      await _executeOnce(active);
    } finally {
      _executing = null;
      if (identical(_active, active)) _active = null;
      if (!active.done.isCompleted) active.done.complete();
    }
    if (_disposed) return;
    if (_queue.isNotEmpty) _launch(_queue.removeAt(0), scheduled: false);
  }

  Future<void> _executeOnce(_Active active) async {
    final runId = active.runId;
    final run = await _run(runId);
    if (run == null) return;
    final scheduled = active.scheduled = run.runTrigger == 'scheduled';
    final ids = await db
        .customSelect(
          'SELECT DISTINCT fi.source_id FROM integrity_run_items ri JOIN file_instances fi ON fi.id = ri.instance_id '
          'WHERE ri.run_id = ?',
          variables: [Variable.withInt(runId)],
        )
        .get();
    final r = await _readable([for (final x in ids) x.read<String>('source_id')]);
    final targets = <VerifyTarget>[
      for (final id in r.disks)
        if (await sources.byId(id) case final row?)
          VerifyTarget(id, sources.accessRoot(row)!, fat: _isFat(row.filesystem)),
      if (!scheduled)
        for (final id in r.phones) VerifyTarget(id, '', deviceId: sources.deviceFor(id)!.deviceId),
    ];
    final bytesPerSecond = scheduled ? lightRate : null;
    try {
      await db.customUpdate(
        "UPDATE integrity_runs SET status = 'running', paused_by_user = 0, message = NULL, "
        'started_at = COALESCE(started_at, ?) WHERE id = ?',
        variables: [Variable.withInt(nowMs()), Variable.withInt(runId)],
        updates: {db.integrityRuns},
      );
      final counts = await _counts(runId);
      final done = counts.values.fold(0, (a, b) => a + b);
      final doneBytes = await _checkedBytes(runId);
      var progress = IntegrityProgress(
        runId: runId,
        scheduled: scheduled,
        filesDone: done,
        filesTotal: run.totalFiles,
        bytesDone: doneBytes,
        bytesTotal: run.totalBytes,
        light: scheduled,
        counts: counts,
      );
      _emit(progress);
      void onFile(VerifyFileEvent e) {
        final c = Map.of(progress.counts);
        if (e.result != null) c[e.result!] = (c[e.result!] ?? 0) + 1;
        progress = IntegrityProgress(
          runId: runId,
          scheduled: scheduled,
          filesDone: progress.filesDone + (e.result == null ? 0 : 1),
          filesTotal: progress.filesTotal,
          bytesDone: progress.bytesDone + e.bytes,
          bytesTotal: progress.bytesTotal,
          currentName: e.name,
          light: scheduled,
          counts: c,
        );
        _emit(progress);
      }

      if (scheduled) {
        // A periódica cede a vez a qualquer outra tarefa pesada.
        _busyWatch = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_busy()) active.stop(_StopReason.busy);
        });
        if (_busy()) active.stop(_StopReason.busy);
      }
      final result = targets.isEmpty || active.stopRequested
          ? const VerifyWorkerDone()
          : await _runEngine(active, targets, bytesPerSecond, onFile);
      _busyWatch?.cancel();
      await _finish(runId, active, result, r.offline);
      _emit(
        IntegrityProgress(
          runId: runId,
          scheduled: scheduled,
          filesDone: progress.filesDone,
          filesTotal: progress.filesTotal,
          bytesDone: progress.bytesDone,
          bytesTotal: progress.bytesTotal,
          running: false,
          light: scheduled,
          counts: progress.counts,
        ),
      );
    } finally {
      _busyWatch?.cancel();
    }
  }

  Future<VerifyWorkerDone> _runEngine(
    _Active active,
    List<VerifyTarget> targets,
    int? bytesPerSecond,
    void Function(VerifyFileEvent) onFile,
  ) {
    // Celular: o helper (outro processo) lê; aqui só chegam as respostas.
    if (!useIsolate || targets.any((t) => t.deviceId != null)) {
      return IntegrityEngine(
            db,
            runId: active.runId,
            targets: targets,
            devices: sources.devices,
            bytesPerSecond: bytesPerSecond,
            chunkSize: chunkSize,
          )
          .run(stopRequested: () => active.stopRequested, onFile: onFile)
          .catchError((Object e) => VerifyWorkerDone(message: 'Erro inesperado na verificação: $e'));
    }
    final finished = Completer<VerifyWorkerDone>();
    final events = ReceivePort();
    final exit = ReceivePort();
    events.listen((message) {
      if (message is SendPort) {
        active.control = message;
        if (active.stopRequested) message.send(true);
      } else if (message is VerifyFileEvent) {
        onFile(message);
      } else if (message is VerifyWorkerDone) {
        events.close();
        if (!finished.isCompleted) finished.complete(message);
      }
    });
    exit.listen((_) {
      exit.close();
      events.close();
      if (!finished.isCompleted) {
        finished.complete(const VerifyWorkerDone(message: 'A verificação parou inesperadamente.'));
      }
    });
    Isolate.spawn(
      _verifyWorkerMain,
      _WorkerArgs(catalog.connectPort, events.sendPort, active.runId, targets, bytesPerSecond, chunkSize),
      onExit: exit.sendPort,
      debugName: 'verify-${active.runId}',
    );
    return finished.future;
  }

  Future<void> _finish(int runId, _Active active, VerifyWorkerDone done, List<String> offlineAtStart) async {
    switch (active.reason) {
      case _StopReason.cancel:
        await _setStatus(runId, RunStatus.cancelled, finished: true);
        return;
      case _StopReason.user:
        await db.customUpdate(
          "UPDATE integrity_runs SET status = 'paused', paused_by_user = 1, message = 'Pausada.' WHERE id = ?",
          variables: [Variable.withInt(runId)],
          updates: {db.integrityRuns},
        );
        return;
      case _StopReason.busy:
        await _setStatus(
          runId,
          RunStatus.paused,
          message: 'Esperando outras tarefas terminarem (continua sozinha, devagar).',
        );
        return;
      case _StopReason.closing:
        await _setStatus(
          runId,
          RunStatus.paused,
          message: 'Interrompida quando o FotoAtlas fechou. Continua de onde parou.',
        );
        return;
      case _StopReason.preempted:
        await _setStatus(runId, RunStatus.paused, message: 'Esperando a verificação pedida por você terminar.');
        return;
      case _StopReason.none:
        break;
    }
    final remaining = await _remainingBySource(runId);
    if (remaining.isEmpty) {
      await _setStatus(runId, RunStatus.completed, message: done.message, finished: true);
      return;
    }
    final names = <String>[];
    for (final id in remaining.keys) {
      names.add((await sources.byId(id))?.name ?? '?');
    }
    final n = remaining.values.fold(0, (a, b) => a + b);
    final files = n == 1 ? '1 arquivo fica' : '$n arquivos ficam';
    await _setStatus(
      runId,
      RunStatus.paused,
      message:
          done.message ??
          '${names.map((s) => '"$s"').join(', ')} não ${names.length == 1 ? 'está' : 'estão'} acessível agora: '
              '$files para quando ${names.length == 1 ? 'voltar' : 'voltarem'}.',
    );
  }

  /// Arquivos da rodada ainda sem resultado (e que ainda podem ser verificados).
  Future<Map<String, int>> _remainingBySource(int runId) async {
    final rows = await db
        .customSelect(
          '''
          SELECT fi.source_id, COUNT(*) AS n FROM integrity_run_items ri
          JOIN file_instances fi ON fi.id = ri.instance_id
          WHERE ri.run_id = ? AND fi.hash_status = 'done' AND fi.availability = 'present' AND fi.content_id IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM integrity_checks ic WHERE ic.run_id = ri.run_id AND ic.instance_id = ri.instance_id)
          GROUP BY fi.source_id
          ''',
          variables: [Variable.withInt(runId)],
        )
        .get();
    return {for (final r in rows) r.read<String>('source_id'): r.read<int>('n')};
  }

  Future<Map<String, int>> _counts(int runId) async {
    final rows = await db
        .customSelect(
          'SELECT result, COUNT(*) AS n FROM integrity_checks WHERE run_id = ? GROUP BY result',
          variables: [Variable.withInt(runId)],
        )
        .get();
    return {for (final r in rows) r.read<String>('result'): r.read<int>('n')};
  }

  Future<int> _checkedBytes(int runId) async =>
      (await db
              .customSelect(
                'SELECT COALESCE(SUM(fi.size_bytes), 0) AS b FROM integrity_checks ic '
                'JOIN file_instances fi ON fi.id = ic.instance_id WHERE ic.run_id = ?',
                variables: [Variable.withInt(runId)],
              )
              .getSingle())
          .read<int>('b');

  Future<IntegrityRunRow?> _run(int id) =>
      (db.select(db.integrityRuns)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<void> _setStatus(int runId, String status, {String? message, bool finished = false}) => db.customUpdate(
    'UPDATE integrity_runs SET status = ?, paused_by_user = 0, message = ?'
    '${finished ? ', finished_at = ?' : ''} WHERE id = ?',
    variables: [
      Variable.withString(status),
      Variable(message),
      if (finished) Variable.withInt(nowMs()),
      Variable.withInt(runId),
    ],
    updates: {db.integrityRuns},
  );

  static bool _isFat(String? fs) {
    final f = (fs ?? '').toUpperCase();
    return f == 'FAT32' || f == 'FAT' || f == 'FAT16' || f == 'FAT12';
  }

  void _emit(IntegrityProgress p) {
    _current = p;
    if (!_progress.isClosed) _progress.add(p);
  }

  // ------------------------------------------------------------ agendamento

  Future<IntegritySchedule> schedule() async => IntegritySchedule.fromJson(await _settings.get(_scheduleKey));

  Future<void> setSchedule(IntegritySchedule s) async {
    await _settings.set(_scheduleKey, s.toJson());
    if (!s.enabled) {
      final a = _active;
      if (a != null && a.scheduled) {
        a.stop(_StopReason.user);
        await _executing;
      }
    }
  }

  /// Liga a verificação periódica: confere a cada [interval] (a primeira vez
  /// depois de [firstDelay]) se há algo a fazer.
  void enableSchedule({
    Duration firstDelay = const Duration(minutes: 2),
    Duration interval = const Duration(minutes: 10),
  }) {
    if (_scheduleTimer != null || _disposed) return;
    _scheduleTimer = Timer(firstDelay, () {
      scheduleTick().ignore();
      _scheduleTimer = Timer.periodic(interval, (_) => scheduleTick().ignore());
    });
  }

  /// Um passo do agendamento (público para testes e CLI):
  /// 1. se há outra tarefa pesada ou uma verificação rodando, não faz nada;
  /// 2. continua uma rodada que estava esperando (só discos);
  /// 3. senão, começa uma rodada leve com o que não é conferido há mais do
  ///    que o intervalo, nos discos conectados. Celulares, nunca.
  /// Devolve o id da rodada que começou ou continuou.
  Future<int?> scheduleTick() async {
    if (_disposed || _active != null || _busy()) return null;
    final s = await schedule();
    if (!s.enabled) return null;
    final waiting = await db
        .customSelect(
          // Só as periódicas continuam sozinhas; a do usuário espera "Continuar".
          "SELECT id, scope_json FROM integrity_runs WHERE status = 'paused' AND paused_by_user = 0 "
          "AND run_trigger = 'scheduled' ORDER BY id",
          readsFrom: {db.integrityRuns},
        )
        .get();
    for (final w in waiting) {
      final id = w.read<int>('id');
      if (_queue.contains(id)) continue;
      final scope = jsonDecode(w.read<String>('scope_json')) as Map;
      if (scope['phone'] == true) continue; // celular: só o usuário continua
      final remaining = await _remainingBySource(id);
      if (remaining.isEmpty) {
        await _setStatus(id, RunStatus.completed, finished: true);
        continue;
      }
      final r = await _readable(remaining.keys);
      if (r.disks.isEmpty) continue;
      final run = await _run(id);
      _launch(id, scheduled: true);
      return run?.id;
    }
    final stale = await db
        .customSelect(
          '''
          SELECT DISTINCT fi.source_id FROM file_instances fi JOIN sources s ON s.id = fi.source_id
          WHERE s.forgotten_at IS NULL AND s.kind != 'phone' AND fi.availability = 'present'
            AND fi.hash_status = 'done' AND COALESCE(fi.last_verified_at, fi.hashed_at, 0) <= ?
          ''',
          variables: [Variable.withInt(nowMs() - s.everyDays * _dayMs)],
        )
        .get();
    final r = await _readable([for (final x in stale) x.read<String>('source_id')]);
    if (r.disks.isEmpty) return null;
    return start(
      VerifyRequest(entries: [for (final id in r.disks) VerifyEntry(id)], olderThanDays: s.everyDays),
      scheduled: true,
    );
  }

  // -------------------------------------------------------------- consultas

  static const _runsSql = '''
    SELECT r.*, (SELECT json_group_object(result, n) FROM
      (SELECT result, COUNT(*) AS n FROM integrity_checks WHERE run_id = r.id GROUP BY result)) AS counts
    FROM integrity_runs r ORDER BY r.id DESC LIMIT ?
  ''';

  Stream<List<IntegrityRunView>> watchRuns({int limit = 50}) => db
      .customSelect(_runsSql, variables: [Variable.withInt(limit)], readsFrom: {db.integrityRuns, db.integrityChecks})
      .watch()
      .map((rows) => rows.map(_runView).toList());

  Future<List<IntegrityRunView>> runs({int limit = 50}) async =>
      (await db.customSelect(_runsSql, variables: [Variable.withInt(limit)]).get()).map(_runView).toList();

  IntegrityRunView _runView(QueryRow r) {
    final scope = jsonDecode(r.read<String>('scope_json')) as Map;
    final counts = (jsonDecode(r.readNullable<String>('counts') ?? '{}') as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
    final finished = r.readNullable<int>('finished_at');
    return IntegrityRunView(
      id: r.read<int>('id'),
      scheduled: r.read<String>('run_trigger') == 'scheduled',
      status: r.read<String>('status'),
      pausedByUser: r.read<int>('paused_by_user') == 1,
      label: scope['label'] as String? ?? '',
      filesTotal: r.read<int>('total_files'),
      bytesTotal: r.read<int>('total_bytes'),
      counts: counts,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
      finishedAt: finished == null ? null : DateTime.fromMillisecondsSinceEpoch(finished),
      message: r.readNullable<String>('message'),
      includesPhone: scope['phone'] == true,
    );
  }

  /// Arquivos de uma rodada (opcionalmente só alguns resultados).
  Future<List<IntegrityCheckView>> checks(int runId, {Set<String>? results, int limit = 500}) async {
    final filter = results == null || results.isEmpty
        ? ''
        : 'AND ic.result IN (${List.filled(results.length, '?').join(',')})';
    final rows = await db
        .customSelect(
          '''
          SELECT ic.instance_id, ic.result, ic.checked_at, ic.reason, fi.source_id, fi.rel_path, s.name
          FROM integrity_checks ic JOIN file_instances fi ON fi.id = ic.instance_id
          JOIN sources s ON s.id = fi.source_id
          WHERE ic.run_id = ? $filter ORDER BY ic.result != 'possibly_corrupt', s.name, fi.rel_path LIMIT ?
          ''',
          variables: [
            Variable.withInt(runId),
            for (final x in results ?? const <String>{}) Variable.withString(x),
            Variable.withInt(limit),
          ],
        )
        .get();
    return [
      for (final r in rows)
        IntegrityCheckView(
          instanceId: r.read<int>('instance_id'),
          sourceId: r.read<String>('source_id'),
          sourceName: r.read<String>('name'),
          relPath: r.read<String>('rel_path'),
          result: r.read<String>('result'),
          checkedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('checked_at')),
          reason: r.readNullable<String>('reason'),
        ),
    ];
  }

  static const _problemsSql = '''
    SELECT fi.id, fi.source_id, fi.rel_path, fi.size_bytes, s.name, s.physical_disk_id,
      (SELECT ic.expected_content_id FROM integrity_checks ic WHERE ic.instance_id = fi.id
         AND ic.result = 'possibly_corrupt' ORDER BY ic.checked_at DESC, ic.id DESC LIMIT 1) AS expected,
      (SELECT MAX(ic.checked_at) FROM integrity_checks ic WHERE ic.instance_id = fi.id
         AND ic.result = 'possibly_corrupt') AS detected
    FROM file_instances fi JOIN sources s ON s.id = fi.source_id
    WHERE fi.integrity = 'possibly_corrupt' AND s.forgotten_at IS NULL
    ORDER BY detected DESC, s.name, fi.rel_path
  ''';

  /// Arquivos possivelmente corrompidos, com as outras cópias conferidas
  /// daquele conteúdo (spec §14).
  Future<List<IntegrityProblem>> problems() async => _problems(await db.customSelect(_problemsSql).get());

  Stream<List<IntegrityProblem>> watchProblems() => db
      .customSelect(_problemsSql, readsFrom: {db.fileInstances, db.integrityChecks, db.sources})
      .watch()
      .asyncMap(_problems);

  Future<List<IntegrityProblem>> _problems(List<QueryRow> rows) async {
    final out = <IntegrityProblem>[];
    for (final r in rows) {
      final id = r.read<int>('id');
      final sourceId = r.read<String>('source_id');
      final expected = r.readNullable<int>('expected');
      out.add(
        IntegrityProblem(
          instanceId: id,
          sourceId: sourceId,
          sourceName: r.read<String>('name'),
          relPath: r.read<String>('rel_path'),
          size: r.read<int>('size_bytes'),
          detectedAt: DateTime.fromMillisecondsSinceEpoch(r.readNullable<int>('detected') ?? 0),
          connected: sources.stateOf(sourceId) == SourceState.connected,
          expectedContentId: expected,
          otherCopies: expected == null
              ? const []
              : await otherCopies(
                  expected,
                  excludeInstance: id,
                  sourceId: sourceId,
                  disk: r.readNullable<int>('physical_disk_id'),
                ),
        ),
      );
    }
    return out;
  }

  /// Cópias conferidas de [contentId] (fora [excludeInstance]).
  Future<List<OtherCopy>> otherCopies(int contentId, {int? excludeInstance, String? sourceId, int? disk}) async {
    final rows = await db
        .customSelect(
          '''
          SELECT fi.id, fi.source_id, fi.rel_path, fi.last_verified_at, fi.hashed_at, s.name, s.kind, s.physical_disk_id
          FROM file_instances fi JOIN sources s ON s.id = fi.source_id
          WHERE fi.content_id = ? AND fi.hash_status = 'done' AND fi.availability != 'missing'
            AND s.forgotten_at IS NULL AND fi.id IS NOT ?
          ORDER BY s.name, fi.rel_path
          ''',
          variables: [Variable.withInt(contentId), Variable(excludeInstance)],
        )
        .get();
    return [
      for (final r in rows)
        () {
          final src = r.read<String>('source_id');
          final kind = r.read<String>('kind');
          final otherDisk = r.readNullable<int>('physical_disk_id');
          final verified = r.readNullable<int>('last_verified_at');
          final confirmed = verified ?? r.readNullable<int>('hashed_at');
          final connected = kind == 'phone'
              ? sources.deviceFor(src)?.isReady ?? false
              : sources.stateOf(src) == SourceState.connected;
          return OtherCopy(
            instanceId: r.read<int>('id'),
            sourceId: src,
            sourceName: r.read<String>('name'),
            sourceKind: kind,
            relPath: r.read<String>('rel_path'),
            connected: connected,
            sameSource: src == sourceId,
            samePhysicalDisk: src == sourceId || (disk != null && otherDisk == disk),
            lastConfirmedAt: confirmed == null ? null : DateTime.fromMillisecondsSinceEpoch(confirmed),
            recentlyVerified: verified != null,
          );
        }(),
    ];
  }

  /// Situação da verificação por fonte, com "não conferido há mais de
  /// [IntegritySchedule.everyDays] dias".
  Stream<List<SourceIntegrity>> watchOverview() => Stream.fromFuture(schedule()).asyncExpand(
    (s) => db
        .customSelect(
          _overviewSql,
          variables: [Variable.withInt(nowMs() - s.everyDays * _dayMs)],
          readsFrom: {db.fileInstances, db.sources},
        )
        .watch()
        .map((rows) => rows.map(_overviewRow).toList()),
  );

  Future<List<SourceIntegrity>> overview() async {
    final s = await schedule();
    final rows = await db
        .customSelect(_overviewSql, variables: [Variable.withInt(nowMs() - s.everyDays * _dayMs)])
        .get();
    return rows.map(_overviewRow).toList();
  }

  static const _overviewSql = '''
    SELECT s.id, s.name, s.kind,
      COUNT(fi.id) AS files,
      COALESCE(SUM(CASE WHEN COALESCE(fi.last_verified_at, fi.hashed_at, 0) <= ?1 THEN 1 ELSE 0 END), 0) AS stale,
      MAX(fi.last_verified_at) AS last_verified,
      MIN(COALESCE(fi.last_verified_at, fi.hashed_at)) AS oldest,
      (SELECT COUNT(*) FROM file_instances x WHERE x.source_id = s.id AND x.integrity = 'possibly_corrupt') AS corrupt
    FROM sources s
    LEFT JOIN file_instances fi ON fi.source_id = s.id AND fi.hash_status = 'done' AND fi.availability = 'present'
    WHERE s.forgotten_at IS NULL
    GROUP BY s.id ORDER BY s.name
  ''';

  SourceIntegrity _overviewRow(QueryRow r) {
    DateTime? at(String c) {
      final v = r.readNullable<int>(c);
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
    }

    return SourceIntegrity(
      sourceId: r.read<String>('id'),
      sourceName: r.read<String>('name'),
      kind: r.read<String>('kind'),
      files: r.read<int>('files'),
      staleFiles: r.read<int>('stale'),
      possiblyCorrupt: r.read<int>('corrupt'),
      lastVerifiedAt: at('last_verified'),
      oldestConfirmedAt: at('oldest'),
    );
  }

  // ------------------------------------------------------------- restaurar

  /// Pedido de cópia segura que restaura o arquivo danificado [instanceId] a
  /// partir da cópia conferida [fromInstanceId] (spec §14).
  ///
  /// A cópia vai para a **mesma pasta** do arquivo danificado, com outro nome
  /// (`foto_1.jpg`): o danificado nunca é substituído nem apagado. Passa pela
  /// prévia e confirmação da cópia segura, que confere o conteúdo da origem
  /// com o catálogo antes de publicar.
  Future<CopyRequest> restoreRequest(int instanceId, {required int fromInstanceId}) async {
    final problem = (await problems()).where((p) => p.instanceId == instanceId).firstOrNull;
    if (problem == null) throw StateError('Este arquivo não está marcado como possivelmente corrompido.');
    final expected = problem.expectedContentId;
    if (expected == null) throw StateError('Não se sabe qual era o conteúdo original deste arquivo.');
    final from = problem.otherCopies.where((c) => c.instanceId == fromInstanceId).firstOrNull;
    if (from == null) throw StateError('A cópia escolhida não tem o conteúdo original.');
    final dest = await sources.byId(problem.sourceId);
    if (dest?.kind == 'phone') {
      throw StateError('O FotoAtlas só lê do celular: para restaurar, copie a foto para um disco.');
    }
    final slash = problem.relPath.lastIndexOf('/');
    return CopyRequest(
      contentIds: [expected],
      destSourceId: problem.sourceId,
      destFolder: slash < 0 ? '' : problem.relPath.substring(0, slash),
      template: '',
      preferSourceIds: [from.sourceId],
      fileNames: {expected: problem.name},
      origin: 'restore',
    );
  }

  /// O usuário diz que a mudança é esperada ("aceitar como está"): o arquivo
  /// volta para a fila de conferência e passa a valer o conteúdo atual. Só
  /// catálogo; o arquivo não é tocado.
  Future<bool> acceptAsIs(int instanceId) async =>
      await db.customUpdate(
        "UPDATE file_instances SET hash_status = 'pending', hash_error = NULL, integrity = 'unknown' "
        "WHERE id = ? AND integrity = 'possibly_corrupt'",
        variables: [Variable.withInt(instanceId)],
        updates: {db.fileInstances},
      ) ==
      1;

  /// Para a rodada em andamento (fica "interrompida") e o agendamento.
  /// `false` se não parou a tempo (a rodada é marcada ao abrir de novo).
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposed = true;
    _scheduleTimer?.cancel();
    _busyWatch?.cancel();
    _queue.clear();
    _active?.stop(_StopReason.closing);
    final running = _executing;
    final ok = running == null ? true : await running.then((_) => true).timeout(timeout, onTimeout: () => false);
    unawaited(_progress.close());
    return ok;
  }
}
