import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';

/// Tamanho, data de modificação e atributos de um arquivo.
class SourceFileInfo {
  const SourceFileInfo({required this.size, required this.mtime, required this.attributes});
  final int size;

  /// FILETIME (100 ns desde 1601, UTC), como no catálogo.
  final int mtime;
  final int attributes;

  /// Placeholder de nuvem: ler (ou até abrir) dispararia o download.
  bool get isCloudPlaceholder =>
      attributes & (fileAttributeRecallOnDataAccess | fileAttributeRecallOnOpen | fileAttributeOffline) != 0;
}

/// Atributos sem abrir o arquivo (`GetFileAttributesExW`). Não dispara o
/// download de placeholders de nuvem.
SourceFileInfo attributesOf(String path) => retryOnZeroError(() => _attributesOf(path));

SourceFileInfo _attributesOf(String path) => using((arena) {
  final data = arena<Uint8>(win32FileAttributeDataSize);
  if (getFileAttributesEx(toExtendedPath(path).toNativeUtf16(allocator: arena), getFileExInfoStandard, data) == 0) {
    throw Win32Exception('GetFileAttributesExW', getLastError(), path);
  }
  final bd = ByteData.sublistView(data.asTypedList(win32FileAttributeDataSize));
  return SourceFileInfo(
    attributes: bd.getUint32(0, Endian.little),
    mtime: bd.getUint32(20, Endian.little) | (bd.getUint32(24, Endian.little) << 32),
    size: (bd.getUint32(28, Endian.little) << 32) | bd.getUint32(32, Endian.little),
  );
});

/// Arquivo de origem aberto **somente para leitura** (regra 2).
///
/// É a única forma de o core abrir um arquivo de usuário: `GENERIC_READ`,
/// compartilhado (não atrapalha outros programas), `OPEN_EXISTING` (nunca
/// cria) e `FILE_FLAG_OPEN_NO_RECALL` (não baixa conteúdo da nuvem). O teste
/// de arquitetura confere essas flags.
class SourceFile {
  SourceFile._(this._handle, this.path);

  final int _handle;
  final String path;
  bool _closed = false;

  /// Abre [path] para leitura. Lança [Win32Exception] se não conseguir.
  static SourceFile open(String path) => retryOnZeroError(() => _open(path));

  static SourceFile _open(String path) {
    final handle = using(
      (arena) => createFile(
        toExtendedPath(path).toNativeUtf16(allocator: arena),
        genericRead,
        fileShareRead | fileShareWrite | fileShareDelete,
        nullptr,
        openExisting,
        fileFlagSequentialScan | fileFlagOpenNoRecall,
        0,
      ),
    );
    if (handle == invalidHandleValue) throw Win32Exception('CreateFileW', getLastError(), path);
    return SourceFile._(handle, path);
  }

  /// Estado atual pelo handle aberto (`GetFileInformationByHandle`).
  SourceFileInfo info() => using((arena) {
    final data = arena<Uint8>(byHandleFileInformationSize);
    if (getFileInformationByHandle(_handle, data) == 0) {
      throw Win32Exception('GetFileInformationByHandle', getLastError(), path);
    }
    final bd = ByteData.sublistView(data.asTypedList(byHandleFileInformationSize));
    return SourceFileInfo(
      attributes: bd.getUint32(0, Endian.little),
      mtime: bd.getUint32(20, Endian.little) | (bd.getUint32(24, Endian.little) << 32),
      size: (bd.getUint32(32, Endian.little) << 32) | bd.getUint32(36, Endian.little),
    );
  });

  /// Lê até [length] bytes em [buffer]. Devolve 0 no fim do arquivo.
  int read(Pointer<Uint8> buffer, int length) => using((arena) {
    final read = arena<Uint32>();
    if (readFile(_handle, buffer, length, read, nullptr) == 0) {
      throw Win32Exception('ReadFile', getLastError(), path);
    }
    return read.value;
  });

  void close() {
    if (_closed) return;
    _closed = true;
    closeHandle(_handle);
  }
}
