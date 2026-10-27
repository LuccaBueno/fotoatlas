import 'dart:async';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../sources/media_types.dart';

/// Situação de backup de um arquivo (`docs/arquitetura.md` §4.6).
enum BackupState {
  /// 🔴 Só 1 cópia conhecida.
  single,

  /// 🟡 Provável cópia (mesmo nome e tamanho em outra fonte), falta conferir.
  probable,

  /// 🟢 2+ cópias com conteúdo idêntico, mas no mesmo disco (ou disco incerto).
  verified,

  /// 🔵 Cópias conferidas em discos físicos diferentes e confiáveis.
  independent,

  /// ⚪ Ainda não dá para saber.
  unknown,
}

/// Contagem por situação.
class CoverageCounts {
  const CoverageCounts(this.files, this.bytes);
  final Map<BackupState, int> files;
  final Map<BackupState, int> bytes;

  int filesIn(BackupState s) => files[s] ?? 0;
  int bytesIn(BackupState s) => bytes[s] ?? 0;
  int get totalFiles => files.values.fold(0, (a, b) => a + b);

  static const empty = CoverageCounts({}, {});
}

/// Cobertura de uma fonte: seus arquivos por situação + espaço em repetidos.
class SourceCoverage {
  const SourceCoverage({
    required this.sourceId,
    required this.counts,
    required this.cloudOnly,
    required this.duplicateFiles,
    required this.duplicateBytes,
  });
  final String sourceId;
  final CoverageCounts counts;

  /// Somente na nuvem (não lidos, não contam como cópia).
  final int cloudOnly;

  /// Arquivos extras com conteúdo idêntico a outro da mesma fonte.
  final int duplicateFiles;
  final int duplicateBytes;
}

/// Visão geral de cobertura (painel do Início e cartões de Dispositivos).
class CoverageReport {
  const CoverageReport({
    required this.overall,
    required this.perSource,
    required this.pendingFiles,
    required this.computedAt,
  });

  /// Por conteúdo distinto (um arquivo não conferido conta como um conteúdo).
  final CoverageCounts overall;
  final Map<String, SourceCoverage> perSource;

  /// Arquivos ainda sem conteúdo conferido (fila de hash).
  final int pendingFiles;
  final DateTime computedAt;
}

/// Um grupo de arquivos com conteúdo idêntico.
class DuplicateGroup {
  const DuplicateGroup(this.contentId, this.sizeBytes, this.instances);
  final int contentId;
  final int sizeBytes;
  final List<({String sourceId, String relPath})> instances;
}

/// Duplicatas exatas e níveis de cobertura (spec §9). Só consulta o catálogo.
///
/// Regras:
/// - cópia = instância `present` de fonte não esquecida; fonte desconectada
///   conta (regra 9); `missing`, `cloud_only` e ilegível não contam;
/// - o mesmo arquivo físico visto por duas fontes sobrepostas conta uma vez;
/// - "disco independente" exige discos de identidade confiável (R1);
/// - sem hash, tamanho único no catálogo já é "só 1 cópia" (L8).
class CoverageService {
  CoverageService(this.db);

  final CatalogDatabase db;

  static String _instancesCte({required bool mediaOnly}) =>
      '''
      inst AS MATERIALIZED (
        SELECT fi.id, fi.source_id, fi.content_id, fi.size_bytes, lower(fi.name) AS lname, fi.hash_status,
          COALESCE(lower(s.volume_guid), s.id) || '|' ||
            lower(CASE WHEN s.root_rel_path = '' THEN fi.rel_path ELSE s.root_rel_path || '/' || fi.rel_path END) AS phys,
          CASE WHEN d.identity_confidence = 'reliable' OR d.user_confirmed THEN d.id END AS rdisk
        FROM file_instances fi
        JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL
        LEFT JOIN physical_disks d ON d.id = s.physical_disk_id
        WHERE fi.availability = 'present' ${mediaOnly ? 'AND fi.ext IN ${MediaTypes.sqlList(MediaTypes.media)}' : ''}
      ),
      per_content AS MATERIALIZED (
        SELECT content_id, COUNT(DISTINCT phys) AS copies, COUNT(DISTINCT rdisk) AS disks
        FROM inst WHERE content_id IS NOT NULL AND hash_status = 'done' GROUP BY content_id
      ),
      by_size AS MATERIALIZED (
        SELECT size_bytes, COUNT(DISTINCT phys) AS phys_n,
          SUM(CASE WHEN content_id IS NULL OR hash_status != 'done' THEN 1 ELSE 0 END) AS unhashed
        FROM inst GROUP BY size_bytes
      ),
      by_name AS MATERIALIZED (
        SELECT size_bytes, lname, COUNT(DISTINCT phys) AS phys_n, COUNT(DISTINCT source_id) AS src_n
        FROM inst GROUP BY size_bytes, lname
      ),
      classified AS (
        SELECT i.*,
          CASE
            WHEN i.content_id IS NOT NULL AND i.hash_status = 'done' THEN
              CASE
                WHEN pc.disks >= 2 THEN 'independent'
                WHEN pc.copies >= 2 THEN 'verified'
                -- Só 1 conferida, mas há arquivo de mesmo tamanho sem hash: ainda não dá para dizer.
                WHEN bs.unhashed > 0 THEN 'unknown'
                ELSE 'single'
              END
            -- Sem hash: tamanho único no catálogo não pode ter cópia idêntica (L8).
            WHEN bs.phys_n = 1 THEN 'single'
            WHEN bn.phys_n >= 2 AND bn.src_n >= 2 THEN 'probable'
            ELSE 'unknown'
          END AS state
        FROM inst i
        LEFT JOIN per_content pc ON pc.content_id = i.content_id
        JOIN by_size bs ON bs.size_bytes = i.size_bytes
        JOIN by_name bn ON bn.size_bytes = i.size_bytes AND bn.lname = i.lname
      )
      ''';

