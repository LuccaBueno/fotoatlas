import 'dart:async';
import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';

final String fakeScript = p.join('test', 'support', 'fake_helper.dart');

HelperClient fakeClient(String mode, {String? marker, Duration ping = const Duration(seconds: 5)}) {
  final client = HelperClient(
    executable: Platform.resolvedExecutable,
    arguments: [
      fakeScript,
      '--mode',
      mode,
      if (marker != null) ...['--marker', marker],
    ],
    pingInterval: ping,
    pingTimeout: ping,
    maxBackoff: const Duration(seconds: 1),
  );
  addTearDown(client.close);
  return client;
}

Future<void> waitForStatus(HelperClient client, HelperStatus status) async {
  if (client.status == status) return;
  await client.statusChanges.firstWhere((s) => s == status).timeout(const Duration(seconds: 30));
}

void main() {
  test('inicia, responde e converte volumes.list', () async {
    final client = fakeClient('normal');
    await client.start();
    expect(client.status, HelperStatus.ready);
    expect(await client.call('system.ping'), containsPair('uptimeMs', 1));

    final volumes = await HelperVolumeProvider(client).list();
    expect(volumes.single.displayMount, r'E:\');
    expect(volumes.single.primaryDisk!.identityConfidence, 'weak');
  });

  test('erro do helper vira HelperException com código', () async {
    final client = fakeClient('normal');
    await client.start();
    await expectLater(
      client.call('nao.existe'),
      throwsA(isA<HelperException>().having((e) => e.code, 'code', 'bad_request')),
    );
  });

  test('queda: pedido em voo falha como helper_crashed e o helper reinicia', () async {
    final temp = await createTestTemp();
    final client = fakeClient('crash-once', marker: p.join(temp.path, 'marcador'));
    await client.start();
    await expectLater(
      client.call('volumes.list'),
      throwsA(isA<HelperException>().having((e) => e.code, 'code', 'helper_crashed')),
    );
    await waitForStatus(client, HelperStatus.ready);
    expect(client.restarts, 1);
    expect((await client.call('volumes.list'))['volumes'], hasLength(1));
  });

  test('helper mudo é morto pelo ping e reiniciado', () async {
    final client = fakeClient('mute', ping: const Duration(milliseconds: 300));
    await client.start();
    await waitForStatus(client, HelperStatus.restarting);
    await waitForStatus(client, HelperStatus.ready);
    expect(client.restarts, greaterThanOrEqualTo(1));
  });

  test('protocolo incompatível é recusado', () async {
    final client = fakeClient('bad-protocol');
    await expectLater(
      client.start(),
      throwsA(isA<HelperException>().having((e) => e.code, 'code', 'protocol_mismatch')),
    );
  });

  test('sem helper, o provedor usa a listagem Win32 de reserva', () async {
    final client = HelperClient(executable: 'nao_existe.exe');
    final volumes = await HelperVolumeProvider(client, fallback: Win32VolumeProvider()).list();
    expect(volumes.where((v) => v.isBoot), hasLength(1));
  });

  final realHelper = HelperClient.locate();
  test('helper real: volumes.list inclui o volume do sistema com disco físico', () async {
    final client = HelperClient(executable: realHelper!);
    addTearDown(client.close);
    await client.start();
    final volumes = await HelperVolumeProvider(client).list();
    final boot = volumes.singleWhere((v) => v.isBoot);
    expect(boot.guidPath, startsWith(r'\\?\Volume{'));
    expect(boot.physicalDisks, isNotEmpty);
  }, skip: realHelper == null ? 'helper não compilado (dotnet build em native/fotoatlas_helper)' : false);
}
