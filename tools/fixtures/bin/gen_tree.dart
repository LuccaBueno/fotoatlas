import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';

/// Uso: `dart run bin/gen_tree.dart --out PASTA [--files 50000] [--seed 1]`
///
/// A pasta precisa estar no temp do sistema ou em tools/fixtures/out.
void main(List<String> args) {
  String? value(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final out = value('--out');
  if (out == null || args.contains('--help')) {
    stdout.writeln('Uso: dart run bin/gen_tree.dart --out <pasta> [--files N] [--seed N]');
    exit(out == null ? 64 : 0);
  }
  final options = FixtureOptions(files: int.parse(value('--files') ?? '1000'), seed: int.parse(value('--seed') ?? '1'));
  final watch = Stopwatch()..start();
  final m = generateTree(out, options);
  stdout.writeln(
    'Gerados ${m.files} arquivos em ${m.dirs} pastas (${m.bytes} bytes) em ${watch.elapsed.inMilliseconds} ms: ${m.root}',
  );
}
