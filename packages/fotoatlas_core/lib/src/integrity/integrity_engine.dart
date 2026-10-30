import 'dart:async';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../devices/devices.dart';
import '../hash/hash_engine.dart';
import '../platform/win_fs.dart';
import '../sources/media_types.dart';
import '../util/clock.dart';
import '../util/crashpoint.dart';
import 'integrity_models.dart';

/// Uma fonte que a rodada lê.
class VerifyTarget {
  const VerifyTarget(this.sourceId, this.accessRoot, {this.deviceId, this.fat = false});
  final String sourceId;

  /// Raiz Win32 de acesso; vazia no celular.
  final String accessRoot;

  /// Celular: ID WPD (o helper lê e calcula o hash).
  final String? deviceId;

  /// Disco FAT (data local: ±1 h exata no horário de verão não conta como edição).
  final bool fat;
}

/// Um arquivo verificado (progresso).
class VerifyFileEvent {
  const VerifyFileEvent(this.name, this.bytes, this.result);
  final String name;
  final int bytes;

  /// [CheckResult]; `null` = não foi registrado (o catálogo mudou no meio).
  final String? result;
}

/// Fim do trabalho de uma rodada.
class VerifyWorkerDone {
  const VerifyWorkerDone({this.goneSources = const [], this.message, this.stopped = false});
  final List<String> goneSources;
  final String? message;

  /// Parou a pedido (pausa, cancelamento, outra tarefa, app fechando).
  final bool stopped;
}

/// Verificação de integridade de uma rodada (spec §14).
///
/// **Só lê os arquivos** (pelo mesmo leitor da conferência,
/// `safe_io/source_reader.dart`, com `GENERIC_READ`); o resultado vai só para
/// o catálogo. Cada arquivo é registrado numa transação; matar o processo
/// perde no máximo o arquivo em andamento, que é lido de novo ao continuar.
class IntegrityEngine {
  IntegrityEngine(
    this.db, {
    required this.runId,
    required this.targets,
    this.devices,
    this.bytesPerSecond,
    this.chunkSize = 1 << 20,
  });

  final CatalogDatabase db;
  final int runId;
  final List<VerifyTarget> targets;
  final DeviceBackend? devices;

  /// Limite de leitura (verificação leve); `null` = sem limite.
  final int? bytesPerSecond;
  final int chunkSize;
  final Map<String, PhonePathResolver> _resolvers = {};

  /// Tempo desde o fim do bloco anterior (limite de vazão).
  final Stopwatch _sinceChunk = Stopwatch();

  Future<VerifyWorkerDone> run({required bool Function() stopRequested, void Function(VerifyFileEvent)? onFile}) async {
    final byId = {for (final t in targets) t.sourceId: t};
    final gone = <String>{};
    while (true) {
      if (stopRequested()) return VerifyWorkerDone(goneSources: gone.toList(), stopped: true);
      final active = byId.keys.where((s) => !gone.contains(s)).toList();
      final rows = await _pending(active);
      if (rows.isEmpty) break;
      for (final row in rows) {
        if (stopRequested()) return VerifyWorkerDone(goneSources: gone.toList(), stopped: true);
        if (gone.contains(row.sourceId)) continue;
        final target = byId[row.sourceId]!;
        final _Observed? seen;
        if (target.deviceId != null) {
          seen = await _readPhone(target.deviceId!, row, stopRequested);
        } else {
          seen = await _readDisk(target, row, stopRequested);
        }
        if (seen == null) {
          gone.add(row.sourceId);
          continue;
        }
        if (seen.interrupted) return VerifyWorkerDone(goneSources: gone.toList(), stopped: true);
        final result = await _record(row, seen, fat: target.fat);
        crashpoint('verify.after_file_commit');
        onFile?.call(VerifyFileEvent(row.relPath.split('/').last, row.size, result));
      }
    }
    return VerifyWorkerDone(goneSources: gone.toList());
  }

  Future<void> _pace(int bytes) async {
    final rate = bytesPerSecond;
    if (rate == null || rate <= 0) {
      await Future<void>.delayed(Duration.zero);
      return;
    }
    // Cada bloco leva pelo menos bytes/rate. Sem "crédito": tempo parado
    // (banco, outro arquivo, máquina ocupada) não vira rajada depois.
    final minimum = Duration(microseconds: bytes * 1000000 ~/ rate);
    final elapsed = _sinceChunk.isRunning ? _sinceChunk.elapsed : Duration.zero;
    final ahead = minimum - elapsed;
    await Future<void>.delayed(ahead.isNegative ? Duration.zero : ahead);
    _sinceChunk
      ..reset()
      ..start();
  }

