import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../hash/hash_engine.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import 'scope.dart';

/// Resposta à pergunta "B contém todo o conteúdo de A?".
enum CompareVerdict {
  /// "Sim, 100%": tudo de A está em B e não há pendências.
  complete,

  /// "Faltam N arquivos (X GB)".
  missing,

  /// Há arquivos sem conteúdo conferido ou pastas não lidas: nunca "100%".
  incomplete,

  /// A não tem nenhum arquivo (nada a comparar).
  emptyA,
}

/// Por que o resultado está incompleto.
sealed class CompareIssue {
  const CompareIssue();
}

/// Arquivos de um lado cujo conteúdo ainda não foi conferido.
class UnverifiedFiles extends CompareIssue {
  const UnverifiedFiles({
    required this.side,
    required this.pending,
    required this.errors,
    required this.changed,
    required this.cloudOnly,
  });

  /// 'A' ou 'B'.
  final String side;
  final int pending;
  final int errors;
  final int changed;
  final int cloudOnly;
  int get total => pending + errors + changed + cloudOnly;
}

/// Fonte do escopo que nunca terminou um escaneamento.
class NeverScanned extends CompareIssue {
  const NeverScanned(this.side, this.sourceId, this.sourceName);
  final String side;
  final String sourceId;
  final String sourceName;
}

/// Pastas do escopo que não puderam ser lidas no último escaneamento.
class UnreadFolders extends CompareIssue {
  const UnreadFolders(this.side, this.sourceId, this.sourceName, this.folders);
  final String side;
  final String sourceId;
  final String sourceName;
  final List<String> folders;
}

/// O escopo cita uma fonte que não existe mais (esquecida).
class UnknownSource extends CompareIssue {
  const UnknownSource(this.side, this.sourceId);
  final String side;
  final String sourceId;
}

/// Avisos que não tornam o resultado incompleto.
sealed class CompareWarning {
  const CompareWarning();
}

/// Fonte desconectada: vale o último escaneamento (regra 9).
class DisconnectedSource extends CompareWarning {
  const DisconnectedSource(this.side, this.sourceName, this.lastScanAt);
  final String side;
  final String sourceName;
  final DateTime? lastScanAt;
}

/// A e B se sobrepõem fisicamente: estar "nos dois" ali não é backup.
class ScopesOverlap extends CompareWarning {
  const ScopesOverlap(this.aName, this.bName);
  final String aName;
  final String bName;
}

/// Contagem e tamanho de um grupo de conteúdos.
class ContentTotals {
  const ContentTotals(this.contents, this.bytes, this.files);
  final int contents;
  final int bytes;

  /// Arquivos (instâncias) do lado de referência.
  final int files;
  static const zero = ContentTotals(0, 0, 0);
}

/// Resultado resumido de uma comparação.
class CompareSummary {
  const CompareSummary({
    required this.verdict,
    required this.aFiles,
    required this.aBytes,
    required this.bFiles,
    required this.bBytes,
    required this.missing,
    required this.onlyInB,
    required this.inBoth,
    required this.issues,
    required this.warnings,
    required this.computedAt,
  });

  final CompareVerdict verdict;
  final int aFiles;
  final int aBytes;
  final int bFiles;
  final int bBytes;

  /// Conteúdos de A que não estão em B (cópias repetidas em A contam uma vez).
  final ContentTotals missing;

  /// Conteúdos de B que não estão em A.
  final ContentTotals onlyInB;

  /// Conteúdos presentes nos dois.
  final ContentTotals inBoth;
  final List<CompareIssue> issues;
  final List<CompareWarning> warnings;
  final DateTime computedAt;

  int get unverifiedTotal => issues.whereType<UnverifiedFiles>().fold(0, (s, u) => s + u.total);
}

/// Listas detalhadas do resultado.
enum CompareList { missing, onlyInB, inBoth, unverifiedA, unverifiedB }

