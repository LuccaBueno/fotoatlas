import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/features/library/details_panel.dart';
import 'package:fotoatlas/features/settings/settings_page.dart';
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder.first);
  await tester.pump();
}

void main() {
  testWidgets('Mapa: pontos sem internet, detalhes, filtro pela área e mapa online só com confirmação', (tester) async {
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
    final ids = <String, int>{};
    const places = {'rio1.jpg': (-22.90, -43.20), 'rio2.jpg': (-22.91, -43.18), 'lisboa.jpg': (38.72, -9.14)};
    await tester.runAsync(() async {
      final vol = Directory(p.join(temp.path, 'vol'))..createSync();
      var n = 0;
      for (final name in [...places.keys, 'semlocal.jpg']) {
        File(p.join(vol.path, 'Fotos', name))
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(baseJpeg(++n))
          ..setLastModifiedSync(DateTime.utc(2024, 5, n, 12));
      }
      final fake = _Volume(vol.path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
        tools: ExternalTools.none,
      );
      final id = (await core.sources.addPath(p.join(vol.path, 'Fotos'), name: 'Fotos')).sourceId;
      await core.scans.wait(await core.scans.start(id));
      await core.hashes.start();
      await core.hashes.waitIdle();
      await core.metadata.start();
      await core.settleDates();
      final db = core.catalog.db;
      for (final name in [...places.keys, 'semlocal.jpg']) {
        // Nomes fixos do teste: dá para pôr direto no SQL.
        ids[name] = (await db.customSelect("SELECT content_id FROM file_instances WHERE name = '$name'").getSingle())
            .read<int>('content_id');
      }
      for (final MapEntry(key: name, value: (lat, lon)) in places.entries) {
        await db.customStatement('UPDATE media_metadata SET lat = ?, lon = ? WHERE content_id = ?', [
          lat,
          lon,
          ids[name],
        ]);
      }
    });

    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
    await _until(tester, () => find.text('Biblioteca').evaluate().isNotEmpty);
    await tester.tap(find.text('Biblioteca').first);
    await _until(tester, () => find.byKey(const ValueKey('tile-1')).evaluate().isNotEmpty);
    await _tap(tester, find.text('Mapa'));

    final summary = find.byKey(const ValueKey('map-summary'));
    await _until(tester, () => summary.evaluate().isNotEmpty && !tester.widget<Text>(summary).data!.contains('…'));
    expect(tester.widget<Text>(summary).data, '3 fotos e vídeos com local · 1 sem local (não aparecem)');
    expect(find.byKey(const ValueKey('map-offline-note')), findsOneWidget, reason: 'padrão: sem internet');
    expect(find.byKey(const ValueKey('map-attribution')), findsNothing);
    // Contornos embutidos carregados (o mapa não fica em branco sem internet).
    await _until(tester, () => find.byKey(ValueKey('map-cluster-${ids['lisboa.jpg']}')).evaluate().isNotEmpty);

    // Lisboa sozinha: abre os detalhes.
    await _tap(tester, find.byKey(ValueKey('map-cluster-${ids['lisboa.jpg']}')));
    await _until(tester, () => find.byType(DetailsPanel).evaluate().isNotEmpty);
    expect(find.byType(DetailsPanel), findsOneWidget);

    // As duas do Rio aproximam até se separar.
    await _tap(tester, find.byKey(const ValueKey('map-fit')));
    Finder rio(String name) => find.byKey(ValueKey('map-cluster-${ids[name]}'));
    bool both() => rio('rio1.jpg').evaluate().isNotEmpty && rio('rio2.jpg').evaluate().isNotEmpty;
    for (var i = 0; i < 12 && !both(); i++) {
      await _tap(tester, rio('rio1.jpg').evaluate().isNotEmpty ? rio('rio1.jpg') : rio('rio2.jpg'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(rio('rio1.jpg'), findsOneWidget);
    expect(rio('rio2.jpg'), findsOneWidget);

    // "Ver as fotos desta área": só as do Rio (Lisboa e a sem local ficam de fora).
    await _tap(tester, find.byKey(const ValueKey('map-filter-area')));
    await _until(tester, () => find.text('2 itens').evaluate().isNotEmpty);
    expect(find.text('2 itens'), findsOneWidget);
    expect(find.text('Área do mapa'), findsOneWidget);

    // Configurações › Mapa: cancelar não liga; confirmar liga e fica guardado.
    await tester.tap(find.text('Configurações').first);
    final toggle = find.byKey(const ValueKey('map-online'));
    Future<void> showToggle() async {
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
      );
      await tester.pump();
    }

    await _until(tester, () => find.byType(SettingsPage).evaluate().isNotEmpty);
    await showToggle();
    await _tap(tester, toggle);
    await _until(tester, () => find.text('Ligar o mapa online?').evaluate().isNotEmpty);
    expect(
      find.textContaining('Os locais das fotos, os nomes dos arquivos e o catálogo nunca são enviados'),
      findsWidgets,
    );
    await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancelar')));
    await _until(tester, () => find.text('Ligar o mapa online?').evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await showToggle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(await tester.runAsync(() => SettingsStore(core.catalog.db).get(MapSettingKeys.online)), isNull);
    await _tap(tester, toggle);
    await _tap(tester, find.byKey(const ValueKey('map-online-confirm')));
    await _until(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await showToggle();
    await _until(tester, () => tester.widget<SwitchListTile>(toggle).value);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(await tester.runAsync(() => SettingsStore(core.catalog.db).get(MapSettingKeys.online)), isTrue);
    // Volta a desligar (o teste não faz pedidos à internet).
    await _tap(tester, toggle);
    await _until(tester, () => !tester.widget<SwitchListTile>(toggle).value);
    expect(await tester.runAsync(() => SettingsStore(core.catalog.db).get(MapSettingKeys.online)), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
