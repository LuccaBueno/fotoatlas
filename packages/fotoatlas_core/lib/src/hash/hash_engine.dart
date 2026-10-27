import 'dart:async';
import 'dart:ffi';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:ffi/ffi.dart';

import '../catalog/catalog_database.dart';
import '../devices/devices.dart';
import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import '../safe_io/source_reader.dart';
import '../sources/media_types.dart';
import '../util/clock.dart';
import '../util/crashpoint.dart';

/// Resultado do hash de um arquivo.
sealed class HashOutcome {
  const HashOutcome();
}

class HashDone extends HashOutcome {
  const HashDone(this.sha256, this.size, this.mtime);
  final Uint8List sha256;
  final int size;
  final int? mtime;
}

/// O arquivo mudou desde o escaneamento ou durante a leitura (spec §7).
class HashChanged extends HashOutcome {
  const HashChanged(this.reason);
  final String reason;
}

/// Placeholder de nuvem: não foi lido (não dispara download).
class HashCloudOnly extends HashOutcome {
  const HashCloudOnly();
}

/// Não deu para ler. Nunca vira "ausente" (regra 10).
class HashFailed extends HashOutcome {
  const HashFailed(this.reason);
  final String reason;
}

/// Parada pedida no meio do arquivo: ele continua pendente.
class HashInterrupted extends HashOutcome {
  const HashInterrupted();
}

/// Gancho de teste: chamado depois do primeiro bloco lido de cada arquivo
/// (só funciona no mesmo isolate; usado para simular mudança durante a leitura).
typedef AfterFirstChunk = void Function(String path);

/// Calcula o SHA-256 de um arquivo de origem em streaming, só leitura, e
/// detecta mudanças comparando tamanho e data antes e depois (spec §7).
Future<HashOutcome> hashSourceFile(
  String path, {
  required int expectedSize,
  required int? expectedMtime,
  int chunkSize = 1 << 20,
  bool Function()? shouldStop,
  AfterFirstChunk? afterFirstChunk,
}) async {
  final SourceFileInfo pre;
  try {
    pre = attributesOf(path);
  } on Win32Exception catch (e) {
    return HashFailed(_readError(e));
  }
  if (pre.isCloudPlaceholder) return const HashCloudOnly();

  final SourceFile file;
  try {
    file = SourceFile.open(path);
  } on Win32Exception catch (e) {
    return HashFailed(_readError(e));
  }
  final buffer = calloc<Uint8>(chunkSize);
  try {
    final before = file.info();
    if (before.isCloudPlaceholder) return const HashCloudOnly();
    if (before.size != expectedSize || before.mtime != expectedMtime) {
      return const HashChanged('O arquivo mudou depois do escaneamento. Escaneie de novo.');
    }
    final digest = _DigestSink();
    final input = sha256.startChunkedConversion(digest);
    var total = 0;
    var chunks = 0;
    while (true) {
      final n = file.read(buffer, chunkSize);
      if (n == 0) break;
      input.add(buffer.asTypedList(n));
      total += n;
      chunks++;
      if (chunks == 1) afterFirstChunk?.call(path);
      // Cede ao event loop de vez em quando (pausa no meio de vídeos grandes).
      if (chunks % 16 == 0) {
        await Future<void>.delayed(Duration.zero);
        if (shouldStop?.call() ?? false) return const HashInterrupted();
      }
    }
    input.close();
    final after = file.info();
    if (total != before.size || after.size != before.size || after.mtime != before.mtime) {
      return const HashChanged('O arquivo mudou enquanto era lido. Escaneie de novo.');
    }
    return HashDone(Uint8List.fromList(digest.value!.bytes), before.size, before.mtime);
  } on Win32Exception catch (e) {
    return HashFailed(_readError(e));
  } finally {
    calloc.free(buffer);
    file.close();
  }
}

