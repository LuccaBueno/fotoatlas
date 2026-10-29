import 'dart:async';
import 'dart:typed_data';

import '../helper/helper_client.dart';

/// Armazenamento de um celular (interno, cartão SD…).
class DeviceStorage {
  const DeviceStorage({required this.storageId, required this.name, this.totalBytes, this.freeBytes});

  factory DeviceStorage.fromJson(Map<String, Object?> json) => DeviceStorage(
    storageId: json['storageId'] as String,
    name: json['name'] as String? ?? 'Armazenamento',
    totalBytes: (json['totalBytes'] as num?)?.toInt(),
    freeBytes: (json['freeBytes'] as num?)?.toInt(),
  );

  final String storageId;
  final String name;
  final int? totalBytes;
  final int? freeBytes;
}

/// Celular (ou câmera) conectado agora (protocolo do helper §5.3).
class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.friendlyName,
    this.manufacturer,
    this.model,
    this.serial,
    this.platform = 'other',
    this.status = 'ok',
    this.storages = const [],
    this.simulated = false,
  });

  factory DeviceInfo.fromJson(Map<String, Object?> json) => DeviceInfo(
    deviceId: json['deviceId'] as String,
    friendlyName: json['friendlyName'] as String? ?? 'Dispositivo',
    manufacturer: json['manufacturer'] as String?,
    model: json['model'] as String?,
    serial: usableSerial(json['serial'] as String?),
    platform: json['kind'] as String? ?? 'other',
    status: json['status'] as String? ?? 'ok',
    storages: [
      for (final s in json['storages'] as List<Object?>? ?? const [])
        DeviceStorage.fromJson((s as Map).cast<String, Object?>()),
    ],
    simulated: json['simulated'] as bool? ?? false,
  );

  /// ID WPD (PnP). Pode mudar de uma porta USB para outra se o aparelho não
  /// tiver serial; por isso a identidade prefere o [serial].
  final String deviceId;
  final String friendlyName;
  final String? manufacturer;
  final String? model;
  final String? serial;

  /// `android`, `iphone`, `camera` ou `other`.
  final String platform;

  /// `ok`, `locked` (bloqueado / sem "Transferência de arquivos") ou
  /// `unauthorized` (falta "Permitir" / "Confiar neste computador").
  final String status;
  final List<DeviceStorage> storages;

  /// Celular simulado (`--fake-devices`), para testes e demonstração.
  final bool simulated;

  bool get isReady => status == 'ok';
  bool get isIphone => platform == 'iphone';

  int? get totalBytes => _sum(storages.map((s) => s.totalBytes));
  int? get freeBytes => _sum(storages.map((s) => s.freeBytes));

  static int? _sum(Iterable<int?> values) {
    final known = values.whereType<int>().toList();
    return known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b);
  }

  /// Serial vazio ou só zeros não identifica nada (R1).
  static String? usableSerial(String? serial) {
    final s = serial?.trim();
    if (s == null || s.isEmpty || RegExp(r'^[0\s-]+$').hasMatch(s)) return null;
    return s;
  }
}

/// Objeto dentro de uma pasta do celular.
class DeviceEntry {
  const DeviceEntry({
    required this.objectId,
    required this.name,
    required this.isFolder,
    this.size,
    this.modified,
    this.created,
  });

  factory DeviceEntry.fromJson(Map<String, Object?> json) => DeviceEntry(
    objectId: json['objectId'] as String,
    name: json['name'] as String,
    isFolder: json['isFolder'] as bool? ?? false,
    size: (json['size'] as num?)?.toInt(),
    modified: _fileTime(json['modified']),
    created: _fileTime(json['created']),
  );

  final String objectId;
  final String name;
  final bool isFolder;
  final int? size;

  /// FILETIME UTC, ou `null` se o aparelho não informa.
  final int? modified;
  final int? created;
}

int? _fileTime(Object? value) => value is String ? int.tryParse(value) : (value as num?)?.toInt();

/// Hash calculado pelo helper lendo o arquivo pelo USB.
class DeviceHash {
  const DeviceHash(this.sha256, this.size, this.modified);
  final Uint8List sha256;
  final int size;
  final int? modified;
}

/// Falha ao falar com o celular. Nunca significa "arquivo ausente" (regra 10).
class DeviceException implements Exception {
  DeviceException(this.code, this.message);

  /// `device_disconnected`, `device_locked`, `device_unauthorized`,
  /// `not_found`, `changed_during_read`, `io_error`, `cancelled`, `unavailable`.
  final String code;
  final String message;

  /// O aparelho (ou o helper) saiu: a operação para e retoma depois.
  bool get isDeviceGone =>
      code == 'device_disconnected' ||
      code == 'device_locked' ||
      code == 'device_unauthorized' ||
      code == 'unavailable';

