import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'compare_widgets_test.dart' show source;
import 'device_flow_widgets_test.dart' show phone;
import 'support/fake_backend.dart';
import 'widgets_test.dart' show harness, openDevices;

/// Prévia sintética: duas fotos saem de "Bagunça" para uma pasta de momento
/// nova, uma ganha _1 e uma vai para "Sem data confirmada".
ReorgPreview reorgPreview(ReorgRequest r) {
  final before = TreeNode('HD', '');
  before.child('Bagunça')
    ..count = 3
    ..becomesEmpty = true
    ..files.addAll(const [
      TreeFile('IMG_1.jpg', '2024/2024-07-13 Festa/IMG_1.jpg'),
      TreeFile('IMG_2.jpg', '2024/2024-07-13 Festa/IMG_2_1.jpg', conflict: true),
      TreeFile('sem_data.jpg', 'Sem data confirmada/sem_data.jpg'),
    ]);
  final after = TreeNode('HD', '');
  after.child('2024').child('2024-07-13 Festa')
    ..count = 2
    ..conflicts = 1
    ..isNew = true
    ..files.addAll(const [
      TreeFile('IMG_1.jpg', 'Bagunça/IMG_1.jpg'),
      TreeFile('IMG_2_1.jpg', 'Bagunça/IMG_2.jpg', conflict: true),
    ]);
  after.child('Sem data confirmada')
    ..count = 1
    ..isNew = true
    ..files.add(const TreeFile('sem_data.jpg', 'Bagunça/sem_data.jpg', toConfirm: true));
  return ReorgPreview(
    request: r,
    sourceName: 'HD',
    sourceDisplay: r'E:\',
    moves: const [
      PlannedMove(
        instanceId: 1,
        srcRelPath: 'Bagunça/IMG_1.jpg',
        dstRelPath: '2024/2024-07-13 Festa/IMG_1.jpg',
        size: 1000,
        mtime: 1,
      ),
      PlannedMove(
        instanceId: 2,
        srcRelPath: 'Bagunça/IMG_2.jpg',
        dstRelPath: '2024/2024-07-13 Festa/IMG_2_1.jpg',
        size: 1000,
        mtime: 1,
        renamedForConflict: true,
      ),
      PlannedMove(
        instanceId: 3,
        srcRelPath: 'Bagunça/sem_data.jpg',
        dstRelPath: 'Sem data confirmada/sem_data.jpg',
        size: 500,
        mtime: 1,
        toConfirm: true,
      ),
    ],
    alreadyInPlace: 1,
    otherFiles: 2,
    notReady: 0,
    before: before,
    after: after,
  );
}

OperationView reorgOp(
  String id,
  String status, {
  String kind = 'reorganize_move',
  Map<String, int>? counts,
  String? undoOf,
}) {
  final c = counts ?? const {'published': 3};
  return OperationView(
    id: id,
    kind: kind,
    status: status,
    destSourceId: 's1',
    destName: 'HD',
    destFolder: 'Bagunça',
    template: '{ano}/{ano}-{mes}-{dia} {momento}',
    createdAt: DateTime.utc(2026, 10, 30, 12),
    counts: c,
    totalItems: c.values.fold(0, (s, n) => s + n),
    totalBytes: 2500,
    doneBytes: 2500,
    undoOf: undoOf,
  );
}