  /// Relatório completo. [mediaOnly]: só fotos, RAW e vídeos (padrão).
  Future<CoverageReport> report({bool mediaOnly = true}) async {
    final cte = _instancesCte(mediaOnly: mediaOnly);
    // Geral: conteúdo conferido conta uma vez; não conferido conta por arquivo físico.
    final overallRows = await db
        .customSelect(
          '''
          WITH $cte,
          units AS (
            SELECT state, size_bytes FROM classified WHERE content_id IS NOT NULL AND hash_status = 'done'
              GROUP BY content_id
            UNION ALL
            SELECT state, size_bytes FROM classified WHERE content_id IS NULL OR hash_status != 'done' GROUP BY phys
          )
          SELECT state, COUNT(*) AS n, COALESCE(SUM(size_bytes), 0) AS b FROM units GROUP BY state
          ''',
          readsFrom: {db.fileInstances, db.sources, db.physicalDisks},
        )
        .get();
    final perRows = await db
        .customSelect(
          'WITH $cte SELECT source_id, state, COUNT(*) AS n, COALESCE(SUM(size_bytes), 0) AS b '
          'FROM classified GROUP BY source_id, state',
          readsFrom: {db.fileInstances, db.sources, db.physicalDisks},
        )
        .get();
    final media = mediaOnly ? 'AND ext IN ${MediaTypes.sqlList(MediaTypes.media)}' : '';
    final extraRows = await db
        .customSelect(
          '''
          SELECT s.id AS source_id,
            (SELECT COUNT(*) FROM file_instances f WHERE f.source_id = s.id AND f.availability = 'cloud_only' $media) AS cloud,
            (SELECT COALESCE(SUM(n - 1), 0) FROM (SELECT COUNT(*) AS n FROM file_instances f
               WHERE f.source_id = s.id AND f.availability = 'present' AND f.hash_status = 'done' $media
               GROUP BY f.content_id HAVING COUNT(*) > 1)) AS dup_files,
            (SELECT COALESCE(SUM((n - 1) * sz), 0) FROM (SELECT COUNT(*) AS n, MAX(f.size_bytes) AS sz FROM file_instances f
               WHERE f.source_id = s.id AND f.availability = 'present' AND f.hash_status = 'done' $media
               GROUP BY f.content_id HAVING COUNT(*) > 1)) AS dup_bytes
          FROM sources s WHERE s.forgotten_at IS NULL
          ''',
          readsFrom: {db.fileInstances, db.sources},
        )
        .get();
    final pending = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM file_instances f JOIN sources s ON s.id = f.source_id AND s.forgotten_at IS NULL "
          "WHERE f.availability = 'present' AND f.hash_status = 'pending' $media",
          readsFrom: {db.fileInstances, db.sources},
        )
        .getSingle();

    CoverageCounts counts(Iterable<QueryRow> rows) {
      final files = <BackupState, int>{};
      final bytes = <BackupState, int>{};
      for (final r in rows) {
        final s = BackupState.values.byName(r.read<String>('state'));
        files[s] = (files[s] ?? 0) + r.read<int>('n');
        bytes[s] = (bytes[s] ?? 0) + r.read<int>('b');
      }
      return CoverageCounts(files, bytes);
    }

