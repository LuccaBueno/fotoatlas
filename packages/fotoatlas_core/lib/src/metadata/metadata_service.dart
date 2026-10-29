import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../catalog/catalog.dart';
import '../catalog/catalog_database.dart';
import '../devices/devices.dart';
import '../hash/hash_service.dart';
import '../scan/scan_service.dart';
import '../settings/settings_store.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import '../util/uuid.dart';
import 'capture_date.dart';
import 'effective_dates.dart';
import 'exiftool.dart';
import 'external_tools.dart';
import 'extracted.dart';

/// Situação da leitura de metadados, para a interface.
class MetadataStatus {
  const MetadataStatus({
    this.running = false,
    this.paused = false,
    this.done = 0,
    this.total = 0,
    this.errors = 0,
    this.exifToolMissing = false,
    this.message,
  });

  final bool running;
  final bool paused;
  final int done;
  final int total;
  final int errors;

  /// Sem ExifTool: as datas vêm só do nome e do sistema de arquivos.
  final bool exifToolMissing;
  final String? message;

  MetadataStatus copyWith({bool? running, bool? paused, int? done, int? total, int? errors, String? message}) =>
      MetadataStatus(
        running: running ?? this.running,
        paused: paused ?? this.paused,
        done: done ?? this.done,
        total: total ?? this.total,
        errors: errors ?? this.errors,
        exifToolMissing: exifToolMissing,
        message: message ?? this.message,
      );
}

/// Chaves de configuração (tabela `settings`).
abstract final class MetadataSettingKeys {
  static const zone = 'metadata.timezone';
  static const priority = 'metadata.datePriority';

  /// Versão das regras de escolha da data já aplicada ao catálogo.
  static const strategyVersion = 'metadata.strategyVersion';
}

class _Instance {
  _Instance(this.contentId, this.sourceId, this.relPath, this.name, this.ext, this.mtime, this.objectId, this.kind);
  final int contentId;
  final String sourceId;
  final String relPath;
  final String name;
  final String ext;
  final int? mtime;
  final String? objectId;
  final String kind;
}

class _Target {
  _Target(this.contentId, this.mediaType, this.instances);
  final int contentId;
  final String mediaType;
  final List<_Instance> instances;
}

/// Leitura de metadados (spec §8): para cada conteúdo conferido (foto, RAW ou
/// vídeo), lê **uma** cópia acessível com o ExifTool (e o ffprobe nos
/// vídeos), junta as datas do nome e do sistema de arquivos de todas as
/// cópias, escolhe a data pela estratégia e grava em `media_metadata`.
///
/// Só lê: os arquivos de origem nunca são modificados (regra 2). Do celular,
/// lê só o começo do arquivo (onde fica o EXIF) para o cache, e apaga a cópia
/// parcial em seguida. Sem nenhuma cópia acessível, grava as datas do nome e
/// do sistema de arquivos (`partial`) e completa quando a fonte conectar.
class MetadataService {
  MetadataService(
    this.catalog,
    this.sources,
    this.scans,
    this.hashes, {
    required this.tools,
    required this.cacheDir,
    this.batchSize = 48,
  }) : settings = SettingsStore(catalog.db) {
    effective = EffectiveDates(db, zone: () => zone);
  }

  final Catalog catalog;
  final SourcesService sources;
  final ScanService scans;
  final HashService hashes;
  final ExternalTools tools;

  /// Pasta de cache (a mesma `--cache-dir` do helper): leituras parciais do celular.
  final String cacheDir;
  final int batchSize;
  final SettingsStore settings;
  late final EffectiveDates effective;

  CatalogDatabase get db => catalog.db;

  String zone = TimeZones.defaultZone;
  List<DateSource> priority = DateSource.defaultPriority;

  /// Datas efetivas mudaram (para recalcular os momentos).
  final _datesChanged = StreamController<void>.broadcast();
  Stream<void> get datesChanged => _datesChanged.stream;

  ExifTool? _exif;
  Ffprobe? _probe;
  final _status = StreamController<MetadataStatus>.broadcast();
  late MetadataStatus _current = MetadataStatus(exifToolMissing: tools.exiftool == null);
  Future<void>? _run;
  bool _stop = false;
  bool _disposed = false;
  StreamSubscription<Object?>? _autoHash;
  StreamSubscription<Object?>? _autoSources;

  Stream<MetadataStatus> get status => _status.stream;
  MetadataStatus get current => _current;
  bool get isRunning => _run != null;

