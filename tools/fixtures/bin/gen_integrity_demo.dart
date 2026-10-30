import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Gera a demonstração da verificação de integridade (ver [generateIntegrityDemo]).
///
/// Uso: `dart run bin/gen_integrity_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_integrity_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  generateIntegrityDemo(out);
  stdout
    ..writeln('Demonstração de integridade gerada em: ${p.canonicalize(out)}')
    ..writeln('Cadastre "HD fotos" e "HD cópia" como pastas, escaneie e espere a conferência.');
}