    final bySource = <String, List<QueryRow>>{};
    for (final r in perRows) {
      (bySource[r.read<String>('source_id')] ??= []).add(r);
    }
    return CoverageReport(
      overall: counts(overallRows),
      perSource: {
        for (final r in extraRows)
          r.read<String>('source_id'): SourceCoverage(
            sourceId: r.read<String>('source_id'),
            counts: counts(bySource[r.read<String>('source_id')] ?? const []),
            cloudOnly: r.read<int>('cloud'),
            duplicateFiles: r.read<int>('dup_files'),
            duplicateBytes: r.read<int>('dup_bytes'),
          ),
      },
      pendingFiles: pending.read<int>('n'),
      computedAt: DateTime.now(),
    );
  }

  /// Relatório reativo, recalculado no máximo a cada [interval] enquanto o
  /// catálogo muda (a fila de hash grava em lotes).
  Stream<CoverageReport> watch({bool mediaOnly = true, Duration interval = const Duration(seconds: 2)}) {
    late StreamController<CoverageReport> controller;
    StreamSubscription<Object?>? sub;
    Timer? timer;
    var dirty = false;
    var computing = false;

    Future<void> compute() async {
      if (computing) {
        dirty = true;
        return;
      }
      computing = true;
      try {
        do {
          dirty = false;
          final r = await report(mediaOnly: mediaOnly);
          if (!controller.isClosed) controller.add(r);
        } while (dirty && !controller.isClosed);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      } finally {
        computing = false;
      }
    }

    controller = StreamController<CoverageReport>(
      onListen: () {
        compute();
        sub = db.tableUpdates(TableUpdateQuery.onAllTables([db.fileInstances, db.sources, db.physicalDisks])).listen((
          _,
        ) {
          if (timer?.isActive ?? false) {
            dirty = true;
            return;
          }
          compute();
          timer = Timer(interval, () {
            if (dirty) compute();
          });
        });
      },
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Situação de cada arquivo de uma fonte (para listas e testes).
  Future<Map<String, BackupState>> statesForSource(String sourceId, {bool mediaOnly = false}) async {
    final rows = await db
        .customSelect(
          'WITH ${_instancesCte(mediaOnly: mediaOnly)} '
          'SELECT fi.rel_path, c.state FROM classified c JOIN file_instances fi ON fi.id = c.id WHERE c.source_id = ?',
          variables: [Variable.withString(sourceId)],
          readsFrom: {db.fileInstances, db.sources, db.physicalDisks},
        )
        .get();
    return {for (final r in rows) r.read<String>('rel_path'): BackupState.values.byName(r.read<String>('state'))};
  }

  /// Grupos de conteúdo idêntico (2+ arquivos), do maior desperdício ao menor.
  Future<List<DuplicateGroup>> duplicateGroups({int offset = 0, int limit = 100}) async {
    final groups = await db
        .customSelect(
          '''
          SELECT f.content_id, c.size_bytes FROM file_instances f
          JOIN contents c ON c.id = f.content_id
          JOIN sources s ON s.id = f.source_id AND s.forgotten_at IS NULL
          WHERE f.availability = 'present' AND f.hash_status = 'done'
          GROUP BY f.content_id HAVING COUNT(*) > 1
          ORDER BY (COUNT(*) - 1) * c.size_bytes DESC, f.content_id LIMIT ? OFFSET ?
          ''',
          variables: [Variable.withInt(limit), Variable.withInt(offset)],
          readsFrom: {db.fileInstances, db.contents, db.sources},
        )
        .get();
    if (groups.isEmpty) return const [];
    final ids = [for (final g in groups) g.read<int>('content_id')];
    final members = await db
        .customSelect(
          "SELECT f.content_id, f.source_id, f.rel_path FROM file_instances f "
          "JOIN sources s ON s.id = f.source_id AND s.forgotten_at IS NULL "
          "WHERE f.availability = 'present' AND f.hash_status = 'done' "
          "AND f.content_id IN (${List.filled(ids.length, '?').join(',')}) ORDER BY f.source_id, f.rel_path",
          variables: [for (final id in ids) Variable.withInt(id)],
          readsFrom: {db.fileInstances, db.sources},
        )
        .get();
    final byContent = <int, List<({String sourceId, String relPath})>>{};
    for (final m in members) {
      (byContent[m.read<int>('content_id')] ??= []).add((
        sourceId: m.read<String>('source_id'),
        relPath: m.read<String>('rel_path'),
      ));
    }
    return [
      for (final g in groups)
        DuplicateGroup(g.read<int>('content_id'), g.read<int>('size_bytes'), byContent[g.read<int>('content_id')]!),
    ];
  }
}
