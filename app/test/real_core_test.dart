import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/main.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;

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
    late Directory temp;
    late FotoAtlasCore core;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('fotoatlas_app_test_');
      final volumeDir = Directory(p.join(temp.path, 'vol'))..createSync();
      final fotos = Directory(p.join(volumeDir.path, 'Fotos'))..createSync();
      for (var i = 0; i < 25; i++) {
        File(p.join(fotos.path, 'IMG_$i.jpg')).writeAsBytesSync(List.filled(100, i));
      }
      File(p.join(fotos.path, 'notas.txt')).writeAsStringSync('x');
      final fake = _OneVolume(volumeDir.path);
      core = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
      );
      await core.sources.addPath(fotos.path);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await core.close();
        await temp.delete(recursive: true);
      });
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
}
