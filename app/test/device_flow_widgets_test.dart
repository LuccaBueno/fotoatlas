import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'phone_widgets_test.dart' show iphone, pixel;
import 'support/fake_backend.dart';
import 'widgets_test.dart' show harness, openDevices;

VolumeInfo volume(String mount, String label, {String driveType = 'fixed', bool isBoot = false}) => VolumeInfo(
  guidPath: '\\\\?\\Volume{$label}\\',
  mountPoints: [mount],
  label: label,
  fileSystem: 'NTFS',
  serial: 9,
  totalBytes: 1 << 30,
  freeBytes: 1 << 29,
  driveType: driveType,
  isBoot: isBoot,
);

final scannedAt = DateTime.utc(2026, 10, 28, 13);

SourceView phone({List<ScannedFolder> folders = const [], ScanRow? lastScan}) => SourceView(
  id: 'p1',
  name: 'Pixel',
  kind: 'phone',
  rootRelPath: '',
  state: SourceState.connected,
  devicePlatform: 'android',
  deviceStatus: 'ok',
  fileCount: folders.isEmpty ? 0 : 6596,
  fileBytes: folders.isEmpty ? 0 : 1 << 30,
  scannedFolders: folders,
  lastScan: lastScan,
);

FakeBackend phoneBackend(SourceView source) => FakeBackend([source])
  ..liveFolders = {
    'p1:': ['Interno'],
    'p1:Interno': ['Interno/DCIM', 'Interno/Download', 'Interno/WhatsApp'],
    'p1:Interno/DCIM': ['Interno/DCIM/Camera'],
  }
  ..stats = {
    'p1:Interno/DCIM': const FolderStats(6596, 1 << 30),
    'p1:Interno/DCIM/Camera': const FolderStats(6596, 1 << 30),
  };

Finder folderRow(String relPath) => find.byKey(ValueKey('scan-folder-$relPath'));

