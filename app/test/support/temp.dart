import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Apaga uma pasta de teste do temp do sistema (rodar dentro de
/// `tester.runAsync`, que tem tempo real). Tenta por até ~10 s, porque o
/// Windows pode segurar arquivos por instantes depois do catálogo fechar; se
/// ainda sobrar, o teste falha em vez de deixar lixo em %TEMP%.
Future<void> deleteTestDir(Directory dir) async {
  final temp = p.canonicalize(Directory.systemTemp.path);
  if (!p.isWithin(temp, p.canonicalize(dir.path))) {
    throw StateError('Caminho de teste fora do temp do sistema: ${dir.path}');
  }
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