  /// `null` = a fonte saiu (nada é registrado; continua na rodada).
  Future<_Observed?> _readDisk(VerifyTarget target, _Row row, bool Function() stopRequested) async {
    final outcome = await hashSourceFile(
      joinNative(target.accessRoot, row.relPath),
      expectedSize: row.size,
      expectedMtime: row.mtime,
      chunkSize: chunkSize,
      shouldStop: stopRequested,
      observeOnly: true,
      pace: _pace,
    );
    switch (outcome) {
      case HashDone(:final sha256, :final size, :final mtime):
        return _Observed.read(sha256, size, mtime);
      case HashInterrupted():
        return const _Observed.interrupted();
      case HashCloudOnly():
        return const _Observed.failed(
          CheckResult.unreadable,
          'Está só na nuvem (não foi baixado para o computador): não foi lido.',
        );
      case HashChanged():
        return const _Observed.failed(
          CheckResult.unreadable,
          'O arquivo mudou enquanto era lido (outro programa gravando?). Verifique de novo depois.',
        );
      case HashFailed(:final reason, :final notFound):
        if (!directoryAccessible(target.accessRoot)) return null;
        if (notFound) {
          return const _Observed.failed(
            CheckResult.missing,
            'Não está mais neste lugar (foi movido, renomeado ou apagado fora do FotoAtlas). Escaneie de novo.',
          );
        }
        return _Observed.failed(CheckResult.unreadable, reason);
    }
  }

