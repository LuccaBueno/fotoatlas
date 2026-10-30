import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../util/clock.dart';
import 'copy_models.dart';

/// Diário de operações (`operations` + `operation_items` + `operation_events`,
/// `docs/arquitetura.md` §3.6): cada transição de um item e o evento dela vão
/// na mesma transação, commitada **antes** do próximo efeito no disco.
class OperationJournal {
  OperationJournal(this.db, {this.onChange});

  final CatalogDatabase db;

  /// Chamado depois de cada transição (progresso na tela).
  final Future<void> Function(String opId)? onChange;

  /// Transição de estado + evento, na mesma transação, só se o item ainda
  /// estiver em [from] (protege contra duas execuções concorrentes). [also]
  /// roda dentro da mesma transação (ex.: atualizar o catálogo).
  Future<bool> transition(
    String opId,
    int itemId,
    String from,
    String to, {
    Map<String, Object?> set = const {},
    String? message,
    Future<void> Function()? also,
  }) async {
    final now = nowMs();
    final cols = set.keys.map((k) => ', $k = ?').join();
    final ok = await db.transaction(() async {
      final n = await db.customUpdate(
        'UPDATE operation_items SET state = ?, updated_at = ?$cols WHERE id = ? AND state = ?',
        variables: [
          Variable.withString(to),
          Variable.withInt(now),
          for (final v in set.values) Variable(v),
          Variable.withInt(itemId),
          Variable.withString(from),
        ],
        updates: {db.operationItems},
      );
      if (n != 1) return false;
      await event(opId, itemId, from, to, message ?? set['last_error_message'] as String?);
      if (also != null) await also();
      return true;
    });
    if (ok) await onChange?.call(opId);
    return ok;
  }

  Future<void> event(String opId, int? itemId, String? from, String? to, String? message) => db.customInsert(
    'INSERT INTO operation_events (operation_id, item_id, at, from_state, to_state, message) VALUES (?, ?, ?, ?, ?, ?)',
    variables: [
      Variable.withString(opId),
      Variable(itemId),
      Variable.withInt(nowMs()),
      Variable(from),
      Variable(to),
      Variable(message),
    ],
    updates: {db.operationEvents},
  );

  Future<void> setStatus(
    String opId,
    String status, {
    bool started = false,
    bool finished = false,
    Map<String, Object?>? summary,
  }) => db.customUpdate(
    'UPDATE operations SET status = ?${started ? ', started_at = ?' : ''}${finished ? ', finished_at = ?' : ''}'
    '${summary != null ? ', summary_json = ?' : ''} WHERE id = ?',
    variables: [
      Variable.withString(status),
      if (started) Variable.withInt(nowMs()),
      if (finished) Variable.withInt(nowMs()),
      if (summary != null) Variable.withString(jsonEncode(summary)),
      Variable.withString(opId),
    ],
    updates: {db.operations},
  );

  /// Pausa com motivo (não repete o evento se já está pausada pelo mesmo motivo).
  Future<void> pause(String opId, String? reason) async {
    final o = await op(opId);
    if (o == null || o.status == OpStatus.paused && summaryOf(o)['pausedReason'] == reason) return;
    await setStatus(opId, OpStatus.paused, summary: {'pausedReason': reason});
    await event(opId, null, o.status, OpStatus.paused, reason ?? 'Pausada.');
  }

  /// Fecha a operação quando nenhum item tem mais o que fazer.
  Future<bool> finishIfDone(String opId) async {
    final c = await counts(opId);
    final open = c.entries.where((e) => !ItemState.finals.contains(e.key)).fold(0, (s, e) => s + e.value);
    if (open > 0) return false;
    final status = (c[ItemState.needsAttention] ?? 0) > 0
        ? OpStatus.needsAttention
        : (c[ItemState.failed] ?? 0) > 0
        ? OpStatus.completedWithErrors
        : OpStatus.completed;
    // Já registrada assim: não repete (a recuperação roda a cada abertura).
    if ((await op(opId))?.status == status) return true;
    await setStatus(opId, status, finished: true, summary: c);
    await event(opId, null, OpStatus.running, status, 'Terminada.');
    return true;
  }

  Future<OperationRow?> op(String id) => (db.select(db.operations)..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<OperationItemRow?> item(int id) =>
      (db.select(db.operationItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<List<OperationItemRow>> itemsIn(String opId, Set<String> states, {bool descending = false}) => db
      .customSelect(
        'SELECT * FROM operation_items WHERE operation_id = ? AND state IN (${states.map((_) => '?').join(',')}) '
        'ORDER BY seq${descending ? ' DESC' : ''}',
        variables: [Variable.withString(opId), for (final s in states) Variable.withString(s)],
        readsFrom: {db.operationItems},
      )
      .map((r) => db.operationItems.map(r.data))
      .get();

  Future<Map<String, int>> counts(String opId) async {
    final rows = await db
        .customSelect(
          'SELECT state, COUNT(*) AS n FROM operation_items WHERE operation_id = ? GROUP BY state',
          variables: [Variable.withString(opId)],
        )
        .get();
    return {for (final r in rows) r.read<String>('state'): r.read<int>('n')};
  }

  static Map<String, Object?> summaryOf(OperationRow o) =>
      o.summaryJson == null ? const {} : (jsonDecode(o.summaryJson!) as Map).cast<String, Object?>();

  static Map<String, Object?> paramsOf(OperationRow o) =>
      o.paramsJson == null ? const {} : (jsonDecode(o.paramsJson!) as Map).cast<String, Object?>();

  static Map<String, Object?> err(String code, String message) => {
    'last_error_code': code,
    'last_error_message': message,
  };
}
