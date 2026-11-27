import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../ops/copy_models.dart';
import '../ops/copy_pump.dart';
import '../ops/journal.dart';
import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import '../safe_io/recycle_bin.dart';
import '../safe_io/source_reader.dart';
import '../scan/scan_service.dart';
import '../settings/settings_store.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import '../util/crashpoint.dart';
import '../util/uuid.dart';
import 'dedupe_models.dart';

/// "Limpar repetidos" (Fase 9, ADR 0027): arquivos com o mesmo conteúdo
/// (SHA-256) no **mesmo** dispositivo.
///
/// - Grupos, sugestão de qual cópia fica e prévia só leem o catálogo.
/// - Nada vem marcado: a pessoa escolhe os grupos (ou aceita as sugestões),
///   vê a prévia e confirma.
/// - Na hora de remover, grupo por grupo: o SHA-256 da cópia que fica e o de
///   cada uma que sai são conferidos de novo; se algo mudou (ou sumiu, ou é o
///   mesmo arquivo físico), o grupo inteiro é pulado e avisado.
/// - O que sai vai para a **Lixeira do Windows** ([RecycleBin]), nunca de vez;
///   cada arquivo passa pelo diário (`pending → publishing → published`) e a
///   recuperação decide pelo disco.
/// - A cópia que fica nunca é removida por esta operação: nunca sai a última
///   cópia de um conteúdo. Celular, pendrive e cartão de memória nunca entram.
class DedupeService {
  DedupeService(this.db, this.sources, this.scans, {required RecycleBin? recycleBin, this.useIsolate = true})
    : _bin = recycleBin {
    journal = OperationJournal(db, onChange: _emitProgress);
  }

  final CatalogDatabase db;
  final SourcesService sources;
  final ScanService scans;
  final bool useIsolate;
  final RecycleBin? _bin;
  late final OperationJournal journal;

  static const keepRuleKey = 'dedupe.keepRule';

  final _progress = StreamController<CopyProgress>.broadcast();
  final _queue = <String>[];
  Future<void>? _draining;
  String? _runningOp;
  final _pauseRequested = <String>{};
  final _cancelRequested = <String>{};
  Completer<void>? _stop;
  bool _disposed = false;

  Stream<CopyProgress> get progress => _progress.stream;
  bool get isRunning => _runningOp != null;

  /// Avisa quando os arquivos do catálogo ou as operações mudam (os grupos
  /// podem ter mudado). A tela agrupa os avisos.
  Stream<void> get changes => db
      .customSelect('SELECT 1', readsFrom: {db.fileInstances, db.operations, db.operationItems, db.sources})
      .watch()
      .map((_) {});

  // --- Regra da sugestão --------------------------------------------------------

  Future<KeepRule> keepRule() async {
    final v = await SettingsStore(db).get(keepRuleKey);
    return KeepRule.values.where((r) => r.name == v).firstOrNull ?? KeepRule.organized;
  }

  Future<void> setKeepRule(KeepRule rule) => SettingsStore(db).set(keepRuleKey, rule.name);

  // --- Consultas (só catálogo) ----------------------------------------------------

  /// Arquivos que podem entrar: conteúdo conferido e ainda válido (mesmo
  /// tamanho e data da conferência), presentes, não corrompidos, de foto,
  /// RAW ou vídeo, com tamanho > 0.
  static const _okFiles = '''
    SELECT fi.id, fi.source_id, fi.content_id, fi.rel_path, fi.size_bytes, fi.mtime, fi.ctime
    FROM file_instances fi JOIN contents c ON c.id = fi.content_id
    WHERE fi.hash_status = 'done' AND fi.availability = 'present' AND fi.integrity != 'possibly_corrupt'
      AND fi.size_bytes > 0 AND fi.hashed_size = fi.size_bytes AND fi.hashed_mtime IS fi.mtime
      AND c.media_type IN ('photo', 'raw', 'video')''';

