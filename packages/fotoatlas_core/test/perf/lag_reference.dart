import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Parada do event loop: terminou em [endUs] (relógio do sistema, µs) e durou
/// [lagMs] além do previsto.
typedef Stall = ({int endUs, int lagMs});

/// Parte de cada parada do app que **não** coincide com uma parada da
/// referência (outro processo, mesmo relógio). Se a máquina inteira parou,
/// o app não tem culpa daquele trecho; o resto é nosso e conta inteiro.
/// Devolve a maior dessas partes (0 sem paradas).
int maxExcessMs(List<Stall> app, List<Stall> reference) {
  var max = 0;
  for (final a in app) {
    final start = a.endUs - a.lagMs * 1000;
    // União das paradas da referência dentro do intervalo da parada do app.
    final cuts = [
      for (final r in reference)
        (s: (r.endUs - r.lagMs * 1000).clamp(start, a.endUs), e: r.endUs.clamp(start, a.endUs)),
    ]..sort((x, y) => x.s.compareTo(y.s));
    var covered = 0, until = start;
    for (final c in cuts) {
      if (c.e <= until) continue;
      covered += c.e - (c.s > until ? c.s : until);
      until = c.e;
    }
    final excess = a.lagMs - covered ~/ 1000;
    if (excess > max) max = excess;
  }
  return max;
}

/// Processo de referência: um `dart` separado (sem heap, catálogo nem disco
/// em comum com o teste) com o mesmo relógio de 10 ms, que relata as paradas
/// de pelo menos [thresholdMs]. Mede o quanto a própria máquina parou.
///
/// Se a referência morrer ou não relatar nada, não há o que descontar: o
/// teste mede o atraso inteiro, como antes.
class LagReference {
  LagReference._(this._process);

  final Process _process;
  final _done = Completer<void>();
  final stalls = <Stall>[];
  var ticks = 0;

  static Future<LagReference> start({int thresholdMs = 20}) async {
    final script = p.join('test', 'perf', 'lag_probe.dart');
    final process = await Process.start(Platform.resolvedExecutable, [script, '$thresholdMs']);
    final ref = LagReference._(process);
    final ready = Completer<void>();
    process.stderr.drain<void>().ignore();
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line == 'pronto' && !ready.isCompleted) ready.complete();
      ref._onLine(line);
    }, onDone: ref._done.complete);
    await ready.future.timeout(const Duration(seconds: 60));
    return ref;
  }

  void _onLine(String line) {
    final parts = line.split(' ');
    if (parts.first == 'parada' && parts.length == 3) {
      stalls.add((endUs: int.parse(parts[1]), lagMs: int.parse(parts[2])));
    } else if (parts.first == 'fim' && parts.length == 2) {
      ticks = int.parse(parts[1]);
    }
  }

  /// Para a referência e espera as últimas linhas.
  Future<void> stop() async {
    await _process.stdin.close();
    await _process.exitCode.timeout(const Duration(seconds: 30));
    await _done.future.timeout(const Duration(seconds: 30));
  }

  int get maxLagMs => stalls.fold(0, (m, s) => s.lagMs > m ? s.lagMs : m);
}
