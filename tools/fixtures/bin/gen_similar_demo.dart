import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Gera a demonstração das fotos parecidas (ver [generateSimilarDemo]).
///
/// Uso: `dart run bin/gen_similar_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_similar_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  generateSimilarDemo(out);
  stdout
    ..writeln('Demonstração de fotos parecidas gerada em: ${p.canonicalize(out)}')
    ..writeln('Cadastre a pasta, escaneie e abra "Parecidas".');
}
