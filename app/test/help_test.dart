import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas/features/library/library_strings.dart';
import 'package:fotoatlas/l10n/strings.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'support/fake_backend.dart';

Widget _app(FakeBackend backend, {bool guide = false}) => ProviderScope(
  overrides: [backendProvider.overrideWithValue(backend)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: AppShell(firstRunGuide: guide),
  ),
);

MomentView _moment(DateTime start, DateTime end, {String? name, int items = 3}) => MomentView(
  id: 1,
  edited: name != null,
  name: name,
  startUtcMs: 0,
  endUtcMs: 0,
  itemCount: items,
  startLocal: start,
  endLocal: end,
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
  });

  testWidgets('primeira execução: guia de 4 passos, pula ou termina em Dispositivos, e não volta sozinho', (
    tester,
  ) async {
    final backend = FakeBackend()..guideDone = false;
    await tester.pumpWidget(_app(backend, guide: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-guide')), findsOneWidget);
    expect(find.text('1. Adicione um dispositivo'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('guide-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('4. Compare'), findsOneWidget);
    await tester.tap(find.text('Começar: adicionar dispositivo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-guide')), findsNothing);
    expect(backend.calls, contains('guide-done'));
    expect(find.text('Adicionar dispositivo'), findsWidgets, reason: 'abriu Dispositivos');

    // Já visto: ao abrir de novo, não aparece.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(backend, guide: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-guide')), findsNothing);
  });

  testWidgets('"?" explica a tela, mostra as cores e reabre o guia', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(_app(backend));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ajuda: Início'), findsOneWidget);
    expect(find.text('Sem backup (só em 1 lugar)'), findsOneWidget);
    expect(find.text('Backup em outro disco'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reopen-guide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-guide')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guide-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-guide')), findsNothing);

    // Outra tela, outra ajuda.
    await tester.tap(find.text('Dispositivos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ajuda: Dispositivos'), findsOneWidget);
  });

  test('momento sem nome tem nome descritivo; 1 instante mostra só uma hora', () {
    final sabado = DateTime.utc(2024, 5, 4, 9);
    expect(momentAutoName(_moment(sabado, sabado)), 'Sábado de manhã');
    expect(momentTimeRange(_moment(sabado, sabado)), '09:00');
    expect(momentSubtitle(_moment(sabado, sabado, items: 1)), '1 item · 09:00');
    expect(momentAutoName(_moment(sabado, DateTime.utc(2024, 5, 4, 15))), 'Sábado, da manhã à tarde');
    expect(
      momentAutoName(_moment(DateTime.utc(2024, 5, 4, 21), DateTime.utc(2024, 5, 5, 1))),
      'Sábado à noite até domingo',
    );
    expect(momentTitle(_moment(sabado, sabado)), 'Sábado de manhã · 4 de maio de 2024');
    expect(momentTitle(_moment(sabado, sabado, name: 'Aniversário')), 'Aniversário');
  });

  test('dica de backup diz onde o arquivo está', () {
    expect(
      backupStateItemHint(BackupState.single, ['Pixel de Teste']),
      'Sem backup: este arquivo só existe em "Pixel de Teste".',
    );
    expect(backupStateItemHint(BackupState.independent, ['Pixel', 'HD']), 'Backup em outro disco: está em Pixel e HD.');
    expect(backupStateLabel(BackupState.single), 'Sem backup (só em 1 lugar)');
    expect(backupStateLabel(BackupState.verified), 'Tem cópia conferida');
    expect(backupStateLabel(BackupState.independent), 'Backup em outro disco');
  });
}
