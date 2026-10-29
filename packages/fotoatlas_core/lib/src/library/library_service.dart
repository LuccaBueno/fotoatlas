import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../coverage/coverage_service.dart';
import '../metadata/capture_date.dart';
import '../metadata/effective_dates.dart';
import '../sources/media_types.dart';
import '../util/clock.dart';
import 'library_filter.dart';

/// Resultado de uma consulta: só IDs e chaves de ordenação (a galeria nunca
/// carrega a biblioteca inteira; os detalhes vêm por página, spec §10).
class LibraryIndex {
  LibraryIndex(this.ids, this.utc, this.day, this.moment);

  /// IDs de conteúdo, na ordem da linha do tempo.
  final Int64List ids;

  /// Instante efetivo (ms UTC); [noDate] = sem data.
  final Int64List utc;

  /// Dia local AAAAMMDD (0 = sem data).
  final Int32List day;

  /// Momento (0 = nenhum).
  final Int32List moment;

  static const noDate = -0x7FFFFFFFFFFFFFFF;
  static final empty = LibraryIndex(Int64List(0), Int64List(0), Int32List(0), Int32List(0));

  int get length => ids.length;
}

/// Um item da galeria (um conteúdo; cópias idênticas aparecem uma vez).
class LibraryItem {
  const LibraryItem({
    required this.contentId,
    required this.name,
    required this.ext,
    required this.mediaType,
    required this.sizeBytes,
    required this.copies,
    required this.backup,
    this.local,
    this.utcMs,
    this.confidence = DateConfidence.none,
    this.dateSource = DateSource.none,
    this.corrected = false,
    this.conflict = false,
    this.momentId,
    this.width,
    this.height,
    this.durationMs,
    this.make,
    this.model,
    this.hasGps = false,
    this.metaError,
    this.sha256Hex,
  });

  final int contentId;

  /// Nome de uma das cópias (a primeira encontrada).
  final String name;
  final String ext;
  final String mediaType;
  final int sizeBytes;
  final int copies;
  final BackupState backup;
  final WallTime? local;
  final int? utcMs;
  final DateConfidence confidence;
  final DateSource dateSource;
  final bool corrected;
  final bool conflict;
  final int? momentId;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? make;
  final String? model;
  final bool hasGps;
  final String? metaError;
  final String? sha256Hex;

  /// Hora incerta: baixa confiança, não corrigida nem confirmada.
  bool get uncertain => (confidence == DateConfidence.low || confidence == DateConfidence.none) && !corrected;
}

/// Onde um conteúdo está (painel de detalhes: "todas as localizações").
class ItemLocation {
  const ItemLocation({
    required this.sourceId,
    required this.sourceName,
    required this.sourceKind,
    required this.relPath,
    required this.availability,
    required this.hashStatus,
    this.mtime,
  });
  final String sourceId;
  final String sourceName;
  final String sourceKind;
  final String relPath;
  final String availability;
  final String hashStatus;
  final DateTime? mtime;
}

/// Tudo de um item para o painel de detalhes.
class LibraryItemDetail {
  const LibraryItemDetail({
    required this.item,
    required this.locations,
    required this.candidates,
    this.extracted,
    this.extractedConfidence,
    this.extractedSource,
    this.correction,
    this.manualNote,
    this.lens,
    this.iso,
    this.aperture,
    this.exposureS,
    this.focalMm,
    this.lat,
    this.lon,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.serial,
    this.software,
    this.extractor,
    this.offsetMin,
  });

  final LibraryItem item;
  final List<ItemLocation> locations;

  /// Todas as datas candidatas encontradas (com a origem).
  final List<DateCandidate> candidates;

  /// Data extraída do arquivo (antes das correções).
  final WallTime? extracted;
  final DateConfidence? extractedConfidence;
  final DateSource? extractedSource;
  final ClockCorrection? correction;
  final String? manualNote;
  final String? lens;
  final int? iso;
  final double? aperture;
  final double? exposureS;
  final double? focalMm;
  final double? lat;
  final double? lon;
  final double? fps;
  final String? videoCodec;
  final String? audioCodec;
  final String? serial;
  final String? software;
  final String? extractor;
  final int? offsetMin;
}

