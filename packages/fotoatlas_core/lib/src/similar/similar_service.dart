import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../sources/sources_service.dart';
import '../thumbs/thumbnail_service.dart';
import '../util/clock.dart';
import 'similar_grouping.dart';
import 'visual_hash.dart';

/// Situação da fila de impressões visuais, para a interface.
class SimilarStatus {
  const SimilarStatus({this.running = false, this.paused = false, this.done = 0, this.total = 0, this.waiting = false});
  final bool running;
  final bool paused;
  final int done;
  final int total;

  /// Parada esperando outra tarefa terminar (cede a vez).
  final bool waiting;
}

/// Resumo para a tela: quantas fotos já têm impressão e quantas faltam.
class SimilarOverview {
  const SimilarOverview({required this.photos, required this.analyzed, required this.dismissedPairs});

  /// Fotos conferidas (conteúdos de foto ou RAW).
  final int photos;

  /// Com impressão visual calculada (inclui as lisas, que ficam de fora).
  final int analyzed;
  final int dismissedPairs;
}

/// Fotos parecidas (Fase 9, spec §9): calcula a impressão visual de cada foto
/// a partir da miniatura em cache e sugere grupos com nível de confiança.
///
/// Só sugere: nenhum arquivo é tocado. A origem só é lida para gerar a
/// miniatura (como na Biblioteca). "Não são parecidas" grava só no catálogo.
/// A fila é leve: uma foto por vez, cede a vez a qualquer tarefa pesada e
/// nunca gera miniatura lendo do celular (usa só a que já estiver em cache).
class SimilarService {
  SimilarService(this.db, this.sources, this.thumbnails, {bool Function()? busy, this.useIsolate = true})
    : _busy = busy ?? (() => false);

  final CatalogDatabase db;
  final SourcesService sources;
  final ThumbnailService thumbnails;
  final bool useIsolate;
  final bool Function() _busy;

  final _status = StreamController<SimilarStatus>.broadcast();
  final _changes = StreamController<void>.broadcast();
  SimilarStatus _current = const SimilarStatus();
  Future<void>? _run;
  bool _stop = false;
  bool _disposed = false;
  bool _pausedByUser = false;
  final Set<int> _failed = {};
  Timer? _retry;
  StreamSubscription<Object?>? _autoSources;

  Stream<SimilarStatus> get status => _status.stream;
  SimilarStatus get current => _current;
  bool get isRunning => _run != null;

  /// Impressões novas ou sugestões descartadas/restauradas.
  Stream<void> get changes => _changes.stream;

  static const _batch = 24;

  /// Automática: começa agora, quando uma fonte conecta e, se estava
  /// esperando outra tarefa, tenta de novo a cada 30 s.
  void enableAuto() {
    _autoSources ??= sources.stateChanges.listen((_) {
      _failed.clear();
      _autoStart();
    });
    _retry ??= Timer.periodic(const Duration(seconds: 30), (_) => _autoStart());
    _autoStart();
  }

  void _autoStart() {
    if (_disposed || _pausedByUser || _run != null) return;
    start().ignore();
  }

  /// Calcula o que falta. Chamar de novo durante uma rodada devolve a mesma.
  Future<void> start() {
    if (_disposed) return Future.value();
    _pausedByUser = false;
    return _run ??= _loop().whenComplete(() => _run = null);
  }

  Future<void> pause() async {
    _pausedByUser = true;
    _stop = true;
    await _run;
    _emit(SimilarStatus(paused: true, done: _current.done, total: _current.total));
  }

  Future<void> waitIdle() async {
    while (_run != null) {
      await _run;
    }
  }

  /// Fotos (e RAW) conferidas que ainda não têm impressão visual atual.
  static const _pendingWhere =
      "c.media_type IN ('photo','raw') AND (vh.content_id IS NULL OR vh.algorithm <> ${VisualHash.algorithm}) "
      "AND EXISTS (SELECT 1 FROM file_instances fi JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL "
      "WHERE fi.content_id = c.id AND fi.availability = 'present' AND fi.hash_status = 'done')";

