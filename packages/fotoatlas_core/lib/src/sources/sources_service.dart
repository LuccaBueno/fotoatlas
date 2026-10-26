import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../catalog/catalog_database.dart';
import '../platform/win_fs.dart';
import '../util/clock.dart';
import '../util/uuid.dart';
import 'identity.dart';
import 'media_types.dart';
import 'volumes.dart';

/// Erro de cadastro de fonte com mensagem pronta para o usuário (PT-BR).
class SourceException implements Exception {
  SourceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Resolve um caminho escolhido pelo usuário para (raiz do volume, GUID).
abstract interface class PathResolver {
  ({String mountRoot, String volumeGuid}) resolve(String path);
}

class Win32PathResolver implements PathResolver {
  @override
  ({String mountRoot, String volumeGuid}) resolve(String path) {
    final root = volumeRootFor(path);
    if (root.startsWith(r'\\')) {
      throw SourceException('Pastas de rede ainda não são suportadas.');
    }
    try {
      return (mountRoot: root, volumeGuid: volumeGuidForRoot(root));
    } on Win32Exception {
      throw SourceException('Não foi possível identificar a unidade de "$path".');
    }
  }
}

enum SourceState { connected, disconnected, ambiguous }

/// Fonte pronta para exibição.
class SourceView {
  const SourceView({
    required this.id,
    required this.name,
    required this.kind,
    required this.rootRelPath,
    required this.state,
    this.mountPath,
    this.lastConnectedAt,
    this.totalBytes,
    this.freeBytes,
    this.fileCount = 0,
    this.fileBytes = 0,
    this.mediaCount = 0,
    this.missingCount = 0,
    this.lastScan,
    this.candidates = const [],
  });

  final String id;
  final String name;

  /// `external_hd`, `internal`, `usb_stick`, `memory_card`, `phone`, `folder`.
  final String kind;
  final String rootRelPath;
  final SourceState state;

  /// Ponto de montagem atual (conectada) ou o último visto.
  final String? mountPath;
  final DateTime? lastConnectedAt;
  final int? totalBytes;
  final int? freeBytes;
  final int fileCount;
  final int fileBytes;
  final int mediaCount;
  final int missingCount;
  final ScanRow? lastScan;

  /// Volumes candidatos quando [state] é [SourceState.ambiguous].
  final List<VolumeInfo> candidates;

  bool get isConnected => state == SourceState.connected;

  /// Caminho para exibição (`E:\Fotos`), mesmo desconectada.
  String? get displayPath {
    final mount = mountPath;
    if (mount == null) return null;
    return rootRelPath.isEmpty ? mount : joinNative(mount, rootRelPath);
  }
}

/// Resultado do cadastro: a fonte e avisos (ex.: sobreposição com outra fonte).
class AddSourceResult {
  const AddSourceResult(this.sourceId, this.warnings);
  final String sourceId;
  final List<String> warnings;
}

/// Cadastro de fontes, reconhecimento independente da letra e conectividade.
class SourcesService {
  SourcesService(this.db, this.volumes, {PathResolver? resolver}) : resolver = resolver ?? Win32PathResolver();

  final CatalogDatabase db;
  final VolumeProvider volumes;
  final PathResolver resolver;

  final Map<String, MatchResult> _matches = {};
  final _stateChanges = StreamController<void>.broadcast();
  Timer? _monitor;
  bool _refreshing = false;
  List<VolumeInfo> _lastVolumes = const [];

  /// Volumes vistos na última verificação.
  List<VolumeInfo> get lastVolumes => _lastVolumes;

  /// Ao abrir: nada está conectado até a primeira verificação.
  Future<void> init() async {
    await db.customUpdate('UPDATE sources SET connected = 0', updates: {db.sources});
  }