/// Um conteúdo (ou, nas listas de não conferidos, um arquivo) do resultado.
class CompareItem {
  const CompareItem({
    required this.sizeBytes,
    required this.sourceId,
    required this.relPath,
    this.contentId,
    this.instanceId,
    this.copies = 1,
    this.otherSourceId,
    this.otherRelPath,
    this.hashStatus,
    this.hashError,
    this.availability,
  });

  final int? contentId;

  /// Arquivo representante (o primeiro, na ordem do catálogo).
  final int? instanceId;
  final int sizeBytes;
  final String sourceId;
  final String relPath;

  /// Quantos arquivos com este conteúdo há no lado de referência.
  final int copies;

  /// Em "nos dois": onde está em B.
  final String? otherSourceId;
  final String? otherRelPath;

  /// Nas listas de não conferidos.
  final String? hashStatus;
  final String? hashError;
  final String? availability;
}

/// Comparação A × B por conteúdo (spec §9) e escopos salvos. Somente leitura
/// sobre os arquivos; só o catálogo é consultado.
class CompareService {
  CompareService(this.db, this.sources);

  final CatalogDatabase db;
  final SourcesService sources;

  /// Instâncias consideradas de um escopo (CTE).
  (String, List<Variable<Object>>) _side(String name, Scope scope) {
    final (pred, vars) = scope.sqlPredicate('fi');
    return (
      '$name AS MATERIALIZED (SELECT fi.id, fi.content_id, fi.size_bytes, fi.hash_status, fi.availability, '
          'fi.source_id, fi.rel_path FROM file_instances fi JOIN sources s ON s.id = fi.source_id '
          "WHERE s.forgotten_at IS NULL AND fi.availability != 'missing' AND $pred)",
      vars,
    );
  }

  (String, List<Variable<Object>>) _with(Scope a, Scope b) {
    final (sa, va) = _side('a', a);
    final (sb, vb) = _side('b', b);
    return (
      'WITH $sa, $sb, '
          "ac AS MATERIALIZED (SELECT DISTINCT content_id FROM a WHERE hash_status = 'done' AND content_id IS NOT NULL), "
          "bc AS MATERIALIZED (SELECT DISTINCT content_id FROM b WHERE hash_status = 'done' AND content_id IS NOT NULL) ",
      [...va, ...vb],
    );
  }

