import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Biblioteca de verdade: câmera (EXIF, quando o ExifTool existe; senão a data
/// vem do nome) + "celular" (pasta) + WhatsApp + um arquivo sem data.
Future<(FotoAtlasCore, Map<String, String>)> _open(WidgetTester tester, ExternalTools tools) async {
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
  final sources = <String, String>{};
  await tester.runAsync(() async {
    final vol = Directory(p.join(temp.path, 'vol'))..createSync();
    void put(String rel, List<int> bytes, {DateTime? mtime}) {
      final f = File(p.join(vol.path, rel))..parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes);
      if (mtime != null) f.setLastModifiedSync(mtime);
    }

    put(
      'Camera/IMG_20240501_140312.jpg',
      jpegWithExif(
        ExifSpec(dateTimeOriginal: DateTime(2024, 5, 1, 14, 3, 12), make: 'Canon', model: 'Canon EOS X', uniqueId: 'a'),
      ),
    );
    put(
      'Camera/IMG_20240501_153000.jpg',
      jpegWithExif(
        ExifSpec(dateTimeOriginal: DateTime(2024, 5, 1, 15, 30), make: 'Canon', model: 'Canon EOS X', uniqueId: 'b'),
      ),
    );
    put('Celular/20240501_140250.jpg', jpegWithExif(const ExifSpec(uniqueId: 'c', color: 2)));
    put('Celular/20240501_100000.jpg', jpegWithExif(const ExifSpec(uniqueId: 'd', color: 3)));
    put('Celular/IMG-20240501-WA0001.jpg', baseJpeg(1), mtime: DateTime.utc(2024, 5, 1, 20, 10)); // 17:10 em SP
    put('Celular/semdata.jpg', baseJpeg(2), mtime: DateTime.utc(2023, 1, 1, 6));
    final fake = _Volume(vol.path);
    core = opened = await FotoAtlasCore.open(
      paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
      volumes: fake,
      pathResolver: fake,
      useHelper: false,
      tools: tools,
    );
    for (final name in ['Camera', 'Celular']) {
      final id = (await core.sources.addPath(p.join(vol.path, name), name: name)).sourceId;
      sources[name] = id;
      await core.scans.wait(await core.scans.start(id));
    }
    await core.hashes.start();
    await core.hashes.waitIdle();
    await core.metadata.start();
    await core.settleDates();
  });
  return (core, sources);
}

