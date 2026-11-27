import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Gera a demonstração do "Limpar repetidos" (ver [generateDedupeDemo]).
///
/// Uso: `dart run bin/gen_dedupe_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_dedupe_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  generateDedupeDemo(out);
  stdout
    ..writeln('Demonstração dos repetidos gerada em: ${p.canonicalize(out)}')
    ..writeln('Cadastre a pasta, escaneie e abra Repetidos.');
}