/// Contagens para os chips de filtro.
class LibraryFacets {
  const LibraryFacets({
    required this.total,
    required this.years,
    required this.sources,
    required this.cameras,
    required this.types,
    required this.toConfirm,
    required this.noDate,
    required this.pendingContent,
    required this.pendingMetadata,
  });
  final int total;
  final Map<int, int> years;

  /// fonte → itens com cópia nela.
  final Map<String, int> sources;

  /// 'fabricante\u0001modelo' → itens.
  final Map<String, int> cameras;
  final Map<String, int> types;
  final int toConfirm;
  final int noDate;

  /// Arquivos de mídia ainda sem conteúdo conferido (não aparecem até a conferência).
  final int pendingContent;

  /// Conteúdos ainda sem metadados lidos.
  final int pendingMetadata;
}

/// Resumo da seleção (barra fixa: "523 itens · 4,2 GB · …").
class SelectionSummary {
  const SelectionSummary({required this.items, required this.bytes, required this.files, required this.backup});
  final int items;
  final int bytes;

  /// Arquivos (cópias) por trás dos itens.
  final int files;
  final Map<BackupState, int> backup;
}

/// Filtro salvo com nome.
class SavedFilter {
  const SavedFilter({required this.id, required this.name, required this.filter});
  final int id;
  final String name;
  final LibraryFilter filter;
}

/// Consultas da Biblioteca. Só lê o catálogo.
class LibraryService {
  LibraryService(this.db);
  final CatalogDatabase db;

  static const _base =
      "FROM contents c LEFT JOIN media_metadata mm ON mm.content_id = c.id "
      "WHERE c.media_type IN ('photo','raw','video') AND c.id IN (SELECT x.content_id FROM file_instances x "
      "JOIN sources xs ON xs.id = x.source_id AND xs.forgotten_at IS NULL "
      "WHERE x.availability = 'present' AND x.content_id IS NOT NULL)";

  /// Avisa quando algo que muda a Biblioteca foi gravado.
  Stream<void> get changes => db
      .tableUpdates(
        TableUpdateQuery.onAllTables([db.mediaMetadata, db.contents, db.fileInstances, db.moments, db.sources]),
      )
      .map((_) {});

  /// Nenhuma fonte cadastrada está dentro de outra (mesmo volume, pasta
  /// dentro de pasta)? Então cada cópia é um arquivo físico diferente.
  Future<bool> _sourcesDisjoint() async {
    final rows = await db
        .customSelect(
          'SELECT lower(volume_guid) AS v, lower(root_rel_path) AS r FROM sources '
          'WHERE forgotten_at IS NULL AND volume_guid IS NOT NULL',
        )
        .get();
    final byVolume = <String, List<String>>{};
    for (final r in rows) {
      (byVolume[r.read<String>('v')] ??= []).add(r.read<String>('r'));
    }
    for (final roots in byVolume.values) {
      for (var i = 0; i < roots.length; i++) {
        for (var j = 0; j < roots.length; j++) {
          if (i == j) continue;
          final a = roots[i], b = roots[j];
          if (a.isEmpty || a == b || b.startsWith('$a/')) return false;
        }
      }
    }
    return true;
  }

  Future<LibraryIndex> index(LibraryFilter filter, {bool ascending = false}) async {
    final (where, vars) = filter.toSql(simpleCopies: await _sourcesDisjoint());
    final dir = ascending ? 'ASC' : 'DESC';
    // Uma linha só, com o índice inteiro em texto: 100 mil linhas soltas
    // custariam caro para atravessar do isolate do catálogo até aqui.
    final row = await db
        .customSelect(
          "SELECT group_concat(c.id || ',' || COALESCE(mm.eff_utc_ms, '') || ',' || "
          "COALESCE(replace(mm.eff_day, '-', ''), '') || ',' || COALESCE(mm.moment_id, ''), ';' "
          'ORDER BY (mm.eff_utc_ms IS NULL), mm.eff_utc_ms $dir, c.id $dir) AS idx, COUNT(*) AS n '
          '$_base AND $where',
          variables: vars,
        )
        .getSingle();
    final n = row.read<int>('n');
    final ids = Int64List(n), utc = Int64List(n);
    final day = Int32List(n), moment = Int32List(n);
    final text = row.readNullable<String>('idx') ?? '';
    var pos = 0;
    int? next(String sep) {
      final end = text.indexOf(sep, pos);
      final s = text.substring(pos, end < 0 ? text.length : end);
      pos = end < 0 ? text.length : end + 1;
      return s.isEmpty ? null : int.parse(s);
    }

    for (var i = 0; i < n; i++) {
      ids[i] = next(',')!;
      utc[i] = next(',') ?? LibraryIndex.noDate;
      day[i] = next(',') ?? 0;
      moment[i] = next(';') ?? 0;
    }
    return LibraryIndex(ids, utc, day, moment);
  }

