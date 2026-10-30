import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/l10n/format.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'compare_widgets_test.dart' show source;
import 'copy_widgets_test.dart' show preview;
import 'device_flow_widgets_test.dart' show phone;
import 'support/fake_backend.dart';
import 'widgets_test.dart' show harness, openDevices;

IntegrityProblem problem({bool connected = true, List<OtherCopy>? copies}) => IntegrityProblem(
  instanceId: 7,
  sourceId: 's1',
  sourceName: 'HD principal',
  relPath: '2024/a.jpg',
  size: 4000,
  detectedAt: DateTime(2026, 10, 30, 9),
  connected: connected,
  expectedContentId: 3,
  otherCopies:
      copies ??
      const [
        OtherCopy(
          instanceId: 9,
          sourceId: 's2',
          sourceName: 'HD backup',
          sourceKind: 'external_hd',
          relPath: 'Backup/copia_a.jpg',
          connected: true,
          sameSource: false,
          samePhysicalDisk: false,
        ),
      ],
);

IntegrityRunView run(String status, {bool byUser = false, Map<String, int> counts = const {}, String? message}) =>
    IntegrityRunView(
      id: 1,
      scheduled: false,
      status: status,
      pausedByUser: byUser,
      label: 'HD principal',
      filesTotal: 4,
      bytesTotal: 16000,
      counts: counts,
      createdAt: DateTime(2026, 10, 30, 9),
      message: message,
    );

