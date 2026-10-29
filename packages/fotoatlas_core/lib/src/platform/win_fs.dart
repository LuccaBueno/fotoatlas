import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'win32/kernel32.dart';

/// Falha de uma chamada Win32, com o código de `GetLastError`.
class Win32Exception implements Exception {
  Win32Exception(this.operation, this.code, [this.path]);
  final String operation;
  final int code;
  final String? path;

  @override
  String toString() => '$operation falhou (Win32 $code)${path == null ? '' : ': $path'}';
}

/// Uma entrada de diretório, exatamente como o `FindFirstFileExW` devolve.
class RawDirEntry {
  const RawDirEntry({
    required this.name,
    required this.attributes,
    required this.size,
    required this.mtime,
    required this.ctime,
    required this.reparseTag,
  });

  final String name;
  final int attributes;
  final int size;

  /// FILETIME (100 ns desde 1601, UTC).
  final int mtime;
  final int ctime;

  /// Válida só quando [attributes] tem `FILE_ATTRIBUTE_REPARSE_POINT`.
  final int reparseTag;

  bool get isDirectory => attributes & fileAttributeDirectory != 0;
  bool get isReparsePoint => attributes & fileAttributeReparsePoint != 0;
}

/// Converte para caminho estendido `\\?\` (caminhos longos, sem normalização
/// do Win32). Aceita caminhos absolutos com `\` ou `/`.
String toExtendedPath(String path) {
  var p = path.replaceAll('/', r'\');
  if (p.startsWith(r'\\?\')) return p;
  if (p.startsWith(r'\\.\')) return r'\\?\' + p.substring(4);
  if (p.startsWith(r'\\')) return r'\\?\UNC\' + p.substring(2);
  return r'\\?\' + p;
}

/// Junta uma raiz Win32 e um caminho relativo com `/`.
String joinNative(String root, String relPath) {
  final base = root.endsWith(r'\') ? root.substring(0, root.length - 1) : root;
  if (relPath.isEmpty) return base;
  return '$base\\${relPath.replaceAll('/', r'\')}';
}

/// Lista um diretório (sem recursão) com `FindFirstFileExW`.
///
/// Não segue nada, não abre arquivos e não dispara download de placeholders
/// de nuvem. Lança [Win32Exception] se o diretório não puder ser listado.
///
/// O `GetLastError` lido via FFI às vezes vem zerado pela VM (medido: ~1 em
/// 2.000 enumerações). Por isso só `ERROR_NO_MORE_FILES` encerra a lista;
/// qualquer outra falha refaz a listagem inteira, e se persistir vira erro
/// daquela pasta — nunca "lista mais curta" (regra 10).
List<RawDirEntry> listDirectory(String dirPath, {int attempts = 3}) {
  for (var attempt = 1; ; attempt++) {
    try {
      return _listDirectoryOnce(dirPath);
    } on Win32Exception {
      if (attempt >= attempts) rethrow;
    }
  }
}

List<RawDirEntry> _listDirectoryOnce(String dirPath) {
  final pattern = '${toExtendedPath(dirPath).replaceAll(RegExp(r'\\+$'), '')}\\*';
  return using((arena) {
    final data = arena<Uint8>(win32FindDataSize);
    final patternPtr = pattern.toNativeUtf16(allocator: arena);
    final handle = findFirstFileEx(
      patternPtr,
      findExInfoBasic,
      data,
      findExSearchNameMatch,
      nullptr,
      findFirstExLargeFetch,
    );
    if (handle == invalidHandleValue) {
      final code = getLastError();
      // Raiz de volume vazia: não há nem "." nem "..".
      if (code == errorFileNotFound) return const <RawDirEntry>[];
      throw Win32Exception('FindFirstFileExW', code, dirPath);
    }
    final entries = <RawDirEntry>[];
    try {
      // Visão sobre a memória nativa; ByteData lê os campos desalinhados.
      final bd = ByteData.sublistView(data.asTypedList(win32FindDataSize));
      while (true) {
        final name = readFixedUtf16(data, 44, 260);
        if (name != '.' && name != '..') {
          final attributes = bd.getUint32(0, Endian.little);
          final ctime = bd.getUint32(4, Endian.little) | (bd.getUint32(8, Endian.little) << 32);
          final mtime = bd.getUint32(20, Endian.little) | (bd.getUint32(24, Endian.little) << 32);
          final size = (bd.getUint32(28, Endian.little) << 32) | bd.getUint32(32, Endian.little);
          entries.add(
            RawDirEntry(
              name: name,
              attributes: attributes,
              size: size,
              mtime: mtime,
              ctime: ctime,
              reparseTag: bd.getUint32(36, Endian.little),
            ),
          );
        }
        if (findNextFile(handle, data) == 0) {
          final code = getLastError();
          if (code == errorNoMoreFiles) break;
          throw Win32Exception('FindNextFileW', code, dirPath);
        }
      }
    } finally {
      findClose(handle);
    }
    return entries;
  });
}

/// Raiz do volume que contém [path] (ex.: `D:\` ou `C:\Montagens\HD\`).
String volumeRootFor(String path) => using((arena) {
  const size = 1024;
  final buffer = arena<Uint16>(size).cast<Utf16>();
  if (getVolumePathName(path.toNativeUtf16(allocator: arena), buffer, size) == 0) {
    throw Win32Exception('GetVolumePathNameW', getLastError(), path);
  }
  return buffer.toDartString();
});

/// GUID do volume montado em [mountRoot] (`\\?\Volume{...}\`).
String volumeGuidForRoot(String mountRoot) => using((arena) {
  const size = 64;
  final root = mountRoot.endsWith(r'\') ? mountRoot : '$mountRoot\\';
  final buffer = arena<Uint16>(size).cast<Utf16>();
  if (getVolumeNameForVolumeMountPoint(root.toNativeUtf16(allocator: arena), buffer, size) == 0) {
    throw Win32Exception('GetVolumeNameForVolumeMountPointW', getLastError(), mountRoot);
  }
  return buffer.toDartString();
});

/// Diretório existe e pode ser listado?
bool directoryAccessible(String dirPath) {
  try {
    listDirectory(dirPath);
    return true;
  } on Win32Exception {
    return false;
  }
}

/// Bytes livres para o usuário no volume que contém [path]
/// (`GetDiskFreeSpaceExW`, respeita cotas). `null` se não der para saber.
int? diskFreeBytes(String path) => using((arena) {
  final free = arena<Uint64>();
  final dir = path.endsWith(r'\') ? path : '$path\\';
  if (getDiskFreeSpaceEx(dir.toNativeUtf16(allocator: arena), free, nullptr, nullptr) == 0) return null;
  return free.value;
});
