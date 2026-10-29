import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/demo_mode.dart';
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
    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.tap(find.text('Dispositivos').first);
    await tester.pump();
    // Cada consulta ao banco precisa de tempo real e de um quadro.
    for (var i = 0; i < 50 && find.text('Fotos').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Fotos'), findsOneWidget);
    expect(find.text('Ainda não escaneado.'), findsOneWidget);

    await tester.tap(find.text('Escanear'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-start')));
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

    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
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

  testWidgets('fechar com a conferência travada no celular: pergunta antes, "Encerrando com segurança…" e sai', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
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
    final phone = _StuckPhone();
    late FotoAtlasCore core;
    await tester.runAsync(() async {
      final fake = _OneVolume((Directory(p.join(temp.path, 'vol'))..createSync()).path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
        devices: phone,
      );
      await core.sources.refreshConnectivity();
      final id = (await core.sources.addPhone(phone.deviceId)).sourceId;
      await core.scans.wait(await core.scans.start(id));
      unawaited(core.hashes.start());
      while (!phone.hashing) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core));
    for (var i = 0; i < 20 && find.text('Comparar').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    // Outra tela: os streams das telas fora de vista ficam pausados (era o bug).
    await tester.tap(find.text('Comparar').first);
    await tester.pump();

    final state = tester.state<FotoAtlasAppState>(find.byType(FotoAtlasApp));
    Future<void> frames(bool Function() until, {int max = 100}) async {
      for (var i = 0; i < max && !until(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    // 1º X: há trabalho em andamento → pergunta antes.
    AppExitResponse? response;
    // Em tempo real (os prazos do encerramento são timers de verdade).
    await tester.runAsync(() async => unawaited(state.requestExit().then((r) => response = r)));
    expect(identical(state.requestExit(), state.requestExit()), isTrue, reason: 'X de novo não abre outra pergunta');
    final dialog = find.byKey(const ValueKey('close-confirm'));
    await frames(() => dialog.evaluate().isNotEmpty);
    expect(dialog, findsOneWidget);
    expect(find.text('Há tarefas em andamento:'), findsOneWidget);
    expect(find.textContaining('Conferindo o conteúdo — 0 de 1 arquivo (0%)'), findsOneWidget);
    expect(find.textContaining('continuam de onde pararam'), findsOneWidget);
    final keep = tester.widget<FilledButton>(find.byKey(const ValueKey('keep-working')));
    expect(keep.autofocus, isTrue, reason: '"Continuar trabalhando" é o padrão');

    // "Continuar trabalhando": não fecha nem pausa nada.
    await tester.tap(find.byKey(const ValueKey('keep-working')));
    await frames(() => response != null);
    expect(response, AppExitResponse.cancel);
    expect(find.text('Encerrando com segurança…'), findsNothing);
    expect(core.hashes.isRunning, isTrue, reason: 'a conferência continua');

    // 2º X: pergunta de novo; "Fechar mesmo assim" → "Encerrando com segurança…" e sai.
    response = null;
    await tester.runAsync(() async => unawaited(state.requestExit().then((r) => response = r)));
    await frames(() => dialog.evaluate().isNotEmpty);
    expect(dialog, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-anyway')));
    final watch = Stopwatch()..start();
    var sawOverlay = false, sawHashStep = false;
    for (var i = 0; i < 200 && response == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      sawOverlay |= find.text('Encerrando com segurança…').evaluate().isNotEmpty;
      sawHashStep |= find.textContaining('Pausando a conferência').evaluate().isNotEmpty;
    }
    expect(response, AppExitResponse.exit);
    expect(watch.elapsed, lessThan(const Duration(seconds: 8)), reason: 'termina em poucos segundos');
    expect(sawOverlay, isTrue);
    expect(sawHashStep, isTrue, reason: 'mostra o que falta');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  for (final demo in [DemoMode.off, DemoMode.discarded]) {
    testWidgets('fechar sem nada em andamento ($demo): fecha direto, sem perguntar', (tester) async {
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
      await tester.runAsync(() async {
        final fake = _OneVolume((Directory(p.join(temp.path, 'vol'))..createSync()).path);
        core = opened = await FotoAtlasCore.open(
          paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
          volumes: fake,
          pathResolver: fake,
          useHelper: false,
        );
      });
      await tester.pumpWidget(FotoAtlasApp(firstRunGuide: false, openCore: () async => core, demoMode: demo));
      for (var i = 0; i < 20 && find.text('Comparar').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      final banner = find.text('Modo demonstração — tudo será descartado ao fechar');
      expect(banner, demo == DemoMode.discarded ? findsOneWidget : findsNothing);
      final state = tester.state<FotoAtlasAppState>(find.byType(FotoAtlasApp));
      AppExitResponse? response;
      var asked = false;
      await tester.runAsync(() async => unawaited(state.requestExit().then((r) => response = r)));
      for (var i = 0; i < 100 && response == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        asked |= find.byKey(const ValueKey('close-confirm')).evaluate().isNotEmpty;
      }
      expect(response, AppExitResponse.exit);
      expect(asked, isFalse);
      await tester.pump();
      // "Encerrando…" não promete continuar quando tudo será descartado.
      expect(
        find.textContaining('tudo é descartado ao fechar'),
        demo == DemoMode.discarded ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('continua de onde parou'), demo == DemoMode.discarded ? findsNothing : findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}

/// Celular que trava na leitura (como uma chamada WPD presa): o hash nunca
/// responde e ignora o cancelamento.
class _StuckPhone implements DeviceBackend {
  final deviceId = 'wpd:travado';
  bool hashing = false;

  @override
  Future<List<DeviceInfo>> list() async => [
    DeviceInfo(
      deviceId: deviceId,
      friendlyName: 'Celular travado',
      serial: 'TRAVADO-1',
      platform: 'android',
      storages: const [DeviceStorage(storageId: 'st', name: 'Interno')],
    ),
  ];

  @override
  Future<List<DeviceEntry>> listChildren(String deviceId, String objectId) async => switch (objectId) {
    '' => const [DeviceEntry(objectId: 'st', name: 'Interno', isFolder: true)],
    'st' => const [DeviceEntry(objectId: 'f1', name: 'IMG_1.jpg', isFolder: false, size: 10, modified: 1)],
    _ => const [],
  };

  @override
  Future<DeviceHash> hash(String deviceId, String objectId, {required int expectedSize, Future<void>? cancel}) {
    hashing = true;
    return Completer<DeviceHash>().future;
  }

  @override
  Future<int> readHead(String deviceId, String objectId, String outPath, {int maxBytes = 256 * 1024}) =>
      Completer<int>().future;
}