  /// Cadastra uma pasta ou unidade inteira a partir de um caminho.
  Future<AddSourceResult> addPath(String path, {String? name}) async {
    final full = p.normalize(p.absolute(path));
    if (!Directory(full).existsSync()) {
      throw SourceException('A pasta "$full" não existe ou não está acessível.');
    }
    final resolved = resolver.resolve(full);
    final all = await volumes.list();
    _lastVolumes = all;
    final volume = all.firstWhere(
      (v) => _normGuid(v.guidPath) == _normGuid(resolved.volumeGuid),
      orElse: () => throw SourceException('A unidade de "$full" não apareceu na lista de unidades.'),
    );
    if (volume.driveType == 'network' || volume.driveType == 'cdrom') {
      throw SourceException('Este tipo de unidade ainda não é suportado.');
    }

    final rel = _relativeTo(resolved.mountRoot, full);
    final existing = await (db.select(db.sources)..where((s) => s.forgottenAt.isNull())).get();
    final sameVolume = existing.where(
      (s) => s.volumeGuid != null && _normGuid(s.volumeGuid!) == _normGuid(volume.guidPath),
    );
    for (final s in sameVolume) {
      if (s.rootRelPath.toLowerCase() == rel.toLowerCase()) {
        throw SourceException('Esta pasta já está cadastrada como "${s.name}".');
      }
    }
    final warnings = <String>[
      for (final s in sameVolume)
        if (_isWithin(s.rootRelPath, rel))
          'Esta pasta fica dentro de "${s.name}". Os arquivos vão aparecer nas duas fontes, '
              'mas contam como uma cópia só.'
        else if (_isWithin(rel, s.rootRelPath))
          '"${s.name}" fica dentro desta pasta. Os arquivos vão aparecer nas duas fontes, '
              'mas contam como uma cópia só.',
    ];

    final diskId = await _upsertDisk(volume.primaryDisk);
    final now = nowMs();
    final id = uuidV4();
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: id,
            name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : _defaultName(full, rel, volume),
            kind: rel.isEmpty ? _kindFor(volume) : 'folder',
            volumeGuid: Value(volume.guidPath),
            volumeSerial: Value(volume.serial),
            volumeLabel: Value(volume.label),
            filesystem: Value(volume.fileSystem),
            volumeSizeBytes: Value(volume.totalBytes),
            physicalDiskId: Value(diskId),
            rootRelPath: Value(rel),
            lastMountPath: Value(volume.displayMount ?? resolved.mountRoot),
            connected: const Value(true),
            lastConnectedAt: Value(now),
            totalBytesLast: Value(volume.totalBytes),
            freeBytesLast: Value(volume.freeBytes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    _matches[id] = Matched(volume, 100);
    _stateChanges.add(null);
    return AddSourceResult(id, warnings);
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw SourceException('O nome não pode ficar vazio.');
    await (db.update(
      db.sources,
    )..where((s) => s.id.equals(id))).write(SourcesCompanion(name: Value(trimmed), updatedAt: Value(nowMs())));
  }

  /// "Esquecer" só oculta a fonte no catálogo; nenhum arquivo é tocado (regra 8).
  Future<void> forget(String id) async {
    await (db.update(db.sources)..where((s) => s.id.equals(id))).write(
      SourcesCompanion(forgottenAt: Value(nowMs()), connected: const Value(false), updatedAt: Value(nowMs())),
    );
    _matches.remove(id);
    _stateChanges.add(null);
  }

  /// Confirma, num caso ambíguo, qual volume é esta fonte.
  Future<void> confirmVolume(String sourceId, String guidPath) async {
    final volume = _lastVolumes.firstWhere(
      (v) => _normGuid(v.guidPath) == _normGuid(guidPath),
      orElse: () => throw SourceException('A unidade escolhida não está mais conectada.'),
    );
    await _learn(sourceId, volume);
    await refreshConnectivity();
  }

  /// Verifica os volumes conectados e atualiza o estado de cada fonte.
  Future<void> refreshConnectivity() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final list = await volumes.list();
      _lastVolumes = list;
      final rows = await (db.select(
        db.sources,
      )..where((s) => s.forgottenAt.isNull() & s.kind.isNotValue('phone'))).get();
      final disks = {for (final d in await db.select(db.physicalDisks).get()) d.id: d};
      var changed = false;
      for (final row in rows) {
        final disk = row.physicalDiskId == null ? null : disks[row.physicalDiskId];
        final identity = SourceIdentity(
          volumeGuid: row.volumeGuid,
          volumeSerial: row.volumeSerial,
          volumeLabel: row.volumeLabel,
          fileSystem: row.filesystem,
          volumeSizeBytes: row.volumeSizeBytes,
          reliableDiskSerial: disk != null && disk.identityConfidence == 'reliable' ? disk.serial : null,
        );
        final result = IdentityScoring.match(identity, list);
        final previous = _matches[row.id];
        _matches[row.id] = result;
        if (_stateKey(previous) != _stateKey(result)) changed = true;
        switch (result) {
          case Matched(:final volume):
            await _learn(row.id, volume, row: row);
          case Ambiguous() || NotConnected():
            if (row.connected) {
              await (db.update(db.sources)..where((s) => s.id.equals(row.id))).write(
                SourcesCompanion(connected: const Value(false), updatedAt: Value(nowMs())),
              );
            }
        }
      }
      if (changed) _stateChanges.add(null);
    } finally {
      _refreshing = false;
    }
  }

  /// Verificação periódica (padrão: a cada 3 s).
  void startMonitoring({Duration interval = const Duration(seconds: 3)}) {
    _monitor?.cancel();
    _monitor = Timer.periodic(interval, (_) => refreshConnectivity().ignore());
  }

  void stopMonitoring() => _monitor?.cancel();

