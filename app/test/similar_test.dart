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

Future<void> _until(WidgetTester tester, bool Function() done, {int max = 150}) async {
  for (var i = 0; i < max && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Parecidas: grupo com nível, comparação lado a lado, tirar do grupo e "Não são parecidas" com Desfazer; '
      'nenhuma foto alterada', (tester) async {
    final temp = (await tester.runAsync(() => Directory.systemTemp.createTemp('fotoatlas_app_test_')))!;
    FotoAtlasCore? opened;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
      await tester.runAsync(() async {
        await opened?.close();
        await deleteTestDir(temp);
      });
    });
    final files = {
      'praia.jpg': sceneJpeg(1),
      'praia_whatsapp.jpg': sceneJpeg(1, SceneVariant.half),
      'outra.jpg': sceneJpeg(2),
    };
    late FotoAtlasCore core;
    late Directory fotos;
    await tester.runAsync(() async {
      final vol = Directory(p.join(temp.path, 'vol'))..createSync();
      fotos = Directory(p.join(vol.path, 'Fotos'))..createSync();
      for (final MapEntry(:key, :value) in files.entries) {
        File(p.join(fotos.path, key)).writeAsBytesSync(value);
      }
      final fake = _Volume(vol.path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
        tools: ExternalTools.none,
      );
      final id = (await core.sources.addPath(fotos.path, name: 'Fotos')).sourceId;
      await core.scans.wait(await core.scans.start(id));
      await core.hashes.start();
      await core.hashes.waitIdle();
      await core.similar.start();
    });

    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
    await _until(tester, () => find.text('Parecidas').evaluate().isNotEmpty);
    await tester.tap(find.text('Parecidas').first);
    await _until(tester, () => find.text('1 grupo sugerido').evaluate().isNotEmpty);
    expect(find.text('1 grupo sugerido'), findsOneWidget);
    expect(find.text('Quase idênticas'), findsWidgets);
    expect(find.text('2 fotos'), findsOneWidget);
    expect(find.textContaining('3 de 3 fotos analisadas'), findsOneWidget);

    // Comparação lado a lado.
    await tester.tap(find.text('Comparar lado a lado'));
    await _until(tester, () => find.text('Tirar do grupo').evaluate().length == 2);
    expect(find.byKey(const ValueKey('similar-compare')), findsOneWidget);
    expect(find.text('Referência'), findsOneWidget);
    expect(find.textContaining('Fotos'), findsWidgets, reason: 'onde está cada uma');
    expect(find.text('Copiar para…'), findsOneWidget, reason: 'nada marcado: botão desligado');
    final checkbox = find.byWidgetPredicate(
      (w) =>
          w is Checkbox &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('similar-select-'),
    );
    await tester.tap(checkbox.first);
    await tester.pump();
    expect(find.text('Copiar 1 foto marcada para…'), findsOneWidget);

    // Tirar do grupo: o grupo de 2 acaba e a comparação fecha.
    await tester.tap(find.text('Tirar do grupo').last);
    await _until(tester, () => find.byKey(const ValueKey('similar-compare')).evaluate().isEmpty);
    await _until(tester, () => find.byKey(const ValueKey('similar-empty')).evaluate().isNotEmpty);
    expect(await tester.runAsync(() async => (await core.similar.overview()).dismissedPairs), 1);

    // Desfazer: a sugestão volta.
    await tester.tap(find.text('Desfazer'));
    await _until(tester, () => find.text('1 grupo sugerido').evaluate().isNotEmpty);
    expect(find.text('1 grupo sugerido'), findsOneWidget);

    // "Não são parecidas" pelo cartão.
    await tester.tap(find.text('Não são parecidas'));
    await _until(tester, () => find.byKey(const ValueKey('similar-empty')).evaluate().isNotEmpty);
    expect(find.byKey(const ValueKey('similar-dismissed')), findsOneWidget);
    expect(find.textContaining('Nenhuma foto foi alterada'), findsOneWidget);

    // "Mostrar de novo as descartadas".
    await tester.tap(find.byKey(const ValueKey('similar-restore')));
    await _until(tester, () => find.text('1 grupo sugerido').evaluate().isNotEmpty);
    expect(find.text('1 grupo sugerido'), findsOneWidget);

    // Nenhuma foto foi alterada nem criada na pasta.
    await tester.runAsync(() async {
      expect(fotos.listSync(), hasLength(3));
      for (final MapEntry(:key, :value) in files.entries) {
        expect(File(p.join(fotos.path, key)).readAsBytesSync(), value, reason: '$key intacta');
      }
    });

    // Desmonta aqui: o fechamento dos streams do catálogo agenda um timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
}
