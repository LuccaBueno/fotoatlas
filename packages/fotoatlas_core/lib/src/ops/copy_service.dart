import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../devices/devices.dart';
import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import '../safe_io/dest_writer.dart';
import '../safe_io/move_no_replace.dart';
import '../safe_io/source_reader.dart';
import '../scan/entry_classifier.dart' show extensionOf;
import '../sources/media_types.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import '../util/crashpoint.dart';
import '../util/uuid.dart';
import 'copy_models.dart';
import 'copy_planner.dart';
import 'copy_pump.dart';
import 'names.dart';

/// Cópia segura com diário e recuperação (spec §11, `docs/arquitetura.md`
/// §3.6, ADR 0016).
///
/// Cada transição de estado de um item é `UPDATE operation_items` + `INSERT
/// operation_events` na mesma transação, commitada **antes** do próximo efeito
/// no disco. Nada é sobrescrito (`CREATE_NEW` no `.part` e `MoveFileExW` sem
/// substituição) e nada do usuário é apagado: o único arquivo que o FotoAtlas
/// apaga é o próprio `.part` ainda não publicado, registrado no diário.
class CopyService {
  CopyService(
    this.db,
    this.sources, {
    FreeSpaceProbe? freeSpace,
    this.useIsolate = true,
    int reserveBytes = defaultReserveBytes,
  }) : _freeSpace = freeSpace ?? diskFreeBytes,
       planner = CopyPlanner(db, sources, freeSpace: freeSpace, reserveBytes: reserveBytes),
       _reserve = reserveBytes;

  final CatalogDatabase db;
  final SourcesService sources;
  final CopyPlanner planner;
  final bool useIsolate;
  final FreeSpaceProbe _freeSpace;
  final int _reserve;

  final _progress = StreamController<CopyProgress>.broadcast();
  final _queue = <String>[];
  Future<void>? _draining;
  String? _runningOp;
  Completer<void>? _stop;
  final _pauseRequested = <String>{};
  final _cancelRequested = <String>{};
  CopyProgress? _current;
  final Map<String, PhonePathResolver> _resolvers = {};
  bool _disposed = false;

  /// Progresso da cópia em andamento.
  Stream<CopyProgress> get progress => _progress.stream;
  CopyProgress? get current => _current;
  bool get isRunning => _runningOp != null;
  String? get runningOperation => _runningOp;

  // --- Prévia e confirmação -------------------------------------------------

  /// Prévia (regra 6): só lê.
  Future<CopyPreview> preview(CopyRequest request) => planner.plan(request);

  /// Confirma a prévia: grava a operação e os itens `pending` no diário (uma
  /// transação) e põe na fila. Devolve o id da operação.
  Future<String> start(CopyPreview preview) async {
    if (!preview.canStart) throw StateError(preview.blocker ?? 'A prévia não permite começar.');
    final r = preview.request;
    final id = uuidV4();
    final now = nowMs();
    await db.transaction(() async {
      await db.customInsert(
        'INSERT INTO operations (id, kind, status, dest_source_id, dest_root_rel, template, conflict_policy, '
        "params_json, created_at, confirmed_at) VALUES (?, 'copy', 'confirmed', ?, ?, ?, ?, ?, ?, ?)",
        variables: [
          Variable.withString(id),
          Variable.withString(r.destSourceId),
          Variable.withString(r.destFolder),
          Variable.withString(r.template),
          Variable.withString(r.conflict.name),
          Variable.withString(
            jsonEncode({
              'origin': r.origin,
              'contents': r.contentIds.length,
              'alreadyThere': preview.alreadyThere,
              'unavailable': preview.unavailable.length,
              'tooLargeForFat32': preview.tooLargeForFat32.length,
            }),
          ),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
        updates: {db.operations},
      );
      var seq = 0;
      for (final i in preview.items) {
        seq++;
        await db.customInsert(
          'INSERT INTO operation_items (operation_id, seq, src_source_id, src_rel_path, src_instance_id, '
          'expected_size, expected_sha256, dst_source_id, dst_rel_path_planned, original_name, state, '
          'last_error_code, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(id),
            Variable.withInt(seq),
            Variable.withString(i.srcSourceId),
            Variable.withString(i.srcRelPath),
            Variable.withInt(i.instanceId),
            Variable.withInt(i.size),
            Variable(i.sha256),
            Variable.withString(r.destSourceId),
            Variable.withString(i.dstRelPath),
            Variable(i.originalName),
            Variable.withString(ItemState.pending),
            Variable(i.askConflict ? 'name_conflict_planned' : null),
            Variable.withInt(now),
          ],
          updates: {db.operationItems},
        );
      }
      await _event(id, null, null, OpStatus.confirmed, 'Cópia confirmada: ${preview.items.length} arquivo(s).');
    });
    _enqueue(id);
    return id;
  }

  /// Continua uma operação pausada ou interrompida.
  Future<void> resume(String operationId) async {
    final op = await _op(operationId);
    if (op == null || !OpStatus.open.contains(op.status)) return;
    _pauseRequested.remove(operationId);
    _enqueue(operationId);
  }

  /// Pausa: o arquivo do momento volta para a fila (o `.part` dele é
  /// descartado) e o resto espera "Continuar".
  Future<void> pause(String operationId) async {
    if (_runningOp == operationId) {
      _pauseRequested.add(operationId);
      _stopCurrent();
      await _draining;
      return;
    }
    _queue.remove(operationId);
    final op = await _op(operationId);
    if (op != null && (op.status == OpStatus.confirmed || op.status == OpStatus.running)) {
      await _setStatus(operationId, OpStatus.paused);
    }
  }

  /// Cancela o que ainda não foi copiado. O que já foi copiado fica (nada é
  /// apagado do destino).
  Future<void> cancel(String operationId) async {
    if (_runningOp == operationId) {
      _cancelRequested.add(operationId);
      _stopCurrent();
      await _draining;
      return;
    }
    _queue.remove(operationId);
    final op = await _op(operationId);
    if (op != null && OpStatus.open.contains(op.status)) {
      await _setStatus(operationId, OpStatus.cancelled, finished: true);
      await _event(
        operationId,
        null,
        op.status,
        OpStatus.cancelled,
        'Cancelada; o que já foi copiado continua no destino.',
      );
    }
  }