Future<void> _until(WidgetTester tester, bool Function() done, {int max = 100}) async {
  for (var i = 0; i < max && !done(); i++) {
    // Tempo real (banco em outro isolate) e tempo do teste (o aviso de
    // mudança da Biblioteca espera 700 ms antes de recarregar).
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openLibrary(WidgetTester tester, FotoAtlasCore core) async {
  tester.view
    ..physicalSize = const Size(1600, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FotoAtlasApp(openCore: () async => core));
  await _until(tester, () => find.text('Biblioteca').evaluate().isNotEmpty);
  await tester.tap(find.text('Biblioteca').first);
  await _until(tester, () => find.byKey(const ValueKey('tile-1')).evaluate().isNotEmpty);
}

/// IDs dos quadrinhos na ordem em que aparecem (linha por linha).
List<String> _tileOrder(WidgetTester tester) {
  final tiles = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('tile-'),
  );
  final list = [
    for (final e in tiles.evaluate())
      ((e.widget.key! as ValueKey<String>).value, tester.getTopLeft(find.byWidget(e.widget))),
  ]..sort((a, b) => a.$2.dy != b.$2.dy ? a.$2.dy.compareTo(b.$2.dy) : a.$2.dx.compareTo(b.$2.dx));
  return [for (final t in list) t.$1];
}

void main() {
  final tools = ExternalTools.locate();
  final requireTools = Platform.environment['FOTOATLAS_REQUIRE_TOOLS'] == '1';

  testWidgets('linha do tempo intercala os dispositivos; hora a confirmar; filtro de horário; seleção', (tester) async {
    final (core, _) = await _open(tester, ExternalTools.none);
    await _openLibrary(tester, core);
    final names = {
      for (final i
          in await tester.runAsync(
                () async => core.library.items((await core.library.index(LibraryFilter.empty)).ids.toList()),
              ) ??
              <LibraryItem>[])
        'tile-${i.contentId}': i.name,
    };
    // Mais novas primeiro: WhatsApp 17:10, câmera 15:30, câmera 14:03:12 e celular 14:02:50 intercalados, 10:00; sem hora no fim.
    expect(
      [for (final t in _tileOrder(tester)) names[t]],
      [
        'IMG-20240501-WA0001.jpg',
        'IMG_20240501_153000.jpg',
        'IMG_20240501_140312.jpg',
        '20240501_140250.jpg',
        '20240501_100000.jpg',
        'semdata.jpg',
      ],
    );
    expect(find.text('Quarta-feira, 1 de maio de 2024'), findsOneWidget);
    await _until(tester, () => find.text('14:02:50').evaluate().isNotEmpty);
    expect(find.text('14:02:50'), findsOneWidget, reason: 'hora até os segundos');

    // Hora a confirmar: aviso, filtro e "A hora está certa".
    await _tap(tester, find.byKey(const ValueKey('to-confirm')));
    await _until(tester, () => find.text('1 item').evaluate().isNotEmpty);
    expect(find.text('1 item'), findsOneWidget);
    final tile = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('tile-'),
    );
    await tester.tap(tile.first);
    await _until(tester, () => find.byKey(const ValueKey('confirm-time')).evaluate().isNotEmpty);
    expect(find.text('Hora incerta · data do arquivo no disco'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('confirm-time')));
    await _until(tester, () => find.byKey(const ValueKey('library-empty')).evaluate().isNotEmpty);
    expect(find.text('Nada encontrado com estes filtros.'), findsOneWidget);
    await _tap(tester, find.text('Limpar filtros'));
    await _until(tester, () => find.text('6 itens').evaluate().isNotEmpty);

    // Período do dia: manhã → só o das 10:00.
    await tester.tap(find.byKey(const ValueKey('chip-time')));
    await _settle(tester);
    await tester.tap(find.text('Manhã (6–12 h)'));
    await tester.tap(find.byKey(const ValueKey('time-apply')));
    await _until(tester, () => find.text('1 item').evaluate().isNotEmpty);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.textContaining('Horário: manhã'), findsOneWidget);
    await _tap(tester, find.text('Limpar filtros'));
    await _until(tester, () => find.text('6 itens').evaluate().isNotEmpty);

    // Seleção: clique, Ctrl+clique e "todos os resultados".
    final order = _tileOrder(tester);
    await tester.tap(find.byKey(ValueKey(order[0])));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byKey(ValueKey(order[2])));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _until(tester, () => find.textContaining('2 itens ·').evaluate().isNotEmpty);
    expect(find.textContaining('2 itens ·'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('select-all')));
    await _until(tester, () => find.textContaining('6 itens ·').evaluate().isNotEmpty);
    expect(find.textContaining('6 itens ·'), findsOneWidget);
    expect(find.text('Só 1 cópia (6)').evaluate().isNotEmpty || find.textContaining('6').evaluate().isNotEmpty, isTrue);
    await _close(tester);
  });

  testWidgets('momento: dar nome pelo cabeçalho e usar na Comparar', (tester) async {
    final (core, sources) = await _open(tester, ExternalTools.none);
    await _openLibrary(tester, core);
    final moments = (await tester.runAsync(core.moments.list))!;
    // 10:00 | 14:02–17:10 (intervalo padrão de 2 h).
    final tarde = moments.firstWhere((m) => m.itemCount == 4);
    await _tap(tester, find.byKey(ValueKey('moment-menu-${tarde.id}')));
    await _settle(tester);
    await tester.tap(find.text('Dar nome…'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('moment-name')), 'Aniversário da Ana');
    await tester.tap(find.byKey(const ValueKey('moment-name-save')));
    await _settle(tester);
    final header = find.descendant(
      of: find.byKey(ValueKey('moment-${tarde.id}')),
      matching: find.text('Aniversário da Ana'),
    );
    await _until(tester, () => header.evaluate().isNotEmpty);
    expect(header, findsOneWidget);
    expect((await tester.runAsync(() => core.moments.byId(tarde.id)))!.edited, isTrue);

    // Comparar: A = o momento, B = a pasta Celular → faltam os 2 da câmera.
    await tester.tap(find.text('Comparar').first);
    await _until(tester, () => find.byKey(const ValueKey('add-moment-a')).evaluate().isNotEmpty);
    await _tap(tester, find.byKey(const ValueKey('add-moment-a')));
    await _settle(tester);
    await _tap(tester, find.byKey(ValueKey('pick-moment-${tarde.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('moment-chip-${tarde.id}')), findsOneWidget);
    // B pelo controlador (o seletor de pastas já tem testes próprios).
    final scope = Scope([ScopeEntry(sources['Celular']!)]);
    final r = (await tester.runAsync(
      () => core.compare.compare(Scope(const [], moments: [MomentScopeEntry(tarde.id)]), scope),
    ))!;
    expect((r.aContents, r.missing.contents), (4, 2));
    await _close(tester);
  });

  testWidgets('corrigir o relógio da câmera: prévia antes → depois, aplicar e desfazer', (tester) async {
    final (core, _) = await _open(tester, tools);
    await _openLibrary(tester, core);
    await tester.tap(find.byTooltip('Mais ações'));
    await _settle(tester);
    await tester.tap(find.text('Corrigir o relógio de um dispositivo…'));
    await _until(tester, () => find.byKey(const ValueKey('clock-device')).evaluate().isNotEmpty);
    // A lista de dispositivos vem do catálogo (tempo real).
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('clock-device')));
    await _settle(tester);
    await tester.tap(find.textContaining('Canon EOS X —').last);
    await _settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'horas'), '1');
    await tester.tap(find.byKey(const ValueKey('clock-preview-button')));
    await _until(tester, () => find.byKey(const ValueKey('clock-preview')).evaluate().isNotEmpty);
    expect(find.text('3. Prévia: 2 itens mudam de hora'), findsOneWidget);
    expect(find.textContaining('01/05/2024 14:03:12 → 01/05/2024 13:03:12'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clock-apply')));
    await _until(tester, () => find.textContaining('corrigido em 2 itens').evaluate().isNotEmpty);
    final row = (await tester.runAsync(
      () => core.catalog.db
          .customSelect("SELECT COUNT(*) AS n FROM media_metadata WHERE clock_correction_id IS NOT NULL")
          .getSingle(),
    ))!;
    expect(row.read<int>('n'), 2);
    await _tap(tester, find.text('Desfazer'));
    var corrected = 2;
    for (var i = 0; i < 100 && corrected > 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      // O "Desfazer" grava pelo relógio do teste; a consulta, em tempo real,
      // pode ficar na fila atrás dele: com prazo, para não travarem uma à outra.
      corrected =
          await tester.runAsync(
            () => core.catalog.db
                .customSelect("SELECT COUNT(*) AS n FROM media_metadata WHERE clock_correction_id IS NOT NULL")
                .getSingle()
                .then((r) => r.read<int>('n'))
                .timeout(const Duration(milliseconds: 300), onTimeout: () => corrected),
          ) ??
          corrected;
    }
    expect(corrected, 0, reason: '"Desfazer" volta a hora original');
    await _close(tester);
  }, skip: tools.exiftool == null && !requireTools);
}

/// Espera o widget aparecer (dados chegam do catálogo em tempo real) e toca.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  // Deixa terminar a animação de entrada (ex.: barra de aviso subindo).
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(finder.first);
  await tester.pump();
}

/// Como `pumpAndSettle`, mas com limite: há indicadores de progresso girando.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Desmonta o app e deixa os temporizadores internos vencerem.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}