Future<void> check(WidgetTester tester, String relPath) async {
  await tester.tap(find.descendant(of: folderRow(relPath), matching: find.byType(Checkbox)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
  });

  testWidgets('"Adicionar dispositivo": uma janela com celulares, unidades e "Escolher uma pasta…"', (tester) async {
    final backend = FakeBackend()
      ..fakeDevices = [(pixel, null), (iphone, null)]
      ..fakeDrives = [
        (volume(r'F:\', 'HD_antigo'), null),
        (volume(r'G:\', 'PENDRIVE', driveType: 'removable'), null),
        (volume(r'H:\', 'Backup'), 'ja'),
      ];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    expect(find.text('Adicionar pasta'), findsNothing);
    expect(find.text('Adicionar celular'), findsNothing);
    expect(find.text('Adicionar unidade'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-device')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text('Adicionar dispositivo')), findsOneWidget);
    expect(find.text('Celulares'), findsOneWidget);
    expect(find.text('Unidades (HD, SSD, pendrive, cartão)'), findsOneWidget);
    expect(find.textContaining('Pronto · Armazenamento interno'), findsOneWidget);
    expect(find.textContaining('Falta permitir o acesso'), findsOneWidget);
    expect(find.textContaining('Disco interno · 512 MB livres de 1,0 GB'), findsOneWidget);
    expect(find.textContaining('Pendrive · '), findsOneWidget);
    expect(find.text('Já cadastrada'), findsOneWidget);
    expect(find.text('Escolher uma pasta…'), findsOneWidget);

    // Unidade já cadastrada não faz nada.
    await tester.tap(find.textContaining('Backup (H:'));
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c.startsWith('add')), isEmpty);

    await tester.tap(find.textContaining('HD_antigo (F:'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains(r'add:F:\'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Dispositivo adicionado'), findsOneWidget);
  });

  testWidgets('sem nada conectado: explica como conectar o celular e ainda oferece a pasta', (tester) async {
    await tester.pumpWidget(harness(FakeBackend()));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.byKey(const ValueKey('add-device-empty')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-phones')), findsOneWidget);
    expect(find.byKey(const ValueKey('no-drives')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-folder')), findsOneWidget);
  });

  testWidgets('escanear só algumas pastas do celular: árvore, tamanho estimado e escolha', (tester) async {
    final backend = phoneBackend(phone());
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(find.text('Tudo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scan-some')));
    await tester.pumpAndSettle();

    // Um armazenamento só: já aparece aberto.
    expect(folderRow('Interno/WhatsApp'), findsOneWidget);
    expect(
      find.descendant(
        of: folderRow('Interno/WhatsApp'),
        matching: find.text('ainda não escaneada · tamanho desconhecido'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: folderRow('Interno/DCIM'), matching: find.textContaining('6.596 arquivos')),
      findsOneWidget,
    );
    final start = find.byKey(const ValueKey('scan-start'));
    expect(tester.widget<FilledButton>(start).onPressed, isNull, reason: 'nenhuma pasta marcada');

    await tester.tap(find.descendant(of: folderRow('Interno/DCIM'), matching: find.byIcon(Icons.chevron_right)));
    await tester.pumpAndSettle();
    await check(tester, 'Interno/DCIM/Camera');
    await check(tester, 'Interno/WhatsApp');
    expect(
      find.text(
        '2 pastas escolhidas · cerca de 6.596 arquivos, 1,0 GB (pelo último escaneamento) · '
        '1 pasta com tamanho desconhecido (ainda não escaneada)',
      ),
      findsOneWidget,
    );

    // Marcar a pasta de cima inclui as de dentro (não conta duas vezes).
    await check(tester, 'Interno/DCIM');
    final camera = tester.widget<Checkbox>(
      find.descendant(of: folderRow('Interno/DCIM/Camera'), matching: find.byType(Checkbox)),
    );
    expect(camera.value, isTrue);
    expect(camera.onChanged, isNull);
    await check(tester, 'Interno/DCIM');

    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('scan:p1:Interno/DCIM/Camera+Interno/WhatsApp'));
  });

  testWidgets('cartão mostra as pastas já escaneadas e o "Escanear" sugere as mesmas', (tester) async {
    final backend = phoneBackend(
      phone(
        folders: [ScannedFolder('Interno/DCIM/Camera', scannedAt)],
        lastScan: completedScan(sourceId: 'p1', coverage: 'partial'),
      ),
    );
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    final parts = find.byKey(const ValueKey('scanned-parts-p1'));
    expect(parts, findsOneWidget);
    expect(
      find.descendant(of: parts, matching: find.textContaining('Escaneadas: Interno › DCIM › Camera (28/10/2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: parts, matching: find.textContaining('O resto ainda não foi escaneado')),
      findsOneWidget,
    );
    expect(find.text('Só algumas pastas foram escaneadas'), findsOneWidget);
    expect(find.textContaining('não puderam ser lidas'), findsNothing, reason: 'parcial por escolha não é erro');

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: folderRow('Interno/DCIM'), matching: find.byIcon(Icons.chevron_right)));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: folderRow('Interno/DCIM/Camera'), matching: find.textContaining('escaneada em 28/10/2026')),
      findsOneWidget,
    );
    expect(find.textContaining('1 pasta escolhida'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('scan:p1:Interno/DCIM/Camera'));
  });

  testWidgets('"Retomar" continua o escaneamento pausado (com as mesmas pastas)', (tester) async {
    final paused = ScanRow(
      id: 7,
      sourceId: 'p1',
      kind: 'full',
      status: 'paused',
      startedAt: DateTime.utc(2026, 10, 28).millisecondsSinceEpoch,
      dirsDone: 1,
      filesSeen: 10,
      bytesSeen: 100,
      errorCount: 0,
    );
    final backend = phoneBackend(phone(lastScan: paused));
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.text('Retomar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(backend.calls, contains('resume:7'));
  });
}
