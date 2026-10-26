import 'dart:io';

/// O catálogo já está aberto por outro processo do FotoAtlas.
class CatalogInUseException implements Exception {
  @override
  String toString() =>
      'O catálogo já está em uso por outro processo do FotoAtlas (app ou CLI). '
      'Feche o outro processo e tente de novo.';
}

/// Trava exclusiva do catálogo: um processo por vez. O SO a libera se o
/// processo morrer, então não sobra trava "presa" após uma queda.
class InstanceLock {
  InstanceLock._(this._file);
  final RandomAccessFile _file;

  static Future<InstanceLock> acquire(String path) async {
    final file = await File(path).open(mode: FileMode.append);
    try {
      await file.lock(FileLock.exclusive);
    } on FileSystemException {
      await file.close();
      throw CatalogInUseException();
    }
    return InstanceLock._(file);
  }

  Future<void> release() async {
    try {
      await _file.unlock();
    } finally {
      await _file.close();
    }
  }
}