  Future<CompareSummary> compare(Scope a, Scope b) async {
    final (withSql, vars) = _with(a, b);
    String totals(String set, String side) =>
        '(SELECT COUNT(*) FROM $set) AS ${set}_n, '
        '(SELECT COALESCE(SUM(c.size_bytes), 0) FROM $set JOIN contents c ON c.id = $set.content_id) AS ${set}_bytes, '
        '(SELECT COUNT(*) FROM $side WHERE content_id IN (SELECT content_id FROM $set)) AS ${set}_files';
    String unverified(String side) =>
        "(SELECT COUNT(*) FROM $side WHERE availability = 'present' AND hash_status = 'pending') AS ${side}_pending, "
        "(SELECT COUNT(*) FROM $side WHERE availability IN ('present','unreadable') AND hash_status = 'error') "
        'AS ${side}_errors, '
        "(SELECT COUNT(*) FROM $side WHERE hash_status = 'changed_during_read') AS ${side}_changed, "
        "(SELECT COUNT(*) FROM $side WHERE availability = 'cloud_only') AS ${side}_cloud";
    final row = await db
        .customSelect(
          '$withSql, '
          'missing AS MATERIALIZED (SELECT content_id FROM ac WHERE content_id NOT IN (SELECT content_id FROM bc)), '
          'onlyb AS MATERIALIZED (SELECT content_id FROM bc WHERE content_id NOT IN (SELECT content_id FROM ac)), '
          'both AS MATERIALIZED (SELECT content_id FROM ac WHERE content_id IN (SELECT content_id FROM bc)) '
          'SELECT (SELECT COUNT(*) FROM a) AS a_files, (SELECT COALESCE(SUM(size_bytes), 0) FROM a) AS a_bytes, '
          '(SELECT COUNT(*) FROM b) AS b_files, (SELECT COALESCE(SUM(size_bytes), 0) FROM b) AS b_bytes, '
          '${totals('missing', 'a')}, ${totals('onlyb', 'b')}, ${totals('both', 'a')}, '
          '${unverified('a')}, ${unverified('b')}',
          variables: vars,
          readsFrom: {db.fileInstances, db.contents, db.sources},
        )
        .getSingle();

    ContentTotals t(String set) =>
        ContentTotals(row.read<int>('${set}_n'), row.read<int>('${set}_bytes'), row.read<int>('${set}_files'));

    final issues = <CompareIssue>[];
    final warnings = <CompareWarning>[];
    for (final side in ['a', 'b']) {
      final u = UnverifiedFiles(
        side: side.toUpperCase(),
        pending: row.read<int>('${side}_pending'),
        errors: row.read<int>('${side}_errors'),
        changed: row.read<int>('${side}_changed'),
        cloudOnly: row.read<int>('${side}_cloud'),
      );
      if (u.total > 0) issues.add(u);
    }
    await _scanIssues('A', a, issues, warnings);
    await _scanIssues('B', b, issues, warnings);
    await _overlap(a, b, warnings);

    final aFiles = row.read<int>('a_files');
    final missing = t('missing');
    final verdict = issues.isNotEmpty
        ? CompareVerdict.incomplete
        : aFiles == 0
        ? CompareVerdict.emptyA
        : missing.contents == 0
        ? CompareVerdict.complete
        : CompareVerdict.missing;
    return CompareSummary(
      verdict: verdict,
      aFiles: aFiles,
      aBytes: row.read<int>('a_bytes'),
      bFiles: row.read<int>('b_files'),
      bBytes: row.read<int>('b_bytes'),
      missing: missing,
      onlyInB: t('onlyb'),
      inBoth: t('both'),
      issues: issues,
      warnings: warnings,
      computedAt: DateTime.now(),
    );
  }