  Future<void> init() async {
    final z = await settings.get(MetadataSettingKeys.zone);
    if (z is String && TimeZones.isValid(z)) zone = z;
    final pr = await settings.get(MetadataSettingKeys.priority);
    if (pr is List) {
      final list = [for (final s in pr) DateSource.fromSql(s as String?)].where((s) => s != DateSource.none).toList();
      if (list.isNotEmpty) priority = list;
    }
    // Regras novas (ex.: relógio zerado vira hora incerta): reescolhe as datas
    // pelas candidatas já guardadas, sem ler os arquivos de novo.
    final applied = await settings.get(MetadataSettingKeys.strategyVersion);
    if (applied != currentStrategyVersion) {
      if (applied != null || await _hasMetadata()) {
        await reresolveAll();
        reresolvedOnInit = true;
      }
      await settings.set(MetadataSettingKeys.strategyVersion, currentStrategyVersion);
    }
  }

  /// As datas foram reescolhidas ao abrir (os momentos precisam ser recalculados).
  bool reresolvedOnInit = false;

  /// Sobe quando as regras de [DateStrategy] mudam.
  static const currentStrategyVersion = 2;

  Future<bool> _hasMetadata() async =>
      (await db.customSelect('SELECT EXISTS (SELECT 1 FROM media_metadata) AS e').getSingle()).read<int>('e') == 1;

  DateStrategy get strategy => DateStrategy(zone: zone, priority: priority);

  /// Automática: quando a conferência termina e quando uma fonte conecta.
  void enableAuto() {
    var wasRunning = hashes.isRunning;
    _autoHash ??= hashes.status.listen((s) {
      if (wasRunning && !s.running) _autoStart();
      wasRunning = s.running;
    });
    _autoSources ??= sources.stateChanges.listen((_) => _autoStart());
    _autoStart();
  }

  void _autoStart() {
    if (_disposed || _current.paused) return;
    start().ignore();
  }

  /// Lê o que falta. Chamar de novo durante uma rodada devolve a mesma.
  Future<void> start() {
    if (_disposed) return Future.value();
    if (_current.paused) _emit(_current.copyWith(paused: false));
    return _run ??= _loop().whenComplete(() => _run = null);
  }

  Future<void> pause() async {
    _emit(_current.copyWith(paused: true));
    _stop = true;
    await _run;
  }

  Future<void> waitIdle() async {
    while (_run != null) {
      await _run;
    }
  }

  /// Fuso padrão (datas sem fuso). Recalcula as datas pelas candidatas já
  /// guardadas, sem ler os arquivos de novo.
  Future<void> setZone(String name) async {
    if (!TimeZones.isValid(name)) throw ArgumentError('Fuso desconhecido: $name');
    zone = name;
    await settings.set(MetadataSettingKeys.zone, name);
    await reresolveAll();
  }

  /// Ordem de prioridade das fontes de data (a correção manual fica sempre acima).
  Future<void> setPriority(List<DateSource> order) async {
    final list = order.where((s) => s != DateSource.manual && s != DateSource.none).toSet().toList();
    for (final s in DateSource.defaultPriority) {
      if (!list.contains(s)) list.add(s);
    }
    priority = list;
    await settings.set(MetadataSettingKeys.priority, [for (final s in list) s.sql]);
    await reresolveAll();
  }

  /// Reescolhe a data de todos os itens a partir das candidatas guardadas.
  Future<int> reresolveAll() async {
    final rows = await db.customSelect('SELECT content_id, candidates_json FROM media_metadata').get();
    final updates = <(int, ResolvedDate?)>[];
    for (final r in rows) {
      final candidates = DateStrategy.candidatesFromJson(r.readNullable<String>('candidates_json'));
      updates.add((r.read<int>('content_id'), strategy.resolve(candidates)));
    }
    await db.transaction(() async {
      for (final (id, d) in updates) {
        await db.customStatement(
          'UPDATE media_metadata SET capture_utc_ms = ?, capture_local = ?, tz_offset_min = ?, date_source = ?, '
          'date_confidence = ?, date_conflict = ? WHERE content_id = ?',
          [
            d?.utcMs,
            d == null ? null : formatWall(d.wall),
            d?.offsetMin,
            (d?.source ?? DateSource.none).sql,
            (d?.confidence ?? DateConfidence.none).name,
            d?.conflict ?? false ? 1 : 0,
            id,
          ],
        );
      }
    });
    final changed = await effective.recompute();
    if (changed > 0) _datesChanged.add(null);
    return changed;
  }

  /// Volta para a fila os itens com erro de leitura.
  Future<int> retryErrors() async {
    final n = await db.customUpdate(
      "UPDATE media_metadata SET meta_status = 'partial' WHERE meta_status = 'error'",
      updates: {db.mediaMetadata},
    );
    if (n > 0) _autoStart();
    return n;
  }

