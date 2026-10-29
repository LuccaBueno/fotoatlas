import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'compare_widgets_test.dart' show addFolder, backendWith, harness, openCompare, summary;
import 'support/fake_backend.dart';

CopyPreview preview(
  CopyRequest r, {
  int items = 2,
  int? free = 10 * 1024 * 1024 * 1024,
  int renamed = 0,
  int fat32 = 0,
  int alreadyThere = 1,
}) => CopyPreview(
  request: r,
  destName: 'Disco 2',
  destDisplay: r'E:\pasta3',
  destFileSystem: fat32 > 0 ? 'FAT32' : 'NTFS',
  items: [
    for (var i = 0; i < items; i++)
      PlannedCopy(
        contentId: i + 1,
        instanceId: i + 1,
        srcSourceId: 's1',
        srcRelPath: 'pasta1/IMG_000$i.jpg',
        size: 1000,
        sha256: null,
        mtime: null,
        dstRelPath: 'pasta3/2024/2024-07/IMG_000$i${i < renamed ? '_1' : ''}.jpg',
        renamedForConflict: i < renamed,
      ),
  ],
  alreadyThere: alreadyThere,
  alreadyThereBytes: 500,
  unavailable: const [],
  tooLargeForFat32: [for (var i = 0; i < fat32; i++) UnavailableCopy(90 + i, 'grande$i.mp4', 'Maior que 4 GB')],
  freeBytes: free,
  reserveBytes: 64 * 1024 * 1024,
  folders: [PlannedFolder('pasta3/2024/2024-07', items, items * 1000)],
);

OperationView op(
  String id,
  String status, {
  Map<String, int> counts = const {'published': 1, 'pending': 2},
  String? reason,
}) => OperationView(
  id: id,
  kind: 'copy',
  status: status,
  destSourceId: 's2',
  destName: 'Disco 2',
  destFolder: 'pasta3',
  template: '{ano}/{ano}-{mes}',
  createdAt: DateTime.utc(2026, 10, 29, 12),
  counts: counts,
  totalItems: counts.values.fold(0, (s, n) => s + n),
  totalBytes: 3000,
  doneBytes: 1000,
  pauseReason: reason,
);

Future<FakeBackend> compareWithResult(WidgetTester tester) async {
  final backend = backendWith(summary());
  await tester.pumpWidget(harness(backend));
  await tester.pumpAndSettle();
  await openCompare(tester);
  await addFolder(tester, 'a', 'Disco 1', 'pasta1');
  await addFolder(tester, 'b', 'Disco 2', 'pasta3');
  await tester.tap(find.byKey(const ValueKey('compare-run')));
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1100)
      ..devicePixelRatio = 1;
  });

  testWidgets('Comparar → "Copiar para B…": prévia com destino de B e confirmação', (tester) async {
    final backend = await compareWithResult(tester);
    backend
      ..missingIds = [2, 4]
      ..onPreview = (r) => preview(r, renamed: 1);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('copy-to-b'))).onPressed, isNull);

    await tester.tap(find.text('Selecionar todos os resultados'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('copy-to-b')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('copy-wizard')), findsOneWidget);
    expect(find.text('Copiar 2 itens com conferência'), findsOneWidget);
    // Destino e pasta vêm do lado B; A é a origem preferida.
    expect(backend.lastRequest!.destSourceId, 's2');
    expect(backend.lastRequest!.destFolder, 'pasta3');
    expect(backend.lastRequest!.preferSourceIds, ['s1']);
    expect(backend.lastRequest!.contentIds, [2, 4]);
    expect(find.textContaining('Vai copiar 2 arquivos'), findsOneWidget);
    expect(find.textContaining('1 item já está em "Disco 2"'), findsOneWidget);
    expect(find.textContaining('Espaço livre no destino: 10,0 GB'), findsOneWidget);
    expect(find.textContaining('1 arquivo tem um nome que já existe no destino'), findsOneWidget);
    expect(find.textContaining('pasta3 › 2024 › 2024-07 — 2 arquivos'), findsOneWidget);
    expect(backend.calls.where((c) => c.startsWith('start-copy')), isEmpty, reason: 'nada antes de confirmar');

    // Trocar o modelo refaz a prévia.
    await tester.tap(find.byKey(const ValueKey('copy-template')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesma estrutura de pastas da origem').last);
    await tester.pumpAndSettle();
    expect(backend.lastRequest!.template, '{original}');

    await tester.tap(find.byKey(const ValueKey('copy-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('start-copy:2'));
    expect(find.byKey(const ValueKey('copy-wizard')), findsNothing);
    expect(find.text('Cópia iniciada. Acompanhe em Tarefas.'), findsOneWidget);
  });

  testWidgets('prévia sem espaço ou com FAT32: avisa e não deixa começar', (tester) async {
    final backend = await compareWithResult(tester);
    backend.onPreview = (r) => preview(r, free: 1000, fat32: 1);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('copy-to-b')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Falta espaço'), findsOneWidget);
    expect(find.textContaining('o destino (FAT32) não aceita'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('copy-confirm'))).onPressed, isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c.startsWith('start-copy')), isEmpty);
  });

  testWidgets('Tarefas: em andamento, pausada com motivo, decisão de conflito e histórico', (tester) async {
    final backend = FakeBackend()
      ..operations = [
        op('run', OpStatus.running),
        op('pau', OpStatus.paused, reason: 'O celular "Pixel" foi desconectado no meio da cópia.'),
        op('att', OpStatus.needsAttention, counts: const {'published': 2, 'needs_attention': 1}),
        op('ok', OpStatus.completed, counts: const {'published': 3}),
      ]
      ..opItems = {
        'att': const [
          OperationItemView(
            id: 7,
            seq: 3,
            state: ItemState.needsAttention,
            srcSourceId: 's1',
            srcRelPath: 'DCIM/IMG_0002.jpg',
            dstRelPath: 'pasta3/IMG_0002.jpg',
            size: 10,
            errorCode: 'name_conflict',
            errorMessage: 'Já existe outro arquivo com o nome "IMG_0002.jpg" no destino.',
          ),
        ],
      }
      ..leftovers = [TempLeftover(name: 'misterio.part', size: 3, modified: DateTime.utc(2026))];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarefas').first);
    await tester.pumpAndSettle();

    expect(find.text('Em andamento ou esperando você'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('op-pause-run')));
    await tester.pump();
    expect(backend.calls, contains('pause-copy:run'));

    expect(find.text('O celular "Pixel" foi desconectado no meio da cópia.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('op-resume-pau')));
    await tester.pump();
    expect(backend.calls, contains('resume-copy:pau'));

    // O que precisa de decisão já vem aberto, com as duas opções.
    expect(find.textContaining('Já existe outro arquivo com o nome'), findsOneWidget);
    expect(find.byKey(const ValueKey('leftover-misterio.part')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('conflict-rename-7')));
    await tester.pump();
    expect(backend.calls, contains('conflict:7:rename'));

    expect(find.textContaining('Concluída — tudo conferido'), findsOneWidget);
    expect(find.textContaining('3 copiados e conferidos'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('op-cancel-pau')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('op-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('cancel-copy:pau'));
  });

  testWidgets('Tarefas vazia explica como começar', (tester) async {
    await tester.pumpWidget(harness(FakeBackend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarefas').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tasks-empty')), findsOneWidget);
  });
}
