import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../util/clock.dart';
import '../util/crashpoint.dart';
import 'entry_classifier.dart';
import 'scan_listers.dart';

/// Progresso de um scan (enviado do worker para a interface).
class ScanProgress {
  const ScanProgress({
    required this.scanId,
    required this.sourceId,
    required this.status,
    required this.dirsDone,
    required this.dirsPending,
    required this.filesSeen,
    required this.bytesSeen,
    required this.errorCount,
    this.currentDir,
    this.message,
  });

  final int scanId;
  final String sourceId;

  /// `running`, `paused`, `interrupted`, `completed`, `cancelled`, `failed`.
  final String status;
  final int dirsDone;
  final int dirsPending;
  final int filesSeen;
  final int bytesSeen;
  final int errorCount;
  final String? currentDir;
  final String? message;

  bool get isFinal => status != 'running';
}

/// Pedido de parada vindo da interface.
enum ScanStop { pause, cancel }

/// Execução de um scan de listagem (sem hash) com checkpoint no banco.
///
/// Cada lote de pastas é aplicado numa transação que grava os arquivos, as
/// subpastas pendentes, o status `done` das pastas e os contadores juntos.
/// Matar o processo a qualquer momento perde no máximo o lote em andamento,
/// e retomar continua exatamente das pastas `pending` (ADR 0007).
class ScanEngine {
  ScanEngine(
    this.db, {
    required this.scanId,
    required this.sourceId,
    required this.lister,
    this.batchFiles = 2000,
    this.batchDirs = 200,
  });

  final CatalogDatabase db;
  final int scanId;
  final String sourceId;

  /// Como as pastas são lidas (Windows ou celular).
  final ScanLister lister;
  final int batchFiles;
  final int batchDirs;

