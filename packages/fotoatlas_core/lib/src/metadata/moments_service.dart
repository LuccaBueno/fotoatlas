import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../settings/settings_store.dart';
import '../util/clock.dart';
import 'capture_date.dart';

/// Um momento (spec §8.3): fotos e vídeos próximos no tempo, de todos os
/// dispositivos. Só existe no catálogo.
class MomentView {
  const MomentView({
    required this.id,
    required this.edited,
    required this.name,
    required this.startUtcMs,
    required this.endUtcMs,
    required this.itemCount,
    this.startLocal,
    this.endLocal,
  });

  final int id;

  /// Nomeado, juntado ou separado: fica fixo nos recálculos.
  final bool edited;
  final String? name;
  final int startUtcMs;
  final int endUtcMs;
  final int itemCount;

  /// Hora local do primeiro e do último item.
  final WallTime? startLocal;
  final WallTime? endLocal;
}

/// O que um recálculo mudou (para mostrar ao usuário).
class MomentsRecalc {
  const MomentsRecalc({this.created = 0, this.removed = 0, this.changed = 0, this.itemsMoved = 0});
  final int created;
  final int removed;

  /// Momentos automáticos que ganharam ou perderam itens.
  final int changed;
  final int itemsMoved;

  bool get isEmpty => created == 0 && removed == 0 && changed == 0 && itemsMoved == 0;
}

/// Agrupamento puro (também usado na prévia da correção de relógio).
///
/// [items]: (id, instante) já em ordem de instante. [edited]: intervalos
/// fixos (id, início, fim), sem sobreposição. Itens dentro de um intervalo
/// editado ficam nele; o resto vira grupos automáticos separados por
/// intervalos sem fotos maiores que [gapMs] (e pelos intervalos editados).
/// Devolve, para cada item, a chave do grupo: `e:<id>` (editado) ou `a:<n>`.
List<String> groupMoments(List<(int, int)> items, List<(int, int, int)> edited, int gapMs) {
  final keys = List<String>.filled(items.length, '');
  var e = 0;
  var auto = -1;
  int? lastAutoTime;
  for (var i = 0; i < items.length; i++) {
    final t = items[i].$2;
    while (e < edited.length && edited[e].$3 < t) {
      e++;
      lastAutoTime = null; // um momento editado no meio separa os automáticos
    }
    if (e < edited.length && edited[e].$2 <= t && t <= edited[e].$3) {
      keys[i] = 'e:${edited[e].$1}';
      lastAutoTime = null;
      continue;
    }
    if (lastAutoTime == null || t - lastAutoTime > gapMs) auto++;
    keys[i] = 'a:$auto';
    lastAutoTime = t;
  }
  return keys;
}

/// Momentos automáticos e edições do usuário. Só mexe no catálogo.
class MomentsService {
  MomentsService(this.db) : settings = SettingsStore(db);

  final CatalogDatabase db;
  final SettingsStore settings;
  static const gapKey = 'moments.gapMinutes';
  static const defaultGap = Duration(hours: 2);

  Duration gap = defaultGap;
  Future<void> _queue = Future.value();

  Future<void> init() async {
    final g = await settings.get(gapKey);
    if (g is int && g > 0) gap = Duration(minutes: g);
  }

  /// Muda o intervalo e recalcula (os momentos editados não mudam).
  Future<MomentsRecalc> setGap(Duration value) async {
    if (value.inMinutes < 1) throw ArgumentError('O intervalo precisa ser de pelo menos 1 minuto.');
    gap = value;
    await settings.set(gapKey, value.inMinutes);
    return recompute();
  }

  /// Uma operação por vez (recálculo e edições não se cruzam).
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _queue.then((_) => body());
    _queue = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  /// Itens que entram em momentos: com data e confiança alta ou média (ou
  /// corrigida/confirmada). Hora incerta fica em "Hora a confirmar".
  static const eligibleSql =
      "eff_utc_ms IS NOT NULL AND (eff_confidence IN ('high','medium') OR eff_source = 'manual')";

  Future<MomentsRecalc> recompute() => _serial(_recompute);

