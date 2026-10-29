import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import 'capture_date.dart';

/// Correção de relógio de um dispositivo de captura (spec §8.2). Só catálogo.
class ClockCorrection {
  const ClockCorrection({
    required this.id,
    this.make,
    this.model,
    this.bodySerial,
    this.offsetMs = 0,
    this.years = 0,
    this.periodStartUtcMs,
    this.periodEndUtcMs,
    this.sourceIds,
    this.note,
    this.createdAt,
    this.undoneAt,
  });

  final int id;
  final String? make;
  final String? model;

  /// `null` = qualquer corpo desse fabricante/modelo.
  final String? bodySerial;
  final int offsetMs;

  /// "Ano errado": soma anos no calendário (antes do [offsetMs]).
  final int years;

  /// Só itens cuja data extraída cai neste período (opcional).
  final int? periodStartUtcMs;
  final int? periodEndUtcMs;

  /// Só itens com cópia nestas fontes (opcional).
  final Set<String>? sourceIds;
  final String? note;
  final DateTime? createdAt;
  final DateTime? undoneAt;

  bool get active => undoneAt == null;

  /// Vale para um item com esta data extraída e este dispositivo?
  bool matches({
    required DateSource source,
    required int? utcMs,
    required String? make,
    required String? model,
    required String? serial,
    Set<String>? itemSources,
  }) {
    // Relógio da câmera: EXIF, vídeo e o nome que a câmera deu. A data do
    // sistema de arquivos não vem do relógio da câmera.
    if (utcMs == null || !{DateSource.exifOriginal, DateSource.videoInternal, DateSource.filename}.contains(source)) {
      return false;
    }
    if (_norm(make) != _norm(this.make) || _norm(model) != _norm(this.model)) return false;
    if (bodySerial != null && _norm(serial) != _norm(bodySerial)) return false;
    if (periodStartUtcMs != null && utcMs < periodStartUtcMs!) return false;
    if (periodEndUtcMs != null && utcMs > periodEndUtcMs!) return false;
    final only = sourceIds;
    if (only != null && (itemSources == null || !itemSources.any(only.contains))) return false;
    return true;
  }

  static String? _norm(String? s) {
    final t = s?.trim().toLowerCase();
    return t == null || t.isEmpty ? null : t;
  }

  /// Desloca a hora: o instante anda o mesmo tanto que a hora local.
  ({int utcMs, WallTime wall}) apply(int utcMs, WallTime wall) {
    var w = wall;
    if (years != 0) {
      final y = w.year + years;
      final lastDay = DateTime.utc(y, w.month + 1, 0).day;
      w = wallTime(y, w.month, w.day > lastDay ? lastDay : w.day, w.hour, w.minute, w.second, w.millisecond);
    }
    w = w.add(Duration(milliseconds: offsetMs));
    final delta = w.millisecondsSinceEpoch - wall.millisecondsSinceEpoch;
    return (utcMs: utcMs + delta, wall: w);
  }

  /// "+1 h", "−3 min 20 s", "+10 anos" (para a interface e o histórico).
  String describe() {
    final parts = <String>[];
    if (years != 0) parts.add('${years > 0 ? '+' : '−'}${years.abs()} ${years.abs() == 1 ? 'ano' : 'anos'}');
    if (offsetMs != 0) {
      var rest = offsetMs.abs() ~/ 1000;
      final d = rest ~/ 86400;
      rest %= 86400;
      final h = rest ~/ 3600;
      rest %= 3600;
      final m = rest ~/ 60;
      final s = rest % 60;
      final bits = [
        if (d > 0) '$d d',
        if (h > 0) '$h h',
        if (m > 0) '$m min',
        if (s > 0 || (d == 0 && h == 0 && m == 0)) '$s s',
      ];
      parts.add('${offsetMs > 0 ? '+' : '−'}${bits.join(' ')}');
    }
    return parts.isEmpty ? 'sem mudança' : parts.join(' ');
  }

