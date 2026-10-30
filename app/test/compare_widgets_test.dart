import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas/l10n/strings.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'support/fake_backend.dart';

Widget harness(FakeBackend backend) => ProviderScope(
  overrides: [backendProvider.overrideWithValue(backend)],
  child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
);

SourceView source(String id, String name) => SourceView(
  id: id,
  name: name,
  kind: 'external_hd',
  rootRelPath: '',
  state: SourceState.connected,
  mountPath: r'E:\',
  lastScan: completedScan(sourceId: id),
);

CompareSummary summary({
  CompareVerdict verdict = CompareVerdict.missing,
  ContentTotals missing = const ContentTotals(2, 2400, 2),
  List<CompareIssue> issues = const [],
}) => CompareSummary(
  verdict: verdict,
  aFiles: 5,
  aBytes: 6400,
  bFiles: 3,
  bBytes: 9000,
  aContents: 4,
  aRepeated: 1,
  bContents: 3,
  bRepeated: 0,
  missing: missing,
  onlyInB: const ContentTotals(1, 5000, 1),
  inBoth: const ContentTotals(2, 4000, 3),
  issues: issues,
  warnings: const [],
  computedAt: DateTime.utc(2026, 10, 27),
);

const missingItems = [
  CompareItem(contentId: 2, instanceId: 3, sizeBytes: 2000, sourceId: 's1', relPath: 'pasta1/IMG_0002.jpg'),
  CompareItem(contentId: 4, instanceId: 5, sizeBytes: 400, sourceId: 's1', relPath: 'pasta2/notas.txt'),
];

FakeBackend backendWith(CompareSummary result) => FakeBackend([source('s1', 'Disco 1'), source('s2', 'Disco 2')])
  ..folders = {
    's1:': ['pasta1', 'pasta2'],
    's2:': ['pasta3'],
  }
  ..compareResult = result
  ..compareLists = {CompareList.missing: missingItems};

Future<void> openCompare(WidgetTester tester) async {
  await tester.tap(find.text('Comparar').first);
  await tester.pumpAndSettle();
}