  Future<MomentsRecalc> _recompute() async {
    final rows = await db
        .customSelect(
          'SELECT content_id, eff_utc_ms, moment_id FROM media_metadata WHERE $eligibleSql '
          'ORDER BY eff_utc_ms, content_id',
        )
        .get();
    final items = [for (final r in rows) (r.read<int>('content_id'), r.read<int>('eff_utc_ms'))];
    final oldMoment = [for (final r in rows) r.readNullable<int>('moment_id')];
    final moments = await db.customSelect('SELECT id, kind, start_utc_ms, end_utc_ms, item_count FROM moments').get();
    final kindOf = {for (final m in moments) m.read<int>('id'): m.read<String>('kind')};
    final edited = [
      for (final m in moments)
        if (m.read<String>('kind') == 'edited')
          (m.read<int>('id'), m.read<int>('start_utc_ms'), m.read<int>('end_utc_ms')),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final keys = groupMoments(items, edited, gap.inMilliseconds);

    // Grupos automáticos: reaproveita o ID do momento automático antigo com
    // mais itens em comum (filtros e escopos salvos continuam valendo).
    final groups = <String, List<int>>{};
    for (var i = 0; i < keys.length; i++) {
      (groups[keys[i]] ??= []).add(i);
    }
    final reused = <int>{};
    final idOf = <String, int?>{};
    final autoKeys = groups.keys.where((k) => k.startsWith('a:')).toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));
    for (final k in autoKeys) {
      final votes = <int, int>{};
      for (final i in groups[k]!) {
        final m = oldMoment[i];
        if (m != null && kindOf[m] == 'auto' && !reused.contains(m)) votes[m] = (votes[m] ?? 0) + 1;
      }
      int? best;
      for (final v in votes.entries) {
        if (best == null || v.value > votes[best]!) best = v.key;
      }
      if (best != null) reused.add(best);
      idOf[k] = best;
    }

