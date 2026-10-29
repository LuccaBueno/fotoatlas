import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../util/clock.dart';
import 'capture_date.dart';
import 'effective_dates.dart';
import 'moments_service.dart';

/// Dispositivo de captura (fabricante + modelo + número de série do corpo
/// quando o EXIF tem), com quantos itens e o período.
class CaptureDevice {
  const CaptureDevice({this.make, this.model, this.serial, required this.items, this.firstUtcMs, this.lastUtcMs});
  final String? make;
  final String? model;
  final String? serial;
  final int items;
  final int? firstUtcMs;
  final int? lastUtcMs;

  /// "Canon EOS X (nº 0123)".
  String get label {
    final m = model ?? '';
    final base = make == null || m.toLowerCase().startsWith(make!.toLowerCase()) ? m : '$make $m';
    final name = base.trim().isEmpty ? 'Dispositivo sem nome' : base.trim();
    return serial == null ? name : '$name (nº $serial)';
  }
}

/// Rascunho de correção de relógio (antes de aplicar).
class ClockCorrectionDraft {
  const ClockCorrectionDraft({
    required this.make,
    required this.model,
    this.serial,
    this.offset = Duration.zero,
    this.years = 0,
    this.periodStartUtcMs,
    this.periodEndUtcMs,
    this.sourceIds,
    this.note,
  });
  final String? make;
  final String? model;
  final String? serial;
  final Duration offset;
  final int years;
  final int? periodStartUtcMs;
  final int? periodEndUtcMs;
  final Set<String>? sourceIds;
  final String? note;

  ClockCorrection toCorrection(int id) => ClockCorrection(
    id: id,
    make: make,
    model: model,
    bodySerial: serial,
    offsetMs: offset.inMilliseconds,
    years: years,
    periodStartUtcMs: periodStartUtcMs,
    periodEndUtcMs: periodEndUtcMs,
    sourceIds: sourceIds,
    note: note,
  );
}

/// Um exemplo "antes → depois" da prévia.
class CorrectionExample {
  const CorrectionExample({
    required this.contentId,
    required this.name,
    required this.before,
    required this.after,
    this.neighborName,
    this.neighborDevice,
    this.neighborLocal,
  });
  final int contentId;
  final String name;
  final WallTime before;
  final WallTime after;

  /// O item de outro dispositivo mais perto da hora nova (para conferir o alinhamento).
  final String? neighborName;
  final String? neighborDevice;
  final WallTime? neighborLocal;
}

/// Prévia obrigatória (spec §8.2): o que muda antes de aplicar.
class CorrectionPreview {
  const CorrectionPreview({
    required this.affected,
    required this.examples,
    required this.momentsBefore,
    required this.momentsAfter,
    required this.itemsChangingMoment,
  });
  final int affected;
  final List<CorrectionExample> examples;

  /// Momentos (automáticos + editados) com itens deste dispositivo, antes e depois.
  final int momentsBefore;
  final int momentsAfter;

  /// Itens (de qualquer dispositivo) que trocariam de momento.
  final int itemsChangingMoment;
}

/// Datas: correção de relógio por dispositivo, correção manual por item e
/// "confirmar a hora". Tudo só no catálogo, nunca nos arquivos (spec §8).
class DatesService {
  DatesService(this.db, this.effective, this.moments);

  final CatalogDatabase db;
  final EffectiveDates effective;
  final MomentsService moments;

  /// Dispositivos de captura conhecidos (pelo EXIF), com mais itens primeiro.
  Future<List<CaptureDevice>> captureDevices() async {
    final rows = await db
        .customSelect(
          'SELECT make, model, body_serial, COUNT(*) AS n, MIN(capture_utc_ms) AS a, MAX(capture_utc_ms) AS b '
          'FROM media_metadata WHERE make IS NOT NULL OR model IS NOT NULL '
          'GROUP BY make, model, body_serial ORDER BY n DESC',
        )
        .get();
    return [
      for (final r in rows)
        CaptureDevice(
          make: r.readNullable<String>('make'),
          model: r.readNullable<String>('model'),
          serial: r.readNullable<String>('body_serial'),
          items: r.read<int>('n'),
          firstUtcMs: r.readNullable<int>('a'),
          lastUtcMs: r.readNullable<int>('b'),
        ),
    ];
  }

  /// Deslocamento que alinha [contentId] (ex.: foto da câmera) com
  /// [referenceContentId] (ex.: foto do celular no mesmo instante).
  Future<Duration> offsetBetween(int contentId, int referenceContentId) async {
    final rows = await db
        .customSelect(
          'SELECT content_id, capture_utc_ms, eff_utc_ms FROM media_metadata WHERE content_id IN (?, ?)',
          variables: [Variable.withInt(contentId), Variable.withInt(referenceContentId)],
        )
        .get();
    int? at(int id, String col) => rows.where((r) => r.read<int>('content_id') == id).firstOrNull?.readNullable(col);
    // Da câmera: a data extraída (sem correções); a referência: a efetiva.
    final a = at(contentId, 'capture_utc_ms');
    final b = at(referenceContentId, 'eff_utc_ms');
    if (a == null || b == null) throw StateError('Um dos itens não tem data.');
    return Duration(milliseconds: b - a);
  }

