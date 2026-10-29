import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_core/src/scan/scan_engine.dart' show isUnderScanRoots, normalizeScanRoots, scanRoots;
import 'package:test/test.dart';

import '../devices/phone_test.dart' show phoneEnv;
import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 31 + seed * 7) & 0xff);

void main() {
  test('normaliza as pastas pedidas: separador, repetidas e pasta dentro de outra', () {
    expect(normalizeScanRoots(null), ['']);
    expect(normalizeScanRoots(const []), ['']);
    expect(normalizeScanRoots(['DCIM', '']), ['']);
    expect(normalizeScanRoots([r'DCIM\Camera\', 'WhatsApp', 'dcim/camera/sub', 'WhatsApp']), [
      'DCIM/Camera',
      'WhatsApp',
    ]);
    expect(normalizeScanRoots(['DCIM/Camera', 'DCIM']), ['DCIM']);
    expect(normalizeScanRoots(['DCIM 2', 'DCIM']), ['DCIM', 'DCIM 2'], reason: '"DCIM 2" não fica dentro de "DCIM"');
    expect(isUnderScanRoots('DCIM/Camera/x', ['DCIM']), isTrue);
    expect(isUnderScanRoots('DCIM2', ['DCIM']), isFalse);
  });

  test('várias pastas num scan só: lê só elas, parcial, ausência só dentro delas', () async {
    final env = await TestEnv.open();
    env.write('Cel/DCIM/Camera/a.jpg', bytes(1, 100));
    env.write('Cel/DCIM/Camera/sub/b.jpg', bytes(2, 101));
    env.write('Cel/WhatsApp/Media/c.jpg', bytes(3, 102));
    env.write('Cel/Download/d.pdf', bytes(4, 103));
    final cel = await env.addFolder('Cel');

    final id = await env.core.scans.start(cel, folders: ['DCIM/Camera', 'WhatsApp']);
    final p = await env.core.scans.wait(id);
    expect(p.status, 'completed');
    expect(p.filesSeen, 3, reason: 'Download fica de fora');
    expect(await scanRoots(env.db, id), ['DCIM/Camera', 'WhatsApp']);
    final scan = await (env.db.select(env.db.scans)..where((s) => s.id.equals(id))).getSingle();
    expect(scan.coverage, 'partial');
    expect(scan.errorCount, 0);

    var view = (await env.core.sources.list()).single;
    expect(view.partlyScanned, isTrue);
    expect(view.scannedFolders.map((f) => f.relPath), ['DCIM/Camera', 'WhatsApp']);
    expect(view.scannedAt('DCIM/Camera/sub'), isNotNull);
    expect(view.scannedAt('Download'), isNull);
    expect(view.scannedAt('DCIM'), isNull, reason: 'só a Camera foi lida, não o resto de DCIM');

    final stats = await env.core.sources.folderStats(cel, ['DCIM', 'DCIM/Camera', 'WhatsApp', 'Download', '']);
    expect(stats['DCIM/Camera']!.files, 2);
    expect(stats['DCIM/Camera']!.bytes, 201);
    expect(stats['DCIM']!.files, 2);
    expect(stats['WhatsApp']!.files, 1);
    expect(stats['Download']!.files, 0, reason: 'nunca escaneada: tamanho desconhecido');
    expect(stats['']!.files, 3);

    // Apagado fora das pastas escolhidas não vira ausente; dentro, sim.
    await env.scan(cel);
    File('${env.volumeDir.path}/Cel/Download/d.pdf').deleteSync();
    File('${env.volumeDir.path}/Cel/WhatsApp/Media/c.jpg').deleteSync();
    await env.core.scans.wait(await env.core.scans.start(cel, folders: ['DCIM/Camera']));
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
    await env.core.scans.wait(await env.core.scans.start(cel, folders: ['WhatsApp']));
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 1);

    // Depois de um scan da fonte inteira, as pastas sozinhas mais novas aparecem à parte.
    view = (await env.core.sources.list()).single;
    expect(view.wholeScannedAt, isNotNull);
    expect(view.partlyScanned, isFalse);
    expect(view.scannedFolders.map((f) => f.relPath), ['WhatsApp', 'DCIM/Camera']);
    expect(view.scannedAt('Download'), view.wholeScannedAt);
  });

  test('retomar com outras pastas é recusado; com as mesmas, retoma', () async {
    final env = await TestEnv.open();
    env.write('Cel/DCIM/a.jpg', bytes(1, 100));
    env.write('Cel/WhatsApp/b.jpg', bytes(2, 100));
    final cel = await env.addFolder('Cel');
    final id = await env.core.scans.start(cel, folders: ['WhatsApp', 'DCIM']);
    await env.core.scans.wait(id);
    await env.db.customStatement("UPDATE scans SET status = 'paused' WHERE id = $id");
    expect(
      () => env.core.scans.start(cel, folders: ['DCIM']),
      throwsA(isA<SourceException>().having((e) => e.message, 'message', contains('de "DCIM", "WhatsApp"'))),
    );
    expect(await env.core.scans.start(cel, folders: ['dcim', 'WhatsApp']), id);
    await env.core.scans.wait(id);
  });

  test('listar pastas de uma unidade agora: só lê, sem pastas ignoradas', () async {
    final env = await TestEnv.open();
    env.write('Fotos/2020/a.jpg', bytes(1, 10));
    env.write(r'Fotos/$RECYCLE.BIN/x', bytes(2, 10));
    env.write('Fotos/WhatsApp/b.jpg', bytes(3, 10));
    final id = await env.addFolder('Fotos');
    expect(await env.core.scans.listFolders(id), ['2020', 'WhatsApp']);
    expect(await env.core.scans.listFolders(id, '2020'), isEmpty);
    expect(await env.count('SELECT COUNT(*) FROM file_instances'), 0, reason: 'listar não cataloga');
    expect(await env.count('SELECT COUNT(*) FROM scans'), 0);
  });

  test('listar pastas do celular: armazenamentos e pastas, depois escanear duas delas', () async {
    final (env, _, id) = await phoneEnv();
    expect(await env.core.scans.listFolders(id), ['Cartão SD', 'Interno']);
    expect(await env.core.scans.listFolders(id, 'Interno'), [
      'Interno/Android',
      'Interno/DCIM',
      'Interno/Download',
      'Interno/WhatsApp',
    ]);
    final scanId = await env.core.scans.start(id, folders: ['Interno/DCIM/Camera', 'Interno/WhatsApp']);
    final p = await env.core.scans.wait(scanId);
    expect(p.filesSeen, 3);
    expect((await env.core.sources.list()).single.scannedFolders.map((f) => f.relPath), [
      'Interno/DCIM/Camera',
      'Interno/WhatsApp',
    ]);
  });
}