    var created = 0, changed = 0, moved = 0;
    final now = nowMs();
    final old = {
      for (final m in moments)
        m.read<int>('id'): (m.read<int>('start_utc_ms'), m.read<int>('end_utc_ms'), m.read<int>('item_count')),
    };
    final stale = [
      for (final e in kindOf.entries)
        if (e.value == 'auto' && !reused.contains(e.key)) e.key,
    ];
    await db.transaction(() async {
      // IDs novos sem ida e volta por momento: tudo em lote (100 mil itens em poucos segundos).
      var nextId =
          (await db.customSelect('SELECT COALESCE(MAX(id), 0) AS m FROM moments').getSingle()).read<int>('m') + 1;
      await db.batch((b) {
        for (final k in autoKeys) {
          final members = groups[k]!;
          final start = items[members.first].$2;
          final end = items[members.last].$2;
          final id = idOf[k];
          if (id == null) {
            idOf[k] = nextId;
            b.customStatement(
              "INSERT INTO moments (id, kind, start_utc_ms, end_utc_ms, item_count, created_at, updated_at) "
              "VALUES (?, 'auto', ?, ?, ?, ?, ?)",
              [nextId++, start, end, members.length, now, now],
            );
            created++;
          } else if (old[id] != (start, end, members.length)) {
            b.customStatement(
              'UPDATE moments SET start_utc_ms = ?, end_utc_ms = ?, item_count = ?, updated_at = ? WHERE id = ?',
              [start, end, members.length, now, id],
            );
            changed++;
          }
        }
        for (final (id, _, _) in edited) {
          final n = groups['e:$id']?.length ?? 0;
          if (old[id]?.$3 != n) b.customStatement('UPDATE moments SET item_count = ? WHERE id = ?', [n, id]);
        }
        // Membros: só grava o que mudou.
        for (var i = 0; i < items.length; i++) {
          final k = keys[i];
          final target = k.startsWith('e:') ? int.parse(k.substring(2)) : idOf[k]!;
          if (oldMoment[i] != target) {
            b.customStatement('UPDATE media_metadata SET moment_id = ? WHERE content_id = ?', [target, items[i].$1]);
            if (oldMoment[i] != null) moved++;
          }
        }
      });
      if (stale.isNotEmpty) await db.customStatement('DELETE FROM moments WHERE id IN (${stale.join(',')})');
      // Quem saiu dos momentos (ex.: virou hora incerta).
      await db.customStatement(
        'UPDATE media_metadata SET moment_id = NULL WHERE moment_id IS NOT NULL AND NOT ($eligibleSql)',
      );
    });
    final removed = stale.length;
    db.notifyUpdates({
      TableUpdate.onTable(db.moments, kind: UpdateKind.update),
      TableUpdate.onTable(db.mediaMetadata, kind: UpdateKind.update),
    });
    return MomentsRecalc(created: created, removed: removed, changed: changed, itemsMoved: moved);
  }

  /// Momentos em ordem de tempo (opcional: só os que tocam um intervalo).
  Future<List<MomentView>> list({int? fromUtcMs, int? toUtcMs, bool includeEmpty = false}) async {
    final rows = await db
        .customSelect(
          '''
          SELECT m.id, m.kind, m.name, m.start_utc_ms, m.end_utc_ms, m.item_count,
            (SELECT eff_local FROM media_metadata WHERE moment_id = m.id ORDER BY eff_utc_ms LIMIT 1) AS first_local,
            (SELECT eff_local FROM media_metadata WHERE moment_id = m.id ORDER BY eff_utc_ms DESC LIMIT 1) AS last_local
          FROM moments m
          WHERE ${includeEmpty ? '1' : 'm.item_count > 0'}
            ${fromUtcMs == null ? '' : 'AND m.end_utc_ms >= $fromUtcMs'}
            ${toUtcMs == null ? '' : 'AND m.start_utc_ms <= $toUtcMs'}
          ORDER BY m.start_utc_ms
          ''',
          readsFrom: {db.moments, db.mediaMetadata},
        )
        .get();
    return [for (final r in rows) _view(r)];
  }

  Future<MomentView?> byId(int id) async {
    final all = await db
        .customSelect(
          '''
          SELECT m.id, m.kind, m.name, m.start_utc_ms, m.end_utc_ms, m.item_count,
            (SELECT eff_local FROM media_metadata WHERE moment_id = m.id ORDER BY eff_utc_ms LIMIT 1) AS first_local,
            (SELECT eff_local FROM media_metadata WHERE moment_id = m.id ORDER BY eff_utc_ms DESC LIMIT 1) AS last_local
          FROM moments m WHERE m.id = ?
          ''',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    return all == null ? null : _view(all);
  }

  static MomentView _view(QueryRow r) => MomentView(
    id: r.read<int>('id'),
    edited: r.read<String>('kind') == 'edited',
    name: r.readNullable<String>('name'),
    startUtcMs: r.read<int>('start_utc_ms'),
    endUtcMs: r.read<int>('end_utc_ms'),
    itemCount: r.read<int>('item_count'),
    startLocal: parseWall(r.readNullable<String>('first_local')),
    endLocal: parseWall(r.readNullable<String>('last_local')),
  );

  Future<void> _log(int? momentId, String action, Map<String, Object?> detail) => db.customStatement(
    'INSERT INTO moment_edits (moment_id, op, detail_json, created_at) VALUES (?, ?, ?, ?)',
    [momentId, action, jsonEncode(detail), nowMs()],
  );

  /// Nomeia (ou tira o nome, com `null`). O momento fica fixo.
  Future<void> rename(int id, String? name) => _serial(() async {
    final clean = name?.trim();
    final n = await db.customUpdate(
      "UPDATE moments SET name = ?, kind = 'edited', updated_at = ? WHERE id = ?",
      variables: [
        clean == null || clean.isEmpty ? const Variable(null) : Variable.withString(clean),
        Variable.withInt(nowMs()),
        Variable.withInt(id),
      ],
      updates: {db.moments},
    );
    if (n == 0) throw StateError('Momento $id não existe.');
    await _log(id, 'rename', {'name': clean});
  });

  /// Junta momentos vizinhos num só (fica com o ID e o nome do primeiro).
  Future<int> merge(List<int> ids) async {
    final result = await _serial(() async {
      if (ids.length < 2) throw ArgumentError('Escolha pelo menos dois momentos.');
      final rows = await db
          .customSelect(
            'SELECT id, name, start_utc_ms, end_utc_ms FROM moments WHERE id IN (${ids.join(',')}) ORDER BY start_utc_ms',
          )
          .get();
      if (rows.length != ids.toSet().length) throw StateError('Algum momento não existe mais.');
      final start = rows.first.read<int>('start_utc_ms');
      final end = rows.map((r) => r.read<int>('end_utc_ms')).reduce((a, b) => a > b ? a : b);
      final between = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM moments WHERE item_count > 0 AND id NOT IN (${ids.join(',')}) '
            'AND start_utc_ms <= ? AND end_utc_ms >= ?',
            variables: [Variable.withInt(end), Variable.withInt(start)],
          )
          .getSingle();
      if (between.read<int>('n') > 0) {
        throw StateError('Só dá para juntar momentos vizinhos (há outro momento no meio).');
      }
      final keep = rows.first.read<int>('id');
      final name = rows.map((r) => r.readNullable<String>('name')).nonNulls.firstOrNull;
      await db.transaction(() async {
        await db.customStatement(
          "UPDATE moments SET kind = 'edited', name = ?, start_utc_ms = ?, end_utc_ms = ?, updated_at = ? WHERE id = ?",
          [name, start, end, nowMs(), keep],
        );
        final others = [for (final r in rows.skip(1)) r.read<int>('id')];
        await db.customStatement('UPDATE media_metadata SET moment_id = ? WHERE moment_id IN (${others.join(',')})', [
          keep,
        ]);
        await db.customStatement('DELETE FROM moments WHERE id IN (${others.join(',')})');
        // Momentos editados vazios dentro do intervalo novo deixariam intervalos sobrepostos.
        await db.customStatement(
          'DELETE FROM moments WHERE item_count = 0 AND id != ? AND start_utc_ms >= ? AND end_utc_ms <= ?',
          [keep, start, end],
        );
        await _log(keep, 'merge', {'merged': others});
      });
      return keep;
    });
    await recompute();
    return result;
  }

  /// Separa [id] antes do item [atContentId]: ele e os seguintes viram um
  /// momento novo. Os dois ficam fixos. Devolve o ID do novo.
  Future<int> split(int id, int atContentId) async {
    final result = await _serial(() async {
      final m = await db
          .customSelect('SELECT start_utc_ms, end_utc_ms FROM moments WHERE id = ?', variables: [Variable.withInt(id)])
          .getSingleOrNull();
      if (m == null) throw StateError('Momento $id não existe.');
      final members = await db
          .customSelect(
            'SELECT content_id, eff_utc_ms FROM media_metadata WHERE moment_id = ? ORDER BY eff_utc_ms, content_id',
            variables: [Variable.withInt(id)],
          )
          .get();
      final at = members.indexWhere((r) => r.read<int>('content_id') == atContentId);
      if (at < 0) throw StateError('O item não está neste momento.');
      final t = members[at].read<int>('eff_utc_ms');
      final before = members.lastWhere((r) => r.read<int>('eff_utc_ms') < t, orElse: () => members[at]);
      final tBefore = before.read<int>('eff_utc_ms');
      if (tBefore >= t) throw StateError('Não dá para separar antes do primeiro item (ou no mesmo segundo).');
      final now = nowMs();
      return db.transaction(() async {
        await db.customStatement("UPDATE moments SET kind = 'edited', end_utc_ms = ?, updated_at = ? WHERE id = ?", [
          tBefore,
          now,
          id,
        ]);
        final newId = await db.customInsert(
          "INSERT INTO moments (kind, start_utc_ms, end_utc_ms, item_count, created_at, updated_at) "
          "VALUES ('edited', ?, ?, 0, ?, ?)",
          variables: [
            Variable.withInt(t),
            Variable.withInt(m.read<int>('end_utc_ms')),
            Variable.withInt(now),
            Variable.withInt(now),
          ],
        );
        await _log(id, 'split', {'new': newId, 'atContentId': atContentId});
        return newId;
      });
    });
    await recompute();
    return result;
  }

  /// Desfaz as edições de um momento: volta a ser automático no recálculo.
  Future<void> reset(int id) async {
    await _serial(() async {
      await db.customStatement("UPDATE moments SET kind = 'auto', name = NULL, updated_at = ? WHERE id = ?", [
        nowMs(),
        id,
      ]);
      await _log(id, 'reset', const {});
    });
    await recompute();
  }

  Future<void> waitIdle() => _queue;
}
