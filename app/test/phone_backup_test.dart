import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas/features/backup/phone_backup_store.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'support/fake_backend.dart';

SourceView _phone() =>
    SourceView(id: 'p1', name: 'Pixel 7', kind: 'phone', rootRelPath: '', state: SourceState.connected, mediaCount: 5);

SourceView _hd({DateTime? whole}) => SourceView(
  id: 'hd',
  name: 'HD Fotos',
  kind: 'external_hd',
  rootRelPath: '',
  state: SourceState.connected,
  mountPath: r'E:\',
  freeBytes: 1 << 34,
  mediaCount: 3,
  wholeScannedAt: whole,
  lastScan: whole == null ? null : completedScan(sourceId: 'hd'),
);

CompareSummary _summary(CompareVerdict verdict, int missing) => CompareSummary(
  verdict: verdict,
  aFiles: 5,
  aBytes: 5000,
  bFiles: 3,
  bBytes: 3000,
  aContents: 5,
  aRepeated: 0,
  bContents: 3,
  bRepeated: 0,
  missing: ContentTotals(missing, missing * 1000, missing),
  onlyInB: ContentTotals.zero,
  inBoth: const ContentTotals(3, 3000, 3),
  issues: const [],
  warnings: const [],
  computedAt: DateTime.now(),
);

CopyPreview _preview(CopyRequest r) => CopyPreview(
  request: r,
  destName: 'HD Fotos',
  destDisplay: r'E:\Backup do celular',
  destFileSystem: 'NTFS',
  items: [
    for (var i = 0; i < 2; i++)
      PlannedCopy(
        contentId: i + 10,
        instanceId: i + 10,
        srcSourceId: 'p1',
        srcRelPath: 'Armazenamento interno/DCIM/Camera/IMG_$i.jpg',
        size: 1000,
        sha256: null,
        mtime: null,
        dstRelPath: 'Backup do celular/Armazenamento interno/DCIM/Camera/IMG_$i.jpg',
      ),
  ],
  alreadyThere: 0,
  alreadyThereBytes: 0,
  unavailable: const [],
  tooLargeForFat32: const [],
  freeBytes: 1 << 34,
  reserveBytes: 0,
  folders: const [
    PlannedFolder('Backup do celular', 0, 0),
    PlannedFolder('Backup do celular/Armazenamento interno/DCIM/Camera', 2, 2000),
  ],
);

