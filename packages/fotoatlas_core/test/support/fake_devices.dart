import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

/// Celular simulado em memória. Os caminhos começam pelo nome do
/// armazenamento (`Interno/DCIM/Camera/a.jpg`).
class FakePhone {
  FakePhone({
    this.deviceId = r'\\?\usb#vid_18d1&pid_4ee1#fake0001#{6ac27878}',
    this.name = 'Pixel de Teste',
    this.serial = 'FAKE-0001',
    this.platform = 'android',
    this.status = 'ok',
  });

  String deviceId;
  String name;
  String? serial;
  String platform;
  String status;
  final files = <String, List<int>>{};
  final modified = <String, int?>{};
  final folders = <String>{};

  /// IDs de objeto mudam a cada "sessão" (como no Android ao reconectar).
  int session = 0;

  void put(String path, List<int> bytes, {int? mtime = 133000000000000000}) {
    files[path] = bytes;
    modified[path] = mtime;
  }

  Set<String> get allFolders {
    final set = <String>{...folders};
    for (final path in [...files.keys, ...folders]) {
      var p = path;
      while (p.contains('/')) {
        p = p.substring(0, p.lastIndexOf('/'));
        set.add(p);
      }
    }
    return set;
  }

  String idOf(String path) => 's$session|$path';
}

class FakeDeviceBackend implements DeviceBackend {
  final phones = <FakePhone>[];

  /// Depois de N listagens, o aparelho "sai" (desconexão no meio do scan).
  int? goneAfterListCalls;
  int listCalls = 0;

  /// Simula o helper travado (ex.: leitura WPD presa): a partir da
  /// listagem N, ou em todo hash, a chamada nunca responde e ignora o
  /// cancelamento.
  int? stallAfterListCalls;
  bool stallHash = false;

  /// Depois de N leituras concluídas, a próxima trava (fechar no meio).
  int? stallAfterHashCalls;
  static final Future<Never> _never = Completer<Never>().future;

  /// Chamado antes de cada hash (para desplugar no meio, por exemplo).
  void Function(String path)? beforeHash;
  final changedDuringRead = <String>{};
  int hashCalls = 0;

  FakePhone _connected(String deviceId) {
    final phone = phones.where((p) => p.deviceId == deviceId).firstOrNull;
    if (phone == null) throw DeviceException('device_disconnected', 'O dispositivo não está conectado.');
    if (phone.status == 'locked') throw DeviceException('device_locked', 'Bloqueado.');
    return phone;
  }

  @override
  Future<List<DeviceInfo>> list() async => [
    for (final p in phones)
      DeviceInfo(
        deviceId: p.deviceId,
        friendlyName: p.name,
        manufacturer: p.platform == 'iphone' ? 'Apple Inc.' : 'Google',
        model: p.platform == 'iphone' ? 'iPhone' : 'Pixel 9',
        serial: p.serial,
        platform: p.platform,
        status: p.status,
        storages: p.status != 'ok'
            ? const []
            : [
                for (final s in {for (final f in p.allFolders) f.split('/').first})
                  DeviceStorage(storageId: p.idOf(s), name: s, totalBytes: 64000000000, freeBytes: 1000000000),
              ],
      ),
  ];

  @override
  Future<List<DeviceEntry>> listChildren(String deviceId, String objectId) async {
    final phone = _connected(deviceId);
    listCalls++;
    final stall = stallAfterListCalls;
    if (stall != null && listCalls > stall) await _never;
    final limit = goneAfterListCalls;
    if (limit != null && listCalls > limit) {
      phones.remove(phone);
      throw DeviceException('device_disconnected', 'O dispositivo foi desconectado.');
    }
    final String folder;
    if (objectId.isEmpty) {
      folder = '';
    } else {
      final prefix = 's${phone.session}|';
      if (!objectId.startsWith(prefix)) throw DeviceException('not_found', 'ID de outra sessão.');
      folder = objectId.substring(prefix.length);
      if (!phone.allFolders.contains(folder)) throw DeviceException('not_found', 'Pasta não existe.');
    }
    bool isChild(String path) {
      if (folder.isEmpty) return !path.contains('/');
      return path.startsWith('$folder/') && !path.substring(folder.length + 1).contains('/');
    }

    String nameOf(String path) => path.substring(path.lastIndexOf('/') + 1);
    final dirs = phone.allFolders.where(isChild).toList()..sort();
    final files = phone.files.keys.where(isChild).toList()..sort();
    return [
      for (final d in dirs) DeviceEntry(objectId: phone.idOf(d), name: nameOf(d), isFolder: true),
      for (final f in files)
        DeviceEntry(
          objectId: phone.idOf(f),
          name: nameOf(f),
          isFolder: false,
          size: phone.files[f]!.length,
          modified: phone.modified[f],
          created: phone.modified[f],
        ),
    ];
  }

  @override
  Future<DeviceHash> hash(String deviceId, String objectId, {required int expectedSize, Future<void>? cancel}) async {
    final phone = _connected(deviceId);
    final prefix = 's${phone.session}|';
    if (!objectId.startsWith(prefix)) throw DeviceException('not_found', 'ID de outra sessão.');
    final path = objectId.substring(prefix.length);
    beforeHash?.call(path);
    if (stallHash) await _never;
    final stallAt = stallAfterHashCalls;
    if (stallAt != null && hashCalls >= stallAt) await _never;
    _connected(deviceId);
    final bytes = phone.files[path];
    if (bytes == null) throw DeviceException('not_found', 'Arquivo não existe.');
    hashCalls++;
    if (bytes.length != expectedSize || changedDuringRead.contains(path)) {
      throw DeviceException('changed_during_read', 'O arquivo mudou enquanto era lido.');
    }
    return DeviceHash(Uint8List.fromList(sha256.convert(bytes).bytes), bytes.length, phone.modified[path]);
  }
}
