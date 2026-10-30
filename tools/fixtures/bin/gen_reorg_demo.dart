import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Gera o "HD bagunçado" (ver [generateReorgDemo]).
///
/// Uso: `dart run bin/gen_reorg_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_reorg_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  generateReorgDemo(out);
  stdout
    ..writeln('HD bagunçado gerado em: ${p.canonicalize(out)}')
    ..writeln('Cadastre como pasta, escaneie e use "Reorganizar…" com "Por ano e momento".');
}
