import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/backend.dart';
import 'package:fotoatlas/app/dedupe_backend.dart';
import 'package:fotoatlas/app/library_backend.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/similar_backend.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas/features/library/library_controller.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
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

/// O core de verdade, mas "Abrir a foto" e "Mostrar na pasta" só anotam o pedido.
class _Recording implements DedupeBackend {
  _Recording(this.inner);
  final CoreDedupeBackend inner;
  final opened = <String>[];
  final revealed = <String>[];

  @override
  Future<void> openFile(String path) async => opened.add(path);
  @override
  Future<void> showInFolder(String path) async => revealed.add(path);
  @override
  Stream<void> changes() => inner.changes();
  @override
  Future<List<DedupeSourceSummary>> summaries() => inner.summaries();
  @override
  Future<List<DedupeGroup>> groups(String sourceId, KeepRule rule) => inner.groups(sourceId, rule);
  @override
  Future<KeepRule> keepRule() => inner.keepRule();
  @override
  Future<void> setKeepRule(KeepRule rule) => inner.setKeepRule(rule);
  @override
  Future<DedupePreview> preview(String sourceId, List<DedupeChoice> choices) => inner.preview(sourceId, choices);
  @override
  Future<String> start(DedupePreview preview) => inner.start(preview);
  @override
  Stream<CopyProgress> get progress => inner.progress;
  @override
  Future<void> pause(String operationId) => inner.pause(operationId);
  @override
  Future<void> resume(String operationId) => inner.resume(operationId);
  @override
  Future<void> cancel(String operationId) => inner.cancel(operationId);
  @override
  Future<int> retryFailed(String operationId) => inner.retryFailed(operationId);
}

Future<void> _until(WidgetTester tester, bool Function() done, {int max = 150}) async {
  for (var i = 0; i < max && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

List<int> _bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101 + (i >> 7)) & 0xff);