OperationView _op(String status, Map<String, int> counts) => OperationView(
  id: 'op1',
  kind: 'copy',
  status: status,
  destSourceId: 'hd',
  destName: 'HD Fotos',
  destFolder: 'Backup do celular',
  template: '{original}',
  createdAt: DateTime.utc(2026, 11, 27, 12),
  counts: counts,
  totalItems: 2,
  totalBytes: 2000,
  doneBytes: 0,
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
  });

  testWidgets('backup do celular: escolher, HD inteiro, ler o celular, comparar, onde guardar, copiar e '
      '"Comparar de novo" com 100%; pausar e continuar de onde parou', (tester) async {
    final backend = FakeBackend([_phone(), _hd()])
      ..compareResult = _summary(CompareVerdict.missing, 2)
      ..compareLists = {
        CompareList.missing: const [
          CompareItem(sizeBytes: 1000, sourceId: 'p1', relPath: 'Armazenamento interno/DCIM/Camera/IMG_0.jpg'),
          CompareItem(sizeBytes: 1000, sourceId: 'p1', relPath: 'Armazenamento interno/DCIM/Camera/IMG_1.jpg'),
        ],
      }
      ..missingIds = [10, 11]
      ..onPreview = _preview;
    final store = MemoryPhoneBackupStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendProvider.overrideWithValue(backend), phoneBackupStoreProvider.overrideWithValue(store)],
        child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fazer backup do celular'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-phone-backup')));
    await tester.pumpAndSettle();
    Future<void> next() async {
      await tester.tap(find.byKey(const ValueKey('phone-backup-next')));
      await tester.pumpAndSettle();
    }

    // 1) Escolher.
    expect(find.text('Passo 1 de 6: Escolher o celular e o HD'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pb-phone-p1')));
    await tester.tap(find.byKey(const ValueKey('pb-hd-hd')));
    await tester.pump();
    await next();

    // 2) O HD não foi escaneado inteiro: explica e escaneia.
    expect(find.textContaining('Senão posso copiar fotos que você já tem nele'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('phone-backup-next'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('pb-scan')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('scan:hd'));
    backend.emitSources([_phone(), _hd(whole: DateTime.utc(2026, 11, 27, 10))]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pb-ready')), findsOneWidget);

    // Pausar e continuar depois: fecha e volta no mesmo passo.
    await tester.tap(find.byKey(const ValueKey('phone-backup-pause')));
    await tester.pumpAndSettle();
    expect(find.text('Continuar o backup do celular'), findsOneWidget);
    expect((await store.load())!.step, 1);
    await tester.tap(find.byKey(const ValueKey('home-phone-backup')));
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 de 6: Conhecer o HD inteiro'), findsOneWidget);
    await next();

    // 3) Ler o celular.
    expect(find.text('Passo 3 de 6: Ler o celular'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pb-scan')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('scan:p1'));
    await next();

    // 4) Comparar pelo conteúdo.
    expect(
      find.text('3 fotos do celular já estão no HD (não serão copiadas) · 2 fotos ainda não estão (2,0 KB).'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pb-full-list')));
    await tester.pumpAndSettle();
    expect(find.text('Armazenamento interno › DCIM › Camera › IMG_1.jpg'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    await next();

    // 5) Onde guardar: "Backup do celular" e as pastas do celular, com o desenho.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Backup do celular'), findsWidgets);
    expect(find.text('Manter as pastas do celular (recomendado)'), findsOneWidget);
    expect(find.byKey(const ValueKey('pb-tree')), findsOneWidget);
    expect(find.text('Camera — 2 arquivos (2,0 KB)'), findsOneWidget);
    expect(backend.calls.where((c) => c.startsWith('preview:')).last, 'preview:2:hd:Backup do celular:{original}');
    await next();

    // 6) Prévia e cópia segura.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Vou copiar 2 fotos e vídeos (2,0 KB) de "Pixel 7" para "HD Fotos › Backup do celular"'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('phone-backup-next')));
    await tester.pump();
    await tester.pump();
    expect(backend.calls, contains('start-copy:2'));
    backend.emitOperations([
      _op(OpStatus.running, {ItemState.pending: 2}),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pb-copying')), findsOneWidget);
    backend.emitOperations([
      _op(OpStatus.completed, {ItemState.published: 2}),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Pronto: 2 arquivos copiados e conferidos.'), findsOneWidget);

    // "Comparar de novo": Sim, 100%.
    backend.compareResult = _summary(CompareVerdict.complete, 0);
    await tester.tap(find.byKey(const ValueKey('pb-compare-again')));
    await tester.pumpAndSettle();
    expect(find.text('Sim, 100%: tudo do celular está no HD.'), findsOneWidget);
    await next();
    expect(await store.load(), isNull);
    expect(find.text('Fazer backup do celular'), findsOneWidget);
  });

  testWidgets('passo 1 mostra o que está conectado e cadastra na hora o celular e o HD novos', (tester) async {
    final backend = FakeBackend()
      ..fakeDevices = [(const DeviceInfo(deviceId: 'd9', friendlyName: 'Galaxy S21', platform: 'android'), null)]
      ..fakeDrives = [
        (
          const VolumeInfo(
            guidPath: r'\?\Volume{1}\',
            mountPoints: [r'F:\'],
            label: 'Backup',
            fileSystem: 'NTFS',
            serial: 1,
            totalBytes: 1 << 40,
            freeBytes: 1 << 39,
            driveType: 'fixed',
          ),
          null,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendProvider.overrideWithValue(backend)],
        child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-phone-backup')));
    await tester.pumpAndSettle();
    expect(find.text('Conectado — vai ser cadastrado agora'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pb-phone-dev-d9')));
    await tester.tap(find.byKey(const ValueKey(r'pb-hd-vol-F:\')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('phone-backup-next')));
    await tester.pumpAndSettle();
    expect(backend.calls, containsAll(['addPhone:d9', r'add:F:\']));
    expect(find.text('Passo 2 de 6: Conhecer o HD inteiro'), findsOneWidget);
  });
}