  /// Uma página de uma das listas do resultado.
  Future<List<CompareItem>> items(Scope a, Scope b, CompareList list, {int offset = 0, int limit = 200}) async {
    final (withSql, vars) = _with(a, b);
    final page = [Variable.withInt(limit), Variable.withInt(offset)];
    switch (list) {
      case CompareList.unverifiedA || CompareList.unverifiedB:
        final side = list == CompareList.unverifiedA ? 'a' : 'b';
        final rows = await db
            .customSelect(
              '$withSql SELECT x.id, x.size_bytes, x.source_id, x.rel_path, x.hash_status, x.availability, '
              'fi.hash_error FROM $side x JOIN file_instances fi ON fi.id = x.id '
              "WHERE x.hash_status != 'done' OR x.content_id IS NULL "
              'ORDER BY x.source_id, x.rel_path LIMIT ? OFFSET ?',
              variables: [...vars, ...page],
              readsFrom: {db.fileInstances, db.sources},
            )
            .get();
        return [
          for (final r in rows)
            CompareItem(
              instanceId: r.read<int>('id'),
              sizeBytes: r.read<int>('size_bytes'),
              sourceId: r.read<String>('source_id'),
              relPath: r.read<String>('rel_path'),
              hashStatus: r.read<String>('hash_status'),
              hashError: r.readNullable<String>('hash_error'),
              availability: r.read<String>('availability'),
            ),
        ];
      case CompareList.missing || CompareList.onlyInB || CompareList.inBoth:
        final (side, other, set) = switch (list) {
          CompareList.missing => ('a', null, 'ac WHERE content_id NOT IN (SELECT content_id FROM bc)'),
          CompareList.onlyInB => ('b', null, 'bc WHERE content_id NOT IN (SELECT content_id FROM ac)'),
          _ => ('a', 'b', 'ac WHERE content_id IN (SELECT content_id FROM bc)'),
        };
        final rows = await db
            .customSelect(
              '$withSql, sel AS (SELECT content_id FROM $set), '
              'grp AS (SELECT x.content_id, MIN(x.id) AS rep, COUNT(*) AS n FROM $side x '
              'WHERE x.content_id IN (SELECT content_id FROM sel) GROUP BY x.content_id) '
              'SELECT g.content_id, g.rep, g.n, c.size_bytes, fi.source_id, fi.rel_path'
              '${other == null ? '' : ', (SELECT o.source_id FROM $other o WHERE o.content_id = g.content_id ORDER BY o.id LIMIT 1) AS o_source, '
                        '(SELECT o.rel_path FROM $other o WHERE o.content_id = g.content_id ORDER BY o.id LIMIT 1) AS o_path'} '
              'FROM grp g JOIN contents c ON c.id = g.content_id JOIN file_instances fi ON fi.id = g.rep '
              'ORDER BY fi.source_id, fi.rel_path LIMIT ? OFFSET ?',
              variables: [...vars, ...page],
              readsFrom: {db.fileInstances, db.contents, db.sources},
            )
            .get();
        return [
          for (final r in rows)
            CompareItem(
              contentId: r.read<int>('content_id'),
              instanceId: r.read<int>('rep'),
              copies: r.read<int>('n'),
              sizeBytes: r.read<int>('size_bytes'),
              sourceId: r.read<String>('source_id'),
              relPath: r.read<String>('rel_path'),
              otherSourceId: other == null ? null : r.readNullable<String>('o_source'),
              otherRelPath: other == null ? null : r.readNullable<String>('o_path'),
            ),
        ];
    }
  }

  /// Trechos para a fila de hash priorizar ("Conferir agora").
  static List<HashPriority> priorityFor(Iterable<Scope> scopes) => [
    for (final s in scopes)
      for (final e in s.entries) HashPriority(e.sourceId, e.relPath),
  ];

  Future<void> _scanIssues(String side, Scope scope, List<CompareIssue> issues, List<CompareWarning> warnings) async {
    for (final sourceId in scope.sourceIds) {
      final row = await sources.byId(sourceId);
      if (row == null || row.forgottenAt != null) {
        issues.add(UnknownSource(side, sourceId));
        continue;
      }
      final scan =
          await (db.select(db.scans)
                ..where((s) => s.sourceId.equals(sourceId) & s.status.equals('completed'))
                ..orderBy([(s) => OrderingTerm.desc(s.id)])
                ..limit(1))
              .getSingleOrNull();
      if (scan == null) {
        issues.add(NeverScanned(side, sourceId, row.name));
        continue;
      }
      if (sources.stateOf(sourceId) != SourceState.connected) {
        warnings.add(
          DisconnectedSource(
            side,
            row.name,
            scan.finishedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(scan.finishedAt!, isUtc: true),
          ),
        );
      }
      if (scan.coverage == 'complete') continue;
      final errorDirs = await db
          .customSelect(
            "SELECT rel_path FROM scan_dirs WHERE scan_id = ? AND status = 'error' ORDER BY rel_path",
            variables: [Variable.withInt(scan.id)],
          )
          .get();
      final entries = scope.entries.where((e) => e.sourceId == sourceId).toList();
      final affected = <String>[
        for (final r in errorDirs)
          if (entries.any((e) => _related(e.relPath, r.read<String>('rel_path')))) r.read<String>('rel_path'),
      ];
      if (affected.isNotEmpty) issues.add(UnreadFolders(side, sourceId, row.name, affected));
    }
  }

  /// A pasta com erro [dir] afeta a entrada [entry] (dentro dela ou acima)?
  static bool _related(String entry, String dir) {
    if (entry.isEmpty || dir.isEmpty) return true;
    return dir == entry || dir.startsWith('$entry/') || entry.startsWith('$dir/');
  }

  Future<void> _overlap(Scope a, Scope b, List<CompareWarning> warnings) async {
    final rows = {for (final s in await db.select(db.sources).get()) s.id: s};
    String? abs(ScopeEntry e) {
      final s = rows[e.sourceId];
      if (s == null || s.volumeGuid == null) return null;
      final rel = [s.rootRelPath, e.relPath].where((x) => x.isNotEmpty).join('/');
      return '${s.volumeGuid!.toLowerCase()}|${rel.toLowerCase()}';
    }

    for (final ea in a.entries) {
      for (final eb in b.entries) {
        final pa = abs(ea), pb = abs(eb);
        if (pa == null || pb == null) continue;
        final (va, ra) = _split(pa);
        final (vb, rb) = _split(pb);
        if (va == vb && _related(ra, rb)) {
          warnings.add(ScopesOverlap(_label(rows[ea.sourceId]!, ea), _label(rows[eb.sourceId]!, eb)));
        }
      }
    }
  }

  static (String, String) _split(String key) {
    final i = key.indexOf('|');
    return (key.substring(0, i), key.substring(i + 1));
  }

  static String _label(SourceRow s, ScopeEntry e) => e.relPath.isEmpty ? s.name : '${s.name} › ${e.relPath}';

  // --- Escopos salvos ---------------------------------------------------------

  Future<List<SavedScope>> savedScopes() async {
    final rows = await (db.select(db.savedScopes)..orderBy([(s) => OrderingTerm.asc(s.name)])).get();
    return [for (final r in rows) _toSaved(r)];
  }

  Stream<List<SavedScope>> watchSavedScopes() => (db.select(
    db.savedScopes,
  )..orderBy([(s) => OrderingTerm.asc(s.name)])).watch().map((rows) => [for (final r in rows) _toSaved(r)]);

  /// Salva [scope] com [name]. Com [replace], atualiza um escopo de mesmo nome.
  Future<SavedScope> saveScope(String name, Scope scope, {bool replace = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw SourceException('Dê um nome ao escopo.');
    if (scope.isEmpty) throw SourceException('O escopo está vazio: escolha ao menos uma pasta ou dispositivo.');
    final now = nowMs();
    final existing = await (db.select(db.savedScopes)..where((s) => s.name.equals(trimmed))).getSingleOrNull();
    if (existing != null && !replace) throw SourceException('Já existe um escopo chamado "$trimmed".');
    if (existing != null) {
      await (db.update(db.savedScopes)..where((s) => s.id.equals(existing.id))).write(
        SavedScopesCompanion(definitionJson: Value(scope.toJson()), updatedAt: Value(now)),
      );
    } else {
      await db
          .into(db.savedScopes)
          .insert(
            SavedScopesCompanion.insert(name: trimmed, definitionJson: scope.toJson(), createdAt: now, updatedAt: now),
          );
    }
    return _toSaved(await (db.select(db.savedScopes)..where((s) => s.name.equals(trimmed))).getSingle());
  }

  Future<void> renameScope(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw SourceException('O nome não pode ficar vazio.');
    final clash = await (db.select(
      db.savedScopes,
    )..where((s) => s.name.equals(trimmed) & s.id.isNotValue(id))).getSingleOrNull();
    if (clash != null) throw SourceException('Já existe um escopo chamado "$trimmed".');
    await (db.update(
      db.savedScopes,
    )..where((s) => s.id.equals(id))).write(SavedScopesCompanion(name: Value(trimmed), updatedAt: Value(nowMs())));
  }

  /// Remove só o escopo salvo (catálogo); nenhum arquivo é tocado.
  Future<void> removeScope(int id) => db.customUpdate(
    'DELETE FROM saved_scopes WHERE id = ?',
    variables: [Variable.withInt(id)],
    updates: {db.savedScopes},
  );

  static SavedScope _toSaved(SavedScopeRow r) => SavedScope(
    id: r.id,
    name: r.name,
    scope: Scope.fromJson(r.definitionJson),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );
}