  /// Dispositivos com repetidos (com o motivo, se não der para limpar agora).
  Future<List<DedupeSourceSummary>> summaries() async {
    final rows = await db
        .customSelect(
          'WITH ok AS ($_okFiles), g AS (SELECT source_id, content_id, COUNT(*) AS n, MAX(size_bytes) AS sz '
          'FROM ok GROUP BY source_id, content_id HAVING COUNT(*) > 1) '
          'SELECT s.id, s.name, s.kind, COUNT(*) AS groups, SUM(g.n - 1) AS extra, SUM((g.n - 1) * g.sz) AS bytes '
          'FROM g JOIN sources s ON s.id = g.source_id WHERE s.forgotten_at IS NULL '
          'GROUP BY s.id ORDER BY bytes DESC',
          readsFrom: {db.fileInstances, db.contents, db.sources},
        )
        .get();
    return [
      for (final r in rows)
        DedupeSourceSummary(
          sourceId: r.read<String>('id'),
          name: r.read<String>('name'),
          kind: r.read<String>('kind'),
          groups: r.read<int>('groups'),
          extraFiles: r.read<int>('extra'),
          reclaimableBytes: r.read<int>('bytes'),
          blocker: await _blocker((await sources.byId(r.read<String>('id')))!),
        ),
    ];
  }

  /// Grupos de repetidos de um dispositivo, do que libera mais espaço para o
  /// que libera menos, com a cópia sugerida pela [rule] (padrão: a salva).
  Future<List<DedupeGroup>> groups(String sourceId, {KeepRule? rule, Set<int>? contentIds}) async {
    final keep = rule ?? await keepRule();
    final source = await sources.byId(sourceId);
    final display = source == null || sources.accessRoot(source) == null ? null : sources.displayRoot(source);
    final only = contentIds == null ? '' : 'AND ok.content_id IN (${contentIds.map((_) => '?').join(',')})';
    final rows = await db
        .customSelect(
          'WITH ok AS ($_okFiles AND fi.source_id = ?), dup AS (SELECT content_id FROM ok GROUP BY content_id '
          'HAVING COUNT(*) > 1) '
          'SELECT ok.*, c.size_bytes AS csize, c.media_type, mm.width, mm.height, mm.eff_local '
          'FROM ok JOIN dup ON dup.content_id = ok.content_id JOIN contents c ON c.id = ok.content_id '
          'LEFT JOIN media_metadata mm ON mm.content_id = ok.content_id WHERE 1 = 1 $only '
          'ORDER BY c.size_bytes DESC, ok.content_id, ok.rel_path',
          variables: [
            Variable.withString(sourceId),
            for (final id in contentIds ?? const <int>{}) Variable.withInt(id),
          ],
          readsFrom: {db.fileInstances, db.contents, db.mediaMetadata},
        )
        .get();
    final out = <DedupeGroup>[];
    List<DedupeCopy> copies = [];
    QueryRow? first;
    void flush() {
      if (first == null || copies.length < 2) return;
      final (keepId, reason) = suggestKeep(copies, keep);
      out.add(
        DedupeGroup(
          contentId: first.read<int>('content_id'),
          sizeBytes: first.read<int>('csize'),
          mediaType: first.read<String>('media_type'),
          copies: copies,
          suggestedKeepId: keepId,
          reason: reason,
          width: first.readNullable<int>('width'),
          height: first.readNullable<int>('height'),
          captureLocal: first.readNullable<String>('eff_local'),
        ),
      );
    }

    for (final r in rows) {
      if (first == null || first.read<int>('content_id') != r.read<int>('content_id')) {
        flush();
        first = r;
        copies = [];
      }
      copies.add(
        DedupeCopy(
          instanceId: r.read<int>('id'),
          relPath: r.read<String>('rel_path'),
          sizeBytes: r.read<int>('size_bytes'),
          mtime: r.readNullable<int>('mtime'),
          ctime: r.readNullable<int>('ctime'),
          fullPath: display == null ? null : joinNative(display, r.read<String>('rel_path')),
        ),
      );
    }
    flush();
    return out;
  }

  static final _dateFolder = RegExp(r'^(19|20)\d{2}($|[-_. ]\d{1,2}|\s)');
  static final _copyMark = RegExp(
    r'(\(\d+\)|[ _-](c[oó]pia|copy)( ?\(\d+\))?|^(c[oó]pia de|copy of) .*)$',
    caseSensitive: false,
  );

