import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import 'source_reader.dart';

/// Nome da pasta temporária do FotoAtlas na raiz do destino (spec §11.1).
const String tempDirName = '.fotoatlas-tmp';

/// `true` se [path] é um `.part` dentro de uma pasta `.fotoatlas-tmp`: o
/// único tipo de arquivo que o FotoAtlas cria do zero e pode apagar (só os
/// próprios, registrados no diário).
bool isOwnPartPath(String path) {
  final norm = path.replaceAll('/', r'\');
  if (norm.split(r'\').contains('..')) return false;
  return p.windows.extension(norm).toLowerCase() == '.part' &&
      p.windows.basename(p.windows.dirname(norm)).toLowerCase() == tempDirName;
}

/// Arquivo temporário novo no destino (`<destino>\.fotoatlas-tmp\<uuid>.part`).
///
/// É a única escrita de conteúdo do core: `CREATE_NEW` (nunca abre, trunca ou
/// sobrescreve um arquivo existente), sem compartilhamento enquanto grava e
/// só em caminhos `.part` dentro de `.fotoatlas-tmp` (teste de arquitetura).
class PartWriter {
  PartWriter._(this._handle, this.path);

  final int _handle;
  final String path;
  bool _closed = false;

  /// Cria o arquivo. Lança [Win32Exception] (ex.: `ERROR_FILE_EXISTS`).
  static PartWriter create(String path) {
    if (!isOwnPartPath(path)) throw ArgumentError.value(path, 'path', 'não é um .part em $tempDirName');
    return retryOnZeroError(() => _create(path));
  }

  static PartWriter _create(String path) {
    final handle = using(
      (arena) => createFile(
        toExtendedPath(path).toNativeUtf16(allocator: arena),
        genericWrite,
        0,
        nullptr,
        createNew,
        fileAttributeNormal,
        0,
      ),
    );
    if (handle == invalidHandleValue) throw Win32Exception('CreateFileW', getLastError(), path);
    return PartWriter._(handle, path);
  }

  /// Grava [length] bytes de [buffer] (tudo, ou lança).
  void write(Pointer<Uint8> buffer, int length) => using((arena) {
    final written = arena<Uint32>();
    var offset = 0;
    while (offset < length) {
      if (writeFile(_handle, buffer + offset, length - offset, written, nullptr) == 0) {
        throw Win32Exception('WriteFile', getLastError(), path);
      }
      if (written.value == 0) throw Win32Exception('WriteFile', errorGenFailure, path);
      offset += written.value;
    }
  });

  /// Data de modificação igual à da origem (FILETIME).
  void setModified(int fileTime) => using((arena) {
    final t = arena<Uint64>()..value = fileTime;
    if (setFileTime(_handle, nullptr, nullptr, t) == 0) throw Win32Exception('SetFileTime', getLastError(), path);
  });

  /// `FlushFileBuffers`: só volta quando os dados chegaram ao disco.
  void flush() {
    if (flushFileBuffers(_handle) == 0) throw Win32Exception('FlushFileBuffers', getLastError(), path);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    closeHandle(_handle);
  }
}

/// Cria [dirPath] e as pastas acima que faltarem (nunca apaga nem substitui
/// nada). Lança [Win32Exception] se um nome do caminho já for um arquivo.
void ensureDirectory(String dirPath) {
  final full = dirPath.replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '');
  if (_isDirectory(full)) return;
  final parent = p.windows.dirname(full);
  if (parent != full) ensureDirectory(parent);
  retryOnZeroError(() {
    final ok = using((arena) => createDirectory(toExtendedPath(full).toNativeUtf16(allocator: arena), nullptr));
    if (ok != 0) return;
    final code = getLastError();
    if (code == errorAlreadyExists && _isDirectory(full)) return;
    throw Win32Exception('CreateDirectoryW', code, full);
  });
}

bool _isDirectory(String path) {
  try {
    return attributesOf(path).attributes & fileAttributeDirectory != 0;
  } on Win32Exception {
    return false;
  }
}

/// Apaga um `.part` **do próprio FotoAtlas** (nunca publicado, registrado no
/// diário). Recusa qualquer outro caminho. Devolve `false` se não conseguiu
/// (ex.: ainda aberto por outro processo); nesse caso ele fica e aparece na
/// lista de arquivos da pasta temporária.
bool deleteOwnPart(String path) {
  if (!isOwnPartPath(path)) throw ArgumentError.value(path, 'path', 'não é um .part em $tempDirName');
  for (var attempt = 0; attempt < 3; attempt++) {
    final ok = using((arena) => deleteFile(toExtendedPath(path).toNativeUtf16(allocator: arena)));
    if (ok != 0) return true;
    final code = getLastError();
    // Código 0 = erro perdido pela VM (ver retryOnZeroError): tenta de novo.
    if (code != 0) return code == errorFileNotFound || code == errorPathNotFound;
  }
  return false;
}
