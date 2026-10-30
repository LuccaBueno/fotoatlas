import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import '../safe_io/dest_writer.dart' show ensureDirectory;
import '../safe_io/empty_dir.dart';
import '../safe_io/move_no_replace.dart';
import '../safe_io/source_reader.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import '../util/crashpoint.dart';
import '../util/uuid.dart';
import 'copy_models.dart';
import 'journal.dart';
import 'names.dart';
import 'reorg_models.dart';
import 'reorg_planner.dart';

/// Reorganização dentro do mesmo disco, com diário, recuperação e Desfazer
/// (spec §12, ADR 0017).
///
/// Cada arquivo: confere no disco que ainda é o do catálogo (tamanho e data) →
/// grava o nome final no diário → `MoveFileExW` **sem substituir e sem
/// copiar** (entre discos o Windows recusa) → atualiza o catálogo e o diário
/// na mesma transação. Nada é apagado: pastas que ficam vazias continuam lá
/// até a pessoa pedir "Remover pastas vazias" (pasta por pasta, conferida).
class ReorgService {
  ReorgService(this.db, this.sources) : planner = ReorgPlanner(db, sources) {
    journal = OperationJournal(db, onChange: _emitProgress);
  }

  final CatalogDatabase db;
  final SourcesService sources;
  final ReorgPlanner planner;
  late final OperationJournal journal;

  final _progress = StreamController<CopyProgress>.broadcast();
  final _queue = <String>[];
  Future<void>? _draining;
  String? _runningOp;
  final _pauseRequested = <String>{};
  final _cancelRequested = <String>{};
  bool _disposed = false;

  Stream<CopyProgress> get progress => _progress.stream;
  bool get isRunning => _runningOp != null;
  String? get runningOperation => _runningOp;

  // --- Prévia e confirmação -------------------------------------------------

  Future<ReorgPreview> preview(ReorgRequest request) => planner.plan(request);