  static bool _inDateFolder(DedupeCopy c) => c.folder.split('/').any(_dateFolder.hasMatch);

  static bool _hasCopyMark(DedupeCopy c) {
    final dot = c.name.lastIndexOf('.');
    return _copyMark.hasMatch(dot > 0 ? c.name.substring(0, dot) : c.name);
  }

  static int _compareOrganized(DedupeCopy a, DedupeCopy b) {
    int key(bool v) => v ? 0 : 1;
    for (final c in [
      key(_inDateFolder(a)).compareTo(key(_inDateFolder(b))),
      key(!_hasCopyMark(a)).compareTo(key(!_hasCopyMark(b))),
      '/'.allMatches(a.relPath).length.compareTo('/'.allMatches(b.relPath).length),
      a.relPath.length.compareTo(b.relPath.length),
      a.relPath.toLowerCase().compareTo(b.relPath.toLowerCase()),
    ]) {
      if (c != 0) return c;
    }
    return a.instanceId.compareTo(b.instanceId);
  }

  /// Qual cópia fica pela [rule], com a frase do porquê.
  static (int, String) suggestKeep(List<DedupeCopy> copies, KeepRule rule) {
    const never = 1 << 62;
    final sorted = [...copies]
      ..sort(
        rule == KeepRule.oldest
            ? (a, b) {
                for (final c in [
                  (a.ctime ?? never).compareTo(b.ctime ?? never),
                  (a.mtime ?? never).compareTo(b.mtime ?? never),
                ]) {
                  if (c != 0) return c;
                }
                return _compareOrganized(a, b);
              }
            : _compareOrganized,
      );
    final keep = sorted.first;
    final String reason;
    if (rule == KeepRule.oldest) {
      reason = 'Sugerida: a mais antiga neste dispositivo.';
    } else if (_inDateFolder(keep) && copies.any((c) => !_inDateFolder(c))) {
      reason = 'Sugerida: está numa pasta organizada por data.';
    } else if (!_hasCopyMark(keep) && copies.any(_hasCopyMark)) {
      reason = 'Sugerida: o nome não tem "(1)" nem "cópia".';
    } else {
      reason = 'Sugerida: o caminho mais curto.';
    }
    return (keep.instanceId, reason);
  }

  // --- Prévia e confirmação --------------------------------------------------------

