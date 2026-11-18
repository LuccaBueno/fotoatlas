import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/main.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;

import 'support/temp.dart';

class _Volume implements VolumeProvider, PathResolver {
  _Volume(this.root);
  final String root;

  @override
  Future<List<VolumeInfo>> list() async => [
    VolumeInfo(
      guidPath: '$root\\',
      mountPoints: const [r'E:\'],
      label: 'Teste',
      fileSystem: 'NTFS',
      serial: 9,
      totalBytes: 1 << 30,
      freeBytes: 1 << 29,
      driveType: 'fixed',
    ),
  ];

  @override
  ({String mountRoot, String volumeGuid}) resolve(String path) => (mountRoot: '$root\\', volumeGuid: '$root\\');
}

Future<void> _until(WidgetTester tester, bool Function() done, {int max = 100}) async {
  for (var i = 0; i < max && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

void main() {
  testWidgets('Extrair zip do Google Takeout: prévia, extração e zips intactos', (tester) async {
    final temp = (await tester.runAsync(() => Directory.systemTemp.createTemp('fotoatlas_app_test_')))!;
    FotoAtlasCore? opened;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() async {
        await opened?.close();
        await deleteTestDir(temp);
      });
    });
    late FotoAtlasCore core;
    late String zips, dest;
    final vol = p.join(temp.path, 'vol');
    await tester.runAsync(() async {
      generateTakeoutDemo(p.join(vol, 'Google Takeout'));
      Directory(p.join(vol, 'Destino')).createSync();
      final fake = _Volume(vol);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
        tools: ExternalTools.none,
      );
      zips = (await core.sources.addPath(p.join(vol, 'Google Takeout', 'Zips'), name: 'Zips')).sourceId;
      dest = (await core.sources.addPath(p.join(vol, 'Destino'), name: 'Destino')).sourceId;
      for (final s in [zips, dest]) {
        await core.scans.wait(await core.scans.start(s));
      }
      await core.sources.refreshConnectivity();
    });
    final zipFiles = Directory(p.join(vol, 'Google Takeout', 'Zips')).listSync().whereType<File>().toList();
    final before = [for (final f in zipFiles) '${f.lengthSync()} ${f.lastModifiedSync()}'];
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
    await _until(tester, () => find.text('Dispositivos').evaluate().isNotEmpty);
    await tester.tap(find.text('Dispositivos').first);
    await _tap(tester, find.byKey(ValueKey('more-$zips')));
    await _tap(tester, find.text('Extrair zip do Google Takeout… (só lê o zip)'));
    await _until(tester, () => find.text('takeout-20240101T000000Z-002.zip').evaluate().isNotEmpty);
    expect(find.text('takeout-20240101T000000Z-001.zip'), findsOneWidget);

    // Destino: "Destino".
    await _tap(tester, find.byKey(const ValueKey('takeout-dest')));
    await _tap(tester, find.text('Destino').last);
    await _tap(tester, find.byKey(const ValueKey('takeout-preview')));
    final summary = find.byKey(const ValueKey('takeout-summary'));
    await _until(tester, () => summary.evaluate().isNotEmpty);
    expect(tester.widget<Text>(summary).data, contains('Vai extrair 4 arquivos'));
    expect(tester.widget<Text>(summary).data, contains('2 fotos e vídeos, 2 .json com datas e locais'));

    await _tap(tester, find.byKey(const ValueKey('takeout-start')));
    await _until(tester, () => find.byKey(const ValueKey('takeout-started')).evaluate().isNotEmpty);
    final out = Directory(p.join(vol, 'Destino', 'Google Fotos (Takeout)', 'Google Fotos', 'Aniversário'));
    // A extração anda com o relógio do teste: espera os 4 arquivos aparecerem.
    await _until(tester, () => out.existsSync() && out.listSync().whereType<File>().length == 4, max: 300);
    expect(out.listSync().map((e) => p.basename(e.path)).toSet(), {
      'IMG_0101.jpg',
      'IMG_0101.jpg.json',
      'IMG_0102.jpg',
      'IMG_0102.jpg.json',
    });
    expect([for (final f in zipFiles) '${f.lengthSync()} ${f.lastModifiedSync()}'], before, reason: 'zips intactos');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
