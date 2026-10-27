import '../devices/devices.dart';
import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import 'entry_classifier.dart';

/// Arquivo encontrado numa pasta.
class ListedFile {
  const ListedFile({
    required this.relPath,
    required this.dirRelPath,
    required this.name,
    required this.size,
    this.mtime,
    this.ctime,
    this.attributes,
    this.cloudOnly = false,
    this.objectId,
  });

  final String relPath;
  final String dirRelPath;
  final String name;
  final int size;
  final int? mtime;
  final int? ctime;
  final int? attributes;
  final bool cloudOnly;

  /// ID do objeto no celular (WPD).
  final String? objectId;
}

/// Resultado da listagem de uma pasta.
class ListedDir {
  ListedDir(this.relDir);
  final String relDir;
  final files = <ListedFile>[];
  final childDirs = <String>[];
  final excludedDirs = <String>[];
  final skippedLinks = <String>[];
  String? errorKind;
  int? errorCode;
  String? errorMessage;
  bool get isError => errorKind != null;
}

/// A fonte inteira ficou inacessível (desconectada, bloqueada…): o scan para
/// como `interrupted` e nada vira ausente (regras 9 e 10).
class SourceGone implements Exception {
  SourceGone(this.message);
  final String message;
}

/// Como o scan lê as pastas de uma fonte.
abstract interface class ScanLister {
  /// `null` se a fonte está acessível; senão, a mensagem para o usuário.
  Future<String?> checkAccessible();

  /// Lista [relDir]. Lança [SourceGone] se a fonte inteira sumiu; erros só
  /// desta pasta vêm em [ListedDir.errorKind].
  Future<ListedDir> list(String relDir);
}

/// Pastas e unidades do Windows (FFI, `FindFirstFileExW`).
class Win32ScanLister implements ScanLister {
  Win32ScanLister(this.accessRoot, {required this.isVolumeRoot});

  /// Raiz Win32 de acesso (ex.: `\\?\Volume{…}\Fotos`).
  final String accessRoot;

  /// A fonte é um volume inteiro (ativa as exclusões de raiz de volume).
  final bool isVolumeRoot;

  @override
  Future<String?> checkAccessible() async =>
      directoryAccessible(accessRoot) ? null : 'A fonte não está acessível (desconectada?).';

  @override
  Future<ListedDir> list(String relDir) async {
    final result = ListedDir(relDir);
    final List<RawDirEntry> entries;
    try {
      entries = listDirectory(joinNative(accessRoot, relDir));
    } on Win32Exception catch (e) {
      if (!directoryAccessible(accessRoot)) {
        throw SourceGone('A fonte foi desconectada durante o escaneamento.');
      }
      result
        ..errorCode = e.code
        ..errorKind = switch (e.code) {
          errorAccessDenied => 'access_denied',
          errorFilenameExcedRange => 'path_too_long',
          _ => 'io_error',
        }
        ..errorMessage = e.toString();
      return result;
    }
    final atVolumeRoot = isVolumeRoot && relDir.isEmpty;
    for (final entry in entries) {
      final rel = relDir.isEmpty ? entry.name : '$relDir/${entry.name}';
      ListedFile file({required bool cloudOnly}) => ListedFile(
        relPath: rel,
        dirRelPath: relDir,
        name: entry.name,
        size: entry.size,
        mtime: entry.mtime,
        ctime: entry.ctime,
        attributes: entry.attributes,
        cloudOnly: cloudOnly,
      );
      switch (classifyEntry(entry, atVolumeRoot: atVolumeRoot)) {
        case EntryAction.file:
          result.files.add(file(cloudOnly: false));
        case EntryAction.cloudOnlyFile:
          result.files.add(file(cloudOnly: true));
        case EntryAction.directory:
          result.childDirs.add(rel);
        case EntryAction.excludedDirectory:
          result.excludedDirs.add(rel);
        case EntryAction.reparsePointSkipped:
          if (entry.isDirectory) result.excludedDirs.add(rel);
          result.skippedLinks.add(rel);
        case EntryAction.ignored:
          break;
      }
    }
    return result;
  }
}

/// Celular pelo helper. A raiz da fonte lista os armazenamentos como pastas
/// (L7: o caminho começa pelo nome do armazenamento).
class PhoneScanLister implements ScanLister {
  PhoneScanLister(this.backend, this.deviceId) : paths = PhonePathResolver(backend, deviceId);

  final DeviceBackend backend;
  final String deviceId;
  final PhonePathResolver paths;

  @override
  Future<String?> checkAccessible() async {
    try {
      final devices = await backend.list();
      final device = devices.where((d) => d.deviceId == deviceId).firstOrNull;
      if (device == null) return 'O celular não está conectado.';
      return phoneStatusMessage(device);
    } on DeviceException catch (e) {
      return 'Não foi possível falar com o celular (${e.message}).';
    }
  }

  @override
  Future<ListedDir> list(String relDir) async {
    final result = ListedDir(relDir);
    try {
      if (relDir.isEmpty) {
        final storages = await paths.storages();
        if (storages.isEmpty) throw SourceGone(lockedMessage);
        for (final (name, _) in storages) {
          result.childDirs.add(name);
        }
        return result;
      }
      final children = await paths.list(relDir);
      if (children == null) {
        // A pasta sumiu entre listar a mãe e listar ela: erro, não ausência.
        return result
          ..errorKind = 'io_error'
          ..errorMessage = 'A pasta não foi encontrada no celular.';
      }
      final slash = relDir.indexOf('/');
      final inStorage = slash < 0 ? '' : relDir.substring(slash + 1);
      for (final c in children) {
        final rel = '$relDir/${c.name}';
        if (c.isFolder) {
          final relInStorage = inStorage.isEmpty ? c.name : '$inStorage/${c.name}';
          (isExcludedPhoneDir(relInStorage) ? result.excludedDirs : result.childDirs).add(rel);
        } else {
          result.files.add(
            ListedFile(
              relPath: rel,
              dirRelPath: relDir,
              name: c.name,
              size: c.size ?? 0,
              mtime: c.modified,
              ctime: c.created,
              objectId: c.objectId,
            ),
          );
        }
      }
      return result;
    } on DeviceException catch (e) {
      if (e.isDeviceGone) throw SourceGone(_goneMessage(e));
      return result
        ..errorKind = 'io_error'
        ..errorMessage = e.message;
    }
  }

  static String _goneMessage(DeviceException e) => switch (e.code) {
    'device_locked' => lockedMessage,
    'device_unauthorized' => unauthorizedMessage,
    'unavailable' => 'A leitura de dispositivos parou. O escaneamento continua quando ela voltar.',
    _ => 'O celular foi desconectado durante o escaneamento.',
  };
}

const lockedMessage =
    'O celular está bloqueado. Desbloqueie a tela e, no aviso "Usar USB para", escolha "Transferência de arquivos".';
const unauthorizedMessage =
    'O celular ainda não permitiu o acesso. Desbloqueie e toque em "Permitir" (Android) ou "Confiar" (iPhone).';

/// Mensagem para o usuário quando o celular não está pronto; `null` se está.
String? phoneStatusMessage(DeviceInfo device) => switch (device.status) {
  'ok' => null,
  'locked' => lockedMessage,
  _ => unauthorizedMessage,
};