  /// Roda até terminar, pausar, cancelar ou a fonte desconectar.
  Future<ScanProgress> run({
    required ScanStop? Function() stopRequested,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    await db.customUpdate(
      "UPDATE scans SET status = 'running' WHERE id = ?",
      variables: [Variable.withInt(scanId)],
      updates: {db.scans},
    );
    final inaccessible = await lister.checkAccessible();
    if (inaccessible != null) return _stop('interrupted', message: inaccessible);
    while (true) {
      final stop = stopRequested();
      if (stop != null) return _stop(stop == ScanStop.pause ? 'paused' : 'cancelled');

      final pending = await db
          .customSelect(
            "SELECT rel_path FROM scan_dirs WHERE scan_id = ? AND status = 'pending' ORDER BY rel_path LIMIT ?",
            variables: [Variable.withInt(scanId), Variable.withInt(batchDirs)],
            readsFrom: {db.scanDirs},
          )
          .get();
      if (pending.isEmpty) break;

      final results = <ListedDir>[];
      var files = 0;
      String? gone;
      for (final row in pending) {
        final ListedDir result;
        try {
          result = await lister.list(row.read<String>('rel_path'));
        } on SourceGone catch (e) {
          gone = e.message;
          break;
        }
        results.add(result);
        files += result.files.length;
        if (files >= batchFiles) break;
      }
      if (results.isNotEmpty) await _apply(results);
      crashpoint('scan.after_batch_commit');
      if (gone != null) return _stop('interrupted', message: gone);
      onProgress?.call(await _progress('running', currentDir: results.isEmpty ? null : results.last.relDir));
      // Cede ao event loop para receber pedidos de pausa/cancelamento.
      await Future<void>.delayed(Duration.zero);
    }
    return _finish();
  }

  static const _upsertSql = '''
    INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, mtime, ctime,
      attributes, hash_status, availability, first_seen_scan_id, last_seen_scan_id, device_object_id)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, CASE WHEN ?10 THEN 'not_applicable' ELSE 'pending' END,
      CASE WHEN ?10 THEN 'cloud_only' ELSE 'present' END, ?11, ?11, ?12)
    ON CONFLICT (source_id, rel_path) DO UPDATE SET
      hash_status = CASE
        WHEN file_instances.size_bytes IS NOT excluded.size_bytes OR file_instances.mtime IS NOT excluded.mtime
          THEN excluded.hash_status
        WHEN file_instances.hash_status = 'not_applicable' AND excluded.availability = 'present' THEN 'pending'
        ELSE file_instances.hash_status END,
      content_id = CASE
        WHEN file_instances.size_bytes IS NOT excluded.size_bytes OR file_instances.mtime IS NOT excluded.mtime
          THEN NULL ELSE file_instances.content_id END,
      dir_rel_path = excluded.dir_rel_path,
      name = excluded.name,
      ext = excluded.ext,
      size_bytes = excluded.size_bytes,
      mtime = excluded.mtime,
      ctime = excluded.ctime,
      attributes = excluded.attributes,
      availability = excluded.availability,
      last_seen_scan_id = excluded.last_seen_scan_id,
      missing_confirmed_at = NULL,
      device_object_id = excluded.device_object_id
  ''';

  Future<void> _apply(List<ListedDir> results) async {
    var dirsDone = 0, filesSeen = 0, bytesSeen = 0, errors = 0;
    final now = nowMs();
    await db.transaction(() async {
      await db.batch((b) {
        for (final r in results) {
          if (r.isError) {
            errors++;
            b.customStatement("UPDATE scan_dirs SET status = 'error' WHERE scan_id = ? AND rel_path = ?", [
              scanId,
              r.relDir,
            ]);
            b.customStatement(
              'INSERT INTO scan_errors (scan_id, rel_path, kind, win32_code, message, at) VALUES (?, ?, ?, ?, ?, ?)',
              [scanId, r.relDir, r.errorKind, r.errorCode, r.errorMessage, now],
            );
            continue;
          }
          for (final f in r.files) {
            b.customStatement(_upsertSql, [
              sourceId,
              f.relPath,
              f.dirRelPath,
              f.name,
              extensionOf(f.name),
              f.size,
              f.mtime,
              f.ctime,
              f.attributes,
              f.cloudOnly ? 1 : 0,
              scanId,
              f.objectId,
            ]);
            filesSeen++;
            bytesSeen += f.size;
          }
          for (final d in r.childDirs) {
            b.customStatement("INSERT OR IGNORE INTO scan_dirs (scan_id, rel_path, status) VALUES (?, ?, 'pending')", [
              scanId,
              d,
            ]);
          }
          for (final d in r.excludedDirs) {
            b.customStatement("INSERT OR IGNORE INTO scan_dirs (scan_id, rel_path, status) VALUES (?, ?, 'excluded')", [
              scanId,
              d,
            ]);
          }
          for (final l in r.skippedLinks) {
            b.customStatement(
              "INSERT INTO scan_errors (scan_id, rel_path, kind, message, at) VALUES (?, ?, 'reparse_point_skipped', ?, ?)",
              [scanId, l, 'Atalho de pasta/arquivo (junction ou link) não seguido.', now],
            );
          }
          b.customStatement("UPDATE scan_dirs SET status = 'done' WHERE scan_id = ? AND rel_path = ?", [
            scanId,
            r.relDir,
          ]);
          dirsDone++;
        }
        b.customStatement(
          'UPDATE scans SET dirs_done = dirs_done + ?, files_seen = files_seen + ?, '
          'bytes_seen = bytes_seen + ?, error_count = error_count + ? WHERE id = ?',
          [dirsDone, filesSeen, bytesSeen, errors, scanId],
        );
      });
    });
  }

  /// Fim normal: define a cobertura e confirma ausências só onde é seguro
  /// (spec §7; regras 9 e 10).
  Future<ScanProgress> _finish() async {
    final errorDirs = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM scan_dirs WHERE scan_id = ? AND status = 'error'",
          variables: [Variable.withInt(scanId)],
        )
        .getSingle();
    // Scan de algumas pastas: é parcial e só confirma ausências nas pastas lidas.
    final complete = errorDirs.read<int>('n') == 0 && (await scanRoots(db, scanId)).first.isEmpty;
    final now = nowMs();
    await db.transaction(() async {
      await db.customUpdate(
        '''
        UPDATE file_instances SET availability = 'missing', missing_confirmed_at = ?1
        WHERE source_id = ?2
          AND availability != 'missing'
          AND (last_seen_scan_id IS NULL OR last_seen_scan_id != ?3)
          AND NOT EXISTS (
            SELECT 1 FROM scan_dirs d
            WHERE d.scan_id = ?3 AND d.status = 'excluded'
              AND (file_instances.dir_rel_path = d.rel_path
                   OR substr(file_instances.dir_rel_path, 1, length(d.rel_path) + 1) = d.rel_path || '/'))
          ${complete ? '' : "AND dir_rel_path IN (SELECT rel_path FROM scan_dirs WHERE scan_id = ?3 AND status = 'done')"}
        ''',
        variables: [Variable.withInt(now), Variable.withString(sourceId), Variable.withInt(scanId)],
        updates: {db.fileInstances},
      );
      await db.customUpdate(
        "UPDATE scans SET status = 'completed', coverage = ?, finished_at = ? WHERE id = ?",
        variables: [
          Variable.withString(complete ? 'complete' : 'partial'),
          Variable.withInt(now),
          Variable.withInt(scanId),
        ],
        updates: {db.scans},
      );
    });
    return _progress('completed');
  }

