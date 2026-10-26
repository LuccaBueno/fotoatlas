import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Cria uma pasta temporária para o teste e a remove ao final.
///
/// Todo caminho de trabalho de teste deve passar por [assertInTemp]: os testes
/// nunca tocam pastas fora do temp do sistema (CLAUDE.md).
Future<Directory> createTestTemp([String prefix = 'fotoatlas_test_']) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() async {
    if (await dir.exists()) await _deleteBestEffort(dir);
  });
  return dir;
}

void assertInTemp(String path) {
  final temp = p.canonicalize(Directory.systemTemp.path);
  final target = p.canonicalize(path);
  if (!p.isWithin(temp, target)) {
    throw StateError('Caminho de teste fora do temp do sistema: $target');
  }
}

Future<void> _deleteBestEffort(Directory dir) async {
  assertInTemp(dir.path);
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}