  /// Confirma a prévia: grava a operação e os itens no diário (uma transação)
  /// e põe na fila. Devolve o id da operação.
  Future<String> start(ReorgPreview preview) async {
    if (!preview.canStart) throw StateError(preview.blocker ?? 'A prévia não tem nada para mover.');
    final r = preview.request;
    final id = uuidV4();
    final now = nowMs();
    await db.transaction(() async {
      await db.customInsert(
        'INSERT INTO operations (id, kind, status, dest_source_id, dest_root_rel, template, conflict_policy, '
        'params_json, created_at, confirmed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(id),
          Variable.withString(OpKind.reorganize),
          Variable.withString(OpStatus.confirmed),
          Variable.withString(r.sourceId),
          Variable.withString(r.destFolder == null ? cleanFolder(r.folder) : cleanFolder(r.destFolder!)),
          Variable.withString(r.template),
          Variable.withString(r.conflict.name),
          Variable.withString(
            jsonEncode({
              'folder': cleanFolder(r.folder),
              'toConfirmFolder': r.toConfirmFolder,
              'sidecars': r.sidecars,
              'alreadyInPlace': preview.alreadyInPlace,
              'otherFiles': preview.otherFiles,
              'notReady': preview.notReady,
            }),
          ),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
        updates: {db.operations},
      );
      var seq = 0;
      for (final m in preview.moves) {
        seq++;
        await db.customInsert(
          'INSERT INTO operation_items (operation_id, seq, src_source_id, src_rel_path, src_instance_id, '
          'expected_size, expected_mtime, dst_source_id, dst_rel_path_planned, original_name, state, '
          'last_error_code, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(id),
            Variable.withInt(seq),
            Variable.withString(r.sourceId),
            Variable.withString(m.srcRelPath),
            Variable.withInt(m.instanceId),
            Variable.withInt(m.size),
            Variable(m.mtime),
            Variable.withString(r.sourceId),
            Variable.withString(m.dstRelPath),
            Variable(m.originalName),
            Variable.withString(ItemState.pending),
            Variable(m.askConflict ? 'name_conflict_planned' : null),
            Variable.withInt(now),
          ],
          updates: {db.operationItems},
        );
      }
      await journal.event(
        id,
        null,
        null,
        OpStatus.confirmed,
        'Reorganização confirmada: ${preview.moves.length} arquivo(s).',
      );
    });
    _enqueue(id);
    return id;
  }

  // --- Desfazer ---------------------------------------------------------------

  /// O que o Desfazer faria agora (só lê o disco).
  Future<UndoPreview> undoPreview(String reorgId) async {
    final op = await journal.op(reorgId);
    if (op == null || op.kind != OpKind.reorganize) {
      return UndoPreview(
        reorgId: reorgId,
        ready: 0,
        changed: const [],
        missing: const [],
        occupied: const [],
        blocker: 'Reorganização não encontrada.',
      );
    }
    if (_runningOp == reorgId) {
      return UndoPreview(
        reorgId: reorgId,
        ready: 0,
        changed: const [],
        missing: const [],
        occupied: const [],
        blocker: 'Pause a reorganização antes de desfazer.',
      );
    }
    final source = await sources.byId(op.destSourceId!);
    final root = source == null ? null : sources.accessRoot(source);
    if (root == null) {
      return UndoPreview(
        reorgId: reorgId,
        ready: 0,
        changed: const [],
        missing: const [],
        occupied: const [],
        blocker: '"${source?.name ?? '?'}" está desconectado. Conecte o disco para desfazer.',
      );
    }
    final items = await journal.itemsIn(reorgId, {ItemState.published});
    var ready = 0;
    final changed = <String>[], missing = <String>[], occupied = <String>[];
    for (final i in items) {
      final now = _attributes(joinNative(root, i.dstRelPathFinal!));
      if (now == null) {
        missing.add(i.dstRelPathFinal!);
      } else if (!_same(now, i.expectedSize, i.expectedMtime)) {
        changed.add(i.dstRelPathFinal!);
      } else if (_attributes(joinNative(root, i.srcRelPath)) != null) {
        occupied.add(i.srcRelPath);
      } else {
        ready++;
      }
    }
    return UndoPreview(reorgId: reorgId, ready: ready, changed: changed, missing: missing, occupied: occupied);
  }

  /// Desfaz a reorganização: uma operação nova no diário que devolve cada
  /// arquivo ao caminho exato de antes, sem sobrescrever. Funciona depois de
  /// fechar e abrir o app (tudo vem do diário). Arquivo que mudou desde a
  /// reorganização, ou lugar antigo ocupado, espera a decisão da pessoa.
  Future<String> undo(String reorgId) async {
    final op = await journal.op(reorgId);
    if (op == null || op.kind != OpKind.reorganize) throw StateError('Reorganização não encontrada.');
    if (_runningOp == reorgId) await pause(reorgId);
    final open = await (db.select(
      db.operations,
    )..where((o) => o.undoOf.equals(reorgId) & o.status.isIn(OpStatus.open))).getSingleOrNull();
    if (open != null) {
      await resume(open.id);
      return open.id;
    }
    // O que ainda não foi movido não é mais movido.
    if (OpStatus.open.contains((await journal.op(reorgId))!.status)) {
      _queue.remove(reorgId);
      await journal.setStatus(reorgId, OpStatus.cancelled, finished: true);
      await journal.event(reorgId, null, op.status, OpStatus.cancelled, 'Cancelada para desfazer.');
    }
    final items = await journal.itemsIn(reorgId, {ItemState.published}, descending: true);
    if (items.isEmpty) throw StateError('Nada para desfazer: nenhum arquivo foi movido (ou já voltou).');
    final id = uuidV4();
    final now = nowMs();
    await db.transaction(() async {
      await db.customInsert(
        'INSERT INTO operations (id, kind, status, dest_source_id, dest_root_rel, conflict_policy, params_json, '
        'undo_of, created_at, confirmed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(id),
          Variable.withString(OpKind.undo),
          Variable.withString(OpStatus.confirmed),
          Variable(op.destSourceId),
          Variable(op.destRootRel),
          Variable.withString(ConflictPolicy.ask.name),
          Variable.withString(jsonEncode({'folder': JournalParams.folder(op)})),
          Variable.withString(reorgId),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
        updates: {db.operations},
      );
      var seq = 0;
      for (final i in items) {
        seq++;
        await db.customInsert(
          'INSERT INTO operation_items (operation_id, seq, src_source_id, src_rel_path, src_instance_id, '
          'expected_size, expected_mtime, dst_source_id, dst_rel_path_planned, state, undo_of_item_id, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(id),
            Variable.withInt(seq),
            Variable.withString(i.dstSourceId),
            Variable.withString(i.dstRelPathFinal!),
            Variable(i.srcInstanceId),
            Variable.withInt(i.expectedSize),
            Variable(i.expectedMtime),
            Variable.withString(i.srcSourceId),
            Variable.withString(i.srcRelPath),
            Variable.withString(ItemState.pending),
            Variable.withInt(i.id),
            Variable.withInt(now),
          ],
          updates: {db.operationItems},
        );
      }
      await journal.event(id, null, null, OpStatus.confirmed, 'Desfazer confirmado: ${items.length} arquivo(s).');
    });
    _enqueue(id);
    return id;
  }

  // --- Controle -----------------------------------------------------------------

  Future<void> resume(String operationId) async {
    final op = await journal.op(operationId);
    if (op == null || !OpStatus.open.contains(op.status)) return;
    _pauseRequested.remove(operationId);
    _enqueue(operationId);
  }

  Future<void> pause(String operationId) async {
    if (_runningOp == operationId) {
      _pauseRequested.add(operationId);
      await _draining;
      return;
    }
    _queue.remove(operationId);
    final op = await journal.op(operationId);
    if (op != null && (op.status == OpStatus.confirmed || op.status == OpStatus.running)) {
      await journal.setStatus(operationId, OpStatus.paused);
    }
  }

  /// Cancela o que ainda não foi movido. O que já foi movido fica (use Desfazer).
  Future<void> cancel(String operationId) async {
    if (_runningOp == operationId) {
      _cancelRequested.add(operationId);
      await _draining;
      return;
    }
    _queue.remove(operationId);
    final op = await journal.op(operationId);
    if (op != null && OpStatus.open.contains(op.status)) {
      await journal.setStatus(operationId, OpStatus.cancelled, finished: true);
      await journal.event(operationId, null, op.status, OpStatus.cancelled, 'Cancelada; o que já foi movido fica.');
      await _emitProgress(operationId, running: false);
    }
  }

  Future<int> retryFailed(String operationId) async {
    var n = 0;
    for (final i in await journal.itemsIn(operationId, {ItemState.failed})) {
      if (await journal.transition(
        operationId,
        i.id,
        ItemState.failed,
        ItemState.pending,
        set: {'last_error_code': null, 'last_error_message': null},
        message: 'Tentar de novo (pedido do usuário).',
      )) {
        n++;
      }
    }
    if (n > 0) {
      await journal.setStatus(operationId, OpStatus.paused);
      _enqueue(operationId);
    }
    return n;
  }

  /// Decide um arquivo que espera a pessoa.
  Future<void> resolve(int itemId, ReorgDecision decision) async {
    final item = await journal.item(itemId);
    if (item == null || item.state != ItemState.needsAttention) return;
    final code = item.lastErrorCode;
    final (allowed, nextCode, message) = switch (decision) {
      ReorgDecision.moveAnyway => (
        code == 'changed_since_reorg',
        'move_back_anyway',
        'Devolver mesmo assim (decisão do usuário).',
      ),
      ReorgDecision.rename => (
        code == 'name_conflict',
        'rename_on_conflict',
        'Mover com outro nome (decisão do usuário).',
      ),
      ReorgDecision.retry => (code == 'recovery_unknown', null, 'Conferir de novo (pedido do usuário).'),
      ReorgDecision.leave => (true, 'left_by_user', 'Deixado onde está (decisão do usuário).'),
    };
    if (!allowed) return;
    if (decision == ReorgDecision.leave) {
      await journal.transition(
        item.operationId,
        itemId,
        ItemState.needsAttention,
        ItemState.skippedIdentical,
        set: {'last_error_code': nextCode, 'last_error_message': 'Deixado onde está (decisão do usuário).'},
        message: message,
      );
      await journal.finishIfDone(item.operationId);
      await _emitProgress(item.operationId, running: false);
      return;
    }
    await journal.transition(
      item.operationId,
      itemId,
      ItemState.needsAttention,
      ItemState.pending,
      set: {'last_error_code': nextCode, 'last_error_message': null, 'dst_rel_path_final': null},
      message: message,
    );
    final op = await journal.op(item.operationId);
    if (op != null && op.status != OpStatus.running) await journal.setStatus(item.operationId, OpStatus.paused);
    _enqueue(item.operationId);
  }

  // --- Execução ---------------------------------------------------------------

  void _enqueue(String id) {
    if (_disposed) return;
    if (!_queue.contains(id) && _runningOp != id) _queue.add(id);
    _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_disposed) {
      final id = _queue.removeAt(0);
      _runningOp = id;
      try {
        await _runOp(id);
      } finally {
        _runningOp = null;
        _pauseRequested.remove(id);
        _cancelRequested.remove(id);
      }
    }
  }

  Future<void> waitIdle() async {
    while (_draining != null) {
      await _draining;
    }
  }

  bool _stopping(String opId) => _disposed || _pauseRequested.contains(opId) || _cancelRequested.contains(opId);

  Future<void> _runOp(String opId) async {
    final op = await journal.op(opId);
    if (op == null || !OpStatus.open.contains(op.status)) return;
    final source = await sources.byId(op.destSourceId!);
    final root = source == null ? null : sources.accessRoot(source);
    if (source == null || root == null) {
      await _pauseOp(opId, '"${source?.name ?? '?'}" está desconectado. Conecte o disco e toque em Continuar.');
      return;
    }
    await journal.setStatus(opId, OpStatus.running, started: op.startedAt == null);
    await _recoverOperation(op, root, RecoveryReport());
    await _emitProgress(opId);
    while (true) {
      if (_stopping(opId)) return _afterStop(opId);
      final next = (await db
          .customSelect(
            'SELECT * FROM operation_items WHERE operation_id = ? AND state = ? ORDER BY seq LIMIT 1',
            variables: [Variable.withString(opId), Variable.withString(ItemState.pending)],
            readsFrom: {db.operationItems},
          )
          .map((r) => db.operationItems.map(r.data))
          .getSingleOrNull());
      if (next == null) break;
      final pauseReason = await _runItem(op, root, next);
      if (pauseReason != null) {
        await _pauseOp(opId, pauseReason);
        return;
      }
    }
    await journal.finishIfDone(opId);
    await _emitProgress(opId, running: false);
  }

  Future<void> _afterStop(String opId) async {
    if (_cancelRequested.contains(opId)) {
      await journal.setStatus(opId, OpStatus.cancelled, finished: true);
      await journal.event(opId, null, OpStatus.running, OpStatus.cancelled, 'Cancelada; o que já foi movido fica.');
      await _emitProgress(opId, running: false);
    } else {
      await _pauseOp(opId, _disposed ? 'Interrompida porque o FotoAtlas foi fechado. Toque em Continuar.' : null);
    }
  }

  /// Um arquivo, de `pending` até `published` (ou parado esperando a pessoa).
  /// Devolve o motivo para pausar a operação, ou `null` para seguir.
  Future<String?> _runItem(OperationRow op, String root, OperationItemRow item) async {
    final isUndo = op.kind == OpKind.undo;
    final src = joinNative(root, item.srcRelPath);
    final info = _attributes(src);
    if (info == null) {
      if (!directoryAccessible(root)) return _disconnected(op);
      await journal.transition(
        op.id,
        item.id,
        ItemState.pending,
        ItemState.failed,
        set: OperationJournal.err(
          'source_missing',
          isUndo
              ? 'Não está mais em "${_label(item.srcRelPath)}": foi movido ou apagado depois da reorganização. '
                    'Nada a devolver.'
              : 'Não está mais em "${_label(item.srcRelPath)}" (foi movido ou apagado depois do escaneamento).',
        ),
      );
      return null;
    }
    if (!_same(info, item.expectedSize, item.expectedMtime)) {
      if (!isUndo) {
        await journal.transition(
          op.id,
          item.id,
          ItemState.pending,
          ItemState.failed,
          set: OperationJournal.err(
            'source_changed',
            'O arquivo mudou desde o escaneamento (tamanho ou data diferente): não foi movido. Escaneie de novo.',
          ),
        );
        return null;
      }
      if (item.lastErrorCode != 'move_back_anyway') {
        await journal.transition(
          op.id,
          item.id,
          ItemState.pending,
          ItemState.needsAttention,
          set: OperationJournal.err(
            'changed_since_reorg',
            'Este arquivo mudou depois da reorganização (tamanho ou data diferente). Ele só volta para '
                '"${_label(item.dstRelPathPlanned)}" se você confirmar.',
          ),
        );
        return null;
      }
    }
    final renameAllowed =
        item.lastErrorCode == 'rename_on_conflict' || (!isUndo && op.conflictPolicy != ConflictPolicy.ask.name);
    var target = item.dstRelPathPlanned;
    if (await _occupied(op, root, target, item.srcInstanceId)) {
      if (!renameAllowed) {
        await journal.transition(
          op.id,
          item.id,
          ItemState.pending,
          ItemState.needsAttention,
          set: OperationJournal.err(
            'name_conflict',
            isUndo
                ? 'O lugar de antes ("${_label(target)}") já tem outro arquivo. Nada foi sobrescrito.'
                : 'Já existe outro arquivo com o nome "${target.split('/').last}" na pasta nova.',
          ),
        );
        return null;
      }
      target = await _nextFree(op, root, target, item.srcInstanceId);
    }
    // O nome final e a data conferida vão para o diário antes de mexer no disco.
    if (!await journal.transition(
      op.id,
      item.id,
      ItemState.pending,
      ItemState.publishing,
      set: {'dst_rel_path_final': target, 'expected_mtime': info.mtime, 'attempts': item.attempts + 1},
    )) {
      return null;
    }
    crashpoint('move.after_publishing_commit');
    return _move(op, root, (await journal.item(item.id))!, src, target);
  }

  Future<String?> _move(OperationRow op, String root, OperationItemRow item, String src, String target) async {
    for (var attempt = 0; attempt < 1000; attempt++) {
      final full = joinNative(root, target);
      try {
        final slash = target.lastIndexOf('/');
        if (slash > 0) ensureDirectory(joinNative(root, target.substring(0, slash)));
        moveNoReplace(src, full);
      } on Win32Exception catch (e) {
        if (e.code == errorAlreadyExists || e.code == errorFileExists) {
          // Alguém criou o nome entre a checagem e o move.
          final renameAllowed =
              item.lastErrorCode == 'rename_on_conflict' ||
              (op.kind != OpKind.undo && op.conflictPolicy != ConflictPolicy.ask.name);
          if (!renameAllowed) {
            await journal.transition(
              op.id,
              item.id,
              ItemState.publishing,
              ItemState.needsAttention,
              set: {
                'dst_rel_path_final': null,
                ...OperationJournal.err(
                  'name_conflict',
                  'O nome "${target.split('/').last}" ficou ocupado. Nada foi sobrescrito.',
                ),
              },
            );
            return null;
          }
          final next = await _nextFree(op, root, target, item.srcInstanceId);
          await journal.transition(
            op.id,
            item.id,
            ItemState.publishing,
            ItemState.publishing,
            set: {'dst_rel_path_final': next},
            message: 'Nome "$target" ocupado; usando "$next".',
          );
          target = next;
          continue;
        }
        if (!directoryAccessible(root)) {
          await journal.transition(
            op.id,
            item.id,
            ItemState.publishing,
            ItemState.pending,
            set: {'dst_rel_path_final': null},
          );
          return _disconnected(op);
        }
        final (code, message) = switch (e.code) {
          errorNotSameDevice => (
            'not_same_disk',
            'O destino fica em outro disco: a reorganização só move dentro do mesmo disco.',
          ),
          errorSharingViolation || errorLockViolation || errorAccessDenied => (
            'in_use',
            'O arquivo está aberto em outro programa (ou sem permissão). Feche o programa e toque em "Tentar de novo".',
          ),
          errorFileNotFound || errorPathNotFound => ('source_missing', 'O arquivo sumiu antes de ser movido.'),
          _ => ('move_error', 'Não foi possível mover (erro ${e.code}).'),
        };
        await journal.transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.failed,
          set: {'dst_rel_path_final': null, ...OperationJournal.err(code, message)},
        );
        return null;
      }
      crashpoint('move.after_move');
      await _commitMoved(op, item, target, message: null);
      crashpoint('move.after_published_commit');
      return null;
    }
    return 'Não foi encontrado um nome livre.';
  }

  /// Movido: diário, catálogo e (no Desfazer) o item original, numa transação.
  Future<bool> _commitMoved(OperationRow op, OperationItemRow item, String target, {String? message}) =>
      journal.transition(
        op.id,
        item.id,
        ItemState.publishing,
        ItemState.published,
        message: message,
        also: () async {
          final instance = item.srcInstanceId;
          if (instance != null) {
            final slash = target.lastIndexOf('/');
            // OR IGNORE: se o catálogo já tiver outra linha nesse caminho (um
            // escaneamento no meio), o próximo escaneamento acerta; nada se perde.
            await db.customUpdate(
              'UPDATE OR IGNORE file_instances SET rel_path = ?, dir_rel_path = ?, name = ? WHERE id = ?',
              variables: [
                Variable.withString(target),
                Variable.withString(slash < 0 ? '' : target.substring(0, slash)),
                Variable.withString(slash < 0 ? target : target.substring(slash + 1)),
                Variable.withInt(instance),
              ],
              updates: {db.fileInstances},
            );
          }
          final original = item.undoOfItemId;
          if (original != null) {
            final n = await db.customUpdate(
              "UPDATE operation_items SET state = 'undone', updated_at = ? WHERE id = ? AND state = 'published'",
              variables: [Variable.withInt(nowMs()), Variable.withInt(original)],
              updates: {db.operationItems},
            );
            if (n == 1) {
              await journal.event(op.undoOf!, original, ItemState.published, undoneState, 'Devolvido pelo Desfazer.');
            }
          }
        },
      );

  // --- Recuperação ------------------------------------------------------------

  /// Recuperação na inicialização (idempotente): decide olhando o disco.
  Future<RecoveryReport> recoverAll() async {
    final report = RecoveryReport();
    final ops = await (db.select(
      db.operations,
    )..where((o) => o.status.isIn(OpStatus.open) & o.kind.isIn([OpKind.reorganize, OpKind.undo]))).get();
    for (final op in ops) {
      if (op.status == OpStatus.running || op.status == OpStatus.confirmed) {
        await _pauseOp(
          op.id,
          'Interrompida (o FotoAtlas foi fechado ou o computador desligou). Nada se perdeu: toque em Continuar.',
        );
      }
      final source = await sources.byId(op.destSourceId!);
      final root = source == null ? null : sources.accessRoot(source);
      if (root == null) {
        report.skippedDestUnavailable += (await journal.itemsIn(op.id, {ItemState.publishing})).length;
        continue;
      }
      await _recoverOperation(op, root, report);
      crashpoint('move.recover.after_operation');
      await journal.finishIfDone(op.id);
    }
    return report;
  }

  /// O nome final foi gravado antes do move: o disco diz se ele aconteceu.
  Future<void> _recoverOperation(OperationRow op, String root, RecoveryReport report) async {
    for (final item in await journal.itemsIn(op.id, {ItemState.publishing})) {
      report.examined++;
      final target = item.dstRelPathFinal!;
      final srcInfo = _attributes(joinNative(root, item.srcRelPath));
      final dstInfo = _attributes(joinNative(root, target));
      final srcIsOurs = srcInfo != null && _same(srcInfo, item.expectedSize, item.expectedMtime);
      final dstIsOurs = dstInfo != null && _same(dstInfo, item.expectedSize, item.expectedMtime);
      if (srcIsOurs && !dstIsOurs) {
        // Ainda não foi movido: volta para a fila (o nome é escolhido de novo).
        await journal.transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.pending,
          set: {'dst_rel_path_final': null},
          message: 'Recuperação: o arquivo ainda não tinha sido movido.',
        );
        report.resumedAsPending++;
      } else if (dstIsOurs && !srcIsOurs) {
        await _commitMoved(op, item, target, message: 'Recuperação: arquivo já movido; registrado.');
        report.published++;
      } else {
        await journal.transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.needsAttention,
          set: OperationJournal.err(
            'recovery_unknown',
            'Não foi possível confirmar onde este arquivo está. Confira "${_label(item.srcRelPath)}" e '
                '"${_label(target)}".',
          ),
        );
        report.needsAttention++;
      }
    }
  }

  // --- Pastas vazias ----------------------------------------------------------

  /// Pastas que esta operação deixou vazias (de onde os arquivos saíram, ou,
  /// depois do Desfazer, as que ela criou). Só lê. As com arquivos ocultos ou
  /// de sistema aparecem com `empty: false` (não são removidas).
  Future<List<EmptyFolder>> emptyFolders(String opId) async {
    final op = await journal.op(opId);
    if (op == null || op.kind == OpKind.copy) return const [];
    final source = await sources.byId(op.destSourceId!);
    final root = source == null ? null : sources.accessRoot(source);
    if (root == null) return const [];
    final candidates = await _candidateFolders(op);
    final out = <EmptyFolder>[];
    final seen = <String>{};
    void add(String rel) {
      if (!seen.add(rel.toLowerCase())) return;
      final full = joinNative(root, rel);
      switch (folderEmptiness(full)) {
        case FolderEmptiness.empty:
          out.add(EmptyFolder(rel, empty: true));
          // Subpastas vazias dentro dela também entram na lista (cada uma aparece).
          for (final e in listDirectory(full)) {
            if (e.isDirectory) add('$rel/${e.name}');
          }
        case FolderEmptiness.hasFiles:
          if (onlyHiddenFiles(full)) out.add(EmptyFolder(rel, empty: false));
        case FolderEmptiness.unavailable:
          break;
      }
    }

    candidates.forEach(add);
    out.sort((a, b) => a.relPath.toLowerCase().compareTo(b.relPath.toLowerCase()));
    return out;
  }

  /// Remove, com confirmação dada na tela, só as pastas listadas que **ainda**
  /// estão vazias (conferidas de novo, uma a uma, da mais funda para a mais
  /// rasa). Cada remoção fica no diário da operação. Devolve quantas saíram.
  Future<int> removeEmptyFolders(String opId, List<String> relPaths) async {
    final op = await journal.op(opId);
    if (op == null) return 0;
    final source = await sources.byId(op.destSourceId!);
    final root = source == null ? null : sources.accessRoot(source);
    if (root == null) return 0;
    final allowed = {
      for (final f in await emptyFolders(opId))
        if (f.empty) f.relPath.toLowerCase(),
    };
    final chosen = relPaths.where((r) => allowed.contains(r.toLowerCase())).toList()
      ..sort((a, b) => '/'.allMatches(b).length.compareTo('/'.allMatches(a).length));
    var removed = 0;
    for (final rel in chosen) {
      await journal.event(opId, null, null, null, 'Removendo pasta vazia "$rel" (pedido do usuário).');
      if (removeEmptyFolder(joinNative(root, rel))) {
        removed++;
        await journal.event(opId, null, null, null, 'Pasta vazia removida: "$rel".');
      } else {
        await journal.event(opId, null, null, null, 'Pasta "$rel" não foi removida (não estava mais vazia).');
      }
    }
    return removed;
  }

  Future<List<String>> _candidateFolders(OperationRow op) async {
    final rows = await (db.select(db.operationItems)..where((i) => i.operationId.equals(op.id))).get();
    final dirs = <String>{};
    void addDirs(String? rel) {
      if (rel == null) return;
      var i = rel.lastIndexOf('/');
      while (i > 0) {
        rel = rel!.substring(0, i);
        dirs.add(rel);
        i = rel.lastIndexOf('/');
      }
    }

    for (final r in rows) {
      if (r.state != ItemState.published && r.state != undoneState) continue;
      addDirs(r.srcRelPath);
      addDirs(r.dstRelPathFinal);
    }
    return dirs.toList()..sort();
  }

  // --- Auxiliares ---------------------------------------------------------------

  Future<String> _disconnected(OperationRow op) async {
    final source = await sources.byId(op.destSourceId!);
    return '"${source?.name ?? '?'}" foi desconectado. Nada se perdeu: conecte o disco e toque em Continuar.';
  }

  Future<void> _pauseOp(String opId, String? reason) async {
    await journal.pause(opId, reason);
    await _emitProgress(opId, running: false);
  }

  /// Ocupado no disco ou no catálogo (por outro arquivo).
  Future<bool> _occupied(OperationRow op, String root, String rel, int? instanceId) async {
    try {
      attributesOf(joinNative(root, rel));
      return true; // arquivo ou pasta com esse nome
    } on Win32Exception {
      // livre no disco; confere o catálogo
    }
    final row = await db
        .customSelect(
          'SELECT id FROM file_instances WHERE source_id = ? AND rel_path = ? AND id IS NOT ? LIMIT 1',
          variables: [Variable(op.destSourceId), Variable.withString(rel), Variable(instanceId)],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<String> _nextFree(OperationRow op, String root, String rel, int? instanceId) async {
    final slash = rel.lastIndexOf('/');
    final dir = slash < 0 ? '' : '${rel.substring(0, slash)}/';
    final name = slash < 0 ? rel : rel.substring(slash + 1);
    for (var n = 1; ; n++) {
      final candidate = '$dir${withSuffix(name, n)}';
      if (!await _occupied(op, root, candidate, instanceId)) return candidate;
    }
  }

  static bool _same(SourceFileInfo info, int size, int? mtime) =>
      info.size == size && (mtime == null || info.mtime == mtime);

  static SourceFileInfo? _attributes(String path) {
    try {
      final info = attributesOf(path);
      return info.attributes & fileAttributeDirectory != 0 ? null : info;
    } on Win32Exception {
      return null;
    }
  }

  static String _label(String rel) => rel.replaceAll('/', ' › ');

  Future<void> _emitProgress(String opId, {bool running = true}) async {
    if (_progress.isClosed) return;
    final rows = await db
        .customSelect(
          'SELECT state, COUNT(*) AS n, SUM(expected_size) AS b FROM operation_items WHERE operation_id = ? GROUP BY state',
          variables: [Variable.withString(opId)],
        )
        .get();
    var done = 0, total = 0, doneBytes = 0, totalBytes = 0;
    for (final r in rows) {
      final n = r.read<int>('n'), b = r.readNullable<int>('b') ?? 0;
      total += n;
      totalBytes += b;
      if (ItemState.finals.contains(r.read<String>('state'))) {
        done += n;
        doneBytes += b;
      }
    }
    if (_progress.isClosed) return;
    _progress.add(
      CopyProgress(
        operationId: opId,
        itemsDone: done,
        itemsTotal: total,
        bytesDone: doneBytes,
        bytesTotal: totalBytes,
        step: 'moving',
        running: running && _runningOp == opId,
      ),
    );
  }

  /// Para depois do arquivo do momento (mover é rápido) e espera até [timeout].
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposed = true;
    _queue.clear();
    final d = _draining;
    var ok = true;
    if (d != null) ok = await d.then((_) => true).timeout(timeout, onTimeout: () => false);
    await _progress.close();
    return ok;
  }
}

/// Leitura dos parâmetros gravados na operação.
abstract final class JournalParams {
  static String folder(OperationRow op) => (OperationJournal.paramsOf(op)['folder'] as String?) ?? '';
}