  Future<ScanProgress> _stop(String status, {String? message}) async {
    await db.customUpdate(
      'UPDATE scans SET status = ?, finished_at = CASE WHEN ? THEN ? ELSE finished_at END WHERE id = ?',
      variables: [
        Variable.withString(status),
        Variable.withBool(status == 'cancelled'),
        Variable.withInt(nowMs()),
        Variable.withInt(scanId),
      ],
      updates: {db.scans},
    );
    return _progress(status, message: message);
  }

  Future<ScanProgress> _progress(String status, {String? currentDir, String? message}) =>
      readScanProgress(db, scanId, status: status, currentDir: currentDir, message: message);
}

/// Pastas onde o scan começou (`['']` = a fonte inteira). Uma pasta do scan é
/// ponto de partida quando a mãe dela não faz parte do scan (toda subpasta
/// encontrada entra junto com a mãe).
Future<List<String>> scanRoots(CatalogDatabase db, int scanId) async {
  final whole = await db
      .customSelect(
        "SELECT 1 FROM scan_dirs WHERE scan_id = ? AND rel_path = ''",
        variables: [Variable.withInt(scanId)],
      )
      .getSingleOrNull();
  if (whole != null) return const [''];
  final rows = await db
      .customSelect('SELECT rel_path FROM scan_dirs WHERE scan_id = ?', variables: [Variable.withInt(scanId)])
      .get();
  final all = {for (final r in rows) r.read<String>('rel_path')};
  if (all.isEmpty) return const [''];
  return [
    for (final path in all)
      if (!all.contains(parentRelPath(path))) path,
  ]..sort();
}

/// `a/b/c` → `a/b`; `a` → `''`.
String parentRelPath(String relPath) {
  final slash = relPath.lastIndexOf('/');
  return slash < 0 ? '' : relPath.substring(0, slash);
}

/// Normaliza as pastas pedidas para um scan: separador `/`, sem repetidas e
/// sem as que ficam dentro de outra da lista. Vazia (ou com `''`) = a fonte
/// inteira.
List<String> normalizeScanRoots(Iterable<String>? folders) {
  final cleaned = <String>{
    for (final f in folders ?? const <String>[])
      f.replaceAll(r'\', '/').split('/').where((p) => p.isNotEmpty).join('/'),
  };
  if (cleaned.isEmpty || cleaned.contains('')) return const [''];
  final byLength = cleaned.toList()..sort((a, b) => a.length.compareTo(b.length));
  final roots = <String>[];
  for (final f in byLength) {
    if (!isUnderScanRoots(f, roots, ignoreCase: true)) roots.add(f);
  }
  return roots..sort();
}

/// [relPath] fica dentro de alguma das [roots] (ou é uma delas).
bool isUnderScanRoots(String relPath, List<String> roots, {bool ignoreCase = false}) {
  final path = ignoreCase ? relPath.toLowerCase() : relPath;
  for (final root in roots) {
    final r = ignoreCase ? root.toLowerCase() : root;
    if (r.isEmpty || path == r || path.startsWith('$r/')) return true;
  }
  return false;
}

/// Lê o progresso atual de um scan a partir do banco.
Future<ScanProgress> readScanProgress(
  CatalogDatabase db,
  int scanId, {
  String? status,
  String? currentDir,
  String? message,
}) async {
  final row = await db
      .customSelect(
        '''
        SELECT s.source_id, s.status, s.dirs_done, s.files_seen, s.bytes_seen, s.error_count,
          (SELECT COUNT(*) FROM scan_dirs d WHERE d.scan_id = s.id AND d.status = 'pending') AS pending
        FROM scans s WHERE s.id = ?
        ''',
        variables: [Variable.withInt(scanId)],
      )
      .getSingle();
  return ScanProgress(
    scanId: scanId,
    sourceId: row.read<String>('source_id'),
    status: status ?? row.read<String>('status'),
    dirsDone: row.read<int>('dirs_done'),
    dirsPending: row.read<int>('pending'),
    filesSeen: row.read<int>('files_seen'),
    bytesSeen: row.read<int>('bytes_seen'),
    errorCount: row.read<int>('error_count'),
    currentDir: currentDir,
    message: message,
  );
}
