import 'dart:async';
import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helper/helper_client_test.dart' show fakeClient;
import 'support/fakes.dart';
import 'support/temp.dart';

/// Falhas do helper **real** (`HelperClient` + helper falso que fala o
/// protocolo dos celulares) nunca podem virar "Unhandled Exception".
void main() {
  late Directory temp;
  late FakeVolumeProvider volumes;
  late CorePaths paths;

  setUp(() async {
    temp = await createTestTemp();
    final volumeDir = Directory(p.join(temp.path, 'vol'))..createSync();
    volumes = FakeVolumeProvider()..volumes = [fakeVolume(volumeDir.path)];
    paths = CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local'));
  });

  Future<FotoAtlasCore> open(HelperClient? helper, {bool asApp = false}) => FotoAtlasCore.open(
    paths: paths,
    volumes: volumes,
    pathResolver: FakePathResolver(volumes),
    helperClient: helper,
    useHelper: helper != null,
    // Como o app: verifica dispositivos a cada 3 s e confere sozinho.
    monitor: asApp,
    autoHash: asApp,
  );

  /// Roda [body] e devolve as exceções que escaparam (não tratadas).
  Future<List<String>> uncaughtIn(Future<void> Function() body) async {
    final uncaught = <String>[];
    await runZonedGuarded(body, (error, stack) => uncaught.add('$error\n$stack'));
    return uncaught;
  }

  Future<void> until(bool Function() condition, {Duration limit = const Duration(seconds: 20)}) async {
    final watch = Stopwatch()..start();
    while (!condition()) {
      if (watch.elapsed > limit) fail('condição não atingida em $limit');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<String> pendingOrDone(FotoAtlasCore core) async =>
      (await core.catalog.db.customSelect('SELECT hash_status FROM file_instances').getSingle()).read<String>(
        'hash_status',
      );

  test('fechar com a conferência do celular presa no helper: sem exceção solta, pendente continua', () async {
    final uncaught = await uncaughtIn(() async {
      final core = await open(fakeClient('phone-stuck'));
      await core.sources.refreshConnectivity();
      final id = (await core.sources.addPhone('wpd:travado')).sourceId;
      await core.scans.wait(await core.scans.start(id));
      unawaited(core.hashes.start());
      await until(() => core.hashes.isRunning);
      await Future<void>.delayed(const Duration(milliseconds: 300)); // a leitura já foi pedida ao helper

      final watch = Stopwatch()..start();
      // Como o helper real: ao fechar o stdin, a leitura presa falha com
      // not_found, a conferência tenta achar o arquivo de novo (pedido novo
      // com o stdin já fechado) e o processo não sai até ser finalizado.
      await core.close(stepTimeout: const Duration(milliseconds: 500));
      expect(watch.elapsed, lessThan(const Duration(seconds: 6)));
      await Future<void>.delayed(const Duration(seconds: 1)); // erros atrasados aparecem aqui
    });
    expect(uncaught, isEmpty, reason: 'nenhuma exceção não tratada ao fechar');

    // Reabrir: a foto continua para conferir (nada perdido, nada como erro).
    final core = await open(null);
    addTearDown(core.close);
    expect(await pendingOrDone(core), 'pending');
  });

  test('helper cai no meio da conferência: tratado, reinicia, avisa e a conferência termina depois', () async {
    final marker = p.join(temp.path, 'caiu.txt');
    final statuses = <HelperStatus>[];
    late FotoAtlasCore core;
    final uncaught = await uncaughtIn(() async {
      core = await open(fakeClient('phone-crash', marker: marker, extra: ['--crash-on', 'hash']), asApp: true);
      core.helperStatus.listen(statuses.add);
      final messages = <String>[];
      core.hashes.status.listen((s) => s.message == null ? null : messages.add(s.message!));
      await core.sources.refreshConnectivity();
      final id = (await core.sources.addPhone('wpd:travado')).sourceId;
      await core.scans.wait(await core.scans.start(id)); // a conferência começa sozinha depois do scan
      await until(() => File(marker).existsSync()); // o helper caiu na leitura

      // Sem ninguém mexer: o helper volta, o celular reaparece e a
      // conferência continua sozinha até o fim.
      final watch = Stopwatch()..start();
      while (await pendingOrDone(core) != 'done') {
        if (watch.elapsed > const Duration(seconds: 30)) fail('a conferência não continuou sozinha');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(core.helper!.restarts, 1);
      expect(messages, isNotEmpty, reason: 'a interface recebe o motivo da parada');
      final row = await core.catalog.db.customSelect('SELECT hash_error FROM file_instances').getSingle();
      expect(row.readNullable<String>('hash_error'), isNull, reason: 'queda do helper não é erro do arquivo');

      await core.close();
    });
    expect(uncaught, isEmpty);
    expect(statuses, contains(HelperStatus.restarting), reason: 'a interface é avisada');
  });

  test('helper cai no meio do scan do celular: scan interrompido, retoma depois sem perder nada', () async {
    final marker = p.join(temp.path, 'caiu.txt');
    final uncaught = await uncaughtIn(() async {
      final core = await open(fakeClient('phone-crash', marker: marker, extra: ['--crash-on', 'list']));
      await core.sources.refreshConnectivity();
      final id = (await core.sources.addPhone('wpd:travado')).sourceId;
      final scanId = await core.scans.start(id);
      final first = await core.scans.wait(scanId);
      expect(first.status, 'interrupted');
      expect(first.message, isNotNull, reason: 'a interface recebe o motivo');
      expect(
        await core.catalog.db
            .customSelect("SELECT COUNT(*) AS n FROM file_instances WHERE availability = 'missing'")
            .getSingle()
            .then((r) => r.read<int>('n')),
        0,
      );

      await until(() => core.helper!.status == HelperStatus.ready && core.helper!.restarts == 1);
      await core.sources.refreshConnectivity();
      final resumed = await core.scans.wait(await core.scans.resume(scanId));
      expect(resumed.status, 'completed');
      expect(resumed.filesSeen, 1);
      await core.close();
    });
    expect(uncaught, isEmpty);
  });
}