  /// Prévia sem gravar nada.
  Future<CorrectionPreview> preview(ClockCorrectionDraft draft, {int maxExamples = 5}) async {
    final current = await effective.activeCorrections();
    final simulated = <int, EffectiveDate>{};
    await effective.recompute(overrideCorrections: [...current, draft.toCorrection(-1)], preview: simulated);
    final affected = simulated.entries.where((e) => e.value.correctionId == -1).map((e) => e.key).toSet();

    // Momentos antes e depois: o mesmo agrupamento da biblioteca, com as horas simuladas.
    final rows = await db
        .customSelect(
          'SELECT content_id, eff_utc_ms, eff_local, eff_confidence, eff_source, moment_id FROM media_metadata '
          'WHERE eff_utc_ms IS NOT NULL',
        )
        .get();
    final edited = [
      for (final m
          in await db
              .customSelect(
                "SELECT id, start_utc_ms, end_utc_ms FROM moments WHERE kind = 'edited' ORDER BY start_utc_ms",
              )
              .get())
        (m.read<int>('id'), m.read<int>('start_utc_ms'), m.read<int>('end_utc_ms')),
    ];
    bool eligible(String? conf, String? src) => conf == 'high' || conf == 'medium' || src == 'manual';
    List<(int, int)> items(bool after) {
      final list = <(int, int)>[];
      for (final r in rows) {
        final id = r.read<int>('content_id');
        final sim = after ? simulated[id] : null;
        final conf = sim?.confidence.name ?? r.readNullable<String>('eff_confidence');
        final src = sim?.source.sql ?? r.readNullable<String>('eff_source');
        if (!eligible(conf, src)) continue;
        list.add((id, sim?.utcMs ?? r.read<int>('eff_utc_ms')));
      }
      return list..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
    }

    final gapMs = moments.gap.inMilliseconds;
    final before = items(false);
    final after = items(true);
    final keyBefore = {for (final (i, k) in _zip(before, groupMoments(before, edited, gapMs))) i: k};
    final keyAfter = {for (final (i, k) in _zip(after, groupMoments(after, edited, gapMs))) i: k};
    // Compara grupos pela composição: item muda de momento se seus vizinhos de grupo mudam.
    final membersBefore = <String, Set<int>>{};
    final membersAfter = <String, Set<int>>{};
    keyBefore.forEach((i, k) => (membersBefore[k] ??= {}).add(i));
    keyAfter.forEach((i, k) => (membersAfter[k] ??= {}).add(i));
    var changing = 0;
    for (final i in keyAfter.keys) {
      final a = membersAfter[keyAfter[i]]!;
      final b = keyBefore[i] == null ? null : membersBefore[keyBefore[i]];
      if (b == null || a.length != b.length || !a.containsAll(b)) changing++;
    }

    final examples = <CorrectionExample>[];
    if (affected.isNotEmpty) {
      final sample = affected.take(maxExamples).toList();
      final names = await db
          .customSelect(
            'SELECT fi.content_id, MIN(fi.name) AS name FROM file_instances fi WHERE fi.content_id IN (${sample.join(',')}) '
            'GROUP BY fi.content_id',
          )
          .get();
      final nameOf = {for (final r in names) r.read<int>('content_id'): r.read<String>('name')};
      final draftKey = (draft.make?.toLowerCase(), draft.model?.toLowerCase());
      for (final id in sample) {
        final row = rows.firstWhere((r) => r.read<int>('content_id') == id);
        final sim = simulated[id]!;
        final neighbor = await db
            .customSelect(
              'SELECT mm.eff_local, mm.make, mm.model, (SELECT MIN(name) FROM file_instances WHERE content_id = mm.content_id) AS name '
              'FROM media_metadata mm WHERE mm.eff_utc_ms IS NOT NULL AND mm.content_id != ? '
              'AND NOT (lower(COALESCE(mm.make, \'\')) = ? AND lower(COALESCE(mm.model, \'\')) = ?) '
              'ORDER BY abs(mm.eff_utc_ms - ?) LIMIT 1',
              variables: [
                Variable.withInt(id),
                Variable.withString(draftKey.$1 ?? ''),
                Variable.withString(draftKey.$2 ?? ''),
                Variable.withInt(sim.utcMs!),
              ],
            )
            .getSingleOrNull();
        examples.add(
          CorrectionExample(
            contentId: id,
            name: nameOf[id] ?? '',
            before: parseWall(row.read<String>('eff_local'))!,
            after: sim.wall!,
            neighborName: neighbor?.readNullable<String>('name'),
            neighborDevice: neighbor == null
                ? null
                : CaptureDevice(
                    make: neighbor.readNullable<String>('make'),
                    model: neighbor.readNullable<String>('model'),
                    items: 0,
                  ).label,
            neighborLocal: parseWall(neighbor?.readNullable<String>('eff_local')),
          ),
        );
      }
    }
    return CorrectionPreview(
      affected: affected.length,
      examples: examples,
      momentsBefore: {for (final i in affected) ?keyBefore[i]}.length,
      momentsAfter: {for (final i in affected) ?keyAfter[i]}.length,
      itemsChangingMoment: changing,
    );
  }

