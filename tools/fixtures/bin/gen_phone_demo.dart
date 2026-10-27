import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Celulares simulados + HD de backup para testar a Fase 3 sem celular real.
///
/// Uso: `dart run bin/gen_phone_demo.dart --out PASTA` (vazia, no temp do sistema).
/// Depois abra o app com `FOTOATLAS_FAKE_DEVICES=<PASTA>\celulares`.
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_phone_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  assertAllowedOutput(out);
  final dir = Directory(out);
  if (dir.existsSync() && dir.listSync().isNotEmpty) {
    stderr.writeln('A pasta de saída precisa estar vazia: $out');
    exit(1);
  }
  final demo = generatePhoneDemo(out);
  stdout
    ..writeln('Celulares simulados: ${p.canonicalize(demo.devicesDir)}')
    ..writeln('HD de backup (cadastre como pasta): ${p.canonicalize(demo.hdDir)}')
    ..writeln('Esperado (Pixel × HD): faltam 3 · nos dois 3 · só em B 1')
    ..writeln('Desplugar o Pixel: renomeie pixel.json para pixel.json.off');
}