String _readError(Win32Exception e) => switch (e.code) {
  errorFileNotFound || errorPathNotFound => 'Arquivo não encontrado (pode ter sido movido). Escaneie de novo.',
  errorAccessDenied => 'Sem permissão para ler o arquivo.',
  errorSharingViolation || errorLockViolation => 'O arquivo está bloqueado por outro programa.',
  errorFilenameExcedRange => 'Caminho longo demais.',
  _ => 'Erro de leitura (Win32 ${e.code}).',
};

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Uma fonte que o worker deve conferir.
class HashTarget {
  const HashTarget(this.sourceId, this.accessRoot, {this.deviceId});
  final String sourceId;

  /// Raiz Win32 de acesso (ex.: `\\?\Volume{…}\Fotos`); vazia no celular.
  final String accessRoot;

  /// Celular: ID WPD do aparelho (o helper lê e calcula o hash).
  final String? deviceId;
}

/// Trecho priorizado (ex.: escopos da comparação em andamento).
class HashPriority {
  const HashPriority(this.sourceId, this.relPath);
  final String sourceId;

  /// '' = a fonte inteira.
  final String relPath;
}

/// Evento de progresso de um worker de hash (por arquivo).
class HashFileEvent {
  const HashFileEvent(this.sourceId, this.bytes, this.kind);
  final String sourceId;
  final int bytes;

  /// `done`, `changed`, `error`, `cloud`.
  final String kind;
}

/// Fim de um worker.
class HashWorkerDone {
  const HashWorkerDone({this.message, this.goneSources = const []});
  final String? message;

  /// Fontes que ficaram inacessíveis durante a conferência.
  final List<String> goneSources;
}

/// Conferência (hash) dos arquivos pendentes de algumas fontes do mesmo disco
/// físico (no máximo um leitor por disco, L9).
///
/// Os resultados são gravados em lotes transacionais. Cada atualização só vale
/// se a linha ainda estiver `pending` com o mesmo tamanho e data: um scan que
/// rodou no meio vence. Matar o processo perde no máximo o lote em andamento,
/// que continua `pending`.
class HashEngine {
  HashEngine(
    this.db, {
    required this.targets,
    this.priority = const [],
    this.batchSize = 32,
    this.chunkSize = 1 << 20,
    this.afterFirstChunk,
    this.devices,
  });

  final CatalogDatabase db;
  final List<HashTarget> targets;

  /// Celulares (só no isolate que tem o helper).
  final DeviceBackend? devices;
  final Map<String, PhonePathResolver> _resolvers = {};
  final List<HashPriority> priority;
  final int batchSize;
  final int chunkSize;
  final AfterFirstChunk? afterFirstChunk;

  Future<HashWorkerDone> run({required bool Function() stopRequested, void Function(HashFileEvent)? onFile}) async {
    final roots = {for (final t in targets) t.sourceId: t.accessRoot};
    final phones = {
      for (final t in targets)
        if (t.deviceId != null) t.sourceId: t.deviceId!,
    };
    final gone = <String>{};
    while (true) {
      final ids = await _orderedPending(roots.keys.where((s) => !gone.contains(s)).toList());
      if (ids.isEmpty) break;
      for (var i = 0; i < ids.length; i += batchSize) {
        if (stopRequested()) return HashWorkerDone(goneSources: gone.toList());
        final rows = await _rows(ids.sublist(i, i + batchSize > ids.length ? ids.length : i + batchSize));
        final results = <(_PendingRow, HashOutcome)>[];
        for (final row in rows) {
          if (gone.contains(row.sourceId)) continue;
          if (stopRequested()) break;
          final root = roots[row.sourceId]!;
          final deviceId = phones[row.sourceId];
          if (deviceId != null) {
            final outcome = await _hashPhone(deviceId, row, stopRequested);
            if (outcome == null) {
              gone.add(row.sourceId);
              continue;
            }
            if (outcome is HashInterrupted) break;
            results.add((row, outcome));
            onFile?.call(HashFileEvent(row.sourceId, row.size, _kind(outcome)));
            continue;
          }
          final outcome = await hashSourceFile(
            joinNative(root, row.relPath),
            expectedSize: row.size,
            expectedMtime: row.mtime,
            chunkSize: chunkSize,
            shouldStop: stopRequested,
            afterFirstChunk: afterFirstChunk,
          );
          if (outcome is HashInterrupted) break;
          if (outcome is HashFailed && !directoryAccessible(root)) {
            // A fonte saiu: o arquivo não "falhou", só ficou para depois.
            gone.add(row.sourceId);
            continue;
          }
          results.add((row, outcome));
          onFile?.call(HashFileEvent(row.sourceId, row.size, _kind(outcome)));
        }
        if (results.isNotEmpty) await _apply(results);
        crashpoint('hash.after_batch_commit');
      }
    }
    return HashWorkerDone(goneSources: gone.toList(), message: gone.isEmpty ? null : 'Fonte desconectada.');
  }