  Future<int> _pendingCount() async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM contents c LEFT JOIN visual_hashes vh ON vh.content_id = c.id WHERE $_pendingWhere',
              )
              .getSingle())
          .read<int>('n');

  Future<void> _loop() async {
    _stop = false;
    final total = await _pendingCount() - _failed.length;
    if (total <= 0) return;
    if (_busy()) {
      _emit(SimilarStatus(waiting: true, total: total));
      return;
    }
    var done = 0;
    _emit(SimilarStatus(running: true, total: total));
    var lastId = 0;
    var any = false;
    try {
      while (!_stop && !_disposed) {
        if (_busy()) {
          _emit(SimilarStatus(waiting: true, done: done, total: total));
          return;
        }
        final rows = await db
            .customSelect(
              'SELECT c.id, hex(c.sha256) AS sha FROM contents c LEFT JOIN visual_hashes vh ON vh.content_id = c.id '
              'WHERE c.id > ? AND $_pendingWhere ORDER BY c.id LIMIT ?',
              variables: [Variable.withInt(lastId), Variable.withInt(_batch)],
            )
            .get();
        if (rows.isEmpty) break;
        lastId = rows.last.read<int>('id');
        final paths = <int, String>{};
        for (final r in rows) {
          if (_stop || _disposed) break;
          final id = r.read<int>('id');
          if (_failed.contains(id)) continue;
          final path = await thumbnails.thumbnail(id, allowPhone: false);
          if (path == null) {
            _failed.add(id);
          } else {
            paths[id] = path;
          }
        }
        if (paths.isEmpty) continue;
        final list = paths.entries.toList();
        final files = [for (final e in list) e.value];
        final hashes = useIsolate ? await _hashFilesInIsolate(files) : _hashFiles(files);
        final now = nowMs();
        await db.transaction(() async {
          for (var k = 0; k < list.length; k++) {
            final h = hashes[k];
            if (h == null) {
              _failed.add(list[k].key);
              continue;
            }
            await db.customStatement(
              'INSERT OR REPLACE INTO visual_hashes (content_id, hash_p, hash_d, flat, algorithm, computed_at) '
              'VALUES (?, ?, ?, ?, ?, ?)',
              [list[k].key, h.perceptual, h.gradient, h.flat ? 1 : 0, VisualHash.algorithm, now],
            );
            any = true;
          }
        });
        done += list.length;
        _emit(SimilarStatus(running: true, done: done, total: total));
      }
      _emit(SimilarStatus(done: done, total: total));
    } finally {
      if (any && !_changes.isClosed) _changes.add(null);
    }
  }

  void _emit(SimilarStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<SimilarOverview> overview() async {
    final r = await db
        .customSelect(
          "SELECT (SELECT COUNT(*) FROM contents c WHERE c.media_type IN ('photo','raw')) AS photos, "
          '(SELECT COUNT(*) FROM visual_hashes WHERE algorithm = ${VisualHash.algorithm}) AS analyzed, '
          '(SELECT COUNT(*) FROM visual_dismissals) AS dismissed',
        )
        .getSingle();
    return SimilarOverview(
      photos: r.read<int>('photos'),
      analyzed: r.read<int>('analyzed'),
      dismissedPairs: r.read<int>('dismissed'),
    );
  }

  /// Grupos de fotos parecidas com pelo menos [minLevel] de confiança, sem os
  /// pares descartados. Só fotos com alguma cópia conhecida no catálogo.
  Future<List<SimilarGroup>> groups({SimilarLevel minLevel = SimilarLevel.maybe}) async {
    final rows = await db
        .customSelect(
          'SELECT vh.content_id, vh.hash_p, vh.hash_d, '
          "CASE WHEN mm.eff_confidence IN ('high','medium') THEN mm.eff_day END AS day "
          'FROM visual_hashes vh LEFT JOIN media_metadata mm ON mm.content_id = vh.content_id '
          'WHERE vh.flat = 0 AND vh.algorithm = ${VisualHash.algorithm} '
          'AND EXISTS (SELECT 1 FROM file_instances fi JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL '
          "WHERE fi.content_id = vh.content_id AND fi.availability <> 'missing')",
        )
        .get();
    final items = [
      for (final r in rows)
        SimilarCandidate(
          r.read<int>('content_id'),
          VisualHash(r.read<int>('hash_p'), r.read<int>('hash_d')),
          day: r.readNullable<String>('day'),
        ),
    ];
    final dismissed = {
      for (final r in await db.customSelect('SELECT content_a, content_b FROM visual_dismissals').get())
        (r.read<int>('content_a'), r.read<int>('content_b')),
    };
    return useIsolate ? _groupsInIsolate(items, dismissed, minLevel) : _groups(items, dismissed, minLevel);
  }

  /// "Não são parecidas": nenhuma das fotos de [contentIds] volta a ser
  /// sugerida junto com as outras. Só catálogo. Devolve os pares gravados
  /// (para o "Desfazer").
  Future<List<(int, int)>> dismiss(List<int> contentIds) async {
    final pairs = <(int, int)>{
      for (var i = 0; i < contentIds.length; i++)
        for (var j = i + 1; j < contentIds.length; j++)
          if (contentIds[i] != contentIds[j]) pairKey(contentIds[i], contentIds[j]),
    }.toList();
    await _insertDismissals(pairs);
    return pairs;
  }

  /// "Tirar do grupo": [contentId] deixa de ser sugerida com as [others].
  Future<List<(int, int)>> dismissFrom(int contentId, List<int> others) async {
    final pairs = <(int, int)>{
      for (final o in others)
        if (o != contentId) pairKey(contentId, o),
    }.toList();
    await _insertDismissals(pairs);
    return pairs;
  }

  Future<void> _insertDismissals(List<(int, int)> pairs) async {
    if (pairs.isEmpty) return;
    final now = nowMs();
    await db.transaction(() async {
      for (final (a, b) in pairs) {
        await db.customStatement(
          'INSERT OR IGNORE INTO visual_dismissals (content_a, content_b, created_at) VALUES (?, ?, ?)',
          [a, b, now],
        );
      }
    });
    _changes.add(null);
  }

  /// Desfaz um "Não são parecidas" (os mesmos pares que ele devolveu).
  Future<void> undoDismiss(List<(int, int)> pairs) async {
    await db.transaction(() async {
      for (final (a, b) in pairs) {
        await db.customStatement('DELETE FROM visual_dismissals WHERE content_a = ? AND content_b = ?', [a, b]);
      }
    });
    _changes.add(null);
  }

  /// "Mostrar de novo as sugestões descartadas" (só catálogo).
  Future<int> restoreAllDismissed() async {
    final n = await db.customUpdate('DELETE FROM visual_dismissals', updates: {db.visualDismissals});
    _changes.add(null);
    return n;
  }

  /// Para a fila e espera a foto atual terminar.
  Future<bool> dispose({Duration timeout = const Duration(seconds: 10)}) async {
    _disposed = true;
    _stop = true;
    _retry?.cancel();
    await _autoSources?.cancel();
    var ok = true;
    final run = _run;
    if (run != null) {
      ok = await run.then((_) => true, onError: (Object _) => true).timeout(timeout, onTimeout: () => false);
    }
    await _status.close();
    await _changes.close();
    return ok;
  }
}

// Fora da classe: o isolate recebe só os dados, nunca o serviço.
List<VisualHash?> _hashFiles(List<String> paths) => [for (final path in paths) visualHashFromFile(path)];

Future<List<VisualHash?>> _hashFilesInIsolate(List<String> paths) => Isolate.run(() => _hashFiles(paths));

List<SimilarGroup> _groups(List<SimilarCandidate> items, Set<(int, int)> dismissed, SimilarLevel minLevel) =>
    groupSimilar(findSimilarPairs(items, dismissed: dismissed, minLevel: minLevel));

Future<List<SimilarGroup>> _groupsInIsolate(
  List<SimilarCandidate> items,
  Set<(int, int)> dismissed,
  SimilarLevel minLevel,
) => Isolate.run(() => _groups(items, dismissed, minLevel));
