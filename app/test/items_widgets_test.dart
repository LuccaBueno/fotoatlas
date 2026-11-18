import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/main.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/media_fixtures.dart';
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

/// Espera [done] continuar verdadeiro por 1 s seguido.
Future<void> _stable(WidgetTester tester, bool Function() done) async {
  for (var ok = 0, i = 0; ok < 10 && i < 60; i++) {
    await _until(tester, done, max: 20);
    ok = done() ? ok + 1 : 0;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
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
  testWidgets('RAW+JPEG: um quadrinho com selo; desagrupar e agrupar de novo (só catálogo)', (tester) async {
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
    late int jpg, raw;
    await tester.runAsync(() async {
      final vol = Directory(p.join(temp.path, 'vol'))..createSync();
      final at = DateTime(2024, 5, 1, 14, 3, 12);
      for (final (name, id) in [('IMG_20240501_140312.JPG', 'a'), ('IMG_20240501_140312.DNG', 'b')]) {
        File(p.join(vol.path, 'Camera', name))
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(jpegWithExif(ExifSpec(dateTimeOriginal: at, uniqueId: id)));
      }
      final fake = _Volume(vol.path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
        tools: ExternalTools.none,
      );
      final id = (await core.sources.addPath(p.join(vol.path, 'Camera'), name: 'Camera')).sourceId;
      await core.scans.wait(await core.scans.start(id));
      await core.hashes.start();
      await core.hashes.waitIdle();
      await core.metadata.start();
      await core.settleDates();
      final item = (await core.items.all()).single;
      jpg = item.members.singleWhere((m) => m.role == 'photo').contentId;
      raw = item.members.singleWhere((m) => m.role == 'raw').contentId;
    });
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
    await _until(tester, () => find.text('Biblioteca').evaluate().isNotEmpty);
    await tester.tap(find.text('Biblioteca').first);
    final jpgTile = find.byKey(ValueKey('tile-$jpg')), rawTile = find.byKey(ValueKey('tile-$raw'));
    final badge = find.descendant(of: jpgTile, matching: find.text('RAW+JPEG'));
    // A Biblioteca recarrega logo depois de abrir (o quadrinho espera os dados de novo).
    await _stable(tester, () => badge.evaluate().isNotEmpty);
    expect(rawTile, findsNothing, reason: 'o RAW aparece dentro do item da foto');
    expect(badge, findsOneWidget);

    // Detalhes: os dois arquivos e "Desagrupar".
    await _tap(tester, jpgTile);
    await _until(tester, () => find.byKey(const ValueKey('details-panel')).evaluate().isNotEmpty);
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('split-item')),
      200,
      scrollable: find
          .descendant(of: find.byKey(const ValueKey('details-panel')), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('IMG_20240501_140312.DNG (RAW)'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('split-item')));
    await _stable(tester, () => rawTile.evaluate().isNotEmpty);
    expect(rawTile, findsOneWidget, reason: 'desagrupado: cada arquivo sozinho');
    expect(find.text('RAW+JPEG'), findsNothing);

    // Agrupar à mão pela seleção.
    // O clique que abriu os detalhes já marcou a foto; marca o RAW junto.
    Finder box(Finder tile) => find.descendant(of: tile, matching: find.byType(Checkbox));
    expect(tester.widget<Checkbox>(box(jpgTile)).value, isTrue);
    // O aviso "Desagrupado…" some sozinho e deixa a barra da seleção livre.
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    await _tap(tester, box(rawTile));
    await _stable(tester, () => find.byKey(const ValueKey('group-selection')).evaluate().isNotEmpty);
    await _tap(tester, find.byKey(const ValueKey('group-selection')));
    final manual = find.descendant(of: jpgTile, matching: find.text('Agrupado'));
    await _stable(tester, () => rawTile.evaluate().isEmpty && manual.evaluate().isNotEmpty);
    expect(rawTile, findsNothing);
    expect(manual, findsOneWidget);
    // Só catálogo: os dois arquivos continuam no disco, intactos.
    expect(Directory(p.join(temp.path, 'vol', 'Camera')).listSync(), hasLength(2));
    // Desmonta o app e deixa os temporizadores internos vencerem.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