  static String _kind(HashOutcome outcome) => switch (outcome) {
    HashDone() => 'done',
    HashChanged() => 'changed',
    HashCloudOnly() => 'cloud',
    HashFailed() => 'error',
    HashInterrupted() => throw StateError('inalcançável'),
  };

  /// Hash de um arquivo do celular pelo helper. `null` = o aparelho saiu
  /// (o arquivo continua pendente, nunca vira ausente).
  Future<HashOutcome?> _hashPhone(String deviceId, _PendingRow row, bool Function() stopRequested) async {
    final backend = devices!;
    final resolver = _resolvers[deviceId] ??= PhonePathResolver(backend, deviceId);
    final stop = Completer<void>();
    final watch = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (stopRequested() && !stop.isCompleted) stop.complete();
    });
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        // 1ª tentativa com o ID do scan; se ele ficou velho, procura pelo caminho.
        final objectId = attempt == 0 ? row.objectId : await resolver.file(row.relPath);
        if (objectId == null) continue;
        try {
          final h = await backend.hash(deviceId, objectId, expectedSize: row.size, cancel: stop.future);
          if (h.size != row.size || h.modified != row.mtime) {
            return const HashChanged('O arquivo mudou depois do escaneamento. Escaneie de novo.');
          }
          return HashDone(h.sha256, h.size, row.mtime);
        } on DeviceException catch (e) {
          if (e.code == 'not_found') continue;
          if (e.code == 'cancelled') return const HashInterrupted();
          if (e.code == 'changed_during_read') return HashChanged(e.message);
          if (e.isDeviceGone) return null;
          return HashFailed('Erro de leitura no celular: ${e.message}');
        }
      }
      return const HashFailed('Arquivo não encontrado no celular (pode ter sido apagado ou movido). Escaneie de novo.');
    } on DeviceException catch (e) {
      // Falha ao procurar pelo caminho.
      if (e.isDeviceGone) return null;
      return HashFailed('Erro de leitura no celular: ${e.message}');
    } finally {
      watch.cancel();
    }
  }

  /// Ids pendentes na ordem de prioridade: trechos priorizados, depois
  /// tamanhos que colidem com outro arquivo (L8), depois por pasta (leitura
  /// mais sequencial no disco).
  Future<List<int>> _orderedPending(List<String> sources) async {
    if (sources.isEmpty) return const [];
    final vars = <Variable<Object>>[for (final s in sources) Variable.withString(s)];
    // Termo de prioridade só quando há trechos (um "ORDER BY 0" seria lido
    // pelo SQLite como índice de coluna).
    final prio = StringBuffer();
    if (priority.isNotEmpty) {
      prio.write('CASE WHEN ');
      final parts = <String>[];
      for (final p in priority) {
        if (p.relPath.isEmpty) {
          parts.add('fi.source_id = ?');
          vars.add(Variable.withString(p.sourceId));
        } else {
          parts.add('(fi.source_id = ? AND (fi.rel_path = ? OR substr(fi.rel_path, 1, ?) = ?))');
          vars
            ..add(Variable.withString(p.sourceId))
            ..add(Variable.withString(p.relPath))
            ..add(Variable.withInt(p.relPath.length + 1))
            ..add(Variable.withString('${p.relPath}/'));
        }
      }
      prio.write('${parts.join(' OR ')} THEN 1 ELSE 0 END DESC,');
    }
    final rows = await db
        .customSelect(
          '''
          SELECT fi.id FROM file_instances fi
          WHERE fi.source_id IN (${List.filled(sources.length, '?').join(',')})
            AND fi.hash_status = 'pending' AND fi.availability = 'present'
          ORDER BY $prio
            EXISTS (SELECT 1 FROM file_instances o
                    WHERE o.size_bytes = fi.size_bytes AND o.id != fi.id AND o.availability != 'missing') DESC,
            fi.source_id, fi.dir_rel_path, fi.name
          ''',
          variables: vars,
          readsFrom: {db.fileInstances},
        )
        .get();
    return [for (final r in rows) r.read<int>('id')];
  }

  Future<List<_PendingRow>> _rows(List<int> ids) async {
    final rows = await db
        .customSelect(
          "SELECT id, source_id, rel_path, size_bytes, mtime, ext, device_object_id FROM file_instances "
          "WHERE id IN (${List.filled(ids.length, '?').join(',')}) "
          "AND hash_status = 'pending' AND availability = 'present'",
          variables: [for (final id in ids) Variable.withInt(id)],
          readsFrom: {db.fileInstances},
        )
        .get();
    final byId = {
      for (final r in rows)
        r.read<int>('id'): _PendingRow(
          r.read<int>('id'),
          r.read<String>('source_id'),
          r.read<String>('rel_path'),
          r.read<int>('size_bytes'),
          r.readNullable<int>('mtime'),
          r.read<String>('ext'),
          r.readNullable<String>('device_object_id'),
        ),
    };
    return [for (final id in ids) ?byId[id]];
  }

  Future<void> _apply(List<(_PendingRow, HashOutcome)> results) async {
    final now = nowMs();
    // Só atualiza se a linha ainda é a mesma que foi lida (scan concorrente vence).
    const guard = "WHERE id = ? AND hash_status = 'pending' AND size_bytes = ? AND mtime IS ?";
    await db.transaction(() async {
      await db.batch((b) {
        for (final (row, outcome) in results) {
          switch (outcome) {
            case HashDone(:final sha256, :final size, :final mtime):
              b.customStatement(
                'INSERT INTO contents (sha256, size_bytes, media_type, created_at) VALUES (?, ?, ?, ?) '
                'ON CONFLICT (sha256, size_bytes) DO NOTHING',
                [sha256, size, MediaTypes.mediaTypeOf(row.ext), now],
              );
              b.customStatement(
                'UPDATE file_instances SET content_id = (SELECT id FROM contents WHERE sha256 = ? AND size_bytes = ?), '
                "hash_status = 'done', hashed_size = ?, hashed_mtime = ?, hashed_at = ?, hash_error = NULL $guard",
                [sha256, size, size, mtime, now, row.id, row.size, row.mtime],
              );
            case HashChanged(:final reason):
              b.customStatement(
                "UPDATE file_instances SET hash_status = 'changed_during_read', hash_error = ? $guard",
                [reason, row.id, row.size, row.mtime],
              );
            case HashCloudOnly():
              b.customStatement(
                "UPDATE file_instances SET hash_status = 'not_applicable', availability = 'cloud_only', "
                'hash_error = NULL $guard',
                [row.id, row.size, row.mtime],
              );
            case HashInterrupted():
              break;
            case HashFailed(:final reason):
              b.customStatement("UPDATE file_instances SET hash_status = 'error', hash_error = ? $guard", [
                reason,
                row.id,
                row.size,
                row.mtime,
              ]);
          }
        }
      });
    });
    // `customStatement` em lote não avisa o drift: notifica quem observa
    // (painel de cobertura, comparação) — também nos outros isolates.
    db.notifyUpdates({
      TableUpdate.onTable(db.fileInstances, kind: UpdateKind.update),
      TableUpdate.onTable(db.contents, kind: UpdateKind.insert),
    });
  }
}

class _PendingRow {
  _PendingRow(this.id, this.sourceId, this.relPath, this.size, this.mtime, this.ext, this.objectId);
  final String? objectId;
  final int id;
  final String sourceId;
  final String relPath;
  final int size;
  final int? mtime;
  final String ext;
}