  static ClockCorrection fromRow(QueryRow r) => ClockCorrection(
    id: r.read<int>('id'),
    make: r.readNullable<String>('make'),
    model: r.readNullable<String>('model'),
    bodySerial: r.readNullable<String>('body_serial'),
    offsetMs: r.read<int>('offset_ms'),
    years: r.read<int>('years'),
    periodStartUtcMs: r.readNullable<int>('period_start_utc_ms'),
    periodEndUtcMs: r.readNullable<int>('period_end_utc_ms'),
    sourceIds: switch (r.readNullable<String>('source_ids_json')) {
      null => null,
      final j => {...(jsonDecode(j) as List<Object?>).cast<String>()},
    },
    note: r.readNullable<String>('note'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at'), isUtc: true),
    undoneAt: switch (r.readNullable<int>('undone_at')) {
      null => null,
      final ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    },
  );
}

/// Data efetiva de um item: a que a linha do tempo, os momentos e os filtros usam.
class EffectiveDate {
  const EffectiveDate({
    this.utcMs,
    this.wall,
    this.offsetMin,
    this.source = DateSource.none,
    this.confidence = DateConfidence.none,
    this.correctionId,
  });

  final int? utcMs;
  final WallTime? wall;
  final int? offsetMin;
  final DateSource source;
  final DateConfidence confidence;
  final int? correctionId;

  bool sameAs(EffectiveDate o) =>
      utcMs == o.utcMs &&
      wall == o.wall &&
      offsetMin == o.offsetMin &&
      source == o.source &&
      confidence == o.confidence &&
      correctionId == o.correctionId;
}

/// Data extraída + correções de relógio (na ordem em que foram criadas) +
/// correção manual por item (vale acima de todas).
EffectiveDate computeEffective({
  required int? utcMs,
  required WallTime? wall,
  required int? offsetMin,
  required DateSource source,
  required DateConfidence confidence,
  String? make,
  String? model,
  String? serial,
  ({WallTime wall, int? offsetMin})? manual,
  List<ClockCorrection> corrections = const [],
  Set<String>? itemSources,
  String zone = TimeZones.defaultZone,
}) {
  if (manual != null) {
    final off = manual.offsetMin ?? TimeZones.fromWall(manual.wall, zone).offsetMin;
    return EffectiveDate(
      utcMs: manual.wall.millisecondsSinceEpoch - off * 60000,
      wall: manual.wall,
      offsetMin: off,
      source: DateSource.manual,
      confidence: DateConfidence.high,
    );
  }
  if (utcMs == null || wall == null) {
    return EffectiveDate(utcMs: utcMs, wall: wall, offsetMin: offsetMin, source: source, confidence: confidence);
  }
  var u = utcMs;
  var w = wall;
  int? applied;
  for (final c in corrections) {
    if (!c.active ||
        !c.matches(source: source, utcMs: utcMs, make: make, model: model, serial: serial, itemSources: itemSources)) {
      continue;
    }
    final r = c.apply(u, w);
    u = r.utcMs;
    w = r.wall;
    applied = c.id;
  }
  return EffectiveDate(
    utcMs: u,
    wall: w,
    offsetMin: offsetMin,
    source: source,
    confidence: confidence,
    correctionId: applied,
  );
}

/// Recalcula as colunas `eff_*` de `media_metadata`.
class EffectiveDates {
  EffectiveDates(this.db, {required this.zone});

  final CatalogDatabase db;
  String Function() zone;

  Future<List<ClockCorrection>> activeCorrections() async => [
    for (final r in await db.customSelect('SELECT * FROM clock_corrections WHERE undone_at IS NULL ORDER BY id').get())
      ClockCorrection.fromRow(r),
  ];