  /// Raiz de acesso atual da fonte (independente da letra), ou `null` se
  /// desconectada ou ambígua.
  String? accessRoot(SourceRow row) {
    final m = _matches[row.id];
    if (m is! Matched) return null;
    return joinNative(m.volume.guidPath, row.rootRelPath);
  }

  /// Estado atual de uma fonte.
  SourceState stateOf(String sourceId) => switch (_matches[sourceId]) {
    Matched() => SourceState.connected,
    Ambiguous() => SourceState.ambiguous,
    _ => SourceState.disconnected,
  };

  Future<SourceRow?> byId(String id) => (db.select(db.sources)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Lista reativa de fontes com contagens e último scan.
  Stream<List<SourceView>> watch() {
    final controller = StreamController<List<SourceView>>();
    StreamSubscription<List<_SourceAggregate>>? dbSub;
    StreamSubscription<void>? stateSub;
    List<_SourceAggregate>? last;
    void emit() {
      final rows = last;
      if (rows != null && !controller.isClosed) controller.add(rows.map(_toView).toList());
    }

    controller
      ..onListen = () {
        dbSub = _aggregates().listen((rows) {
          last = rows;
          emit();
        }, onError: controller.addError);
        stateSub = _stateChanges.stream.listen((_) => emit());
      }
      ..onCancel = () async {
        await dbSub?.cancel();
        await stateSub?.cancel();
      };
    return controller.stream;
  }

  Future<List<SourceView>> list() => _aggregates().first.then((rows) => rows.map(_toView).toList());

  Stream<List<_SourceAggregate>> _aggregates() {
    final media = MediaTypes.sqlList(MediaTypes.media);
    return db
        .customSelect(
          '''
          SELECT s.*,
            (SELECT COUNT(*) FROM file_instances f WHERE f.source_id = s.id AND f.availability != 'missing') AS file_count,
            (SELECT COALESCE(SUM(size_bytes), 0) FROM file_instances f WHERE f.source_id = s.id AND f.availability != 'missing') AS file_bytes,
            (SELECT COUNT(*) FROM file_instances f WHERE f.source_id = s.id AND f.availability != 'missing' AND f.ext IN $media) AS media_count,
            (SELECT COUNT(*) FROM file_instances f WHERE f.source_id = s.id AND f.availability = 'missing') AS missing_count,
            (SELECT id FROM scans sc WHERE sc.source_id = s.id ORDER BY sc.started_at DESC, sc.id DESC LIMIT 1) AS last_scan_id
          FROM sources s
          WHERE s.forgotten_at IS NULL
          ORDER BY s.created_at
          ''',
          readsFrom: {db.sources, db.fileInstances, db.scans},
        )
        .watch()
        .asyncMap((rows) async {
          final scanIds = [for (final r in rows) r.readNullable<int>('last_scan_id')].whereType<int>().toList();
          final scans = scanIds.isEmpty
              ? <int, ScanRow>{}
              : {for (final s in await (db.select(db.scans)..where((t) => t.id.isIn(scanIds))).get()) s.id: s};
          return [
            for (final r in rows)
              _SourceAggregate(
                db.sources.map(r.data),
                fileCount: r.read<int>('file_count'),
                fileBytes: r.read<int>('file_bytes'),
                mediaCount: r.read<int>('media_count'),
                missingCount: r.read<int>('missing_count'),
                lastScan: scans[r.readNullable<int>('last_scan_id')],
              ),
          ];
        });
  }

  SourceView _toView(_SourceAggregate a) {
    final row = a.row;
    final match = _matches[row.id];
    final state = switch (match) {
      Matched() => SourceState.connected,
      Ambiguous() => SourceState.ambiguous,
      _ => SourceState.disconnected,
    };
    final volume = match is Matched ? match.volume : null;
    return SourceView(
      id: row.id,
      name: row.name,
      kind: row.kind,
      rootRelPath: row.rootRelPath,
      state: state,
      mountPath: volume?.displayMount ?? row.lastMountPath,
      lastConnectedAt: row.lastConnectedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastConnectedAt!, isUtc: true),
      totalBytes: volume?.totalBytes ?? row.totalBytesLast,
      freeBytes: volume?.freeBytes ?? row.freeBytesLast,
      fileCount: a.fileCount,
      fileBytes: a.fileBytes,
      mediaCount: a.mediaCount,
      missingCount: a.missingCount,
      lastScan: a.lastScan,
      candidates: match is Ambiguous ? [for (final c in match.candidates) c.$1] : const [],
    );
  }

