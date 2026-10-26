import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'support/fake_backend.dart';

Widget harness(FakeBackend backend) => ProviderScope(
  overrides: [backendProvider.overrideWithValue(backend)],
  child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
);

Future<void> openDevices(WidgetTester tester) async {
  await tester.tap(find.text('Dispositivos').first);
  await tester.pumpAndSettle();
}

const connectedHd = SourceView(
  id: 's1',
  name: 'Backup 2020',
  kind: 'external_hd',
  rootRelPath: '',
  state: SourceState.connected,
  mountPath: r'E:\',
  totalBytes: 2000 * 1024 * 1024 * 1024,
  freeBytes: 500 * 1024 * 1024 * 1024,
  fileCount: 1500,
  fileBytes: 5 * 1024 * 1024 * 1024,
  mediaCount: 1234,
);

void main() {
  setUp(() {
    // Janela de desktop típica.
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
  });

  testWidgets('primeira execução: boas-vindas e lista vazia com orientação', (tester) async {
    await tester.pumpWidget(harness(FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao FotoAtlas'), findsOneWidget);

    await tester.tap(find.text('Adicionar dispositivo'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum dispositivo cadastrado'), findsOneWidget);
    expect(find.textContaining('O FotoAtlas só lê'), findsOneWidget);
  });

  testWidgets('navegação lateral tem as 6 telas; as futuras explicam o que vem', (tester) async {
    await tester.pumpWidget(harness(FakeBackend()));
    await tester.pumpAndSettle();
    for (final label in ['Início', 'Biblioteca', 'Dispositivos', 'Comparar', 'Tarefas', 'Configurações']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Disponível em breve'), findsOneWidget);
  });

  testWidgets('dispositivo conectado mostra contagens em PT-BR e escaneia', (tester) async {
    final backend = FakeBackend([
      SourceView(
        id: connectedHd.id,
        name: connectedHd.name,
        kind: connectedHd.kind,
        rootRelPath: '',
        state: SourceState.connected,
        mountPath: r'E:\',
        totalBytes: connectedHd.totalBytes,
        freeBytes: connectedHd.freeBytes,
        fileCount: 1500,
        fileBytes: connectedHd.fileBytes,
        mediaCount: 1234,
        lastScan: completedScan(),
      ),
    ]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);

    expect(find.text('Backup 2020'), findsOneWidget);
    expect(find.text('Conectado'), findsOneWidget);
    expect(find.textContaining('1.234 fotos e vídeos · 1.500 arquivos · 5,0 GB'), findsOneWidget);
    expect(find.textContaining('500 GB livres de 2,0 TB'), findsOneWidget);

    await tester.tap(find.text('Escanear'));
    await tester.pump();
    expect(backend.calls, contains('scan:s1'));

    backend.emitProgress(
      const ScanProgress(
        scanId: 1,
        sourceId: 's1',
        status: 'running',
        dirsDone: 5,
        dirsPending: 5,
        filesSeen: 2500,
        bytesSeen: 1024,
        errorCount: 0,
      ),
    );
    await tester.pump();
    expect(find.text('Pausar'), findsOneWidget);
    expect(find.textContaining('2.500 arquivos encontrados'), findsOneWidget);
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    expect(backend.calls, contains('pause:1'));
  });

  testWidgets('dispositivo desconectado continua visível, esmaecido e sem botão de escanear ativo', (tester) async {
    final backend = FakeBackend([
      SourceView(
        id: 's2',
        name: 'HD Antigo',
        kind: 'external_hd',
        rootRelPath: '',
        state: SourceState.disconnected,
        mountPath: r'F:\',
        lastConnectedAt: DateTime.utc(2026, 9, 1, 15),
        fileCount: 900,
        fileBytes: 1024 * 1024,
        mediaCount: 800,
        lastScan: completedScan(sourceId: 's2'),
      ),
    ]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    expect(find.textContaining('"HD Antigo" está desconectado'), findsOneWidget);

    await openDevices(tester);
    expect(find.text('Desconectado'), findsOneWidget);
    expect(find.textContaining('800 fotos e vídeos'), findsOneWidget);
    expect(find.textContaining('visto pela última vez em 01/09/2026'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('HD Antigo'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, lessThan(1));
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Escanear'), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('escaneamento parcial explica quantas pastas não puderam ser lidas', (tester) async {
    final backend = FakeBackend([
      SourceView(
        id: 's3',
        name: 'Pendrive',
        kind: 'usb_stick',
        rootRelPath: '',
        state: SourceState.connected,
        fileCount: 10,
        mediaCount: 10,
        lastScan: completedScan(sourceId: 's3', coverage: 'partial', errors: 2),
      ),
    ]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    expect(find.textContaining('2 pastas não puderam ser lidas'), findsOneWidget);
  });

  testWidgets('esquecer pede confirmação e explica que nada é apagado', (tester) async {
    final backend = FakeBackend([connectedHd]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esquecer este dispositivo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum arquivo é apagado'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Esquecer'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('forget:s1'));
  });

  testWidgets('tema escuro também monta', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendProvider.overrideWithValue(FakeBackend([connectedHd])),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('O que você tem e onde está'), findsOneWidget);
  });
}