  /// Volta os itens que falharam para a fila. Devolve quantos.
  Future<int> retryFailed(String operationId) async {
    final ids = await db
        .customSelect(
          "SELECT id FROM operation_items WHERE operation_id = ? AND state = 'failed'",
          variables: [Variable.withString(operationId)],
        )
        .get();
    var n = 0;
    for (final r in ids) {
      final id = r.read<int>('id');
      // O .part de um item que falhou na conferência fica para diagnóstico:
      // a nova tentativa usa outro arquivo temporário.
      if (await _transition(
        operationId,
        id,
        ItemState.failed,
        ItemState.pending,
        set: {'tmp_rel_path': null, 'last_error_code': null, 'last_error_message': null},
        message: 'Tentar de novo (pedido do usuário).',
      )) {
        n++;
      }
    }
    if (n > 0) {
      await _setStatus(operationId, OpStatus.paused);
      _enqueue(operationId);
    }
    return n;
  }

  /// Decide um conflito de nome (política "perguntar"): [rename] = copiar com
  /// um nome novo (`_1`, `_2`…); `false` = não copiar este arquivo.
  Future<void> resolveConflict(int itemId, {required bool rename}) async {
    final item = await _item(itemId);
    if (item == null || item.state != ItemState.needsAttention || item.lastErrorCode != 'name_conflict') return;
    if (rename) {
      await _transition(
        item.operationId,
        itemId,
        ItemState.needsAttention,
        ItemState.verified,
        set: {'last_error_code': 'rename_on_conflict', 'last_error_message': null},
        message: 'Conflito de nome: copiar com outro nome (decisão do usuário).',
      );
      final op = await _op(item.operationId);
      if (op != null && op.status != OpStatus.running) await _setStatus(item.operationId, OpStatus.paused);
      _enqueue(item.operationId);
    } else {
      final dest = await sources.byId(item.dstSourceId);
      final root = dest == null ? null : sources.accessRoot(dest);
      await _transition(
        item.operationId,
        itemId,
        ItemState.needsAttention,
        ItemState.skippedIdentical,
        set: {'last_error_code': 'skipped_by_user', 'last_error_message': 'Não copiado (decisão do usuário).'},
        message: 'Conflito de nome: não copiar (decisão do usuário).',
      );
      // O .part verificado era só nosso: descarta.
      if (root != null && item.tmpRelPath != null) deleteOwnPart(joinNative(root, item.tmpRelPath!));
      await _finishIfDone(item.operationId);
    }
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
        _current = null;
      }
    }
  }

  /// Espera a fila esvaziar (testes e CLI).
  Future<void> waitIdle() async {
    while (_draining != null) {
      await _draining;
    }
  }

  void _stopCurrent() {
    final s = _stop;
    if (s != null && !s.isCompleted) s.complete();
  }

  bool _stopping(String opId) => _disposed || _pauseRequested.contains(opId) || _cancelRequested.contains(opId);

  Future<void> _runOp(String opId) async {
    final op = await _op(opId);
    if (op == null || !OpStatus.open.contains(op.status)) return;
    final dest = await sources.byId(op.destSourceId!);
    final root = dest == null ? null : sources.accessRoot(dest);
    if (dest == null || root == null) {
      await _pauseOp(
        opId,
        'O disco de destino "${dest?.name ?? '?'}" está desconectado. Conecte-o e toque em Continuar.',
      );
      return;
    }
    await _setStatus(opId, OpStatus.running, started: op.startedAt == null);
    // Termina com segurança o que ficou no meio (mesma lógica da recuperação).
    await _recoverOperation(opId, root, RecoveryReport());
    await _emitProgress(opId);

    while (true) {
      if (_stopping(opId)) return _afterStop(opId);
      final next = await db
          .customSelect(
            'SELECT * FROM operation_items WHERE operation_id = ? AND state IN (?, ?) ORDER BY seq LIMIT 1',
            variables: [
              Variable.withString(opId),
              Variable.withString(ItemState.pending),
              Variable.withString(ItemState.verified),
            ],
            readsFrom: {db.operationItems},
          )
          .map((r) => db.operationItems.map(r.data))
          .getSingleOrNull();
      if (next == null) break;
      final outcome = await _runItem(op, dest, root, next);
      if (outcome is _Pause) {
        await _pauseOp(opId, outcome.reason);
        return;
      }
      if (outcome is _Stopped) return _afterStop(opId);
    }
    await _finishIfDone(opId);
  }

  Future<void> _afterStop(String opId) async {
    if (_cancelRequested.contains(opId)) {
      await _setStatus(opId, OpStatus.cancelled, finished: true);
      await _event(
        opId,
        null,
        OpStatus.running,
        OpStatus.cancelled,
        'Cancelada; o que já foi copiado continua no destino.',
      );
    } else {
      await _pauseOp(opId, _disposed ? 'Interrompida porque o FotoAtlas foi fechado. Toque em Continuar.' : null);
    }
  }

  Future<void> _finishIfDone(String opId) async {
    final counts = await _counts(opId);
    final open = counts.entries.where((e) => !ItemState.finals.contains(e.key)).fold(0, (s, e) => s + e.value);
    if (open > 0) return;
    final status = (counts[ItemState.needsAttention] ?? 0) > 0
        ? OpStatus.needsAttention
        : (counts[ItemState.failed] ?? 0) > 0
        ? OpStatus.completedWithErrors
        : OpStatus.completed;
    // Já registrada assim: não repete (a recuperação roda a cada abertura).
    if ((await _op(opId))?.status == status) return;
    await _setStatus(opId, status, finished: true, summary: counts);
    await _event(opId, null, OpStatus.running, status, 'Terminada.');
    await _emitProgress(opId, running: false);
  }

  /// Um item, de onde ele estiver (`pending` ou `verified`) até o fim.
  Future<_Outcome> _runItem(OperationRow op, SourceRow dest, String root, OperationItemRow item) async {
    if (item.state == ItemState.verified) return _publish(op, dest, root, item);
    final src = await sources.byId(item.srcSourceId);
    if (src == null) {
      await _transition(
        op.id,
        item.id,
        ItemState.pending,
        ItemState.failed,
        set: _err('source_forgotten', 'A origem foi esquecida no catálogo.'),
      );
      return const _Next();
    }
    final isPhone = src.kind == 'phone';
    final srcRoot = isPhone ? null : sources.accessRoot(src);
    if (isPhone ? sources.deviceFor(src.id)?.status != 'ok' : srcRoot == null) {
      return _Pause(
        isPhone
            ? 'O celular "${src.name}" foi desconectado ou está bloqueado. Conecte e desbloqueie, depois toque em Continuar.'
            : 'A origem "${src.name}" está desconectada. Conecte-a e toque em Continuar.',
      );
    }
    if (isFat(dest.filesystem) && item.expectedSize > fat32MaxFileSize) {
      await _transition(
        op.id,
        item.id,
        ItemState.pending,
        ItemState.failed,
        set: _err('too_large_for_fs', 'Maior que 4 GB: o disco de destino (FAT32) não aceita arquivos assim.'),
      );
      return const _Next();
    }
    final free = _freeSpace(root);
    if (free != null && free < item.expectedSize + _reserve) {
      return const _Pause(
        'Falta espaço no disco de destino. Libere espaço (ou escolha outro destino) e toque em Continuar.',
      );
    }

    final tmpRel = '$tempDirName/${uuidV4()}.part';
    final part = joinNative(root, tmpRel);
    if (!await _transition(
      op.id,
      item.id,
      ItemState.pending,
      ItemState.copying,
      set: {'tmp_rel_path': tmpRel, 'attempts': item.attempts + 1, 'last_error_code': null, 'last_error_message': null},
    )) {
      return const _Next();
    }
    crashpoint('copy.after_copying_commit');
    try {
      ensureDirectory(joinNative(root, tempDirName));
    } on Win32Exception {
      await _transition(op.id, item.id, ItemState.copying, ItemState.pending, set: {'tmp_rel_path': null});
      return const _Pause('O disco de destino não está acessível (foi desconectado?). Conecte-o e toque em Continuar.');
    }

    final stop = _stop = Completer<void>();
    final name = item.srcRelPath.split('/').last;
    void onBytes(int b) => _onItemProgress(op.id, name, b, item.expectedSize, 'copying');
    Uint8List srcSha;
    int bytes;
    if (isPhone) {
      final pulled = await _pullFromPhone(op, src, item, part, stop.future, onBytes);
      if (pulled is _Outcome) return pulled;
      (srcSha, bytes) = pulled as (Uint8List, int);
    } else {
      final request = PumpRequest(
        sourcePath: joinNative(srcRoot!, item.srcRelPath),
        partPath: part,
        expectedSize: item.expectedSize,
        expectedMtime: await _catalogMtime(item.srcInstanceId),
        crashMidWrite: crashpointArmed('copy.mid_write'),
      );
      final result = useIsolate
          ? await copyToPartInIsolate(request, stop: stop.future, onProgress: onBytes)
          : await copyToPart(request, shouldStop: () => stop.isCompleted, onProgress: onBytes);
      switch (result) {
        case PumpDone(:final sha256, bytes: final n):
          (srcSha, bytes) = (sha256, n);
        case PumpStopped():
          await _discardAndRequeue(op.id, item.id, ItemState.copying, part, 'Pausada no meio do arquivo.');
          return const _Stopped();
        case PumpFailed(:final failure, :final message):
          return _onCopyFailure(op.id, item.id, part, failure, message, srcRoot: srcRoot);
      }
    }
    crashpoint('copy.after_flush');
    final expected = item.expectedSha256;
    if (bytes != item.expectedSize || (expected != null && !_eq(expected, srcSha))) {
      deleteOwnPart(part);
      await _transition(
        op.id,
        item.id,
        ItemState.copying,
        ItemState.failed,
        set: _err('source_changed', 'O conteúdo do arquivo na origem mudou desde a conferência. Escaneie de novo.'),
      );
      return const _Next();
    }
    if (!await _transition(
      op.id,
      item.id,
      ItemState.copying,
      ItemState.copied,
      set: {'src_sha256': srcSha, 'bytes_copied': bytes},
    )) {
      return const _Next();
    }
    crashpoint('copy.after_copied_commit');
    return _verify(op, dest, root, (await _item(item.id))!);
  }

  /// Passos 5–6: relê o `.part` e compara com o hash da origem.
  Future<_Outcome> _verify(OperationRow op, SourceRow dest, String root, OperationItemRow item) async {
    if (!await _transition(op.id, item.id, ItemState.copied, ItemState.verifying)) return const _Next();
    crashpoint('copy.after_verifying_commit');
    final part = joinNative(root, item.tmpRelPath!);
    final stop = _stop = Completer<void>();
    final name = item.srcRelPath.split('/').last;
    void onBytes(int b) => _onItemProgress(op.id, name, b, item.expectedSize, 'verifying');
    final h = useIsolate
        ? await hashDestFileInIsolate(part, stop: stop.future, onProgress: onBytes)
        : await hashDestFile(part, shouldStop: () => stop.isCompleted, onProgress: onBytes);
    switch (h) {
      case null:
        await _transition(
          op.id,
          item.id,
          ItemState.verifying,
          ItemState.pending,
          set: {'tmp_rel_path': null},
          message: 'O arquivo temporário sumiu; a cópia será refeita.',
        );
        return const _Next();
      case PumpStopped():
        await _discardAndRequeue(op.id, item.id, ItemState.verifying, part, 'Pausada durante a conferência.');
        return const _Stopped();
      case PumpFailed(:final failure, :final message):
        if (failure == PumpFailure.destUnavailable) return _Pause('$message Conecte o disco e toque em Continuar.');
        await _transition(op.id, item.id, ItemState.verifying, ItemState.failed, set: _err('verify_error', message));
        return const _Next();
      case PumpDone(:final sha256):
        if (!_eq(sha256, item.srcSha256!)) {
          // Mantém o .part para diagnóstico e não publica (spec §11.1, passo 6).
          await _transition(
            op.id,
            item.id,
            ItemState.verifying,
            ItemState.failed,
            set: {
              'dst_sha256': sha256,
              ..._err(
                'hash_mismatch',
                'A cópia gravada não confere com a origem. O disco de destino pode ter problemas.',
              ),
            },
          );
          return const _Next();
        }
        if (!await _transition(op.id, item.id, ItemState.verifying, ItemState.verified, set: {'dst_sha256': sha256})) {
          return const _Next();
        }
    }
    crashpoint('copy.after_verified_commit');
    return _publish(op, dest, root, (await _item(item.id))!);
  }

  /// Passos 7–8: publica com `MoveFileExW` sem substituição e registra.
  Future<_Outcome> _publish(OperationRow op, SourceRow dest, String root, OperationItemRow item) async {
    final part = joinNative(root, item.tmpRelPath!);
    var target = item.dstRelPathPlanned;
    final renameAllowed = op.conflictPolicy != ConflictPolicy.ask.name || item.lastErrorCode == 'rename_on_conflict';
    final existing = _attributes(joinNative(root, target));
    if (existing != null) {
      // Mesmo conteúdo já está lá (destino não escaneado): não duplica.
      if (existing.size == item.expectedSize && await _sameContent(joinNative(root, target), item.srcSha256!)) {
        await db.transaction(() async {
          await _transition(
            op.id,
            item.id,
            ItemState.verified,
            ItemState.skippedIdentical,
            set: {'dst_rel_path_final': target},
            message: 'O destino já tinha este arquivo, idêntico.',
          );
          await _register(dest.id, target, item.srcSha256!, existing);
        });
        deleteOwnPart(part);
        return const _Next();
      }
      if (!renameAllowed) {
        await _transition(
          op.id,
          item.id,
          ItemState.verified,
          ItemState.needsAttention,
          set: _err('name_conflict', 'Já existe outro arquivo com o nome "${target.split('/').last}" no destino.'),
        );
        return const _Next();
      }
      target = _nextFree(root, target);
    }
    if (!await _transition(
      op.id,
      item.id,
      ItemState.verified,
      ItemState.publishing,
      set: {'dst_rel_path_final': target},
    )) {
      return const _Next();
    }
    crashpoint('copy.after_publishing_commit');
    return _move(op, dest, root, item.id, part, target);
  }

  Future<_Outcome> _move(OperationRow op, SourceRow dest, String root, int itemId, String part, String target) async {
    for (var attempt = 0; attempt < 1000; attempt++) {
      final full = joinNative(root, target);
      try {
        final slash = target.lastIndexOf('/');
        if (slash > 0) ensureDirectory(joinNative(root, target.substring(0, slash)));
        moveNoReplace(part, full);
      } on Win32Exception catch (e) {
        if (e.code == errorAlreadyExists || e.code == errorFileExists) {
          // Alguém criou o nome entre a checagem e o move: próximo sufixo,
          // gravado antes da nova tentativa (L1).
          final next = _nextFree(root, target);
          await _transition(
            op.id,
            itemId,
            ItemState.publishing,
            ItemState.publishing,
            set: {'dst_rel_path_final': next},
            message: 'Nome "$target" ocupado; usando "$next".',
          );
          target = next;
          continue;
        }
        return _Pause(
          'Não foi possível publicar no destino (${e.code}). Confira se o disco está conectado e toque em Continuar.',
        );
      }
      crashpoint('copy.after_move');
      final item = (await _item(itemId))!;
      final info = _attributes(full);
      await db.transaction(() async {
        await _transition(op.id, itemId, ItemState.publishing, ItemState.published);
        if (info != null) await _register(dest.id, target, item.srcSha256!, info);
      });
      crashpoint('copy.after_published_commit');
      await _emitProgress(op.id);
      return const _Next();
    }
    return const _Pause('Não foi encontrado um nome livre no destino.');
  }

  Future<Object> _pullFromPhone(
    OperationRow op,
    SourceRow src,
    OperationItemRow item,
    String part,
    Future<void> stop,
    void Function(int) onBytes,
  ) async {
    final backend = sources.devices;
    final device = sources.deviceFor(src.id);
    if (backend == null || device == null) {
      await _transition(op.id, item.id, ItemState.copying, ItemState.pending, set: {'tmp_rel_path': null});
      return _Pause('O celular "${src.name}" foi desconectado. Conecte e desbloqueie, depois toque em Continuar.');
    }
    final resolver = _resolvers[device.deviceId] ??= PhonePathResolver(backend, device.deviceId);
    final mtime = await _catalogMtime(item.srcInstanceId);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final objectId = attempt == 0 ? await _objectId(item.srcInstanceId) : await resolver.file(item.srcRelPath);
        if (objectId == null) continue;
        try {
          final pulled = await backend.pullToFile(
            device.deviceId,
            objectId,
            part,
            expectedSize: item.expectedSize,
            modified: mtime,
            cancel: stop,
            onProgress: onBytes,
          );
          return (pulled.sha256, pulled.bytesWritten);
        } on DeviceException catch (e) {
          // ID velho (o Android muda os IDs entre sessões): procura pelo caminho.
          // O helper já tinha criado o .part (vazio): é nosso, descarta.
          if (e.code == 'not_found' && attempt == 0) {
            deleteOwnPart(part);
            continue;
          }
          rethrow;
        }
      }
      deleteOwnPart(part);
      await _transition(
        op.id,
        item.id,
        ItemState.copying,
        ItemState.failed,
        set: _err('source_missing', 'O arquivo não está mais no celular (foi apagado ou movido?).'),
      );
      return const _Next();
    } on DeviceException catch (e) {
      if (e.code == 'cancelled') {
        await _discardAndRequeue(op.id, item.id, ItemState.copying, part, 'Pausada no meio do arquivo.');
        return const _Stopped();
      }
      if (e.isDeviceGone || e.code == 'io_error') {
        await _discardAndRequeue(op.id, item.id, ItemState.copying, part, 'Celular desconectado no meio da cópia.');
        return _Pause(
          'O celular "${src.name}" foi desconectado no meio da cópia. Nada se perdeu: conecte e '
          'desbloqueie o celular e toque em Continuar.',
        );
      }
      if (e.code == 'disk_full') {
        await _discardAndRequeue(op.id, item.id, ItemState.copying, part, 'Disco de destino cheio.');
        return const _Pause('Falta espaço no disco de destino. Libere espaço e toque em Continuar.');
      }
      deleteOwnPart(part);
      final (code, message) = switch (e.code) {
        'changed_during_read' => (
          'source_changed',
          'O arquivo mudou no celular depois do escaneamento. Escaneie de novo.',
        ),
        'not_found' => ('source_missing', 'O arquivo não está mais no celular (foi apagado ou movido?).'),
        _ => ('source_unreadable', 'Erro de leitura no celular: ${e.message}'),
      };
      await _transition(op.id, item.id, ItemState.copying, ItemState.failed, set: _err(code, message));
      return const _Next();
    }
  }

  Future<_Outcome> _onCopyFailure(
    String opId,
    int itemId,
    String part,
    PumpFailure failure,
    String message, {
    String? srcRoot,
  }) async {
    switch (failure) {
      case PumpFailure.diskFull:
        await _discardAndRequeue(opId, itemId, ItemState.copying, part, message);
        return const _Pause('O disco de destino ficou sem espaço. Libere espaço e toque em Continuar.');
      case PumpFailure.destUnavailable:
        await _discardAndRequeue(opId, itemId, ItemState.copying, part, message);
        return const _Pause(
          'O disco de destino não está acessível (foi desconectado?). Conecte-o e toque em Continuar.',
        );
      case PumpFailure.sourceMissing when srcRoot != null && !directoryAccessible(srcRoot):
        // A unidade inteira saiu: não é "arquivo sumiu" (regra 9).
        await _discardAndRequeue(opId, itemId, ItemState.copying, part, message);
        return const _Pause('A origem foi desconectada no meio da cópia. Conecte-a e toque em Continuar.');
      case PumpFailure.partExists:
        // Não é nosso (ou não sabemos): não apaga.
        await _transition(opId, itemId, ItemState.copying, ItemState.pending, set: {'tmp_rel_path': null});
        return const _Next();
      default:
        deleteOwnPart(part);
        await _transition(opId, itemId, ItemState.copying, ItemState.failed, set: _err(_codeOf(failure), message));
        return const _Next();
    }
  }

  static String _codeOf(PumpFailure f) => switch (f) {
    PumpFailure.sourceMissing => 'source_missing',
    PumpFailure.sourceUnreadable => 'source_unreadable',
    PumpFailure.sourceChanged => 'source_changed',
    PumpFailure.sourceCloudOnly => 'source_cloud_only',
    PumpFailure.tooLarge => 'too_large_for_fs',
    PumpFailure.diskFull => 'disk_full',
    PumpFailure.destUnavailable => 'dest_unavailable',
    PumpFailure.partExists => 'part_exists',
    PumpFailure.writeError => 'write_error',
  };

  Future<void> _discardAndRequeue(String opId, int itemId, String from, String part, String message) async {
    deleteOwnPart(part);
    await _transition(opId, itemId, from, ItemState.pending, set: {'tmp_rel_path': null}, message: message);
  }

  // --- Recuperação ------------------------------------------------------------

  /// Recuperação na inicialização (spec §11.2), idempotente: decide olhando o
  /// disco, não só o diário. Operações que estavam `running` viram `paused`
  /// ("interrompida"); itens no meio são conferidos e terminados quando o
  /// destino está conectado. Rodar de novo não muda nada.
  Future<RecoveryReport> recoverAll() async {
    final report = RecoveryReport();
    final ops = await (db.select(db.operations)..where((o) => o.status.isIn(OpStatus.open))).get();
    for (final op in ops) {
      if (op.kind != 'copy') continue;
      if (op.status == OpStatus.running || op.status == OpStatus.confirmed) {
        await _pauseOp(
          op.id,
          'Interrompida (o FotoAtlas foi fechado ou o computador desligou). Nada se perdeu: '
          'toque em Continuar.',
        );
      }
      final dest = op.destSourceId == null ? null : await sources.byId(op.destSourceId!);
      final root = dest == null ? null : sources.accessRoot(dest);
      if (root == null) {
        report.skippedDestUnavailable += await _countInFlight(op.id);
        continue;
      }
      await _recoverOperation(op.id, root, report);
      crashpoint('recover.after_operation');
      await _finishIfDone(op.id);
    }
    return report;
  }

  Future<int> _countInFlight(String opId) async {
    final r = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM operation_items WHERE operation_id = ? AND state IN '
          '(${ItemState.inFlight.map((_) => '?').join(',')})',
          variables: [Variable.withString(opId), for (final s in ItemState.inFlight) Variable.withString(s)],
        )
        .getSingle();
    return r.read<int>('n');
  }

  Future<void> _recoverOperation(String opId, String root, RecoveryReport report) async {
    final op = (await _op(opId))!;
    final dest = (await sources.byId(op.destSourceId!))!;
    final items = await db
        .customSelect(
          'SELECT * FROM operation_items WHERE operation_id = ? AND state IN '
          '(${ItemState.inFlight.map((_) => '?').join(',')}) ORDER BY seq',
          variables: [Variable.withString(opId), for (final s in ItemState.inFlight) Variable.withString(s)],
          readsFrom: {db.operationItems},
        )
        .map((r) => db.operationItems.map(r.data))
        .get();
    for (final item in items) {
      report.examined++;
      final part = item.tmpRelPath == null ? null : joinNative(root, item.tmpRelPath!);
      switch (item.state) {
        case ItemState.copying:
          // Cópia pela metade (ou completa, mas sem o hash registrado): refaz.
          if (part != null) deleteOwnPart(part);
          await _transition(
            opId,
            item.id,
            ItemState.copying,
            ItemState.pending,
            set: {'tmp_rel_path': null},
            message: 'Recuperação: cópia interrompida, será refeita.',
          );
          report.resumedAsPending++;
        case ItemState.copied || ItemState.verifying || ItemState.verified:
          final h = part == null ? null : await hashDestFile(part);
          if (h is PumpDone && _eq(h.sha256, item.srcSha256!)) {
            if (item.state != ItemState.verified) {
              await _transition(
                opId,
                item.id,
                item.state,
                ItemState.verified,
                set: {'dst_sha256': h.sha256},
                message: 'Recuperação: arquivo temporário conferido.',
              );
              report.verified++;
            }
            final outcome = await _publish(op, dest, root, (await _item(item.id))!);
            if (outcome is _Next && (await _item(item.id))!.state == ItemState.published) report.published++;
          } else if (h is PumpFailed && h.failure == PumpFailure.destUnavailable) {
            report.skippedDestUnavailable++;
          } else {
            if (part != null) deleteOwnPart(part);
            await _transition(
              opId,
              item.id,
              item.state,
              ItemState.pending,
              set: {'tmp_rel_path': null, 'src_sha256': null, 'dst_sha256': null, 'bytes_copied': 0},
              message: 'Recuperação: arquivo temporário ausente ou diferente; a cópia será refeita.',
            );
            report.resumedAsPending++;
          }
        case ItemState.publishing:
          await _recoverPublishing(op, dest, root, item, report);
      }
    }
  }

  /// O nome final foi gravado antes do move (L1): o disco diz se o move
  /// aconteceu.
  Future<void> _recoverPublishing(
    OperationRow op,
    SourceRow dest,
    String root,
    OperationItemRow item,
    RecoveryReport report,
  ) async {
    final part = joinNative(root, item.tmpRelPath!);
    final target = item.dstRelPathFinal!;
    final full = joinNative(root, target);
    final partInfo = _attributes(part);
    final finalInfo = _attributes(full);
    if (partInfo != null) {
      final h = await hashDestFile(part);
      if (h is! PumpDone || !_eq(h.sha256, item.srcSha256!)) {
        deleteOwnPart(part);
        await _transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.pending,
          set: {'tmp_rel_path': null, 'dst_rel_path_final': null, 'src_sha256': null, 'dst_sha256': null},
          message: 'Recuperação: arquivo temporário diferente; a cópia será refeita.',
        );
        report.resumedAsPending++;
        return;
      }
      // .part conferido: publica (se o nome estiver ocupado por outro
      // arquivo, o _move escolhe o próximo sufixo).
      final next = finalInfo == null ? target : _nextFree(root, target);
      if (next != target) {
        await _transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.publishing,
          set: {'dst_rel_path_final': next},
          message: 'Recuperação: nome "$target" ocupado; usando "$next".',
        );
      }
      final outcome = await _move(op, dest, root, item.id, part, next);
      if (outcome is _Next) report.published++;
      return;
    }
    if (finalInfo != null) {
      // Movido, mas o registro não chegou a ser gravado: confere e registra.
      if (await _sameContent(full, item.srcSha256!)) {
        await db.transaction(() async {
          await _transition(
            op.id,
            item.id,
            ItemState.publishing,
            ItemState.published,
            message: 'Recuperação: arquivo publicado conferido e registrado.',
          );
          await _register(dest.id, target, item.srcSha256!, finalInfo);
        });
        report.published++;
        return;
      }
    }
    await _transition(
      op.id,
      item.id,
      ItemState.publishing,
      ItemState.needsAttention,
      set: _err('recovery_unknown', 'Não foi possível confirmar se este arquivo foi copiado. Confira o destino.'),
    );
    report.needsAttention++;
  }

  // --- Consultas (tela Tarefas) -----------------------------------------------

  Stream<List<OperationView>> watch() => db
      .customSelect('SELECT COUNT(*) FROM operation_items', readsFrom: {db.operations, db.operationItems})
      .watch()
      .asyncMap((_) => list());

  Future<List<OperationView>> list({int limit = 200}) async {
    final ops =
        await (db.select(db.operations)
              ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
              ..limit(limit))
            .get();
    if (ops.isEmpty) return const [];
    final rows = await db
        .customSelect(
          'SELECT operation_id, state, COUNT(*) AS n, SUM(expected_size) AS bytes FROM operation_items '
          'GROUP BY operation_id, state',
          readsFrom: {db.operationItems},
        )
        .get();
    final counts = <String, Map<String, int>>{};
    final bytes = <String, Map<String, int>>{};
    for (final r in rows) {
      final id = r.read<String>('operation_id');
      (counts[id] ??= {})[r.read<String>('state')] = r.read<int>('n');
      (bytes[id] ??= {})[r.read<String>('state')] = r.readNullable<int>('bytes') ?? 0;
    }
    final names = {for (final s in await db.select(db.sources).get()) s.id: s.name};
    return [
      for (final o in ops)
        OperationView(
          id: o.id,
          kind: o.kind,
          status: o.status,
          destSourceId: o.destSourceId,
          destName: names[o.destSourceId] ?? '?',
          destFolder: o.destRootRel ?? '',
          template: o.template,
          createdAt: DateTime.fromMillisecondsSinceEpoch(o.createdAt, isUtc: true),
          startedAt: o.startedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(o.startedAt!, isUtc: true),
          finishedAt: o.finishedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(o.finishedAt!, isUtc: true),
          counts: counts[o.id] ?? const {},
          totalItems: (counts[o.id] ?? const {}).values.fold(0, (s, n) => s + n),
          totalBytes: (bytes[o.id] ?? const {}).values.fold(0, (s, n) => s + n),
          doneBytes: (bytes[o.id]?[ItemState.published] ?? 0) + (bytes[o.id]?[ItemState.skippedIdentical] ?? 0),
          pauseReason: _summary(o)['pausedReason'] as String?,
          origin: _params(o)['origin'] as String?,
        ),
    ];
  }

  Future<OperationView?> view(String operationId) async => (await list()).where((o) => o.id == operationId).firstOrNull;

  /// Itens de uma operação (opcionalmente só alguns estados).
  Future<List<OperationItemView>> items(
    String operationId, {
    Set<String>? states,
    int offset = 0,
    int limit = 500,
  }) async {
    final filter = states == null || states.isEmpty ? '' : 'AND state IN (${states.map((_) => '?').join(',')})';
    final rows = await db
        .customSelect(
          'SELECT * FROM operation_items WHERE operation_id = ? $filter ORDER BY seq LIMIT ? OFFSET ?',
          variables: [
            Variable.withString(operationId),
            for (final s in states ?? const <String>{}) Variable.withString(s),
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: {db.operationItems},
        )
        .map((r) => db.operationItems.map(r.data))
        .get();
    return [
      for (final r in rows)
        OperationItemView(
          id: r.id,
          seq: r.seq,
          state: r.state,
          srcSourceId: r.srcSourceId,
          srcRelPath: r.srcRelPath,
          dstRelPath: r.dstRelPathFinal ?? r.dstRelPathPlanned,
          size: r.expectedSize,
          errorCode: r.lastErrorCode,
          errorMessage: r.lastErrorMessage,
          originalName: r.originalName,
        ),
    ];
  }

  /// Relatório da operação em CSV (`;`, UTF-8 com BOM, abre no Excel).
  Future<String> exportCsv(String operationId) async {
    final op = await _op(operationId);
    if (op == null) throw StateError('Operação não encontrada.');
    final names = {for (final s in await db.select(db.sources).get()) s.id: s.name};
    final rows =
        await (db.select(db.operationItems)
              ..where((i) => i.operationId.equals(operationId))
              ..orderBy([(i) => OrderingTerm.asc(i.seq)]))
            .get();
    String q(Object? v) {
      final s = v?.toString() ?? '';
      return s.contains(RegExp('[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String hex(Uint8List? b) => b == null ? '' : b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final out = StringBuffer('﻿')
      ..writeln('# FotoAtlas — relatório da cópia ${op.id}')
      ..writeln(
        '# Destino: ${q(names[op.destSourceId])}${op.destRootRel == null || op.destRootRel!.isEmpty ? '' : ' › ${op.destRootRel}'}',
      )
      ..writeln('# Situação: ${op.status}')
      ..writeln(
        'item;estado;origem;caminho na origem;caminho no destino;tamanho (bytes);sha256 origem;sha256 destino;tentativas;motivo',
      );
    for (final r in rows) {
      out.writeln(
        [
          r.seq,
          r.state,
          q(names[r.srcSourceId]),
          q(r.srcRelPath),
          q(r.dstRelPathFinal ?? r.dstRelPathPlanned),
          r.expectedSize,
          hex(r.srcSha256),
          hex(r.dstSha256),
          r.attempts,
          q(r.lastErrorMessage),
        ].join(';'),
      );
    }
    return out.toString();
  }

  /// Arquivos na pasta temporária do destino que não pertencem a nenhuma
  /// cópia em andamento: listados para o usuário, **nunca apagados
  /// automaticamente** (spec §11.2). `null` = destino desconectado.
  Future<List<TempLeftover>?> tempLeftovers(String destSourceId) async {
    final dest = await sources.byId(destSourceId);
    final root = dest == null ? null : sources.accessRoot(dest);
    if (root == null) return null;
    final List<RawDirEntry> entries;
    try {
      entries = listDirectory(joinNative(root, tempDirName));
    } on Win32Exception {
      return const [];
    }
    final rows = await db
        .customSelect(
          'SELECT tmp_rel_path, state, last_error_code FROM operation_items WHERE dst_source_id = ? AND tmp_rel_path IS NOT NULL',
          variables: [Variable.withString(destSourceId)],
        )
        .get();
    final byName = {
      for (final r in rows)
        r.read<String>('tmp_rel_path').split('/').last.toLowerCase(): (
          r.read<String>('state'),
          r.readNullable<String>('last_error_code'),
        ),
    };
    return [
      for (final e in entries)
        if (!e.isDirectory)
          if (byName[e.name.toLowerCase()] case final ref
              when ref == null || !(ItemState.inFlight.contains(ref.$1) || ref.$1 == ItemState.needsAttention))
            TempLeftover(
              name: e.name,
              size: e.size,
              modified: fileTimeToDateTime(e.mtime),
              note: ref?.$2 == 'hash_mismatch'
                  ? 'Guardado para diagnóstico: a conferência desta cópia não bateu.'
                  : null,
            ),
    ];
  }

  // --- Encerramento -----------------------------------------------------------

  /// Para a cópia em andamento (o arquivo do momento volta para a fila) e
  /// espera até [timeout]. `false` se não parou a tempo (a recuperação cuida).
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposed = true;
    _queue.clear();
    _stopCurrent();
    final d = _draining;
    var ok = true;
    if (d != null) {
      ok = await d.then((_) => true).timeout(timeout, onTimeout: () => false);
    }
    await _progress.close();
    return ok;
  }

  // --- Auxiliares ---------------------------------------------------------------

  Map<String, Object?> _err(String code, String message) => {'last_error_code': code, 'last_error_message': message};

  /// Transição de estado + evento, na mesma transação, só se o item ainda
  /// estiver em [from] (protege contra duas execuções concorrentes).
  Future<bool> _transition(
    String opId,
    int itemId,
    String from,
    String to, {
    Map<String, Object?> set = const {},
    String? message,
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
      await _event(opId, itemId, from, to, message ?? set['last_error_message'] as String?);
      return true;
    });
    if (ok) await _emitProgress(opId);
    return ok;
  }

  Future<void> _event(String opId, int? itemId, String? from, String? to, String? message) => db.customInsert(
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

  Future<void> _pauseOp(String opId, String? reason) async {
    final op = await _op(opId);
    if (op == null || op.status == OpStatus.paused && _summary(op)['pausedReason'] == reason) return;
    await _setStatus(opId, OpStatus.paused, summary: {'pausedReason': reason});
    await _event(opId, null, op.status, OpStatus.paused, reason ?? 'Pausada.');
    await _emitProgress(opId, running: false);
  }

  Future<void> _setStatus(
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

  /// Registra o arquivo do destino no catálogo, já conferido (passo 8).
  Future<void> _register(String sourceId, String relPath, Uint8List sha, SourceFileInfo info) async {
    final now = nowMs();
    final slash = relPath.lastIndexOf('/');
    final name = slash < 0 ? relPath : relPath.substring(slash + 1);
    final ext = extensionOf(name);
    await db.customInsert(
      'INSERT INTO contents (sha256, size_bytes, media_type, created_at) VALUES (?, ?, ?, ?) '
      'ON CONFLICT (sha256, size_bytes) DO NOTHING',
      variables: [
        Variable.withBlob(sha),
        Variable.withInt(info.size),
        Variable.withString(MediaTypes.mediaTypeOf(ext)),
        Variable.withInt(now),
      ],
      updates: {db.contents},
    );
    await db.customInsert(
      'INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, mtime, attributes, '
      'content_id, hash_status, hashed_size, hashed_mtime, hashed_at, last_verified_at, availability, integrity) '
      "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, (SELECT id FROM contents WHERE sha256 = ?9 AND size_bytes = ?6), 'done', "
      "?6, ?7, ?10, ?10, 'present', 'ok') "
      'ON CONFLICT (source_id, rel_path) DO UPDATE SET size_bytes = excluded.size_bytes, mtime = excluded.mtime, '
      'attributes = excluded.attributes, content_id = excluded.content_id, hash_status = excluded.hash_status, '
      'hashed_size = excluded.hashed_size, hashed_mtime = excluded.hashed_mtime, hashed_at = excluded.hashed_at, '
      "last_verified_at = excluded.last_verified_at, availability = 'present', integrity = 'ok', "
      'missing_confirmed_at = NULL, hash_error = NULL',
      variables: [
        Variable.withString(sourceId),
        Variable.withString(relPath),
        Variable.withString(slash < 0 ? '' : relPath.substring(0, slash)),
        Variable.withString(name),
        Variable.withString(ext),
        Variable.withInt(info.size),
        Variable.withInt(info.mtime),
        Variable.withInt(info.attributes),
        Variable.withBlob(sha),
        Variable.withInt(now),
      ],
      updates: {db.fileInstances},
    );
  }

  String _nextFree(String root, String relPath) {
    final slash = relPath.lastIndexOf('/');
    final dir = slash < 0 ? '' : '${relPath.substring(0, slash)}/';
    final name = slash < 0 ? relPath : relPath.substring(slash + 1);
    for (var n = 1; ; n++) {
      final candidate = '$dir${withSuffix(name, n)}';
      if (_attributes(joinNative(root, candidate)) == null) return candidate;
    }
  }

  Future<bool> _sameContent(String path, Uint8List sha) async {
    final h = await hashDestFile(path);
    return h is PumpDone && _eq(h.sha256, sha);
  }

  static SourceFileInfo? _attributes(String path) {
    try {
      return attributesOf(path);
    } on Win32Exception {
      return null;
    }
  }

  static bool _eq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<int?> _catalogMtime(int? instanceId) async {
    if (instanceId == null) return null;
    final r = await (db.select(db.fileInstances)..where((f) => f.id.equals(instanceId))).getSingleOrNull();
    return r?.mtime;
  }

  Future<String?> _objectId(int? instanceId) async {
    if (instanceId == null) return null;
    final r = await (db.select(db.fileInstances)..where((f) => f.id.equals(instanceId))).getSingleOrNull();
    return r?.deviceObjectId;
  }

  Future<OperationRow?> _op(String id) => (db.select(db.operations)..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<OperationItemRow?> _item(int id) =>
      (db.select(db.operationItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<Map<String, int>> _counts(String opId) async {
    final rows = await db
        .customSelect(
          'SELECT state, COUNT(*) AS n FROM operation_items WHERE operation_id = ? GROUP BY state',
          variables: [Variable.withString(opId)],
        )
        .get();
    return {for (final r in rows) r.read<String>('state'): r.read<int>('n')};
  }

  static Map<String, Object?> _summary(OperationRow o) =>
      o.summaryJson == null ? const {} : (jsonDecode(o.summaryJson!) as Map).cast<String, Object?>();

  static Map<String, Object?> _params(OperationRow o) =>
      o.paramsJson == null ? const {} : (jsonDecode(o.paramsJson!) as Map).cast<String, Object?>();

  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  void _onItemProgress(String opId, String name, int bytes, int size, String step) {
    final now = DateTime.now();
    if (now.difference(_lastEmit) < const Duration(milliseconds: 150) && bytes < size) return;
    _lastEmit = now;
    final c = _current;
    if (c == null || c.operationId != opId) return;
    _publishProgress(
      CopyProgress(
        operationId: opId,
        itemsDone: c.itemsDone,
        itemsTotal: c.itemsTotal,
        bytesDone: c.bytesDone,
        bytesTotal: c.bytesTotal,
        currentName: name,
        currentBytes: bytes,
        currentSize: size,
        step: step,
      ),
    );
  }

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
    _publishProgress(
      CopyProgress(
        operationId: opId,
        itemsDone: done,
        itemsTotal: total,
        bytesDone: doneBytes,
        bytesTotal: totalBytes,
        running: running && _runningOp == opId,
      ),
    );
  }

  void _publishProgress(CopyProgress p) {
    _current = p.running ? p : null;
    if (!_progress.isClosed) _progress.add(p);
  }
}

sealed class _Outcome {
  const _Outcome();
}

class _Next extends _Outcome {
  const _Next();
}

class _Stopped extends _Outcome {
  const _Stopped();
}

class _Pause extends _Outcome {
  const _Pause(this.reason);
  final String reason;
}