  /// Recalcula [contentIds] (ou todos). Devolve quantos mudaram.
  /// [overrideCorrections] simula outro conjunto de correções sem gravar
  /// (prévia): devolve as datas novas em [preview] em vez de atualizar.
  Future<int> recompute({
    Iterable<int>? contentIds,
    List<ClockCorrection>? overrideCorrections,
    Map<int, EffectiveDate>? preview,
  }) async {
    final corrections = overrideCorrections ?? await activeCorrections();
    final needSources = corrections.any((c) => c.sourceIds != null);
    final ids = contentIds?.toList();
    var changed = 0;
    const chunk = 5000;
    for (var start = 0; ids == null ? true : start < ids.length; start += chunk) {
      final part = ids?.sublist(start, (start + chunk).clamp(0, ids.length));
      final where = part == null ? '' : 'WHERE mm.content_id IN (${part.join(',')})';
      final rows = await db.customSelect('''
            SELECT mm.content_id, mm.capture_utc_ms, mm.capture_local, mm.tz_offset_min, mm.date_source, mm.date_confidence,
              mm.make, mm.model, mm.body_serial, mm.eff_utc_ms, mm.eff_local, mm.eff_offset_min, mm.eff_source,
              mm.eff_confidence, mm.clock_correction_id,
              dc.capture_local AS manual_local, dc.tz_offset_min AS manual_offset
              ${needSources ? ", (SELECT group_concat(DISTINCT fi.source_id) FROM file_instances fi WHERE fi.content_id = mm.content_id AND fi.availability != 'missing') AS srcs" : ''}
            FROM media_metadata mm
            LEFT JOIN date_corrections dc ON dc.content_id = mm.content_id AND dc.superseded_at IS NULL
            $where
            ORDER BY mm.content_id ${ids == null ? 'LIMIT $chunk OFFSET $start' : ''}
            ''').get();
      if (rows.isEmpty) break;
      final updates = <(int, EffectiveDate)>[];
      for (final r in rows) {
        final manualLocal = parseWall(r.readNullable<String>('manual_local'));
        final eff = computeEffective(
          utcMs: r.readNullable<int>('capture_utc_ms'),
          wall: parseWall(r.readNullable<String>('capture_local')),
          offsetMin: r.readNullable<int>('tz_offset_min'),
          source: DateSource.fromSql(r.readNullable<String>('date_source')),
          confidence: DateConfidence.fromSql(r.readNullable<String>('date_confidence')),
          make: r.readNullable<String>('make'),
          model: r.readNullable<String>('model'),
          serial: r.readNullable<String>('body_serial'),
          manual: manualLocal == null ? null : (wall: manualLocal, offsetMin: r.readNullable<int>('manual_offset')),
          corrections: corrections,
          itemSources: needSources ? (r.readNullable<String>('srcs')?.split(',').toSet() ?? const {}) : null,
          zone: zone(),
        );
        final current = EffectiveDate(
          utcMs: r.readNullable<int>('eff_utc_ms'),
          wall: parseWall(r.readNullable<String>('eff_local')),
          offsetMin: r.readNullable<int>('eff_offset_min'),
          source: DateSource.fromSql(r.readNullable<String>('eff_source')),
          confidence: DateConfidence.fromSql(r.readNullable<String>('eff_confidence')),
          correctionId: r.readNullable<int>('clock_correction_id'),
        );
        if (!eff.sameAs(current) || r.readNullable<String>('eff_source') == null) {
          updates.add((r.read<int>('content_id'), eff));
        }
      }
      if (preview != null) {
        for (final (id, eff) in updates) {
          preview[id] = eff;
        }
      } else if (updates.isNotEmpty) {
        await write(db, updates);
      }
      changed += updates.length;
      if (ids == null && rows.length < chunk) break;
    }
    return changed;
  }

  /// Grava as colunas `eff_*` (com as derivadas para os filtros).
  static Future<void> write(CatalogDatabase db, List<(int, EffectiveDate)> updates) async {
    // Em lote: o mesmo comando preparado para todas as linhas.
    await db.batch((b) {
      for (final (id, e) in updates) {
        final w = e.wall;
        b.customStatement(
          'UPDATE media_metadata SET eff_utc_ms = ?, eff_local = ?, eff_offset_min = ?, eff_source = ?, '
          'eff_confidence = ?, clock_correction_id = ?, eff_year = ?, eff_month = ?, eff_day = ?, eff_minute = ?, '
          'eff_weekday = ? WHERE content_id = ?',
          [
            e.utcMs,
            w == null ? null : formatWall(w),
            e.offsetMin,
            e.source.sql,
            e.confidence.name,
            e.correctionId,
            w?.year,
            w?.month,
            w == null ? null : formatWall(w).substring(0, 10),
            w == null ? null : w.hour * 60 + w.minute,
            w?.weekday,
            id,
          ],
        );
      }
    });
    // customStatement não avisa as consultas reativas (telas abertas).
    db.notifyUpdates({TableUpdate.onTable(db.mediaMetadata, kind: UpdateKind.update)});
  }
}
