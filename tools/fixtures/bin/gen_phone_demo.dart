import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Celulares simulados + HD de backup para testar a Fase 3 sem celular real.
///
/// Uso: `dart run bin/gen_phone_demo.dart --out PASTA [--leitura-lenta MS]`
/// (pasta vazia, no temp do sistema). Depois abra o app com
/// `FOTOATLAS_FAKE_DEVICES=<PASTA>\celulares`.
///   --leitura-lenta MS: cada arquivo do Pixel leva MS milissegundos para ser
///   conferido (dá tempo de fechar o app no meio da conferência).
void main(List<String> args) {
  final i = args.indexOf('--out');
  final slow = args.indexOf('--leitura-lenta');
  final delayMs = slow >= 0 && slow + 1 < args.length ? int.tryParse(args[slow + 1]) : null;
  if (i < 0 || i + 1 >= args.length || (slow >= 0 && (delayMs == null || delayMs < 0))) {
    stdout.writeln('Uso: dart run bin/gen_phone_demo.dart --out <pasta vazia no temp> [--leitura-lenta MS]');
    exit(64);
  }
  final out = args[i + 1];
  assertAllowedOutput(out);
  final dir = Directory(out);
  if (dir.existsSync() && dir.listSync().isNotEmpty) {
    stderr.writeln('A pasta de saída precisa estar vazia: $out');
    exit(1);
  }
  final demo = generatePhoneDemo(out, pixelFaults: delayMs != null && delayMs > 0 ? {'readDelayMs': delayMs} : null);
  stdout
    ..writeln('Celulares simulados: ${p.canonicalize(demo.devicesDir)}')
    ..writeln('HD de backup (cadastre como pasta): ${p.canonicalize(demo.hdDir)}')
    ..writeln('Câmera com o relógio 1 h adiantado (cadastre como pasta): ${p.canonicalize(demo.cameraDir)}')
    ..writeln('Esperado (Pixel × HD): faltam 3 · nos dois 3 · só em B 1')
    ..writeln('Desplugar o Pixel: renomeie pixel.json para pixel.json.off');
  if (delayMs != null && delayMs > 0) stdout.writeln('Leitura lenta no Pixel: $delayMs ms por arquivo');
}
