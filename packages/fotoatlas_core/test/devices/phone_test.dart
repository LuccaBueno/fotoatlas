import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/fake_devices.dart';
import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 31 + seed * 7) & 0xff);

/// Celular com fotos, parte já copiada para o HD (com outros nomes).
///
/// | conteúdo | celular                                  | HD (Backup/Celular)     |
/// |----------|------------------------------------------|-------------------------|
/// | P1       | Interno/DCIM/Camera/IMG_0001.jpg         | 2024/foto1.jpg          |
/// | P2       | Interno/DCIM/Camera/IMG_0002.jpg         | —                       |
/// | P3       | Interno/WhatsApp/Media/IMG-WA0001.jpg    | 2024/zap.jpg            |
/// | P4       | Cartão SD/DCIM/VID_0001.mp4              | —                       |
/// | (excl.)  | Interno/Android/data/app/cache.bin       | —                       |
FakePhone pixel() => FakePhone()
  ..put('Interno/DCIM/Camera/IMG_0001.jpg', bytes(1, 1000))
  ..put('Interno/DCIM/Camera/IMG_0002.jpg', bytes(2, 2000))
  ..put('Interno/WhatsApp/Media/IMG-WA0001.jpg', bytes(3, 300))
  ..put('Interno/Android/data/app/cache.bin', bytes(9, 50))
  ..put('Cartão SD/DCIM/VID_0001.mp4', bytes(4, 4000))
  ..folders.add('Interno/Download');

Future<(TestEnv, FakeDeviceBackend, String)> phoneEnv({FakePhone? phone}) async {
  final devices = FakeDeviceBackend()..phones.add(phone ?? pixel());
  final env = await TestEnv.open(devices: devices);
  await env.core.sources.refreshConnectivity();
  final id = (await env.core.sources.addPhone(devices.phones.single.deviceId)).sourceId;
  return (env, devices, id);
}