Future<void> openTasks(WidgetTester tester) async {
  await tester.tap(find.text('Tarefas').first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1100)
      ..devicePixelRatio = 1;
  });

  testWidgets('Reorganizar: prévia em árvore antes → depois e nada muda antes de confirmar', (tester) async {
    final backend = FakeBackend([source('s1', 'HD'), phone()])..onReorgPreview = reorgPreview;
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    // Celular nunca é reorganizado: nem aparece o botão.
    expect(find.byKey(const ValueKey('reorg-p1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reorg-s1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reorg-wizard')), findsOneWidget);
    expect(
      backend.lastReorgRequest!.template,
      FolderTemplate.byMoment.pattern,
      reason: 'modelo com momento é o padrão',
    );
    expect(find.textContaining('Vai mover 3 arquivos'), findsOneWidget);
    expect(find.textContaining('1 arquivo tem um nome que já existe na pasta nova'), findsOneWidget);
    expect(find.textContaining('vai para "Sem data confirmada"'), findsOneWidget);
    expect(find.textContaining('Pastas que ficarem vazias não são apagadas'), findsOneWidget);
    // Árvore: antes (de onde saem) e depois (para onde vão).
    expect(find.text('Antes (de onde saem)'), findsOneWidget);
    expect(find.text('Depois (para onde vão)'), findsOneWidget);
    expect(find.textContaining('fica vazia (não é apagada)'), findsOneWidget);
    expect(find.byKey(const ValueKey('tree-after-2024')), findsOneWidget);
    final party = find.byKey(const ValueKey('tree-after-2024/2024-07-13 Festa'));
    await tester.ensureVisible(party);
    await tester.pumpAndSettle();
    await tester.tap(party);
    await tester.pumpAndSettle();
    expect(find.textContaining('pasta nova'), findsWidgets);
    expect(find.text('IMG_2_1.jpg (nome ajustado: já existia)'), findsOneWidget);
    expect(backend.calls.where((c) => c.startsWith('start-reorg')), isEmpty, reason: 'nada antes de confirmar');

    // Trocar a pasta refaz a prévia.
    await tester.enterText(find.byKey(const ValueKey('reorg-folder')), r'Fotos\Bagunça');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(backend.lastReorgRequest!.folder, 'Fotos/Bagunça');

    await tester.tap(find.byKey(const ValueKey('reorg-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('start-reorg:3'));
    expect(find.byKey(const ValueKey('reorg-started')), findsOneWidget);
  });

  testWidgets('Reorganizar bloqueado mostra o motivo; "Copiar para outro disco…" abre a cópia', (tester) async {
    final backend = FakeBackend([source('s1', 'HD')])
      ..onReorgPreview = ((r) => ReorgPreview(
        request: r,
        sourceName: 'HD',
        sourceDisplay: null,
        moves: const [],
        alreadyInPlace: 0,
        otherFiles: 0,
        notReady: 0,
        before: TreeNode('HD', ''),
        after: TreeNode('HD', ''),
        blocker: 'Um escaneamento de "HD" está em andamento. Espere terminar.',
      ))
      ..contentsInFolder = [1, 2];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.byKey(const ValueKey('reorg-s1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reorg-blocker')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('reorg-confirm'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('reorg-copy-elsewhere')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('copy-wizard')), findsOneWidget);
    expect(find.text('Copiar 2 itens com conferência'), findsOneWidget);
  });

  testWidgets('disco principal: marcar no cartão', (tester) async {
    final backend = FakeBackend([source('s1', 'HD')]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    expect(find.byKey(const ValueKey('primary-s1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('more-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tornar disco principal'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('primary:s1'));
    expect(find.byKey(const ValueKey('primary-s1')), findsOneWidget);
  });

  testWidgets('Desfazer avisa quem mudou, quem sumiu e lugar ocupado antes de confirmar', (tester) async {
    final backend = FakeBackend()
      ..operations = [reorgOp('r1', OpStatus.completed)]
      ..undoCheck = const UndoPreview(
        reorgId: 'r1',
        ready: 1,
        changed: ['2024/2024-07-13 Festa/IMG_1.jpg'],
        missing: ['2024/2024-07-13 Festa/IMG_2_1.jpg'],
        occupied: ['Bagunça/sem_data.jpg'],
      );
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openTasks(tester);
    expect(find.text('Reorganização de "HD › Bagunça"'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('op-undo-r1')));
    await tester.pumpAndSettle();
    expect(find.text('1 arquivo volta para o lugar exato de antes.'), findsOneWidget);
    expect(find.textContaining('1 arquivo mudou depois da reorganização'), findsOneWidget);
    expect(find.textContaining('Ele não volta sem a sua confirmação'), findsOneWidget);
    expect(find.textContaining('1 lugar de antes já tem outro arquivo'), findsOneWidget);
    expect(find.textContaining('1 arquivo não está mais onde a reorganização'), findsOneWidget);
    expect(backend.calls.where((c) => c.startsWith('undo:')), isEmpty, reason: 'nada antes de confirmar');
    await tester.tap(find.byKey(const ValueKey('undo-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('undo:r1'));
  });

  testWidgets('Desfazer em Tarefas: decisões e Desfazer escondido enquanto há um em andamento', (tester) async {
    final backend = FakeBackend()
      ..operations = [
        reorgOp(
          'u1',
          OpStatus.needsAttention,
          kind: 'undo',
          counts: const {'published': 1, 'needs_attention': 2},
          undoOf: 'r1',
        ),
        reorgOp('r1', OpStatus.cancelled, counts: const {'published': 2, 'undone': 1}),
      ]
      ..opItems = {
        'u1': const [
          OperationItemView(
            id: 5,
            seq: 1,
            state: ItemState.needsAttention,
            srcSourceId: 's1',
            srcRelPath: '2024/2024-07-13 Festa/IMG_1.jpg',
            dstRelPath: 'Bagunça/IMG_1.jpg',
            size: 10,
            errorCode: 'changed_since_reorg',
            errorMessage: 'Este arquivo mudou depois da reorganização (tamanho ou data diferente).',
          ),
          OperationItemView(
            id: 6,
            seq: 2,
            state: ItemState.needsAttention,
            srcSourceId: 's1',
            srcRelPath: 'Sem data confirmada/sem_data.jpg',
            dstRelPath: 'Bagunça/sem_data.jpg',
            size: 10,
            errorCode: 'name_conflict',
            errorMessage: 'O lugar de antes já tem outro arquivo.',
          ),
        ],
      };
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openTasks(tester);
    expect(find.text('Desfazer a reorganização de "HD › Bagunça"'), findsOneWidget);
    expect(find.byKey(const ValueKey('op-undo-r1')), findsNothing, reason: 'já há um Desfazer em andamento');
    // O que espera decisão já vem aberto.
    expect(find.textContaining('mudou depois da reorganização'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('decide-back-5')));
    await tester.pump();
    expect(backend.calls, contains('resolve:5:moveAnyway'));
    expect(
      find.byKey(const ValueKey('decide-back-6')),
      findsNothing,
      reason: 'lugar ocupado não tem "devolver mesmo assim"',
    );
    await tester.tap(find.byKey(const ValueKey('decide-leave-6')));
    await tester.pump();
    expect(backend.calls, contains('resolve:6:leave'));
  });

  testWidgets('Remover pastas vazias: lista cada uma, ocultos ficam, só as marcadas', (tester) async {
    final backend = FakeBackend()
      ..operations = [reorgOp('r1', OpStatus.completed)]
      ..emptyFolderList = const [
        EmptyFolder('Bagunça/sub', empty: true),
        EmptyFolder('Bagunça/velha', empty: true),
        EmptyFolder('Bagunça/thumbs', empty: false),
      ];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openTasks(tester);
    await tester.tap(find.byKey(const ValueKey('op-empty-r1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('empty-folders-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-Bagunça/sub')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-Bagunça/velha')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-Bagunça/thumbs')), findsNothing);
    expect(find.byKey(const ValueKey('hidden-Bagunça/thumbs')), findsOneWidget);
    expect(find.textContaining('arquivos ocultos ou de sistema'), findsOneWidget);
    // Desmarca uma: só a outra é removida.
    await tester.tap(find.byKey(const ValueKey('empty-Bagunça/velha')));
    await tester.pump();
    expect(find.text('Remover 1 pasta vazia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('empty-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('remove-folders:r1:Bagunça/sub'));
    expect(find.text('1 pasta vazia removida.'), findsOneWidget);
  });
}