  /// Só a contagem (para os chips e o Início).
  Future<int> count(LibraryFilter filter) async {
    final (where, vars) = filter.toSql(simpleCopies: await _sourcesDisjoint());
    return (await db.customSelect('SELECT COUNT(*) AS n $_base AND $where', variables: vars).getSingle()).read<int>(
      'n',
    );
  }

  /// Detalhes de uma página de itens, na ordem de [ids].
  Future<List<LibraryItem>> items(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final list = ids.join(',');
    final rows = await db.customSelect('''
          SELECT c.id, c.media_type, c.size_bytes, hex(c.sha256) AS sha,
            mm.eff_local, mm.eff_utc_ms, mm.eff_confidence, mm.eff_source, mm.clock_correction_id, mm.date_conflict,
            mm.moment_id, mm.width, mm.height, mm.duration_ms, mm.make, mm.model, mm.lat, mm.meta_status, mm.meta_error,
            (SELECT fi.name FROM file_instances fi WHERE fi.content_id = c.id AND fi.availability != 'missing' ORDER BY fi.id LIMIT 1) AS name,
            (SELECT fi.ext FROM file_instances fi WHERE fi.content_id = c.id ORDER BY fi.id LIMIT 1) AS ext,
            b.copies, b.state
          FROM contents c
          LEFT JOIN media_metadata mm ON mm.content_id = c.id
          LEFT JOIN (${LibraryFilter.backupStatesSql(onlyIds: list)}) b ON b.content_id = c.id
          WHERE c.id IN ($list)
          ''').get();
    final byId = {for (final r in rows) r.read<int>('id'): _item(r)};
    return [for (final id in ids) ?byId[id]];
  }

  static LibraryItem _item(QueryRow r) => LibraryItem(
    contentId: r.read<int>('id'),
    name: r.readNullable<String>('name') ?? '',
    ext: r.readNullable<String>('ext') ?? '',
    mediaType: r.read<String>('media_type'),
    sizeBytes: r.read<int>('size_bytes'),
    copies: r.readNullable<int>('copies') ?? 0,
    backup: switch (r.readNullable<String>('state')) {
      'independent' => BackupState.independent,
      'verified' => BackupState.verified,
      'single' => BackupState.single,
      _ => BackupState.unknown,
    },
    local: parseWall(r.readNullable<String>('eff_local')),
    utcMs: r.readNullable<int>('eff_utc_ms'),
    confidence: DateConfidence.fromSql(r.readNullable<String>('eff_confidence')),
    dateSource: DateSource.fromSql(r.readNullable<String>('eff_source')),
    corrected: r.readNullable<int>('clock_correction_id') != null || r.readNullable<String>('eff_source') == 'manual',
    conflict: (r.readNullable<int>('date_conflict') ?? 0) == 1,
    momentId: r.readNullable<int>('moment_id'),
    width: r.readNullable<int>('width'),
    height: r.readNullable<int>('height'),
    durationMs: r.readNullable<int>('duration_ms'),
    make: r.readNullable<String>('make'),
    model: r.readNullable<String>('model'),
    hasGps: r.readNullable<double>('lat') != null,
    metaError: r.readNullable<String>('meta_status') == 'error' ? r.readNullable<String>('meta_error') : null,
    sha256Hex: r.readNullable<String>('sha')?.toLowerCase(),
  );

