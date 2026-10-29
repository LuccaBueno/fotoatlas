import 'dart:async';
import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import 'devices/phone_test.dart' show phoneEnv, pixel;
import 'helper/helper_client_test.dart' show fakeClient, waitForStatus;
import 'support/fake_devices.dart';
import 'support/test_core.dart';

/// Fechar o app tem que terminar sempre e rápido (bug: o X ficava vermelho e
/// a janela não fechava).
void main() {
  Future<Duration> timedClose(FotoAtlasCore core, {List<List<ShutdownStep>>? reports}) async {
    final watch = Stopwatch()..start();
    await core.close(
      stepTimeout: const Duration(milliseconds: 500),
      onProgress: (steps) => reports?.add([for (final s in steps) ShutdownStep(s.id, s.label)..done = s.done]),
    );
    return watch.elapsed;
  }

  test('fecha mesmo com ouvintes pausados (tela fora de vista no app)', () async {
    final env = await TestEnv.open();
    // O Riverpod pausa os streams de telas que não estão visíveis; close()
    // de um StreamController com ouvinte pausado nunca terminava.
    final subs = [
      env.core.scans.progress.listen((_) {})..pause(),
      env.core.hashes.status.listen((_) {})..pause(),
      env.core.sources.watch().listen((_) {})..pause(),
      // Consulta reativa do próprio banco (como as telas do app usam).
      env.db.select(env.db.sources).watch().listen((_) {})..pause(),
    ];
    addTearDown(() => Future.wait(subs.map((s) => s.cancel())));
    // Prazo padrão (3 s por etapa): terminar bem antes prova que nenhuma
    // etapa ficou esperando o prazo estourar.
    final watch = Stopwatch()..start();
    await env.core.close();
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
  });

  test('fecha com o celular travado no meio do scan: pausa/interrompe e retoma exato depois', () async {
    final devices = FakeDeviceBackend()
      ..phones.add(pixel())
      ..stallAfterListCalls = 3;
    final env = await TestEnv.open(devices: devices);
    await env.core.sources.refreshConnectivity();
    final id = (await env.core.sources.addPhone(devices.phones.single.deviceId)).sourceId;
    final scanId = await env.core.scans.start(id);
    while (devices.listCalls <= 3) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final reports = <List<ShutdownStep>>[];
    expect(await timedClose(env.core, reports: reports), lessThan(const Duration(seconds: 3)));
    expect(reports.first.map((s) => s.id), contains('scan'));
    expect(reports.last.every((s) => s.done), isTrue);

    devices.stallAfterListCalls = null;
    await env.reopen(devices: devices);
    final scan = await (env.db.select(env.db.scans)..where((s) => s.id.equals(scanId))).getSingle();
    expect(scan.status, anyOf('interrupted', 'paused'));
    await env.core.sources.refreshConnectivity();
    final p = await env.core.scans.wait(await env.core.scans.resume(scanId));
    expect(p.status, 'completed');
    expect(await env.count('SELECT COUNT(*) FROM file_instances'), 4, reason: 'nada duplicado nem perdido');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
  });

  test('fecha com a conferência travada numa leitura do celular: o que falta continua pendente', () async {
    final (env, devices, id) = await phoneEnv();
    await env.scan(id);
    devices.stallHash = true;
    unawaited(env.core.hashes.start());
    while (!env.core.hashes.isRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final reports = <List<ShutdownStep>>[];
    expect(await timedClose(env.core, reports: reports), lessThan(const Duration(seconds: 3)));
    expect(reports.first.map((s) => s.id), contains('hash'));

    devices.stallHash = false;
    await env.reopen(devices: devices);
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'pending'"), 4);
    await env.core.sources.refreshConnectivity();
    await env.hashAll();
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"), 4);
  });

  test('scan e conferência em isolates no meio: fecha em poucos segundos', () async {
    final env = await TestEnv.open(isolate: true);
    for (var i = 0; i < 400; i++) {
      env.write('Fotos/${i ~/ 20}/IMG_$i.jpg', List.filled(64 * 1024, i & 0xff));
    }
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    env.write('Fotos/novo/a.jpg', [1]);
    unawaited(env.core.hashes.start());
    await env.core.scans.start(id);
    expect(await timedClose(env.core), lessThan(const Duration(seconds: 3)));
    await env.reopen();
    final pending = await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'pending'");
    final done = await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'");
    expect(pending + done, await env.count('SELECT COUNT(*) FROM file_instances'), reason: 'nenhum em estado inválido');
  });

  test('helper travado que não sai: é finalizado e close() termina', () async {
    final client = fakeClient('stuck');
    await client.start();
    await waitForStatus(client, HelperStatus.ready);
    final watch = Stopwatch()..start();
    await client.close(grace: const Duration(milliseconds: 500));
    expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    expect(client.status, HelperStatus.stopped);
    if (Platform.isWindows) {
      // O processo do helper falso foi finalizado (não fica órfão).
      expect(client.pid, isNotNull);
      final r = await Process.run('tasklist', ['/FI', 'PID eq ${client.pid}', '/NH']);
      expect('${r.stdout}', isNot(contains('${client.pid}')));
    }
  });

  test('conferência do celular interrompida ao fechar retoma exatamente de onde parou', () async {
    final phone = pixel();
    // Mais arquivos que o necessário para caber num lote só.
    for (var i = 0; i < 6; i++) {
      phone.put('Interno/DCIM/Camera/EXTRA_$i.jpg', List.generate(500 + i, (b) => (b * 7 + i) & 0xff));
    }
    final devices = FakeDeviceBackend()..phones.add(phone);
    final env = await TestEnv.open(devices: devices);
    await env.core.sources.refreshConnectivity();
    final id = (await env.core.sources.addPhone(devices.phones.single.deviceId)).sourceId;
    await env.scan(id);
    final total = await env.count('SELECT COUNT(*) FROM file_instances');
    expect(total, 10);

    devices.stallAfterHashCalls = 3; // lê 3 arquivos e trava no 4º
    unawaited(env.core.hashes.start());
    while (devices.hashCalls < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await timedClose(env.core);

    devices.stallAfterHashCalls = null;
    await env.reopen(devices: devices);
    expect(
      await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"),
      3,
      reason: 'os 3 lidos antes de fechar ficam gravados',
    );
    await env.core.sources.refreshConnectivity();
    final before = devices.hashCalls;
    await env.hashAll();
    expect(devices.hashCalls - before, total - 3, reason: 'só lê pelo USB o que faltava');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"), total);
  });

  test('tarefas em andamento (para perguntar antes de fechar): nenhuma, scan e conferência', () async {
    final devices = FakeDeviceBackend()
      ..phones.add(pixel())
      ..stallAfterListCalls = 2;
    final env = await TestEnv.open(devices: devices);
    expect(await env.core.runningTasks(), isEmpty, reason: 'nada rodando: fecha sem perguntar');
    await env.core.sources.refreshConnectivity();
    final id = (await env.core.sources.addPhone(devices.phones.single.deviceId)).sourceId;
    await env.core.scans.start(id);
    while (env.core.scans.runningProgress.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final tasks = await env.core.runningTasks();
    expect(tasks.single.kind, RunningTaskKind.scan);
    expect(tasks.single.sourceName, 'Pixel de Teste');
    await timedClose(env.core);

    devices
      ..stallAfterListCalls = null
      ..stallHash = true;
    await env.reopen(devices: devices);
    await env.core.sources.refreshConnectivity();
    await env.core.scans.wait(await env.core.scans.start(id));
    unawaited(env.core.hashes.start());
    while (!env.core.hashes.isRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final hash = (await env.core.runningTasks()).single;
    expect(hash.kind, RunningTaskKind.hash);
    expect(hash.total, 4);
  });
}
