@Tags(['slow'])
library;

import 'dart:async';
import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

/// Critério da Fase 1: escanear 50 mil arquivos sem travar a interface.
///
/// O scan roda em isolate próprio (como no app). Enquanto isso, um timer de
/// 10 ms no isolate principal (o da UI no app) mede o maior atraso do event
/// loop. Um quadro a 60 Hz dura 16,7 ms; exigimos atraso máximo < 100 ms.
void main() {
  test('50 mil arquivos: scan completo e event loop principal responsivo', () async {
    final env = await TestEnv.open(isolate: true);
    final genWatch = Stopwatch()..start();
    final manifest = generateTree(
      p.join(env.volumeDir.path, 'Fotos'),
      const FixtureOptions(files: 50000, seed: 50, maxFileBytes: 512),
    );
    genWatch.stop();
    final id = await env.addFolder('Fotos');

    var maxLagMs = 0;
    var ticks = 0;
    final tickWatch = Stopwatch()..start();
    var expected = 10;
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final lag = tickWatch.elapsedMilliseconds - expected;
      if (lag > maxLagMs) maxLagMs = lag;
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

    final report =
        'FASE1-EVIDENCIA geracao=${genWatch.elapsedMilliseconds}ms '
        'scan=${scanWatch.elapsedMilliseconds}ms arquivos=${result.filesSeen} '
        'pastas=${result.dirsDone} eventos=$progressEvents ticks=$ticks atrasoMaximo=${maxLagMs}ms';
    stdout.writeln(report);

    expect(result.status, 'completed');
    expect(result.filesSeen, manifest.files);
    expect(await env.count('SELECT COUNT(*) FROM file_instances'), manifest.files);
    expect(maxLagMs, lessThan(100), reason: report);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