void main() {
  testWidgets('Repetidos: nada marcado, cópias lado a lado, abrir e mostrar, trocar qual fica, um por vez, '
      'prévia com confirmação e Lixeira; o histórico vai para Tarefas', (tester) async {
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
    final a = _bytes(1, 6000), b = _bytes(2, 9000);
    final files = {
      'Fotos/2024/2024-07/IMG_0001.jpg': a,
      'Bagunca/IMG_0001 (1).jpg': a,
      'Bagunca/WhatsApp/IMG_0001.jpg': a,
      'Videos/VID_0002.mp4': b,
      'Backup/VID_0002.mp4': b,
    };
    late FotoAtlasCore core;
    late Directory hd;
    late Directory bin;
    late String sourceId;
    await tester.runAsync(() async {
      final vol = Directory(p.join(temp.path, 'vol'))..createSync();
      hd = Directory(p.join(vol.path, 'HD'))..createSync();
      bin = Directory(p.join(temp.path, 'fotoatlas_test_bin'));
      for (final MapEntry(:key, :value) in files.entries) {
        (File(p.join(hd.path, key))..parent.createSync(recursive: true)).writeAsBytesSync(value);
      }
      final fake = _Volume(vol.path);
      core = opened = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        volumes: fake,
        pathResolver: fake,
        useHelper: false,
        tools: ExternalTools.none,
        recycleBin: FolderRecycleBin(bin.path),
        verifyInIsolate: false,
      );
      final id = sourceId = (await core.sources.addPath(hd.path, name: 'HD')).sourceId;
      await core.scans.wait(await core.scans.start(id));
      await core.hashes.start();
      await core.hashes.waitIdle();
    });
    final dedupe = _Recording(CoreDedupeBackend(core));
    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump();
    }

    // Botões do topo (podem ter rolado para fora da tela).
    Future<void> tapTop(Finder f) async {
      for (var i = 0; i < 20 && f.evaluate().isEmpty; i++) {
        await tester.drag(find.byKey(const ValueKey('dedupe-list')), const Offset(0, 600), warnIfMissed: false);
        await tester.pump();
      }
      await tap(f);
    }

    tester.view
      ..physicalSize = const Size(1600, 1100)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendProvider.overrideWithValue(CoreBackend(core)),
          libraryBackendProvider.overrideWithValue(CoreLibraryBackend(core)),
          similarBackendProvider.overrideWithValue(CoreSimilarBackend(core)),
          dedupeBackendProvider.overrideWithValue(dedupe),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
      ),
    );
    await _until(tester, () => find.text('Repetidos').evaluate().isNotEmpty);

    // Números clicáveis do cartão: dica "Ver estes arquivos" e cursor de mão.
    await tester.tap(find.text('Dispositivos').first);
    final verified = find.byKey(ValueKey('count-verified-$sourceId'));
    await _until(tester, () => verified.evaluate().isNotEmpty);
    expect(find.descendant(of: verified, matching: find.byTooltip('Ver estes arquivos')), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.descendant(of: verified, matching: find.byType(InkWell))).mouseCursor,
      SystemMouseCursors.click,
    );
    expect(find.text('5 arquivos com cópia conferida'), findsOneWidget);
    // "5 arquivos com cópia conferida" abre a Biblioteca filtrada por dispositivo e situação.
    await tester.tap(verified);
    await _until(tester, () => find.byKey(const ValueKey('chip-coverage')).evaluate().isNotEmpty);
    expect(find.text('Situação: Tem cópia conferida'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    await _until(tester, () => container.read(libraryControllerProvider).index.length == 2);
    expect(container.read(libraryControllerProvider).index.length, 2, reason: 'a foto e o vídeo repetidos');
    expect(container.read(libraryControllerProvider).filter.of(FilterKind.sources)!.values, [sourceId]);
    // "5 arquivos repetidos" abre a Limpar repetidos daquele dispositivo.
    await tester.tap(find.text('Dispositivos').first);
    final dups = find.byKey(ValueKey('count-duplicates-$sourceId'));
    await _until(tester, () => dups.evaluate().isNotEmpty);
    await tester.tap(dups);
    final summary = find.byKey(const ValueKey('dedupe-summary'));
    await _until(tester, () => summary.evaluate().isNotEmpty);
    await _until(tester, () => find.textContaining('2 grupos de repetidos').evaluate().isNotEmpty);

    // Nada vem marcado: nada iria sair, e o botão fica desligado.
    expect(find.text('2 grupos de repetidos. Nenhum marcado: nada vai sair.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('dedupe-review'))).onPressed, isNull);

    // Cópias lado a lado, com caminho completo e a sugestão.
    final photo = (await tester.runAsync(() => core.dedupe.groups(sourceId)))!
        .singleWhere((g) => g.mediaType == 'photo');
    final organized = photo.copies.singleWhere((c) => c.relPath.startsWith('Fotos/'));
    final whatsapp = photo.copies.singleWhere((c) => c.relPath.contains('WhatsApp'));
    expect(find.text('Fica esta'), findsNWidgets(2), reason: 'uma sugerida por grupo');
    expect(find.textContaining(r'E:\HD\Fotos\2024\2024-07\IMG_0001.jpg'), findsOneWidget);
    expect(find.text('Sugerida: está numa pasta organizada por data.'), findsOneWidget);

    await tap(find.byKey(ValueKey('dedupe-open-${whatsapp.instanceId}')));
    await tap(find.byKey(ValueKey('dedupe-reveal-${whatsapp.instanceId}')));
    await tester.pump();
    expect(dedupe.opened, [r'E:\HD\Bagunca\WhatsApp\IMG_0001.jpg']);
    expect(dedupe.revealed, [r'E:\HD\Bagunca\WhatsApp\IMG_0001.jpg']);

    // Troca qual fica e marca só o grupo da foto.
    await tap(find.byKey(ValueKey('dedupe-keep-${whatsapp.instanceId}')));
    await tap(find.byKey(ValueKey('dedupe-mark-${photo.contentId}')));
    await tester.pump();
    expect(find.textContaining('1 de 2 grupos marcados — 2 arquivos iriam para a Lixeira'), findsOneWidget);
    expect(find.text('Você escolheu qual fica.'), findsOneWidget);

    // Desmarcar todos e aceitar as sugestões de todos (volta para as sugeridas).
    await tapTop(find.byKey(const ValueKey('dedupe-clear')));
    await tester.pump();
    expect(find.textContaining('Nenhum marcado'), findsOneWidget);
    await tapTop(find.byKey(const ValueKey('dedupe-accept-all')));
    await tester.pump();
    expect(find.textContaining('2 de 2 grupos marcados — 3 arquivos iriam para a Lixeira'), findsOneWidget);

    // Um grupo por vez (o maior primeiro: o vídeo). "Não mexer" no vídeo.
    await tapTop(find.text('Um grupo por vez'));
    await tester.pump();
    expect(find.text('Grupo 1 de 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dedupe-skip-next')));
    await tester.pump();
    expect(find.text('Grupo 2 de 2'), findsOneWidget);
    expect(find.textContaining('1 de 2 grupos marcados — 2 arquivos iriam para a Lixeira'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dedupe-prev')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dedupe-mark-next')));
    await tester.pump();
    expect(find.textContaining('2 de 2 grupos marcados — 3 arquivos iriam'), findsOneWidget);

    // Prévia: lista, quantidade, espaço e a confirmação explícita.
    await tester.tap(find.byKey(const ValueKey('dedupe-review')));
    await _until(tester, () => find.byKey(const ValueKey('dedupe-preview')).evaluate().isNotEmpty);
    expect(
      find.text('3 arquivos vão para a Lixeira, de 2 grupos em "HD". Libera 20,5 KB. Em cada grupo, uma cópia fica.'),
      findsOneWidget,
    );
    expect(find.text('Bagunca › WhatsApp › IMG_0001.jpg'), findsOneWidget);
    expect(find.textContaining('Fica: Fotos › 2024 › 2024-07 › IMG_0001.jpg'), findsNWidgets(2));
    final confirm = find.byKey(const ValueKey('dedupe-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'só depois de marcar "Entendi"');
    await tester.tap(find.byKey(const ValueKey('dedupe-understood')));
    await tester.pump();
    await tester.tap(confirm);
    await _until(tester, () => find.byKey(const ValueKey('dedupe-started')).evaluate().isNotEmpty);
    await _until(tester, () => find.byKey(const ValueKey("dedupe-empty")).evaluate().isNotEmpty, max: 300);

    await tester.runAsync(() async {
      expect(File(p.join(hd.path, organized.relPath)).readAsBytesSync(), a);
      // Empate no vídeo (mesma profundidade e tamanho de caminho): fica a primeira em ordem alfabética.
      expect(File(p.join(hd.path, 'Backup', 'VID_0002.mp4')).readAsBytesSync(), b);
      expect(File(p.join(hd.path, 'Videos', 'VID_0002.mp4')).existsSync(), isFalse);
      expect(File(p.join(hd.path, 'Bagunca', 'WhatsApp', 'IMG_0001.jpg')).existsSync(), isFalse);
      expect(bin.listSync().whereType<File>(), hasLength(3), reason: 'inteiros na "Lixeira"');
    });

    // Tarefas: o histórico da limpeza.
    await tester.tap(find.text('Tarefas').first);
    await _until(tester, () => find.textContaining('Concluída — as cópias repetidas').evaluate().isNotEmpty);
    expect(find.textContaining('3 arquivos foram para a Lixeira'), findsOneWidget);
    expect(find.textContaining('Concluída — as cópias repetidas foram para a Lixeira'), findsOneWidget);
    expect(find.text('Exportar relatório (CSV)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
}
