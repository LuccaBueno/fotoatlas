import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/main.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;

import 'support/temp.dart';

/// Volume simulado: uma pasta real no temp faz o papel da raiz da unidade.
class _OneVolume implements VolumeProvider, PathResolver {
  _OneVolume(this.root);
  final String root;

  VolumeInfo get volume => VolumeInfo(
    guidPath: '$root\\',
    mountPoints: const [r'E:\'],
    label: 'Teste',
    fileSystem: 'NTFS',
    serial: 7,
    totalBytes: 1 << 30,
    freeBytes: 1 << 29,
    driveType: 'fixed',
  );

  @override
  Future<List<VolumeInfo>> list() async => [volume];

  @override
  ({String mountRoot, String volumeGuid}) resolve(String path) => (mountRoot: '$root\\', volumeGuid: '$root\\');
}

void main() {
  testWidgets('app com o core real: escaneia uma pasta e mostra o resultado', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    final temp = (await tester.runAsync(() => Directory.systemTemp.createTemp('fotoatlas_app_test_')))!;
    FotoAtlasCore? opened;
    addTearDown(() async {
      // Desmonta antes de fechar o core (também quando o teste falha no meio).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() async {
        await opened?.close();
        await deleteTestDir(temp);
      });
    });
    late FotoAtlasCore core;
    await tester.runAsync(() async {
      final volumeDir = Directory(p.join(temp.path, 'vol'))..createSync();
      final fotos = Directory(p.join(volumeDir.path, 'Fotos'))..createSync();
      for (var i = 0; i < 25; i++) {
        File(p.join(fotos.path, 'IMG_$i.jpg')).writeAsBytesSync(List.filled(100, i));
      }
      File(p.join(fotos.path, 'notas.txt')).writeAsStringSync('x');
      final fake = _OneVolume(volumeDir.path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
      );
      await core.sources.addPath(fotos.path);
    });
    await tester.pumpWidget(FotoAtlasApp(openCore: () async => core));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.tap(find.text('Dispositivos').first);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('Fotos'), findsOneWidget);
    expect(find.text('Ainda não escaneado.'), findsOneWidget);

    await tester.tap(find.text('Escanear'));
    // O scan roda de verdade (isolates, banco); alterna tempo real e quadros.
    final result = find.textContaining('25 fotos e vídeos · 26 arquivos');
    for (var i = 0; i < 100 && result.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(result, findsOneWidget);
    expect(find.textContaining('Escaneado em'), findsOneWidget);

    // Desmonta e deixa os timers internos (streams/Riverpod) vencerem.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('app com o core real: compara Celular × Backup pelo conteúdo', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 1100)
      ..devicePixelRatio = 1;
    final temp = (await tester.runAsync(() => Directory.systemTemp.createTemp('fotoatlas_app_test_')))!;
    FotoAtlasCore? opened;
    addTearDown(() async {
      // Desmonta antes de fechar o core (também quando o teste falha no meio).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() async {
        await opened?.close();
        await deleteTestDir(temp);
      });
    });
    late FotoAtlasCore core;
    await tester.runAsync(() async {
      final volumeDir = Directory(p.join(temp.path, 'vol'))..createSync();
      void write(String rel, List<int> bytes) {
        final f = File(p.join(volumeDir.path, rel));
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(bytes);
      }

      write('Celular/IMG_1.jpg', List.filled(300, 1));
      write('Celular/IMG_2.jpg', List.filled(400, 2));
      write('Backup/2020/foto renomeada.jpg', List.filled(300, 1));
      final fake = _OneVolume(volumeDir.path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
      );
      for (final name in ['Celular', 'Backup']) {
        final id = (await core.sources.addPath(p.join(volumeDir.path, name))).sourceId;
        await core.scans.wait(await core.scans.start(id));
      }
      await core.hashes.start();
      await core.hashes.waitIdle();
    });
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }

    await tester.pumpWidget(FotoAtlasApp(openCore: () async => core));
    final single = find.textContaining('existe em um lugar só');
    for (var i = 0; i < 50 && single.evaluate().isEmpty; i++) {
      await settle();
    }
    expect(single, findsOneWidget, reason: 'IMG_2 só está no Celular');

    await tester.tap(find.text('Comparar').first);
    await settle();
    for (final (side, name) in [('a', 'Celular'), ('b', 'Backup')]) {
      await tester.tap(find.byKey(ValueKey('add-$side')));
      await settle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(name)));
      await tester.pump();
      await tester.tap(find.text('Adicionar'));
      await settle();
    }
    await tester.tap(find.byKey(const ValueKey('compare-run')));
    final verdict = find.textContaining('Falta 1 arquivo');
    for (var i = 0; i < 50 && verdict.evaluate().isEmpty; i++) {
      await settle();
    }
    expect(verdict, findsOneWidget);
    for (var i = 0; i < 10 && find.textContaining('IMG_2.jpg').evaluate().isEmpty; i++) {
      await settle();
    }
    expect(find.text('Celular › IMG_2.jpg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