  Future<LibraryItemDetail?> detail(int contentId) async {
    final item = (await items([contentId])).firstOrNull;
    if (item == null) return null;
    final mm = await db
        .customSelect('SELECT * FROM media_metadata WHERE content_id = ?', variables: [Variable.withInt(contentId)])
        .getSingleOrNull();
    final locs = await db
        .customSelect(
          'SELECT fi.source_id, s.name, s.kind, fi.rel_path, fi.availability, fi.hash_status, fi.mtime '
          'FROM file_instances fi JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL '
          'WHERE fi.content_id = ? ORDER BY s.name, fi.rel_path',
          variables: [Variable.withInt(contentId)],
        )
        .get();
    ClockCorrection? correction;
    final cid = mm?.readNullable<int>('clock_correction_id');
    if (cid != null) {
      final r = await db
          .customSelect('SELECT * FROM clock_corrections WHERE id = ?', variables: [Variable.withInt(cid)])
          .getSingleOrNull();
      if (r != null) correction = ClockCorrection.fromRow(r);
    }
    final manual = await db
        .customSelect(
          'SELECT note FROM date_corrections WHERE content_id = ? AND superseded_at IS NULL',
          variables: [Variable.withInt(contentId)],
        )
        .getSingleOrNull();
    return LibraryItemDetail(
      item: item,
      locations: [
        for (final l in locs)
          ItemLocation(
            sourceId: l.read<String>('source_id'),
            sourceName: l.read<String>('name'),
            sourceKind: l.read<String>('kind'),
            relPath: l.read<String>('rel_path'),
            availability: l.read<String>('availability'),
            hashStatus: l.read<String>('hash_status'),
            mtime: switch (l.readNullable<int>('mtime')) {
              final ft? when ft > 0 => DateTime.fromMillisecondsSinceEpoch(
                (ft - 116444736000000000) ~/ 10000,
                isUtc: true,
              ),
              _ => null,
            },
          ),
      ],
      candidates: DateStrategy.candidatesFromJson(mm?.readNullable<String>('candidates_json')),
      extracted: parseWall(mm?.readNullable<String>('capture_local')),
      extractedConfidence: mm == null ? null : DateConfidence.fromSql(mm.readNullable<String>('date_confidence')),
      extractedSource: mm == null ? null : DateSource.fromSql(mm.readNullable<String>('date_source')),
      correction: correction,
      manualNote: manual?.readNullable<String>('note'),
      lens: mm?.readNullable<String>('lens'),
      iso: mm?.readNullable<int>('iso'),
      aperture: mm?.readNullable<double>('aperture'),
      exposureS: mm?.readNullable<double>('exposure_s'),
      focalMm: mm?.readNullable<double>('focal_mm'),
      lat: mm?.readNullable<double>('lat'),
      lon: mm?.readNullable<double>('lon'),
      fps: mm?.readNullable<double>('fps'),
      videoCodec: mm?.readNullable<String>('video_codec'),
      audioCodec: mm?.readNullable<String>('audio_codec'),
      serial: mm?.readNullable<String>('body_serial'),
      software: mm?.readNullable<String>('software'),
      extractor: mm?.readNullable<String>('extractor'),
      offsetMin: mm?.readNullable<int>('eff_offset_min'),
    );
  }