/// Abre o seletor do lado [side], expande [sourceName] e adiciona [folder].
Future<void> addFolder(WidgetTester tester, String side, String sourceName, String folder) async {
  await tester.tap(find.byKey(ValueKey('add-$side')));
  await tester.pumpAndSettle();
  final dialog = find.byType(AlertDialog);
  final row = find.ancestor(
    of: find.descendant(of: dialog, matching: find.text(sourceName)),
    matching: find.byType(ListTile),
  );
  await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: dialog, matching: find.text(folder)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1100)
      ..devicePixelRatio = 1;
  });

  testWidgets('A = pasta1 + pasta2, B = pasta3: "Faltam 2 arquivos", listas e seleção', (tester) async {
    final backend = backendWith(summary());
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openCompare(tester);

    await addFolder(tester, 'a', 'Disco 1', 'pasta1');
    await addFolder(tester, 'a', 'Disco 1', 'pasta2');
    await addFolder(tester, 'b', 'Disco 2', 'pasta3');
    expect(find.text('Disco 1 › pasta1'), findsOneWidget);
    expect(find.text('Disco 1 › pasta2'), findsOneWidget);
    expect(find.text('Disco 2 › pasta3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compare-run')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('compare:s1:pasta1+s1:pasta2|s2:pasta3|'));
    expect(find.text('Faltam 2 arquivos (2,3 KB) de A em B.'), findsOneWidget);
    expect(find.text('Em A, não contido em B — faltam (2)'), findsOneWidget);
    expect(find.text('Em B, não contido em A (1)'), findsOneWidget);
    expect(find.text('Contido em A e em B (2)'), findsOneWidget);
    // As dicas das abas citam os nomes reais dos lados.
    String tip(String list) => tester
        .widget<Tooltip>(find.descendant(of: find.byKey(ValueKey('tab-$list')), matching: find.byType(Tooltip)))
        .message!;
    expect(
      tip('missing'),
      'Arquivos de "Disco 1 › pasta1 + Disco 1 › pasta2" que "Disco 2 › pasta3" ainda não contém. '
      'São estes que dá para copiar para B.',
    );
    expect(tip('onlyInB'), startsWith('Arquivos de "Disco 2 › pasta3" que não estão em "Disco 1 › pasta1 + '));
    expect(tip('inBoth'), contains('e também em "Disco 2 › pasta3"'));
    // "Copiar para B…" desabilitado explica o porquê.
    expect(
      tester.widget<Tooltip>(find.byKey(const ValueKey('copy-to-b-tip'))).message,
      'Marque arquivos ou clique em "Selecionar todos os resultados".',
    );
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('copy-to-b'))).onPressed, isNull);
    // Os outros comandos têm dica.
    for (final key in ['add-a', 'add-moment-a', 'scope-filter-b', 'compare-swap']) {
      expect(
        find.ancestor(of: find.byKey(ValueKey(key)), matching: find.byType(Tooltip)),
        findsWidgets,
        reason: key,
      );
    }
    expect(find.text('Disco 1 › pasta1 › IMG_0002.jpg'), findsOneWidget);

    // Seleção: um item, depois todos os resultados.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('1 item · 2,0 KB'), findsOneWidget);
    await tester.tap(find.text('Selecionar todos os resultados'));
    await tester.pump();
    expect(find.text('2 itens · 2,3 KB'), findsOneWidget);
    expect(tester.widget<Tooltip>(find.byKey(const ValueKey('copy-to-b-tip'))).message, startsWith('Abre a prévia'));
  });

  testWidgets('resultado incompleto nunca diz 100% e oferece "Conferir agora"', (tester) async {
    final backend = backendWith(
      summary(
        verdict: CompareVerdict.incomplete,
        missing: const ContentTotals(1, 400, 1),
        issues: const [UnverifiedFiles(side: 'B', pending: 2, errors: 0, changed: 0, cloudOnly: 1)],
      ),
    );
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openCompare(tester);
    await addFolder(tester, 'a', 'Disco 1', 'pasta1');
    await addFolder(tester, 'b', 'Disco 2', 'pasta3');
    await tester.tap(find.byKey(const ValueKey('compare-run')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Resultado incompleto'), findsOneWidget);
    expect(find.textContaining('100%'), findsNothing);
    expect(find.textContaining('3 arquivos em B ainda sem conteúdo conferido (1 só na nuvem)'), findsOneWidget);
    expect(find.textContaining('faltam pelo menos 1 arquivo'), findsOneWidget);
    await tester.tap(find.text('Conferir agora'));
    await tester.pump();
    expect(backend.calls, contains('hash:s1:pasta1,s2:pasta3'));
  });

  testWidgets('tudo presente: "Sim, 100%"', (tester) async {
    final backend = backendWith(summary(verdict: CompareVerdict.complete, missing: ContentTotals.zero))
      ..compareLists = const {};
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openCompare(tester);
    await addFolder(tester, 'a', 'Disco 1', 'pasta1');
    await addFolder(tester, 'b', 'Disco 2', 'pasta3');
    await tester.tap(find.byKey(const ValueKey('compare-run')));
    await tester.pumpAndSettle();
    expect(find.text('Sim, 100%. B contém todo o conteúdo de A.'), findsOneWidget);
    expect(find.text('Nada falta em B.'), findsOneWidget);
  });

  testWidgets('salvar escopo com nome e reutilizar no outro lado; filtro por tipo', (tester) async {
    final backend = backendWith(summary());
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openCompare(tester);
    await addFolder(tester, 'a', 'Disco 1', 'pasta1');
    await addFolder(tester, 'a', 'Disco 1', 'pasta2');

    final menuA = find.descendant(
      of: find.byKey(const ValueKey('scope-a')),
      matching: find.byIcon(Icons.bookmarks_outlined),
    );
    await tester.tap(menuA);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar este escopo…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fotos do celular antigo');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('save-scope:Fotos do celular antigo'));
    expect(find.text('Fotos do celular antigo'), findsOneWidget, reason: 'o lado A passa a mostrar o nome');

    final menuB = find.descendant(
      of: find.byKey(const ValueKey('scope-b')),
      matching: find.byIcon(Icons.bookmarks_outlined),
    );
    await tester.tap(menuB);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar "Fotos do celular antigo"'));
    await tester.pumpAndSettle();
    expect(find.text('Disco 1 › pasta1'), findsNWidgets(2));

    // Filtro "Vídeos" no lado A.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('scope-a')), matching: find.text('Vídeos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compare-run')));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'compare:s1:pasta1+s1:pasta2|s1:pasta1+s1:pasta2|video');
  });

  testWidgets('Início mostra o painel de cobertura com cor, ícone e texto', (tester) async {
    final backend = FakeBackend([source('s1', 'Celular antigo')])
      ..coverage = CoverageReport(
        overall: const CoverageCounts(
          {BackupState.single: 3, BackupState.independent: 10},
          {BackupState.single: 3 * 1024 * 1024, BackupState.independent: 10 * 1024 * 1024},
        ),
        perSource: {
          's1': const SourceCoverage(
            sourceId: 's1',
            counts: CoverageCounts({BackupState.single: 3}, {BackupState.single: 3 * 1024 * 1024}),
            cloudOnly: 0,
            duplicateFiles: 0,
            duplicateBytes: 0,
          ),
        },
        pendingFiles: 0,
        computedAt: DateTime.utc(2026),
      );
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    expect(find.text('3 fotos e vídeos existem em um lugar só (3,0 MB).'), findsOneWidget);
    expect(find.text('3 arquivos sem backup (só em 1 lugar) (3,0 MB)'), findsOneWidget);
    expect(find.text('10 arquivos com backup em outro disco (10,0 MB)'), findsOneWidget);
    expect(find.text('3 arquivos sem backup (só em 1 lugar)'), findsOneWidget, reason: 'por dispositivo');
  });

  testWidgets('cópias em disco que não dá para identificar: Início e cartão avisam (R1)', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const counts = CoverageCounts({BackupState.verified: 3}, {BackupState.verified: 3000}, verifiedUncertainDisk: 3);
    final backend = FakeBackend([source('s1', 'Pixel')])
      ..coverage = CoverageReport(
        overall: counts,
        perSource: {
          's1': const SourceCoverage(
            sourceId: 's1',
            counts: counts,
            cloudOnly: 0,
            duplicateFiles: 0,
            duplicateBytes: 0,
          ),
        },
        pendingFiles: 0,
        computedAt: DateTime.utc(2026),
      );
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    expect(find.text('3 arquivos com cópia conferida (2,9 KB)'), findsOneWidget);
    expect(
      find.text(
        'Há outra cópia idêntica, mas não dá para confirmar que estão em discos diferentes: '
        'o Windows não identifica com certeza um dos discos (ex.: SSD interno).',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Dispositivos').first);
    await tester.pumpAndSettle();
    expect(find.text('Não dá para confirmar que estão em discos diferentes'), findsOneWidget);
  });

  test('dica dos discos incertos só quando há, e com a quantidade quando é parte', () {
    expect(
      verifiedHint(4, 0),
      'Tem cópia com conteúdo idêntico, mas no mesmo disco: se esse disco falhar, as duas se perdem.',
    );
    expect(verifiedHint(4, 1), contains('Em 1 arquivo, não dá para confirmar'));
    expect(uncertainDiskShort(4, 2), 'Não dá para confirmar que 2 delas estão em discos diferentes');
  });

  testWidgets('resumo deixa claro arquivos × conteúdos e caminhos usam um só separador', (tester) async {
    await tester.pumpWidget(harness(backendWith(summary())));
    await tester.pumpAndSettle();
    await openCompare(tester);
    await addFolder(tester, 'a', 'Disco 1', 'pasta1');
    await addFolder(tester, 'b', 'Disco 2', 'pasta3');
    await tester.tap(find.byKey(const ValueKey('compare-run')));
    await tester.pumpAndSettle();
    expect(find.text('A: 5 arquivos (4 conteúdos diferentes, 1 repetido) · 6,3 KB'), findsOneWidget);
    expect(find.text('B: 3 arquivos (3 conteúdos diferentes) · 8,8 KB'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing, reason: 'sem misturar › e /');
  });

  testWidgets('seletor: dica e "Adicionar dispositivo…" cadastra, pergunta o que escanear e não sai', (tester) async {
    final backend = backendWith(summary())
      ..fakeDrives = [
        (
          VolumeInfo(
            guidPath: r'\?\Volume{1}\',
            mountPoints: const [r'F:\'],
            label: 'HD_antigo',
            fileSystem: 'NTFS',
            serial: 9,
            totalBytes: 1 << 30,
            freeBytes: 1 << 29,
            driveType: 'fixed',
          ),
          null,
        ),
      ];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openCompare(tester);
    await tester.tap(find.byKey(const ValueKey('add-a')));
    await tester.pumpAndSettle();
    expect(find.text('Não encontrou? Ela precisa ser adicionada e escaneada primeiro.'), findsOneWidget);

    await tester.tap(find.text('Adicionar dispositivo…'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('HD_antigo (F:'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-whole')), findsOneWidget, reason: 'pergunta o que escanear');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pumpAndSettle();
    expect(backend.calls, containsAllInOrder([r'add:F:\', 'scan:novo']));
    backend.emitSources([
      source('s1', 'Disco 1'),
      source('s2', 'Disco 2'),
      SourceView(id: 'novo', name: 'HD_antigo', kind: 'external_hd', rootRelPath: '', state: SourceState.connected),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'continua no seletor');
    expect(find.text('ainda não escaneado'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('HD_antigo'), findsOneWidget, reason: 'a nova fonte já entra no escopo A');
  });
}