  @override
  String toString() => 'DeviceException($code): $message';
}

/// Acesso de leitura a celulares. Não existe operação de escrita.
abstract interface class DeviceBackend {
  Future<List<DeviceInfo>> list();

  /// Filhos diretos de [objectId] (`''` = raiz, cujos filhos são os armazenamentos).
  Future<List<DeviceEntry>> listChildren(String deviceId, String objectId);

  /// SHA-256 em streaming, calculado no helper. [cancel] interrompe.
  Future<DeviceHash> hash(String deviceId, String objectId, {required int expectedSize, Future<void>? cancel});

  /// Copia no máximo [maxBytes] do começo do arquivo para [outPath] (arquivo
  /// novo dentro do cache): o bastante para ler o EXIF de uma foto.
  Future<int> readHead(String deviceId, String objectId, String outPath, {int maxBytes = 256 * 1024});

  /// Cópia segura (Fase 5): o helper lê o arquivo do aparelho e grava em
  /// [destPath] (um `.part` novo dentro de `.fotoatlas-tmp`), com o SHA-256
  /// calculado durante a leitura e `FlushFileBuffers` antes de responder.
  /// [modified] (FILETIME) vira a data de modificação do `.part`.
  /// Desconexão no meio: [DeviceException] `device_disconnected`, e o `.part`
  /// parcial fica para o core decidir.
  Future<DevicePull> pullToFile(
    String deviceId,
    String objectId,
    String destPath, {
    required int expectedSize,
    int? modified,
    Future<void>? cancel,
    void Function(int bytes)? onProgress,
  });
}

/// Resultado de [DeviceBackend.pullToFile].
class DevicePull {
  const DevicePull(this.sha256, this.bytesWritten);
  final Uint8List sha256;
  final int bytesWritten;
}

/// Celulares pelo helper (WPD).
class HelperDeviceBackend implements DeviceBackend {
  HelperDeviceBackend(this.client);
  final HelperClient client;

  @override
  Future<List<DeviceInfo>> list() => _guard(() async {
    final result = await client.call('devices.list');
    return [
      for (final d in result['devices'] as List<Object?>? ?? const [])
        DeviceInfo.fromJson((d as Map).cast<String, Object?>()),
    ];
  });

  @override
  Future<List<DeviceEntry>> listChildren(String deviceId, String objectId) => _guard(() async {
    final items = <DeviceEntry>[];
    await client.call(
      'devices.listChildren',
      params: {'deviceId': deviceId, 'objectId': objectId},
      // Pastas com milhares de fotos pelo USB demoram; o ping do helper
      // continua vigiando se ele travou.
      timeout: const Duration(minutes: 10),
      onEvent: (e) {
        if (e.name != 'entries') return;
        for (final item in e.data['items'] as List<Object?>? ?? const []) {
          items.add(DeviceEntry.fromJson((item as Map).cast<String, Object?>()));
        }
      },
    );
    return items;
  });

  @override
  Future<DeviceHash> hash(String deviceId, String objectId, {required int expectedSize, Future<void>? cancel}) =>
      _guard(() async {
        final result = await client.call(
          'devices.hashObject',
          params: {'deviceId': deviceId, 'objectId': objectId, 'expectedSize': expectedSize},
          // Pelo menos ~512 KB/s, mais folga: um vídeo grande pelo USB leva minutos.
          timeout: Duration(minutes: 2) + Duration(seconds: expectedSize ~/ (512 * 1024)),
          cancel: cancel,
        );
        return DeviceHash(
          _hex(result['sha256'] as String),
          (result['size'] as num).toInt(),
          _fileTime(result['modified']),
        );
      });

  @override
  Future<int> readHead(String deviceId, String objectId, String outPath, {int maxBytes = 256 * 1024}) =>
      _guard(() async {
        final result = await client.call(
          'devices.readHead',
          params: {'deviceId': deviceId, 'objectId': objectId, 'outPath': outPath, 'maxBytes': maxBytes},
          timeout: const Duration(minutes: 1),
        );
        return (result['bytes'] as num).toInt();
      });

  @override
  Future<DevicePull> pullToFile(
    String deviceId,
    String objectId,
    String destPath, {
    required int expectedSize,
    int? modified,
    Future<void>? cancel,
    void Function(int bytes)? onProgress,
  }) => _guard(() async {
    final result = await client.call(
      'devices.pullToFile',
      params: {
        'deviceId': deviceId,
        'objectId': objectId,
        'destPath': destPath,
        'expectedSize': expectedSize,
        if (modified != null) 'modified': '$modified',
      },
      timeout: Duration(minutes: 2) + Duration(seconds: expectedSize ~/ (512 * 1024)),
      cancel: cancel,
      onEvent: onProgress == null
          ? null
          : (e) {
              if (e.name == 'progress') onProgress((e.data['bytes'] as num).toInt());
            },
    );
    return DevicePull(_hex(result['sha256'] as String), (result['bytesWritten'] as num).toInt());
  });

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on HelperException catch (e) {
      final code = switch (e.code) {
        'helper_crashed' || 'helper_unavailable' || 'helper_closed' || 'timeout' => 'unavailable',
        final c => c,
      };
      throw DeviceException(code, e.message);
    }
  }

  static Uint8List _hex(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}