  Future<int> _pendingCount() async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS n FROM contents c LEFT JOIN media_metadata mm ON mm.content_id = c.id "
                "WHERE c.media_type IN ('photo','raw','video') AND (mm.content_id IS NULL OR mm.meta_status = 'partial')",
              )
              .getSingle())
          .read<int>('n');

  Future<void> _loop() async {
    _stop = false;
    final total = await _pendingCount();
    if (total == 0) return;
    _emit(MetadataStatus(running: true, total: total, exifToolMissing: tools.exiftool == null));
    var lastId = 0;
    var anyChanged = false;
    try {
      while (!_stop && !_disposed) {
        final targets = await _nextBatch(lastId);
        if (targets.isEmpty) break;
        lastId = targets.last.contentId;
        final changed = await _process(targets);
        anyChanged |= changed;
        if (changed) _datesChanged.add(null);
      }
      _emit(_current.copyWith(running: false));
    } on Object catch (e) {
      _emit(_current.copyWith(running: false, message: 'Erro inesperado ao ler metadados: $e'));
    }
    if (anyChanged && !_datesChanged.isClosed) _datesChanged.add(null);
  }

  Future<List<_Target>> _nextBatch(int afterId) async {
    final rows = await db
        .customSelect(
          "SELECT c.id, c.media_type FROM contents c LEFT JOIN media_metadata mm ON mm.content_id = c.id "
          "WHERE c.id > ? AND c.media_type IN ('photo','raw','video') "
          "AND (mm.content_id IS NULL OR mm.meta_status = 'partial') ORDER BY c.id LIMIT ?",
          variables: [Variable.withInt(afterId), Variable.withInt(batchSize)],
        )
        .get();
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r.read<int>('id')];
    final inst = await db
        .customSelect(
          "SELECT fi.content_id, fi.source_id, fi.rel_path, fi.name, fi.ext, fi.mtime, fi.device_object_id, s.kind "
          "FROM file_instances fi JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL "
          "WHERE fi.content_id IN (${ids.join(',')}) AND fi.availability = 'present' AND fi.hash_status = 'done' "
          "ORDER BY fi.id",
        )
        .get();
    final by = <int, List<_Instance>>{};
    for (final r in inst) {
      final i = _Instance(
        r.read<int>('content_id'),
        r.read<String>('source_id'),
        r.read<String>('rel_path'),
        r.read<String>('name'),
        r.read<String>('ext'),
        r.readNullable<int>('mtime'),
        r.readNullable<String>('device_object_id'),
        r.read<String>('kind'),
      );
      (by[i.contentId] ??= []).add(i);
    }
    return [
      for (final r in rows) _Target(r.read<int>('id'), r.read<String>('media_type'), by[r.read<int>('id')] ?? []),
    ];
  }

  /// Uma cópia que dá para ler agora: caminho local ou celular pronto.
  Future<({String? path, _Instance? phone})?> _readable(_Target t) async {
    if (tools.exiftool == null && tools.ffprobe == null) return null;
    for (final i in t.instances) {
      if (i.kind == 'phone') continue;
      final row = await sources.byId(i.sourceId);
      final root = row == null ? null : sources.accessRoot(row);
      if (root != null) return (path: _join(root, i.relPath), phone: null);
    }
    for (final i in t.instances) {
      if (i.kind != 'phone') continue;
      final device = sources.deviceFor(i.sourceId);
      // Um leitor por celular: não disputa com a conferência nem com o scan.
      if (device == null || !device.isReady || sources.devices == null) continue;
      if (hashes.isReading(i.sourceId) || scans.isRunning(i.sourceId)) continue;
      return (path: null, phone: i);
    }
    return null;
  }

  static String _join(String root, String rel) {
    final base = root.endsWith(r'\') ? root.substring(0, root.length - 1) : root;
    return '$base\\${rel.replaceAll('/', r'\')}';
  }

  Future<bool> _process(List<_Target> targets) async {
    final local = <int, String>{};
    final phone = <int, _Instance>{};
    final skip = <int>{};
    final existing = {
      for (final r
          in await db
              .customSelect(
                'SELECT content_id, meta_status FROM media_metadata WHERE content_id IN (${targets.map((t) => t.contentId).join(',')})',
              )
              .get())
        r.read<int>('content_id'): r.read<String>('meta_status'),
    };
    for (final t in targets) {
      final r = await _readable(t);
      if (r == null) {
        // Nada acessível agora: se já tem as datas parciais, espera a fonte voltar.
        if (existing[t.contentId] == 'partial') skip.add(t.contentId);
        continue;
      }
      if (r.path != null) local[t.contentId] = r.path!;
      if (r.phone != null) phone[t.contentId] = r.phone!;
    }

    final results = <int, ExtractResult>{};
    final notes = <int, String>{};
    final exifPath = tools.exiftool;
    if (exifPath != null && local.isNotEmpty) {
      final exif = _exif ??= ExifTool(exifPath);
      final r = await exif.extract(local.values.toList());
      for (final e in local.entries) {
        results[e.key] = r[e.value]!;
      }
    }
    final probePath = tools.ffprobe;
    if (probePath != null) {
      final probe = _probe ??= Ffprobe(probePath);
      for (final t in targets) {
        final path = local[t.contentId];
        if (path == null || t.mediaType != 'video' || _stop) continue;
        final v = await probe.probe(path);
        final prev = results[t.contentId];
        if (v.metadata != null) {
          if (prev?.metadata != null) {
            prev!.metadata!.fillFrom(v.metadata!);
          } else {
            results[t.contentId] = v;
          }
        }
      }
    }
    if (exifPath != null && phone.isNotEmpty) {
      await _readPhoneHeads(phone, results, notes);
    }

    final now = nowMs();
    final written = <int>[];
    var errors = 0;
    await db.transaction(() async {
      for (final t in targets) {
        if (skip.contains(t.contentId)) continue;
        final res = results[t.contentId];
        final meta = res?.metadata;
        final fromPhone = phone.containsKey(t.contentId);
        final String status;
        if (res == null) {
          status = 'partial';
        } else if (meta == null && !fromPhone) {
          status = 'error';
          errors++;
        } else {
          status = 'full';
        }
        final candidates = <DateCandidate>[
          ?meta?.exifDate,
          ?meta?.videoDate,
          ..._nameCandidates(t.instances),
          ?_fsCandidate(t.instances),
        ];
        final resolved = strategy.resolve(candidates);
        await db.customStatement(
          '''
          INSERT INTO media_metadata (content_id, capture_utc_ms, capture_local, tz_offset_min, date_source,
            date_confidence, date_conflict, candidates_json, make, model, lens, iso, aperture, exposure_s, focal_mm,
            width, height, orientation, lat, lon, duration_ms, fps, video_codec, audio_codec, bitrate, software,
            extractor, extracted_at, body_serial, meta_status, meta_error)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(content_id) DO UPDATE SET capture_utc_ms = excluded.capture_utc_ms,
            capture_local = excluded.capture_local, tz_offset_min = excluded.tz_offset_min,
            date_source = excluded.date_source, date_confidence = excluded.date_confidence,
            date_conflict = excluded.date_conflict, candidates_json = excluded.candidates_json,
            make = excluded.make, model = excluded.model, lens = excluded.lens, iso = excluded.iso,
            aperture = excluded.aperture, exposure_s = excluded.exposure_s, focal_mm = excluded.focal_mm,
            width = excluded.width, height = excluded.height, orientation = excluded.orientation,
            lat = excluded.lat, lon = excluded.lon, duration_ms = excluded.duration_ms, fps = excluded.fps,
            video_codec = excluded.video_codec, audio_codec = excluded.audio_codec, bitrate = excluded.bitrate,
            software = excluded.software, extractor = excluded.extractor, extracted_at = excluded.extracted_at,
            body_serial = excluded.body_serial, meta_status = excluded.meta_status, meta_error = excluded.meta_error
          ''',
          [
            t.contentId,
            resolved?.utcMs,
            resolved == null ? null : formatWall(resolved.wall),
            resolved?.offsetMin,
            (resolved?.source ?? DateSource.none).sql,
            (resolved?.confidence ?? DateConfidence.none).name,
            resolved?.conflict ?? false ? 1 : 0,
            DateStrategy.candidatesJson(candidates),
            meta?.make,
            meta?.model,
            meta?.lens,
            meta?.iso,
            meta?.aperture,
            meta?.exposureS,
            meta?.focalMm,
            meta?.width,
            meta?.height,
            meta?.orientation,
            meta?.lat,
            meta?.lon,
            meta?.durationMs,
            meta?.fps,
            meta?.videoCodec,
            meta?.audioCodec,
            meta?.bitrate,
            meta?.software,
            res == null
                ? null
                : [_exif?.name, if (t.mediaType == 'video' && tools.ffprobe != null) 'ffprobe'].nonNulls.join(' + '),
            now,
            meta?.serial,
            status,
            res?.error ?? notes[t.contentId],
          ],
        );
        written.add(t.contentId);
      }
    });
    db.notifyUpdates({TableUpdate.onTable(db.mediaMetadata, kind: UpdateKind.insert)});
    final changed = written.isEmpty ? 0 : await effective.recompute(contentIds: written);
    _emit(_current.copyWith(done: _current.done + targets.length, errors: _current.errors + errors));
    return changed > 0;
  }

  /// Celular: copia o começo de cada arquivo para o cache, lê com o ExifTool e
  /// apaga as cópias parciais.
  Future<void> _readPhoneHeads(
    Map<int, _Instance> phone,
    Map<int, ExtractResult> results,
    Map<int, String> notes,
  ) async {
    final backend = sources.devices;
    if (backend == null) return;
    final dir = Directory(p.join(cacheDir, '_leitura'))..createSync(recursive: true);
    final heads = <int, String>{};
    final resolvers = <String, PhonePathResolver>{};
    try {
      for (final e in phone.entries) {
        if (_stop) break;
        final i = e.value;
        final device = sources.deviceFor(i.sourceId);
        if (device == null) continue;
        final out = p.join(dir.path, '${e.key}-${uuidV4().substring(0, 8)}.${i.ext.isEmpty ? 'bin' : i.ext}');
        final resolver = resolvers[device.deviceId] ??= PhonePathResolver(backend, device.deviceId);
        for (var attempt = 0; attempt < 2; attempt++) {
          try {
            final objectId = attempt == 0 ? i.objectId : await resolver.file(i.relPath);
            if (objectId == null) continue;
            await backend.readHead(device.deviceId, objectId, out, maxBytes: 512 * 1024);
            heads[e.key] = out;
            break;
          } on DeviceException catch (err) {
            _deleteQuietly(out);
            if (err.code != 'not_found') {
              notes[e.key] = 'Não deu para ler do celular: ${err.message}';
              break;
            }
          }
        }
      }
      if (heads.isEmpty) return;
      final r = await (_exif ??= ExifTool(tools.exiftool!)).extract(heads.values.toList());
      for (final e in heads.entries) {
        final res = r[e.value]!;
        // Só o começo do arquivo: vídeos com o índice no fim não têm a data aqui.
        if (res.metadata != null) {
          results[e.key] = res;
        } else {
          results[e.key] = ExtractResult.ok(ExtractedMetadata());
          notes[e.key] = 'Lido só o começo do arquivo no celular: ${res.error}';
        }
      }
    } finally {
      for (final f in heads.values) {
        _deleteQuietly(f);
      }
    }
  }

  void _deleteQuietly(String path) {
    // Só cópias parciais na pasta de leitura do cache.
    assert(p.isWithin(cacheDir, path));
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // Fica para a limpeza ao abrir.
    }
  }

  /// Apaga sobras de leituras parciais (ex.: o app fechou no meio).
  void cleanLeftovers() {
    final dir = Directory(p.join(cacheDir, '_leitura'));
    if (!dir.existsSync()) return;
    for (final f in dir.listSync().whereType<File>()) {
      _deleteQuietly(f.path);
    }
  }

  static List<DateCandidate> _nameCandidates(List<_Instance> instances) {
    DateCandidate? full;
    DateCandidate? dayOnly;
    for (final i in instances) {
      final c = filenameDate(i.name);
      if (c == null) continue;
      if (!c.dayOnly) {
        full ??= c;
      } else {
        dayOnly ??= c;
      }
    }
    return [?full, if (full == null) ?dayOnly];
  }

  /// A data de arquivo mais antiga entre as cópias (cópias novas têm datas novas).
  static DateCandidate? _fsCandidate(List<_Instance> instances) {
    int? min;
    for (final i in instances) {
      final ft = i.mtime;
      if (ft == null || ft <= 0) continue;
      final ms = (ft - 116444736000000000) ~/ 10000;
      if (ms <= 0) continue;
      if (min == null || ms < min) min = ms;
    }
    return min == null ? null : DateCandidate(source: DateSource.filesystem, utcMs: min);
  }

  void _emit(MetadataStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  /// Para a rodada e fecha o ExifTool; espera no máximo [timeout].
  Future<bool> dispose({Duration timeout = const Duration(seconds: 3)}) async {
    _disposed = true;
    _stop = true;
    unawaited(_autoHash?.cancel());
    unawaited(_autoSources?.cancel());
    var ok = true;
    final run = _run;
    if (run != null) ok = await run.then((_) => true).timeout(timeout, onTimeout: () => false);
    await _exif?.close().timeout(const Duration(seconds: 3), onTimeout: () {});
    unawaited(_status.close());
    unawaited(_datesChanged.close());
    return ok;
  }
}