Future<void> openTasks(WidgetTester tester) async {
  await tester.tap(find.text('Tarefas').first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
  });

  testWidgets('Verificar integridade pelo cartão: diz que só lê, mostra quanto vai ler e começa', (tester) async {
    final backend = FakeBackend([source('s1', 'HD principal')]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.byKey(const ValueKey('more-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Verificar integridade…'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Só lê: nenhum arquivo é alterado, movido ou apagado'), findsOneWidget);
    expect(find.text('Vai ler 3 arquivos (2,9 KB).'), findsOneWidget);
    expect(find.byKey(const ValueKey('verify-phone-warning')), findsNothing);
    // Só o que passou do prazo.
    await tester.tap(find.textContaining('Só o que não é conferido há mais de 90 dias'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('estimate-verify:90'));
    expect(backend.calls.where((c) => c.startsWith('start-verify')), isEmpty, reason: 'nada antes de confirmar');
    await tester.tap(find.byKey(const ValueKey('verify-start')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('start-verify:s1:0:90'));
    expect(find.text('Verificação começou. Acompanhe em Tarefas.'), findsOneWidget);
  });

  testWidgets('celular: só a pedido, com aviso de leitura lenta', (tester) async {
    final backend = FakeBackend([phone(lastScan: completedScan(sourceId: 'p1'))]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.byKey(ValueKey('more-${phone().id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('lê o celular de novo, devagar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('verify-phone-warning')), findsOneWidget);
    expect(find.textContaining('O celular só é verificado quando você pede'), findsOneWidget);
  });

  testWidgets('nada para verificar: o botão fica desligado', (tester) async {
    final backend = FakeBackend([source('s1', 'HD principal')])..estimate = const VerifyEstimate(files: 0, bytes: 0);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.byKey(const ValueKey('more-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Verificar integridade…'));
    await tester.pumpAndSettle();
    expect(find.text('Nada para verificar agora.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('verify-start'))).onPressed, isNull);
  });

  testWidgets('Tarefas: possivelmente corrompido com a outra cópia e restauração com prévia', (tester) async {
    final backend = FakeBackend([source('s1', 'HD principal'), source('s2', 'HD backup')])
      ..problems = [problem()]
      ..verifyRuns = [
        run(RunStatus.completed, counts: const {CheckResult.unchanged: 3, CheckResult.possiblyCorrupt: 1}),
      ]
      ..onRestoreRequest = ((id, from) =>
          const CopyRequest(contentIds: [3], destSourceId: 's1', destFolder: '2024', template: '', origin: 'restore'))
      ..onPreview = ((r) => preview(r, items: 1, alreadyThere: 0));
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openTasks(tester);
    expect(find.text('Possivelmente corrompidos (1)'), findsOneWidget);
    expect(find.textContaining('nunca é substituído nem apagado'), findsOneWidget);
    expect(find.text('HD backup › Backup › copia_a.jpg'), findsOneWidget);
    expect(find.textContaining('Concluída — encontrou problemas'), findsOneWidget);
    expect(find.text('3 inalterados · 1 possivelmente corrompido'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('restore-7-9')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('restore-request:7:9'));
    expect(backend.calls, contains('preview:1:s1:2024:'));
    expect(find.byKey(const ValueKey('restore-target')), findsOneWidget);
    expect(find.textContaining('O arquivo danificado fica onde está'), findsOneWidget);
    expect(backend.calls.where((c) => c.startsWith('start-copy')), isEmpty, reason: 'nada antes de confirmar');
    await tester.tap(find.byKey(const ValueKey('restore-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('start-copy:1'));
  });

  testWidgets('sem outra cópia: explica e não oferece restaurar; "a mudança é esperada" pede confirmação', (
    tester,
  ) async {
    final backend = FakeBackend([source('s1', 'HD principal')])..problems = [problem(copies: const [])];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openTasks(tester);
    expect(find.byKey(const ValueKey('no-copies-7')), findsOneWidget);
    expect(find.textContaining('Restaurar desta cópia'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('accept-7')));
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c.startsWith('accept')), isEmpty);
    await tester.tap(find.byKey(const ValueKey('accept-confirm')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('accept:7'));
  });

  testWidgets('rodada em andamento: pausar; pausada: continuar; esperando mostra o motivo', (tester) async {
    final backend = FakeBackend([source('s1', 'HD principal')])
      ..verifyRuns = [
        run(RunStatus.running, counts: const {CheckResult.unchanged: 1}),
      ];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openTasks(tester);
    await tester.tap(find.byKey(const ValueKey('run-pause-1')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('pause-verify:1'));

    backend.emitRuns([run(RunStatus.paused, byUser: true)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run-resume-1')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('resume-verify:1'));

    backend.emitRuns([
      run(RunStatus.paused, message: 'Esperando outras tarefas terminarem (continua sozinha, devagar).'),
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Esperando ·'), findsOneWidget);
    expect(find.textContaining('continua sozinha'), findsOneWidget);
  });

  testWidgets('Início: aviso de corrompido e de disco sem verificação há tempo', (tester) async {
    final backend = FakeBackend([source('s1', 'HD principal')])
      ..problems = [problem()]
      ..overview = [
        SourceIntegrity(
          sourceId: 's1',
          sourceName: 'HD principal',
          kind: 'external_hd',
          files: 100,
          staleFiles: 40,
          possiblyCorrupt: 1,
          oldestConfirmedAt: DateTime.now().subtract(const Duration(days: 200)),
        ),
      ];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('alert-corrupt')), findsOneWidget);
    expect(find.textContaining('1 arquivo possivelmente corrompido'), findsOneWidget);
    expect(
      find.textContaining('"HD principal" nunca foi verificado (conferido pela última vez há 6 meses)'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('alert-verify-s1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verificar integridade — HD principal'), findsOneWidget);
  });

  testWidgets('Configurações: verificação periódica ligada por padrão, intervalo e desligar', (tester) async {
    final backend = FakeBackend([source('s1', 'HD principal')]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    expect(find.text('Verificação periódica'), findsOneWidget);
    expect(find.textContaining('Celulares nunca são verificados sozinhos'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('schedule-enabled'))).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('schedule-days')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('180 dias').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('schedule:true:180'));
    await tester.tap(find.byKey(const ValueKey('schedule-enabled')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('schedule:false:180'));
  });

  test('há quanto tempo, em palavras', () {
    final now = DateTime(2026, 10, 30);
    expect(formatAgo(now, now: now), 'hoje');
    expect(formatAgo(DateTime(2026, 10, 29), now: now), 'ontem');
    expect(formatAgo(DateTime(2026, 10, 10), now: now), 'há 20 dias');
    expect(formatAgo(DateTime(2026, 4, 30), now: now), 'há 6 meses');
    expect(formatAgo(DateTime(2023, 10, 30), now: now), 'há 3 anos');
  });
}