  /// Reconhecida com segurança: atualiza conexão e "aprende" a identidade
  /// atual (ex.: GUID novo do mesmo HD em outro PC, rótulo renomeado).
  Future<void> _learn(String sourceId, VolumeInfo volume, {SourceRow? row}) async {
    final current = row ?? await byId(sourceId);
    if (current == null) return;
    final diskId = await _upsertDisk(volume.primaryDisk);
    final now = nowMs();
    final mount = volume.displayMount ?? current.lastMountPath;
    final identityChanged =
        current.volumeGuid != volume.guidPath ||
        current.volumeSerial != volume.serial ||
        current.volumeLabel != volume.label ||
        current.filesystem != volume.fileSystem ||
        current.volumeSizeBytes != volume.totalBytes ||
        (diskId != null && current.physicalDiskId != diskId);
    final stateChanged = !current.connected || current.lastMountPath != mount;
    final spaceChanged = current.freeBytesLast != volume.freeBytes || current.totalBytesLast != volume.totalBytes;
    if (!identityChanged && !stateChanged && !spaceChanged) return;
    await (db.update(db.sources)..where((s) => s.id.equals(sourceId))).write(
      SourcesCompanion(
        volumeGuid: Value(volume.guidPath),
        volumeSerial: Value(volume.serial),
        volumeLabel: Value(volume.label),
        filesystem: Value(volume.fileSystem),
        volumeSizeBytes: Value(volume.totalBytes),
        physicalDiskId: diskId == null ? const Value.absent() : Value(diskId),
        connected: const Value(true),
        lastMountPath: Value(mount),
        lastConnectedAt: Value(now),
        totalBytesLast: Value(volume.totalBytes),
        freeBytesLast: Value(volume.freeBytes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int?> _upsertDisk(PhysicalDiskInfo? disk) async {
    if (disk == null || disk.identityConfidence == 'unknown') return null;
    final now = nowMs();
    final query = db.select(db.physicalDisks);
    if (disk.isReliable) {
      query.where((d) => d.identityConfidence.equals('reliable') & d.serial.equals(disk.serial!));
    } else {
      // Fraca: modelo + tamanho. Discos iguais se fundem — conservador (R1).
      query.where(
        (d) =>
            d.identityConfidence.equals('weak') &
            d.model.equalsNullable(disk.model) &
            d.sizeBytes.equalsNullable(disk.sizeBytes),
      );
    }
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      await (db.update(db.physicalDisks)..where((d) => d.id.equals(existing.id))).write(
        PhysicalDisksCompanion(lastSeenAt: Value(now), busType: Value(disk.busType)),
      );
      return existing.id;
    }
    return db
        .into(db.physicalDisks)
        .insert(
          PhysicalDisksCompanion.insert(
            serial: Value(disk.isReliable ? disk.serial : null),
            model: Value(disk.model),
            sizeBytes: Value(disk.sizeBytes),
            busType: Value(disk.busType),
            identityConfidence: disk.identityConfidence,
            firstSeenAt: now,
            lastSeenAt: now,
          ),
        );
  }

  Future<void> dispose() async {
    _monitor?.cancel();
    await _stateChanges.close();
  }

  static String _stateKey(MatchResult? m) => switch (m) {
    Matched(:final volume) => 'm:${volume.guidPath}:${volume.displayMount}',
    Ambiguous(:final candidates) => 'a:${candidates.length}',
    _ => 'n',
  };

  static String _normGuid(String g) {
    var s = g.toLowerCase();
    if (s.endsWith(r'\')) s = s.substring(0, s.length - 1);
    return s;
  }

  static String _relativeTo(String mountRoot, String full) {
    final rel = p.relative(full, from: mountRoot);
    if (rel == '.') return '';
    return rel.replaceAll(r'\', '/');
  }

  /// [inner] fica dentro de [outer] (ou é igual)? Caminhos relativos com '/'.
  static bool _isWithin(String outer, String inner) {
    final o = outer.toLowerCase();
    final i = inner.toLowerCase();
    if (o.isEmpty) return true;
    return i == o || i.startsWith('$o/');
  }

  static String _kindFor(VolumeInfo v) {
    final disk = v.primaryDisk;
    if (disk != null && (disk.busType == 'sd' || disk.busType == 'mmc')) return 'memory_card';
    if (v.driveType == 'removable') return 'usb_stick';
    if (disk != null && disk.busType == 'usb') return 'external_hd';
    return 'internal';
  }

  static String _defaultName(String full, String rel, VolumeInfo v) {
    if (rel.isNotEmpty) return p.basename(full);
    if (v.label != null && v.label!.trim().isNotEmpty) return v.label!.trim();
    final mount = v.displayMount;
    return mount == null ? 'Unidade' : 'Unidade ${mount.replaceAll(r'\', '')}';
  }
}

class _SourceAggregate {
  _SourceAggregate(
    this.row, {
    required this.fileCount,
    required this.fileBytes,
    required this.mediaCount,
    required this.missingCount,
    required this.lastScan,
  });
  final SourceRow row;
  final int fileCount;
  final int fileBytes;
  final int mediaCount;
  final int missingCount;
  final ScanRow? lastScan;
}