void main() {
  test('cadastrar celular: conectado, sem duplicar, celular como disco próprio', () async {
    final (env, devices, id) = await phoneEnv();
    final view = (await env.core.sources.list()).single;
    expect(view.kind, 'phone');
    expect(view.isConnected, isTrue);
    expect(view.isReady, isTrue);
    expect(view.devicePlatform, 'android');
    expect(view.name, 'Pixel de Teste');
    await expectLater(
      env.core.sources.addPhone(devices.phones.single.deviceId),
      throwsA(isA<SourceException>().having((e) => e.message, 'msg', contains('já está cadastrado'))),
    );
    final disk = await env.count(
      "SELECT COUNT(*) FROM physical_disks d JOIN sources s ON s.physical_disk_id = d.id "
      "WHERE s.id = ? AND d.identity_confidence = 'reliable' AND d.bus_type = 'mtp'",
      [id],
    );
    expect(disk, 1);

    // Mesmo serial em outra porta USB (ID WPD novo): reconhecido e aprendido.
    devices.phones.single.deviceId = r'\\?\usb#vid_18d1&pid_4ee1#fake0001#porta2';
    await env.core.sources.refreshConnectivity();
    expect(env.core.sources.stateOf(id), SourceState.connected);
    expect((await env.core.sources.byId(id))!.deviceId, endsWith('porta2'));

    devices.phones.clear();
    await env.core.sources.refreshConnectivity();
    expect(env.core.sources.stateOf(id), SourceState.disconnected);
  });

  test('escanear: caminhos com o armazenamento, exclusões, sem tocar no celular', () async {
    final (env, _, id) = await phoneEnv();
    final p = await env.scan(id);
    expect(p.status, 'completed');
    expect(p.filesSeen, 4);
    final rows = await env.db
        .customSelect('SELECT rel_path, device_object_id FROM file_instances ORDER BY rel_path')
        .get();
    expect(rows.map((r) => r.read<String>('rel_path')), [
      'Cartão SD/DCIM/VID_0001.mp4',
      'Interno/DCIM/Camera/IMG_0001.jpg',
      'Interno/DCIM/Camera/IMG_0002.jpg',
      'Interno/WhatsApp/Media/IMG-WA0001.jpg',
    ]);
    expect(rows.every((r) => r.readNullable<String>('device_object_id') != null), isTrue);
    expect(
      await env.count("SELECT COUNT(*) FROM scan_dirs WHERE status = 'excluded' AND rel_path = 'Interno/Android/data'"),
      1,
    );
    expect((await env.db.customSelect("SELECT coverage FROM scans").getSingle()).read<String>('coverage'), 'complete');
  });

  test('celular bloqueado: não escaneia e explica o que fazer', () async {
    final (env, devices, id) = await phoneEnv(phone: pixel()..status = 'locked');
    expect((await env.core.sources.list()).single.isReady, isFalse);
    await expectLater(
      env.core.scans.start(id),
      throwsA(isA<SourceException>().having((e) => e.message, 'msg', contains('Transferência de arquivos'))),
    );
    devices.phones.single.status = 'ok';
    await env.core.sources.refreshConnectivity();
    expect((await env.scan(id)).status, 'completed');
  });

  test('desconexão no meio do scan: interrompido, catálogo íntegro, nada ausente, retoma exato', () async {
    final (env, devices, id) = await phoneEnv();
    // Primeiro scan completo; depois uma foto nova e outro scan que cai no meio.
    expect((await env.scan(id)).filesSeen, 4);
    final phone = devices.phones.single..put('Interno/DCIM/Camera/IMG_0003.jpg', bytes(5, 500));
    devices
      ..listCalls = 0
      ..goneAfterListCalls = 4;
    final cut = await env.scan(id);
    expect(cut.status, 'interrupted');
    expect(cut.message, contains('desconectado'));
    expect((await env.db.customSelect('PRAGMA integrity_check').getSingle()).data.values.single, 'ok');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);

    // Reconecta: IDs de objeto novos (outra sessão), e o scan continua das pastas pendentes.
    devices
      ..goneAfterListCalls = null
      ..phones.add(phone..session = 1);
    await env.core.sources.refreshConnectivity();
    final resumed = await env.scan(id);
    expect(resumed.status, 'completed');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'present'"), 5);
    expect(await env.count('SELECT COUNT(*) FROM file_instances'), 5);
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
  });

  test('foto apagada no celular só vira ausente num scan completo', () async {
    final (env, devices, id) = await phoneEnv();
    await env.scan(id);
    final phone = devices.phones.single..files.remove('Interno/DCIM/Camera/IMG_0002.jpg');
    phone.modified.remove('Interno/DCIM/Camera/IMG_0002.jpg');
    devices
      ..listCalls = 0
      ..goneAfterListCalls = 2;
    expect((await env.scan(id)).status, 'interrupted');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
    devices
      ..goneAfterListCalls = null
      ..phones.add(phone);
    await env.core.sources.refreshConnectivity();
    expect((await env.scan(id)).status, 'completed');
    expect(
      await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing' AND name = 'IMG_0002.jpg'"),
      1,
    );
  });

  test('conferência pelo celular: hash, ID velho re-resolvido, mudança e desconexão', () async {
    final (env, devices, id) = await phoneEnv();
    await env.scan(id);
    final phone = devices.phones.single;
    phone.session = 7; // IDs do scan não valem mais
    devices.changedDuringRead.add('Cartão SD/DCIM/VID_0001.mp4');
    await env.hashAll();
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"), 3);
    final changed = await env.db
        .customSelect("SELECT name, hash_error FROM file_instances WHERE hash_status = 'changed_during_read'")
        .getSingle();
    expect(changed.read<String>('name'), 'VID_0001.mp4');

    // Desplugado no meio: o resto continua pendente, nunca "ausente" nem "erro".
    await env.core.hashes.retryFailed();
    devices.changedDuringRead.clear();
    devices.beforeHash = (_) => devices.phones.clear();
    await env.hashAll();
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'pending'"), 1);
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'error'"), 0);
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
  });

  test('comparar celular × HD: o que falta no HD, por conteúdo', () async {
    final (env, _, phoneId) = await phoneEnv();
    env
      ..write('Backup/Celular/2024/foto1.jpg', bytes(1, 1000))
      ..write('Backup/Celular/2024/zap.jpg', bytes(3, 300))
      ..write('Backup/Celular/2023/antiga.jpg', bytes(8, 800));
    final hd = await env.addFolder('Backup', name: 'HD');
    await env.scan(phoneId);
    await env.scan(hd);
    await env.hashAll();

    final a = Scope([ScopeEntry(phoneId, '')]);
    final b = Scope([ScopeEntry(hd, '')]);
    final r = await env.core.compare.compare(a, b);
    expect(r.verdict, CompareVerdict.missing);
    expect(r.missing.contents, 2);
    expect(r.missing.bytes, 6000);
    expect(r.inBoth.contents, 2);
    expect(r.onlyInB.contents, 1);
    final missing = await env.core.compare.items(a, b, CompareList.missing);
    expect(missing.map((i) => i.relPath).toSet(), {'Interno/DCIM/Camera/IMG_0002.jpg', 'Cartão SD/DCIM/VID_0001.mp4'});

    // Só a câmera do celular × HD.
    final camera = await env.core.compare.compare(Scope([ScopeEntry(phoneId, 'Interno/DCIM')]), b);
    expect(camera.missing.contents, 1);

    // Celular e HD em discos diferentes e confiáveis: backup independente.
    final report = await env.core.coverage.report();
    expect(report.overall.files[BackupState.independent], 2); // P1 e P3
    expect(report.overall.files[BackupState.single], 3); // P2, P4 e a antiga do HD
  });
}