/// Exclusões no celular (relativas ao armazenamento, sem caixa): dados
/// privados de apps (enormes e quase sempre ilegíveis) e caches de miniaturas.
bool isExcludedPhoneDir(String relPathInStorage) {
  final lower = relPathInStorage.toLowerCase();
  if (lower == 'android/data' || lower == 'android/obb') return true;
  final name = lower.split('/').last;
  return name == '.thumbnails' || name == '.fotoatlas-tmp';
}

/// Resolve caminhos do catálogo (`Armazenamento/DCIM/Camera`) para IDs de
/// objeto do celular, com cache. Se um ID antigo não vale mais (os IDs do
/// Android mudam entre sessões), refaz o caminho a partir da raiz.
class PhonePathResolver {
  PhonePathResolver(this.backend, this.deviceId);

  final DeviceBackend backend;
  final String deviceId;
  final Map<String, String> _folders = {'': ''};

  /// Lembra os IDs das subpastas de [relDir] vistas numa listagem.
  void learn(String relDir, List<DeviceEntry> children, {String Function(DeviceEntry)? nameOf}) {
    for (final c in children) {
      if (!c.isFolder) continue;
      final name = nameOf?.call(c) ?? c.name;
      _folders[relDir.isEmpty ? name : '$relDir/$name'] = c.objectId;
    }
  }

  /// Nomes dos armazenamentos na raiz, sem repetição (L7).
  static List<String> storageNames(List<DeviceEntry> storages) {
    final seen = <String, int>{};
    return [
      for (final s in storages)
        () {
          final n = seen[s.name.toLowerCase()] = (seen[s.name.toLowerCase()] ?? 0) + 1;
          return n == 1 ? s.name : '${s.name} ($n)';
        }(),
    ];
  }

  /// Lista a raiz e devolve os armazenamentos com o nome usado no catálogo.
  Future<List<(String, DeviceEntry)>> storages() async {
    final root = await backend.listChildren(deviceId, '');
    final names = storageNames(root);
    final result = [for (var i = 0; i < root.length; i++) (names[i], root[i])];
    for (final (name, entry) in result) {
      _folders[name] = entry.objectId;
    }
    return result;
  }

  /// ID da pasta [relDir]; `null` se ela não existe mais no aparelho.
  Future<String?> folder(String relDir, {bool refresh = false}) async {
    if (refresh) _forget(relDir);
    final cached = _folders[relDir];
    if (cached != null) return cached;
    final slash = relDir.lastIndexOf('/');
    if (slash < 0) {
      await storages();
      return _folders[relDir];
    }
    final parent = relDir.substring(0, slash);
    final parentId = await folder(parent);
    if (parentId == null) return null;
    final children = await _listOrRefresh(parent, parentId);
    learn(parent, children);
    return _folders[relDir];
  }

  /// Lista [relDir] (re-resolvendo o ID uma vez se ele ficou velho).
  Future<List<DeviceEntry>?> list(String relDir) async {
    final id = await folder(relDir);
    if (id == null) return null;
    final children = await _listOrRefresh(relDir, id);
    if (relDir.isNotEmpty) learn(relDir, children);
    return children;
  }

  /// ID atual do arquivo [relPath] (procura pelo nome na pasta).
  Future<String?> file(String relPath) async {
    final slash = relPath.lastIndexOf('/');
    if (slash < 0) return null;
    final children = await list(relPath.substring(0, slash));
    final name = relPath.substring(slash + 1);
    for (final c in children ?? const <DeviceEntry>[]) {
      if (!c.isFolder && c.name == name) return c.objectId;
    }
    return null;
  }

  Future<List<DeviceEntry>> _listOrRefresh(String relDir, String id) async {
    try {
      return await backend.listChildren(deviceId, id);
    } on DeviceException catch (e) {
      if (e.code != 'not_found' || relDir.isEmpty) rethrow;
      final fresh = await folder(relDir, refresh: true);
      if (fresh == null) throw DeviceException('not_found', 'A pasta "$relDir" não existe mais no aparelho.');
      return backend.listChildren(deviceId, fresh);
    }
  }

  void _forget(String relDir) {
    _folders.removeWhere((k, _) => k.isNotEmpty && (k == relDir || k.startsWith('$relDir/')));
  }
}
