import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Gera a demonstração dos itens agrupados, RAW+JPEG e Live Photos (ver [generateItemsDemo]).
///
/// Uso: `dart run bin/gen_items_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_items_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  generateItemsDemo(out);
  stdout
    ..writeln('Demonstração de itens agrupados gerada em: ${p.canonicalize(out)}')
    ..writeln('Cadastre a pasta, escaneie e abra a Biblioteca.');
}
