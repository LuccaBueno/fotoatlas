import 'dart:io';
import 'dart:math';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

/// Cenário sintético da comparação com escopo livre (Fase 2):
///
///     HD_antigo/pasta1  HD_antigo/pasta2   ×   HD_novo/pasta3
///
/// com nomes diferentes e conteúdo parcial. Resultado esperado para
/// A = pasta1 + pasta2 e B = pasta3: faltam 2 (IMG_0002.jpg e notas.txt),
/// só em B 1 (extra.jpg), nos dois 2 (IMG_0001 e VID_0001, com outros nomes).
///
/// Uso: `dart run bin/gen_compare_demo.dart --out PASTA` (no temp do sistema).
void main(List<String> args) {
  final i = args.indexOf('--out');
  if (i < 0 || i + 1 >= args.length) {
    stdout.writeln('Uso: dart run bin/gen_compare_demo.dart --out <pasta vazia no temp>');
    exit(64);
  }
  final out = args[i + 1];
  assertAllowedOutput(out);
  final dir = Directory(out);
  if (dir.existsSync() && dir.listSync().isNotEmpty) {
    stderr.writeln('A pasta de saída precisa estar vazia: $out');
    exit(1);
  }

  List<int> content(int seed, int size) {
    final r = Random(seed);
    return List.generate(size, (_) => r.nextInt(256));
  }

  void write(String rel, List<int> bytes) {
    final f = File(p.join(out, rel));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
  }

  final c1 = content(1, 800 * 1024), c2 = content(2, 1200 * 1024), c3 = content(3, 3 * 1024 * 1024);
  final c4 = content(4, 2 * 1024), c5 = content(5, 600 * 1024);
  write('HD_antigo/pasta1/IMG_0001.jpg', c1);
  write('HD_antigo/pasta1/copia de IMG_0001.jpg', c1);
  write('HD_antigo/pasta1/IMG_0002.jpg', c2);
  write('HD_antigo/pasta2/VID_0001.mp4', c3);
  write('HD_antigo/pasta2/notas.txt', c4);
  write('HD_antigo/fora_do_escopo/IMG_0002.jpg', c2);
  write('HD_novo/pasta3/foto renomeada.jpg', c1);
  write('HD_novo/pasta3/2020/video.mp4', c3);
  write('HD_novo/pasta3/extra.jpg', c5);

  stdout
    ..writeln('Cenário gerado em: ${p.canonicalize(out)}')
    ..writeln('A = HD_antigo › pasta1 + pasta2 · B = HD_novo › pasta3')
    ..writeln('Esperado: faltam 2 (IMG_0002.jpg, notas.txt) · só em B 1 (extra.jpg) · nos dois 2');
}