  /// Por que não dá para limpar neste dispositivo agora (`null` = dá).
  Future<String?> _blocker(SourceRow s) async {
    if (s.kind == 'phone') return 'Celular: o FotoAtlas nunca remove nada do celular.';
    if (s.kind == 'usb_stick' || s.kind == 'memory_card') {
      return 'Pendrive e cartão de memória não têm Lixeira no Windows: o FotoAtlas não remove nada neles.';
    }
    if (_bin == null) {
      return 'A Lixeira do Windows não está disponível agora (o componente de dispositivos não iniciou). '
          'Feche e abra o FotoAtlas.';
    }
    if (sources.accessRoot(s) == null) return '"${s.name}" está desconectado. Conecte para limpar.';
    if (scans.runningProgress.values.any((p) => p.sourceId == s.id)) {
      return '"${s.name}" está sendo escaneado. Espere o escaneamento terminar.';
    }
    final open = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM operations WHERE kind = ? AND dest_source_id = ? AND status IN '
          '(${OpStatus.open.map((_) => '?').join(',')})',
          variables: [
            Variable.withString(dedupeOpKind),
            Variable.withString(s.id),
            for (final st in OpStatus.open) Variable.withString(st),
          ],
        )
        .getSingle();
    if (open.read<int>('n') > 0) {
      return 'Já há uma limpeza deste dispositivo em andamento. Continue ou cancele em Tarefas.';
    }
    return null;
  }

  /// O que vai para a Lixeira com as [choices] (um grupo = só a cópia
  /// escolhida fica). Só lê o catálogo.
  Future<DedupePreview> preview(String sourceId, List<DedupeChoice> choices) async {
    final source = await sources.byId(sourceId);
    if (source == null) {
      return DedupePreview(
        sourceId: sourceId,
        sourceName: '?',
        removals: const [],
        groups: 0,
        blocker: 'Dispositivo não encontrado.',
      );
    }
    final wanted = {for (final c in choices) c.contentId: c.keepInstanceId};
    final current = {for (final g in await groups(sourceId, contentIds: wanted.keys.toSet())) g.contentId: g};
    final removals = <DedupeRemoval>[];
    final skipped = <String>[];
    var included = 0;
    for (final MapEntry(key: contentId, value: keepId) in wanted.entries) {
      final g = current[contentId];
      final keep = g?.copies.where((c) => c.instanceId == keepId).firstOrNull;
      if (g == null || keep == null) {
        skipped.add('Um grupo mudou desde que a tela foi aberta (uma cópia sumiu ou ainda está sendo conferida).');
        continue;
      }
      included++;
      for (final c in g.copies) {
        if (c.instanceId == keepId) continue;
        removals.add(
          DedupeRemoval(
            contentId: contentId,
            instanceId: c.instanceId,
            relPath: c.relPath,
            sizeBytes: c.sizeBytes,
            mtime: c.mtime,
            keepInstanceId: keepId,
            keepRelPath: keep.relPath,
          ),
        );
      }
    }
    return DedupePreview(
      sourceId: sourceId,
      sourceName: source.name,
      removals: removals,
      groups: included,
      skipped: skipped,
      blocker: await _blocker(source) ?? (choices.isEmpty ? 'Nenhum grupo marcado.' : null),
    );
  }

  /// Confirma a prévia: operação e itens no diário (uma transação) e fila.
  Future<String> start(DedupePreview preview) async {
    if (!preview.canStart) throw StateError(preview.blocker ?? 'A prévia não tem nada para remover.');
    final source = await sources.byId(preview.sourceId);
    final blocker = source == null ? 'Dispositivo não encontrado.' : await _blocker(source);
    if (blocker != null) throw StateError(blocker);
    // Nunca a última cópia: em cada grupo, a que fica não está entre as que saem.
    final leaving = {for (final r in preview.removals) r.instanceId};
    for (final r in preview.removals) {
      if (leaving.contains(r.keepInstanceId)) throw StateError('A cópia que fica não pode sair.');
    }
    final contentIds = {for (final r in preview.removals) r.contentId};
    final shas = {
      for (final r
          in await db
              .customSelect(
                'SELECT id, sha256 FROM contents WHERE id IN (${contentIds.map((_) => '?').join(',')})',
                variables: [for (final id in contentIds) Variable.withInt(id)],
              )
              .get())
        r.read<int>('id'): r.read<Uint8List>('sha256'),
    };
    final ordered = [...preview.removals]..sort((a, b) => a.contentId.compareTo(b.contentId));
    final id = uuidV4();
    final now = nowMs();
    await db.transaction(() async {
      await db.customInsert(
        'INSERT INTO operations (id, kind, status, dest_source_id, dest_root_rel, params_json, created_at, '
        'confirmed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(id),
          Variable.withString(dedupeOpKind),
          Variable.withString(OpStatus.confirmed),
          Variable.withString(preview.sourceId),
          Variable.withString(''),
          Variable.withString(jsonEncode({'groups': preview.groups, 'bytes': preview.bytes})),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
        updates: {db.operations},
      );
      var seq = 0;
      for (final r in ordered) {
        seq++;
        // dst_rel_path_planned = a cópia que fica (o grupo); expected_sha256 = o conteúdo do grupo.
        await db.customInsert(
          'INSERT INTO operation_items (operation_id, seq, src_source_id, src_rel_path, src_instance_id, '
          'expected_size, expected_sha256, expected_mtime, dst_source_id, dst_rel_path_planned, state, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(id),
            Variable.withInt(seq),
            Variable.withString(preview.sourceId),
            Variable.withString(r.relPath),
            Variable.withInt(r.instanceId),
            Variable.withInt(r.sizeBytes),
            Variable.withBlob(shas[r.contentId]!),
            Variable(r.mtime),
            Variable.withString(preview.sourceId),
            Variable.withString(r.keepRelPath),
            Variable.withString(ItemState.pending),
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
        'Limpeza confirmada: ${preview.files} arquivo(s) de ${preview.groups} grupo(s) para a Lixeira.',
      );
    });
    _enqueue(id);
    return id;
  }

  // --- Controle -------------------------------------------------------------------

  Future<bool> isDedupe(String operationId) async => (await journal.op(operationId))?.kind == dedupeOpKind;

  Future<void> resume(String operationId) async {
    final op = await journal.op(operationId);
    if (op == null || op.kind != dedupeOpKind || !OpStatus.open.contains(op.status)) return;
    _pauseRequested.remove(operationId);
    _enqueue(operationId);
  }

  Future<void> pause(String operationId) async {
    if (_runningOp == operationId) {
      _pauseRequested.add(operationId);
      _requestStop();
      await _draining;
      return;
    }
    _queue.remove(operationId);
    final op = await journal.op(operationId);
    if (op != null && (op.status == OpStatus.confirmed || op.status == OpStatus.running)) {
      await journal.setStatus(operationId, OpStatus.paused);
    }
  }

  /// Cancela o que ainda não foi para a Lixeira (o que já foi fica lá).
  Future<void> cancel(String operationId) async {
    if (_runningOp == operationId) {
      _cancelRequested.add(operationId);
      _requestStop();
      await _draining;
      return;
    }
    _queue.remove(operationId);
    final op = await journal.op(operationId);
    if (op != null && OpStatus.open.contains(op.status)) {
      await _cancelled(op.id, op.status);
    }
  }

  Future<void> _cancelled(String opId, String from) async {
    await journal.setStatus(opId, OpStatus.cancelled, finished: true);
    await journal.event(opId, null, from, OpStatus.cancelled, 'Cancelada; o que já foi para a Lixeira fica lá.');
    await _emitProgress(opId, running: false);
  }

  /// Tenta de novo os grupos pulados (conferidos de novo do zero).
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

  // --- Execução -------------------------------------------------------------------

  void _enqueue(String id) {
    if (_disposed) return;
    if (!_queue.contains(id) && _runningOp != id) _queue.add(id);
    _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_disposed) {
      final id = _queue.removeAt(0);
      _runningOp = id;
      _stop = Completer<void>();
      try {
        await _runOp(id);
      } finally {
        _runningOp = null;
        _stop = null;
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

  /// Interrompe uma conferência (SHA-256) em andamento.
  void _requestStop() {
    final s = _stop;
    if (s != null && !s.isCompleted) s.complete();
  }

  bool _stopping(String opId) => _disposed || _pauseRequested.contains(opId) || _cancelRequested.contains(opId);

  Future<void> _runOp(String opId) async {
    final op = await journal.op(opId);
    if (op == null || op.kind != dedupeOpKind || !OpStatus.open.contains(op.status)) return;
    final source = await sources.byId(op.destSourceId!);
    final root = source == null ? null : sources.accessRoot(source);
    if (source == null || root == null) {
      await _pauseOp(opId, '"${source?.name ?? '?'}" está desconectado. Conecte e toque em Continuar.');
      return;
    }
    await journal.setStatus(opId, OpStatus.running, started: op.startedAt == null);
    await _recoverOperation(op, root);
    await _emitProgress(opId);
    while (true) {
      if (_stopping(opId)) return _afterStop(opId);
      final pending = await journal.itemsIn(opId, {ItemState.pending});
      if (pending.isEmpty) break;
      final keep = pending.first.dstRelPathPlanned;
      final group = [
        for (final i in pending)
          if (i.dstRelPathPlanned == keep) i,
      ];
      final pauseReason = await _runGroup(op, root, group);
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
      await _cancelled(opId, OpStatus.running);
    } else {
      await _pauseOp(opId, _disposed ? 'Interrompida porque o FotoAtlas foi fechado. Toque em Continuar.' : null);
    }
  }

  /// Um grupo: confere tudo de novo e só então manda as cópias que saem para
  /// a Lixeira, uma a uma. Devolve o motivo para pausar, ou `null`.
  Future<String?> _runGroup(OperationRow op, String root, List<OperationItemRow> items) async {
    final keepRel = items.first.dstRelPathPlanned;
    final sha = items.first.expectedSha256!;
    final keepPath = joinNative(root, keepRel);
    await _emitProgress(op.id, step: 'checking', current: keepRel);

    // 1. A cópia que fica: está lá, com o mesmo conteúdo.
    final keepInfo = _attributes(keepPath);
    if (keepInfo == null) {
      if (!directoryAccessible(root)) return _disconnected(op);
      return _skipGroup(op, items, 'keep_missing', 'A cópia que ia ficar ("${_label(keepRel)}") não está mais lá.');
    }
    final keepHash = await _hash(keepPath);
    if (keepHash == null) return null; // pausa ou cancelamento pedido
    if (keepHash is! PumpDone || !_eq(keepHash.sha256, sha)) {
      return _skipGroup(
        op,
        items,
        'keep_changed',
        'A cópia que ia ficar ("${_label(keepRel)}") mudou ou não pôde ser lida.',
      );
    }
    final keepIdentity = _identity(keepPath);
    if (keepIdentity == null) {
      return _skipGroup(op, items, 'keep_changed', 'A cópia que ia ficar ("${_label(keepRel)}") não pôde ser aberta.');
    }

    // 2. Cada cópia que sai: mesmo tamanho e data da prévia, mesmo conteúdo e
    // outro arquivo físico (não o mesmo com outro nome nem um link).
    final observed = <int, int>{};
    for (final item in items) {
      if (_stopping(op.id)) return null;
      final path = joinNative(root, item.srcRelPath);
      await _emitProgress(op.id, step: 'checking', current: item.srcRelPath);
      final info = _attributes(path);
      if (info == null) {
        if (!directoryAccessible(root)) return _disconnected(op);
        return _skipGroup(op, items, 'source_missing', '"${_label(item.srcRelPath)}" não está mais lá.');
      }
      if (info.size != item.expectedSize || (item.expectedMtime != null && info.mtime != item.expectedMtime)) {
        return _skipGroup(op, items, 'source_changed', '"${_label(item.srcRelPath)}" mudou desde a prévia.');
      }
      final h = await _hash(path);
      if (h == null) return null;
      if (h is! PumpDone || !_eq(h.sha256, sha)) {
        return _skipGroup(op, items, 'source_changed', '"${_label(item.srcRelPath)}" mudou ou não pôde ser lido.');
      }
      final identity = _identity(path);
      if (identity == null || identity == keepIdentity) {
        return _skipGroup(
          op,
          items,
          'same_file',
          '"${_label(item.srcRelPath)}" é o mesmo arquivo que fica (outro nome para ele), não uma cópia.',
        );
      }
      observed[item.id] = info.mtime;
    }
    crashpoint('dedupe.after_check');

    // 3. Para a Lixeira, uma de cada vez.
    for (final item in items) {
      if (_stopping(op.id)) return null;
      final now = _attributes(keepPath);
      if (now == null || now.size != keepInfo.size || now.mtime != keepInfo.mtime) {
        return _skipGroup(
          op,
          items,
          'keep_changed',
          'A cópia que ia ficar ("${_label(keepRel)}") mudou durante a limpeza.',
        );
      }
      // Intenção no diário antes de mexer no disco.
      if (!await journal.transition(
        op.id,
        item.id,
        ItemState.pending,
        ItemState.publishing,
        set: {'src_sha256': sha, 'expected_mtime': observed[item.id], 'attempts': item.attempts + 1},
      )) {
        continue;
      }
      crashpoint('dedupe.after_publishing_commit');
      await _emitProgress(op.id, step: 'recycling', current: item.srcRelPath);
      final outcome = await _bin!.recycle(
        joinNative(root, item.srcRelPath),
        size: item.expectedSize,
        mtime: observed[item.id],
      );
      if (outcome.recycled) {
        crashpoint('dedupe.after_recycle');
        await _commitRecycled(op, item, message: 'Foi para a Lixeira. Ficou "${_label(keepRel)}".');
        crashpoint('dedupe.after_published_commit');
        continue;
      }
      switch (outcome.refusal!) {
        case RecycleRefusal.unavailable:
          await journal.transition(op.id, item.id, ItemState.publishing, ItemState.pending, message: outcome.message);
          return 'A Lixeira do Windows não respondeu agora. Nada se perdeu: toque em Continuar.';
        case RecycleRefusal.noRecycleBin:
          await journal.transition(
            op.id,
            item.id,
            ItemState.publishing,
            ItemState.failed,
            set: OperationJournal.err('no_recycle_bin', _noBinMessage),
          );
          // Vale para o disco inteiro: nada mais sai dele.
          for (final rest in await journal.itemsIn(op.id, {ItemState.pending})) {
            await journal.transition(
              op.id,
              rest.id,
              ItemState.pending,
              ItemState.failed,
              set: OperationJournal.err('no_recycle_bin', _noBinMessage),
            );
          }
          return null;
        case RecycleRefusal.changed || RecycleRefusal.missing || RecycleRefusal.inUse || RecycleRefusal.error:
          await journal.transition(
            op.id,
            item.id,
            ItemState.publishing,
            ItemState.failed,
            set: OperationJournal.err(switch (outcome.refusal!) {
              RecycleRefusal.changed => 'source_changed',
              RecycleRefusal.missing => 'source_missing',
              RecycleRefusal.inUse => 'in_use',
              _ => 'recycle_error',
            }, '${outcome.message} O arquivo ficou onde estava.'),
          );
      }
    }
    return null;
  }

  static const _noBinMessage = 'Neste dispositivo o Windows apagaria de vez (não há Lixeira): nada foi removido dele.';

  /// O grupo inteiro fica como está, com o motivo.
  Future<String?> _skipGroup(OperationRow op, List<OperationItemRow> items, String code, String reason) async {
    for (final i in items) {
      await journal.transition(
        op.id,
        i.id,
        ItemState.pending,
        ItemState.failed,
        set: OperationJournal.err(code, 'Grupo pulado: $reason Nada deste grupo foi para a Lixeira agora.'),
      );
    }
    return null;
  }

  /// Foi para a Lixeira: diário e catálogo (o arquivo não está mais na pasta)
  /// numa transação.
  Future<bool> _commitRecycled(OperationRow op, OperationItemRow item, {required String message}) => journal.transition(
    op.id,
    item.id,
    ItemState.publishing,
    ItemState.published,
    message: message,
    also: () async {
      final instance = item.srcInstanceId;
      if (instance == null) return;
      await db.customUpdate(
        "UPDATE file_instances SET availability = 'missing', missing_confirmed_at = ? WHERE id = ?",
        variables: [Variable.withInt(nowMs()), Variable.withInt(instance)],
        updates: {db.fileInstances},
      );
    },
  );

  // --- Recuperação -----------------------------------------------------------------

  /// Na abertura (idempotente): operações abertas ficam pausadas e cada
  /// arquivo "a caminho da Lixeira" é decidido pelo disco.
  Future<RecoveryReport> recoverAll() async {
    final report = RecoveryReport();
    final ops = await (db.select(
      db.operations,
    )..where((o) => o.status.isIn(OpStatus.open) & o.kind.equals(dedupeOpKind))).get();
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
      crashpoint('dedupe.recover.after_operation');
      await journal.finishIfDone(op.id);
    }
    return report;
  }

  /// `publishing` = a intenção foi gravada; o disco diz se aconteceu. Ainda lá
  /// e igual → volta para a fila (será conferido de novo do zero); não está
  /// mais lá → foi para a Lixeira; lá mas diferente → fica, com o motivo.
  Future<void> _recoverOperation(OperationRow op, String root, [RecoveryReport? report]) async {
    for (final item in await journal.itemsIn(op.id, {ItemState.publishing})) {
      report?.examined++;
      final info = _attributes(joinNative(root, item.srcRelPath));
      if (info == null) {
        await _commitRecycled(
          op,
          item,
          message:
              'Recuperação: o arquivo não está mais na pasta (foi para a Lixeira). Ficou "${_label(item.dstRelPathPlanned)}".',
        );
        report?.published++;
      } else if (info.size == item.expectedSize && (item.expectedMtime == null || info.mtime == item.expectedMtime)) {
        await journal.transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.pending,
          message: 'Recuperação: o arquivo ainda não tinha ido para a Lixeira; será conferido de novo.',
        );
        report?.resumedAsPending++;
      } else {
        await journal.transition(
          op.id,
          item.id,
          ItemState.publishing,
          ItemState.failed,
          set: OperationJournal.err('source_changed', 'O arquivo mudou: ficou onde estava.'),
          message: 'Recuperação: o arquivo mudou; não foi para a Lixeira.',
        );
        report?.needsAttention++;
      }
    }
  }

  // --- Relatório --------------------------------------------------------------------

  /// Relatório em CSV (`;`, UTF-8 com BOM): o que saiu e qual cópia ficou.
  Future<String> exportCsv(String operationId) async {
    final op = await journal.op(operationId);
    if (op == null || op.kind != dedupeOpKind) throw StateError('Limpeza não encontrada.');
    final source = await sources.byId(op.destSourceId!);
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
    final recycled = rows.where((r) => r.state == ItemState.published).toList();
    final groupOf = <String, int>{};
    final out = StringBuffer('﻿')
      ..writeln('# FotoAtlas — relatório da limpeza de repetidos ${op.id}')
      ..writeln('# Dispositivo: ${q(source?.name)}')
      ..writeln('# Situação: ${op.status}')
      ..writeln(
        '# Foram para a Lixeira do Windows: ${recycled.length} arquivo(s), '
        '${recycled.fold(0, (s, r) => s + r.expectedSize)} bytes (dá para restaurar pela Lixeira).',
      )
      ..writeln('grupo;situação;arquivo;cópia que ficou;tamanho (bytes);sha256;motivo');
    for (final r in rows) {
      final group = groupOf.putIfAbsent(r.dstRelPathPlanned, () => groupOf.length + 1);
      out.writeln(
        [
          group,
          switch (r.state) {
            ItemState.published => 'foi para a Lixeira',
            ItemState.failed => 'ficou (não removido)',
            ItemState.pending => 'na fila',
            ItemState.publishing => 'indo para a Lixeira',
            _ => r.state,
          },
          q(r.srcRelPath),
          q(r.dstRelPathPlanned),
          r.expectedSize,
          hex(r.expectedSha256),
          q(r.lastErrorMessage),
        ].join(';'),
      );
    }
    return out.toString();
  }

  // --- Auxiliares --------------------------------------------------------------------

  /// SHA-256 só lendo o arquivo; `null` se a pausa/cancelamento foi pedida.
  Future<PumpResult?> _hash(String path) async {
    final stop = _stop;
    final r = useIsolate
        ? await hashDestFileInIsolate(path, stop: stop?.future ?? Completer<void>().future)
        : await hashDestFile(path, shouldStop: () => stop?.isCompleted ?? false);
    if (r is PumpStopped) return null;
    return r ?? const PumpFailed(PumpFailure.sourceMissing, 'O arquivo não está mais lá.');
  }

  static String? _identity(String path) {
    try {
      final f = SourceFile.open(path);
      try {
        return f.identity();
      } finally {
        f.close();
      }
    } on Win32Exception {
      return null;
    }
  }

  static SourceFileInfo? _attributes(String path) {
    try {
      final info = attributesOf(path);
      return info.attributes & fileAttributeDirectory != 0 ? null : info;
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

  static String _label(String rel) => rel.replaceAll('/', ' › ');

  Future<String> _disconnected(OperationRow op) async {
    final source = await sources.byId(op.destSourceId!);
    return '"${source?.name ?? '?'}" foi desconectado. Nada se perdeu: conecte e toque em Continuar.';
  }

  Future<void> _pauseOp(String opId, String? reason) async {
    await journal.pause(opId, reason);
    await _emitProgress(opId, running: false);
  }

  Future<void> _emitProgress(String opId, {bool running = true, String? step, String? current}) async {
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
        currentName: current?.split('/').last,
        step: step ?? 'recycling',
        running: running && _runningOp == opId,
      ),
    );
  }

  /// Para no próximo ponto seguro (entre arquivos) e espera até [timeout].
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposed = true;
    _queue.clear();
    _requestStop();
    final d = _draining;
    var ok = true;
    if (d != null) ok = await d.then((_) => true).timeout(timeout, onTimeout: () => false);
    await _progress.close();
    return ok;
  }
}
