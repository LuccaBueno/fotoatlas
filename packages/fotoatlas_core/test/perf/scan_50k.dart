@Tags(['slow'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';
import 'lag_reference.dart';

/// Critério da Fase 1: escanear 50 mil arquivos sem travar a interface.
///
/// O scan roda em isolate próprio (como no app). Enquanto isso, um timer de
/// 10 ms no isolate principal (o da UI no app) mede o maior atraso do event
/// loop. Um quadro a 60 Hz dura 16,7 ms; exigimos atraso máximo < 100 ms.
/// Um processo de referência mede ao mesmo tempo as paradas da máquina; só o
/// que não coincide com elas conta como atraso do app ([maxExcessMs]).
void main() {
  test('50 mil arquivos: scan completo e event loop principal responsivo', () async {
    final env = await TestEnv.open(isolate: true);
    final genWatch = Stopwatch()..start();
    // Gera a árvore em outro isolate: o lixo de criar 50 mil arquivos não pode
    // ficar no heap do isolate medido (uma coleta grande no meio do scan
    // aparecia como atraso do event loop — run 40962539372, 205 ms).
    final root = p.join(env.volumeDir.path, 'Fotos');
    final files = await Isolate.run(
      () => generateTree(root, const FixtureOptions(files: 50000, seed: 50, maxFileBytes: 512)).files,
    );
    genWatch.stop();
    final id = await env.addFolder('Fotos');

    // A mesma medição num processo à parte: o quanto a própria máquina parou.
    final reference = await LagReference.start();
    final stalls = <Stall>[];
    var maxLagMs = 0, maxLagAtMs = 0, over50 = 0;
    var ticks = 0;
    final tickWatch = Stopwatch()..start();
    var expected = 10;
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final lag = tickWatch.elapsedMilliseconds - expected;
      if (lag > maxLagMs) {
        maxLagMs = lag;
        maxLagAtMs = tickWatch.elapsedMilliseconds;
      }
      if (lag > 50) over50++;
      if (lag >= 20) stalls.add((endUs: DateTime.now().microsecondsSinceEpoch, lagMs: lag));
      expected = tickWatch.elapsedMilliseconds + 10;
      ticks++;
    });

    final scanWatch = Stopwatch()..start();
    var progressEvents = 0;
    final sub = env.core.scans.progress.listen((_) => progressEvents++);
    final result = await env.scan(id);
    scanWatch.stop();
    timer.cancel();
    await sub.cancel();
    await reference.stop();
    final ourLagMs = maxExcessMs(stalls, reference.stalls);

    final report =
        'FASE1-EVIDENCIA geracao=${genWatch.elapsedMilliseconds}ms '
        'scan=${scanWatch.elapsedMilliseconds}ms arquivos=${result.filesSeen} '
        'pastas=${result.dirsDone} eventos=$progressEvents ticks=$ticks atrasoMaximo=${maxLagMs}ms '
        // Para diagnosticar um atraso alto: quando foi (desde o início do scan) e quantos passaram de 50 ms.
        'atrasoMaximoEm=${maxLagAtMs}ms atrasosAcimaDe50ms=$over50 '
        // Referência (outro processo, mesmo relógio): quanto a máquina parou, e o atraso que é só nosso.
        'referenciaTicks=${reference.ticks} referenciaAtrasoMaximo=${reference.maxLagMs}ms '
        'atrasoDoApp=${ourLagMs}ms';
    stdout.writeln(report);

    expect(result.status, 'completed');
    expect(result.filesSeen, files);
    expect(await env.count('SELECT COUNT(*) FROM file_instances'), files);
    // Limite de 100 ms sobre o atraso do app; o trecho em que o outro
    // processo também parou é da máquina (runs 44774253106 e 46059361792).
    expect(ourLagMs, lessThan(100), reason: report);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