  Future<LibraryFacets> facets() async {
    Future<Map<K, int>> group<K>(String sql, K Function(QueryRow) key) async => {
      for (final r in await db.customSelect(sql).get()) key(r): r.read<int>('n'),
    };
    final total = await count(LibraryFilter.empty);
    final years = await group<int>(
      'SELECT mm.eff_year AS y, COUNT(*) AS n $_base AND mm.eff_year IS NOT NULL GROUP BY mm.eff_year',
      (r) => r.read<int>('y'),
    );
    final cameras = await group<String>(
      "SELECT COALESCE(mm.make, '') || char(1) || COALESCE(mm.model, '') AS k, COUNT(*) AS n $_base "
      'AND (mm.make IS NOT NULL OR mm.model IS NOT NULL) GROUP BY k',
      (r) => r.read<String>('k'),
    );
    final types = await group<String>(
      'SELECT c.media_type AS k, COUNT(*) AS n $_base GROUP BY c.media_type',
      (r) => r.read<String>('k'),
    );
    final sources = await group<String>(
      "SELECT fi.source_id AS k, COUNT(DISTINCT fi.content_id) AS n FROM file_instances fi "
      "JOIN contents c ON c.id = fi.content_id AND c.media_type IN ('photo','raw','video') "
      "WHERE fi.availability = 'present' GROUP BY fi.source_id",
      (r) => r.read<String>('k'),
    );
    final (tc, tv) = const LibraryFilter([FilterCondition(FilterKind.toConfirm)]).toSql();
    final toConfirm = (await db.customSelect('SELECT COUNT(*) AS n $_base AND $tc', variables: tv).getSingle())
        .read<int>('n');
    final noDate = (await db.customSelect('SELECT COUNT(*) AS n $_base AND mm.eff_utc_ms IS NULL').getSingle())
        .read<int>('n');
    final media = "('photo','raw','video')";
    final pendingContent =
        (await db
                .customSelect(
                  "SELECT COUNT(*) AS n FROM file_instances fi JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL "
                  "WHERE fi.availability = 'present' AND fi.hash_status = 'pending' "
                  "AND fi.ext IN ${MediaTypes.sqlList(MediaTypes.media)}",
                )
                .getSingle())
            .read<int>('n');
    final pendingMetadata =
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM contents c LEFT JOIN media_metadata mm ON mm.content_id = c.id '
                  "WHERE c.media_type IN $media AND (mm.content_id IS NULL OR mm.meta_status = 'partial')",
                )
                .getSingle())
            .read<int>('n');
    return LibraryFacets(
      total: total,
      years: years,
      sources: sources,
      cameras: cameras,
      types: types,
      toConfirm: toConfirm,
      noDate: noDate,
      pendingContent: pendingContent,
      pendingMetadata: pendingMetadata,
    );
  }

  Future<SelectionSummary> summarize(Iterable<int> contentIds) async {
    final ids = contentIds.toList();
    if (ids.isEmpty) return const SelectionSummary(items: 0, bytes: 0, files: 0, backup: {});
    var bytes = 0, files = 0;
    final backup = <BackupState, int>{};
    const chunk = 20000;
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(i, (i + chunk).clamp(0, ids.length)).join(',');
      final r = await db
          .customSelect(
            'SELECT COALESCE(SUM(size_bytes), 0) AS b, '
            "(SELECT COUNT(*) FROM file_instances WHERE content_id IN ($part) AND availability = 'present') AS f "
            'FROM contents WHERE id IN ($part)',
          )
          .getSingle();
      bytes += r.read<int>('b');
      files += r.read<int>('f');
      for (final s
          in await db
              .customSelect(
                'SELECT state, COUNT(*) AS n FROM (${LibraryFilter.backupStatesSql(onlyIds: part)}) GROUP BY state',
              )
              .get()) {
        final st = BackupState.values.byName(s.read<String>('state'));
        backup[st] = (backup[st] ?? 0) + s.read<int>('n');
      }
    }
    return SelectionSummary(items: ids.length, bytes: bytes, files: files, backup: backup);
  }

  // --- Filtros salvos ---------------------------------------------------------

  Future<List<SavedFilter>> savedFilters() async => [
    for (final r in await db.customSelect('SELECT id, name, definition_json FROM saved_filters ORDER BY name').get())
      SavedFilter(
        id: r.read<int>('id'),
        name: r.read<String>('name'),
        filter: LibraryFilter.fromJson(r.read<String>('definition_json')),
      ),
  ];

  /// Salva (ou substitui, pelo nome) um filtro. Só catálogo.
  Future<int> saveFilter(String name, LibraryFilter filter) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Dê um nome ao filtro.');
    final now = nowMs();
    return db.customInsert(
      'INSERT INTO saved_filters (name, definition_json, created_at, updated_at) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(name) DO UPDATE SET definition_json = excluded.definition_json, updated_at = excluded.updated_at',
      variables: [
        Variable.withString(trimmed),
        Variable.withString(filter.toJson()),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
      updates: {db.savedFilters},
    );
  }

  Future<void> deleteFilter(int id) => db.customUpdate(
    'DELETE FROM saved_filters WHERE id = ?',
    variables: [Variable.withInt(id)],
    updates: {db.savedFilters},
    updateKind: UpdateKind.delete,
  );
}