  Future<_Observed?> _readPhone(String deviceId, _Row row, bool Function() stopRequested) async {
    final backend = devices!;
    final resolver = _resolvers[deviceId] ??= PhonePathResolver(backend, deviceId);
    final stop = Completer<void>();
    final watch = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (stopRequested() && !stop.isCompleted) stop.complete();
    });
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final objectId = attempt == 0 ? row.objectId : await resolver.file(row.relPath);
        if (objectId == null) continue;
        try {
          final h = await backend.hash(deviceId, objectId, expectedSize: row.size, cancel: stop.future);
          return _Observed.read(h.sha256, h.size, h.modified);
        } on DeviceException catch (e) {
          if (e.code == 'not_found') continue;
          if (e.code == 'cancelled') return const _Observed.interrupted();
          if (e.isDeviceGone) return null;
          if (e.code == 'changed_during_read') {
            return const _Observed.failed(
              CheckResult.unreadable,
              'O arquivo no celular mudou de tamanho desde o escaneamento. Escaneie de novo.',
            );
          }
          return _Observed.failed(CheckResult.unreadable, 'Erro de leitura no celular: ${e.message}');
        }
      }
      return const _Observed.failed(
        CheckResult.missing,
        'Não está mais no celular neste lugar (apagado ou movido). Escaneie de novo.',
      );
    } on DeviceException catch (e) {
      if (e.isDeviceGone) return null;
      return _Observed.failed(CheckResult.unreadable, 'Erro de leitura no celular: ${e.message}');
    } finally {
      watch.cancel();
    }
  }

  /// Arquivos da rodada ainda sem resultado, nas fontes ativas (lote).
  Future<List<_Row>> _pending(List<String> sources) async {
    if (sources.isEmpty) return const [];
    final rows = await db
        .customSelect(
          '''
          SELECT fi.id, fi.source_id, fi.rel_path, fi.ext, fi.size_bytes, fi.mtime, fi.content_id,
                 fi.device_object_id, c.sha256
          FROM integrity_run_items ri
          JOIN file_instances fi ON fi.id = ri.instance_id
          JOIN contents c ON c.id = fi.content_id
          WHERE ri.run_id = ? AND fi.source_id IN (${List.filled(sources.length, '?').join(',')})
            AND fi.hash_status = 'done' AND fi.availability = 'present'
            AND NOT EXISTS (SELECT 1 FROM integrity_checks ic
                            WHERE ic.run_id = ri.run_id AND ic.instance_id = ri.instance_id)
          ORDER BY fi.source_id, fi.dir_rel_path, fi.name
          LIMIT 64
          ''',
          variables: [Variable.withInt(runId), for (final s in sources) Variable.withString(s)],
          readsFrom: {db.integrityRunItems, db.fileInstances, db.contents, db.integrityChecks},
        )
        .get();
    return [
      for (final r in rows)
        _Row(
          r.read<int>('id'),
          r.read<String>('source_id'),
          r.read<String>('rel_path'),
          r.read<String>('ext'),
          r.read<int>('size_bytes'),
          r.readNullable<int>('mtime'),
          r.read<int>('content_id'),
          r.read<Uint8List>('sha256'),
          r.readNullable<String>('device_object_id'),
        ),
    ];
  }

  /// Grava o resultado no catálogo (uma transação). Só vale se a linha ainda
  /// for a que foi lida: um scan ou cópia no meio vence, e o arquivo é lido de
  /// novo. Devolve o resultado, ou `null` se não registrou.
  Future<String?> _record(_Row row, _Observed seen, {required bool fat}) async {
    final now = nowMs();
    final result = seen.sha256 == null
        ? seen.failure!
        : classifyCheck(
            expectedSha256: row.sha256,
            expectedSize: row.size,
            expectedMtime: row.mtime,
            observedSha256: seen.sha256!,
            observedSize: seen.size!,
            observedMtime: seen.mtime,
            fat: fat,
          );
    const guard =
        "WHERE id = ? AND content_id = ? AND size_bytes = ? AND mtime IS ? AND hash_status = 'done' "
        "AND availability = 'present'";
    final guardVars = [row.id, row.contentId, row.size, row.mtime];
    final recorded = await db.transaction(() async {
      final int changed;
      switch (result) {
        case CheckResult.unchanged:
          // Data mudou com o mesmo conteúdo: o catálogo acompanha (C7).
          changed = await db.customUpdate(
            "UPDATE file_instances SET last_verified_at = ?, integrity = 'ok', mtime = ?, hashed_mtime = ? $guard",
            variables: _vars([now, seen.mtime, seen.mtime, ...guardVars]),
            updates: {db.fileInstances},
          );
        case CheckResult.changedLegit:
          // Editado: passa a ser o conteúdo novo (já conferido nesta leitura).
          await db.customInsert(
            'INSERT INTO contents (sha256, size_bytes, media_type, created_at) VALUES (?, ?, ?, ?) '
            'ON CONFLICT (sha256, size_bytes) DO NOTHING',
            variables: _vars([seen.sha256, seen.size, MediaTypes.mediaTypeOf(row.ext), now]),
            updates: {db.contents},
          );
          changed = await db.customUpdate(
            'UPDATE file_instances SET content_id = (SELECT id FROM contents WHERE sha256 = ? AND size_bytes = ?), '
            'size_bytes = ?, mtime = ?, hashed_size = ?, hashed_mtime = ?, hashed_at = ?, last_verified_at = ?, '
            "integrity = 'changed' $guard",
            variables: _vars([
              seen.sha256,
              seen.size,
              seen.size,
              seen.mtime,
              seen.size,
              seen.mtime,
              now,
              now,
              ...guardVars,
            ]),
            updates: {db.fileInstances},
          );
        case CheckResult.possiblyCorrupt:
          // Deixa de contar como cópia do conteúdo (cobertura e comparação), e
          // não volta para a fila de conferência: aceitar o conteúdo danificado
          // como "conferido" esconderia o problema.
          changed = await db.customUpdate(
            "UPDATE file_instances SET content_id = NULL, hash_status = 'error', hash_error = ?, "
            "integrity = 'possibly_corrupt' $guard",
            variables: _vars([
              'Possivelmente corrompido: o conteúdo mudou, mas a data de modificação não. '
                  'Veja em Tarefas › Verificações.',
              ...guardVars,
            ]),
            updates: {db.fileInstances},
          );
        default:
          // Não lido / não encontrado: só o registro (regra 10: nunca "ausente").
          changed =
              (await db.customSelect('SELECT 1 FROM file_instances $guard', variables: _vars(guardVars)).get()).length;
      }
      if (changed == 0) return false;
      await db.customInsert(
        'INSERT INTO integrity_checks (instance_id, run_id, checked_at, result, observed_sha256, observed_size, '
        'observed_mtime, expected_content_id, reason) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: _vars([
          row.id,
          runId,
          now,
          result,
          seen.sha256,
          seen.size,
          seen.mtime,
          row.contentId,
          seen.reason ?? _reasonOf(result),
        ]),
        updates: {db.integrityChecks},
      );
      return true;
    });
    return recorded ? result : null;
  }

  static String? _reasonOf(String result) => switch (result) {
    CheckResult.changedLegit => 'O conteúdo e a data de modificação mudaram: o arquivo foi editado ou gravado de novo.',
    CheckResult.possiblyCorrupt =>
      'O conteúdo mudou, mas a data de modificação não: sinal de dano no disco. '
          'O arquivo não foi alterado nem apagado pelo FotoAtlas.',
    _ => null,
  };

  static List<Variable<Object>> _vars(List<Object?> values) => [for (final v in values) Variable<Object>(v)];
}

class _Observed {
  const _Observed.read(Uint8List this.sha256, int this.size, this.mtime)
    : failure = null,
      reason = null,
      interrupted = false;
  const _Observed.failed(String this.failure, this.reason)
    : sha256 = null,
      size = null,
      mtime = null,
      interrupted = false;
  const _Observed.interrupted()
    : sha256 = null,
      size = null,
      mtime = null,
      failure = null,
      reason = null,
      interrupted = true;

  final Uint8List? sha256;
  final int? size;
  final int? mtime;
  final String? failure;
  final String? reason;
  final bool interrupted;
}

class _Row {
  _Row(
    this.id,
    this.sourceId,
    this.relPath,
    this.ext,
    this.size,
    this.mtime,
    this.contentId,
    this.sha256,
    this.objectId,
  );
  final int id;
  final String sourceId;
  final String relPath;
  final String ext;
  final int size;
  final int? mtime;
  final int contentId;
  final Uint8List sha256;
  final String? objectId;
}
