import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Cria uma pasta temporária para o teste e a remove ao final.
///
/// Todo caminho de trabalho de teste deve passar por [assertInTemp]: os testes
/// nunca tocam pastas fora do temp do sistema (CLAUDE.md).
Future<Directory> createTestTemp([String prefix = 'fotoatlas_test_']) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() => deleteTestDir(dir));
  return dir;
}

void assertInTemp(String path) {
  final temp = p.canonicalize(Directory.systemTemp.path);
  final target = p.canonicalize(path);
  if (!p.isWithin(temp, target)) {
    throw StateError('Caminho de teste fora do temp do sistema: $target');
  }
}

/// Apaga uma pasta de teste. No Windows um processo recém-encerrado (CLI
/// morta, helper saindo pelo vigia do processo pai) ou o antivírus ainda podem
/// segurar arquivos por alguns instantes: tenta por até ~10 s. Se ainda assim
/// sobrar, o teste falha — pasta esquecida em %TEMP% é defeito (catálogo ou
/// processo que não foi fechado), não algo para ignorar.
Future<void> deleteTestDir(Directory dir) async {
  assertInTemp(dir.path);
  FileSystemException? last;
  for (var attempt = 0; attempt < 50; attempt++) {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException catch (e) {
      last = e;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  fail('Não foi possível apagar a pasta de teste ${dir.path}: $last');
}
