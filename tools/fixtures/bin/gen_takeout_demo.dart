import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Gera a demonstração do Google Takeout (pasta e zips) (ver [generateTakeoutDemo]).
///
/// Uso: `dart run bin/gen_takeout_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_takeout_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  generateTakeoutDemo(out);
  stdout
    ..writeln('Demonstração do Google Takeout gerada em: ${p.canonicalize(out)}')
    ..writeln('Cadastre "Pasta" e "Zips", escaneie e use "Extrair zip do Google Takeout…".');
}
