import 'package:ffi/ffi.dart';

import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import 'source_reader.dart';

/// Situação de uma pasta para "Remover pastas vazias".
enum FolderEmptiness {
  /// Sem nada dentro (nem oculto), ou só com subpastas também vazias.
  empty,

  /// Tem algum arquivo (inclusive oculto ou de sistema, ex.: `Thumbs.db`).
  hasFiles,

  /// Não existe mais, não é pasta, é um atalho de pasta (junção) ou não deu
  /// para ler: não mexe.
  unavailable,
}

/// Olha [dirPath] **e todas as subpastas**: vazia só se não houver nenhum
/// arquivo em lugar nenhum (ocultos e de sistema contam como arquivo).
FolderEmptiness folderEmptiness(String dirPath) {
  try {
    final info = attributesOf(dirPath);
    if (info.attributes & fileAttributeDirectory == 0) return FolderEmptiness.unavailable;
    if (info.attributes & fileAttributeReparsePoint != 0) return FolderEmptiness.unavailable;
    for (final e in listDirectory(dirPath)) {
      if (!e.isDirectory || e.attributes & fileAttributeReparsePoint != 0) return FolderEmptiness.hasFiles;
      final sub = folderEmptiness(joinNative(dirPath, e.name));
      if (sub != FolderEmptiness.empty) return sub == FolderEmptiness.unavailable ? FolderEmptiness.hasFiles : sub;
    }
    return FolderEmptiness.empty;
  } on Win32Exception {
    return FolderEmptiness.unavailable;
  }
}

/// `true` se [dirPath] (e subpastas) só tem arquivos ocultos ou de sistema
/// (ex.: `Thumbs.db`, `desktop.ini`): para avisar que a pasta não está vazia.
bool onlyHiddenFiles(String dirPath) {
  try {
    var any = false;
    for (final e in listDirectory(dirPath)) {
      if (e.attributes & fileAttributeReparsePoint != 0) return false;
      if (e.isDirectory) {
        final sub = folderEmptiness(joinNative(dirPath, e.name));
        if (sub == FolderEmptiness.unavailable) return false;
        if (sub == FolderEmptiness.hasFiles) {
          if (!onlyHiddenFiles(joinNative(dirPath, e.name))) return false;
          any = true;
        }
        continue;
      }
      if (e.attributes & (fileAttributeHidden | fileAttributeSystem) == 0) return false;
      any = true;
    }
    return any;
  } on Win32Exception {
    return false;
  }
}

/// Remove **uma** pasta [dirPath] só se ela não tiver nada dentro agora
/// (conferido aqui, inclusive ocultos) e não for junção. Não é recursivo: para
/// remover uma pasta com subpastas vazias, remova as subpastas antes (da mais
/// funda para a mais rasa). Usa `RemoveDirectoryW`, que o próprio Windows
/// recusa em pasta com qualquer coisa dentro: nunca apaga arquivo. Devolve
/// `false` se não removeu (não estava vazia, sumiu ou o Windows recusou).
bool removeEmptyFolder(String dirPath) {
  try {
    final info = attributesOf(dirPath);
    if (info.attributes & fileAttributeDirectory == 0 || info.attributes & fileAttributeReparsePoint != 0) {
      return false;
    }
    if (listDirectory(dirPath).isNotEmpty) return false;
  } on Win32Exception {
    return false;
  }
  return retryOnZeroError(() {
    final ok = using((arena) => removeDirectory(toExtendedPath(dirPath).toNativeUtf16(allocator: arena)));
    if (ok != 0) return true;
    final code = getLastError();
    if (code == errorDirNotEmpty || code == errorFileNotFound || code == errorPathNotFound) return false;
    throw Win32Exception('RemoveDirectoryW', code, dirPath);
  });
}