  static Iterable<(int, String)> _zip(List<(int, int)> items, List<String> keys) sync* {
    for (var i = 0; i < items.length; i++) {
      yield (items[i].$1, keys[i]);
    }
  }

  /// Aplica (depois da prévia). Devolve o ID da correção.
  Future<int> applyCorrection(ClockCorrectionDraft draft) async {
    final id = await db.customInsert(
      'INSERT INTO clock_corrections (make, model, body_serial, offset_ms, years, period_start_utc_ms, '
      'period_end_utc_ms, source_ids_json, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        _v(draft.make),
        _v(draft.model),
        _v(draft.serial),
        Variable.withInt(draft.offset.inMilliseconds),
        Variable.withInt(draft.years),
        _vi(draft.periodStartUtcMs),
        _vi(draft.periodEndUtcMs),
        _v(draft.sourceIds == null ? null : jsonEncode(draft.sourceIds!.toList()..sort())),
        _v(draft.note),
        Variable.withInt(nowMs()),
      ],
      updates: {db.clockCorrections},
    );
    await _afterChange();
    return id;
  }

  /// Desfaz uma correção (fica no histórico como desfeita).
  Future<void> undoCorrection(int id) async {
    final n = await db.customUpdate(
      'UPDATE clock_corrections SET undone_at = ? WHERE id = ? AND undone_at IS NULL',
      variables: [Variable.withInt(nowMs()), Variable.withInt(id)],
      updates: {db.clockCorrections},
    );
    if (n == 0) throw StateError('A correção $id não existe ou já foi desfeita.');
    await _afterChange();
  }

  /// Histórico de correções de relógio (as desfeitas também).
  Future<List<ClockCorrection>> corrections() async => [
    for (final r in await db.customSelect('SELECT * FROM clock_corrections ORDER BY id DESC').get())
      ClockCorrection.fromRow(r),
  ];

  /// Hora manual para itens (vale acima de tudo). [offsetMin] `null` = fuso padrão.
  Future<void> setManual(Iterable<int> contentIds, WallTime wall, {int? offsetMin, String? note}) async {
    final ids = contentIds.toList();
    if (ids.isEmpty) return;
    final now = nowMs();
    await db.transaction(() async {
      for (final id in ids) {
        await db.customStatement(
          'UPDATE date_corrections SET superseded_at = ? WHERE content_id = ? AND superseded_at IS NULL',
          [now, id],
        );
        await db.customStatement(
          'INSERT INTO date_corrections (content_id, capture_local, tz_offset_min, note, created_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [id, formatWall(wall), offsetMin, note, now],
        );
      }
    });
    await _afterChange(ids);
  }

  /// "A hora está certa": confirma a hora atual (sai de "Hora a confirmar").
  Future<int> confirm(Iterable<int> contentIds) async {
    final ids = contentIds.toList();
    if (ids.isEmpty) return 0;
    final rows = await db
        .customSelect(
          'SELECT content_id, eff_local, eff_offset_min FROM media_metadata '
          "WHERE content_id IN (${ids.join(',')}) AND eff_local IS NOT NULL AND eff_source != 'manual'",
        )
        .get();
    final now = nowMs();
    await db.transaction(() async {
      for (final r in rows) {
        final id = r.read<int>('content_id');
        await db.customStatement(
          'UPDATE date_corrections SET superseded_at = ? WHERE content_id = ? AND superseded_at IS NULL',
          [now, id],
        );
        await db.customStatement(
          'INSERT INTO date_corrections (content_id, capture_local, tz_offset_min, note, created_at) '
          "VALUES (?, ?, ?, 'hora confirmada', ?)",
          [id, r.read<String>('eff_local'), r.readNullable<int>('eff_offset_min'), now],
        );
      }
    });
    await _afterChange([for (final r in rows) r.read<int>('content_id')]);
    return rows.length;
  }

  /// Tira a correção manual (volta para a data do arquivo).
  Future<void> clearManual(Iterable<int> contentIds) async {
    final ids = contentIds.toList();
    if (ids.isEmpty) return;
    await db.customStatement(
      'UPDATE date_corrections SET superseded_at = ? WHERE superseded_at IS NULL AND content_id IN (${ids.join(',')})',
      [nowMs()],
    );
    await _afterChange(ids);
  }

  Future<void> _afterChange([List<int>? ids]) async {
    await effective.recompute(contentIds: ids);
    await moments.recompute();
  }

  static Variable<Object> _v(String? s) => s == null ? const Variable(null) : Variable.withString(s);
  static Variable<Object> _vi(int? i) => i == null ? const Variable(null) : Variable.withInt(i);
}
