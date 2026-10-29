import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/close_confirm_dialog.dart';
import 'package:fotoatlas/app/demo_mode.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

void main() {
  test('FOTOATLAS_DEMO define o modo de demonstração', () {
    expect(DemoMode.fromEnvironment(const {}), DemoMode.off);
    expect(DemoMode.fromEnvironment(const {'FOTOATLAS_DEMO': 'descartavel'}), DemoMode.discarded);
    expect(DemoMode.fromEnvironment(const {'FOTOATLAS_DEMO': 'persistente'}), DemoMode.persistent);
    expect(DemoMode.fromEnvironment(const {'FOTOATLAS_DEMO': 'outra coisa'}), DemoMode.off);
  });

  Future<void> showDialogFor(WidgetTester tester, DemoMode mode) => tester.pumpWidget(
    MaterialApp(
      home: CloseConfirmDialog(tasks: const [RunningTask(RunningTaskKind.hash, done: 3, total: 10)], demoMode: mode),
    ),
  );

  testWidgets('pergunta ao fechar em demonstração descartável não promete continuar', (tester) async {
    await showDialogFor(tester, DemoMode.discarded);
    expect(find.textContaining('nada será mantido'), findsOneWidget);
    expect(find.textContaining('de onde pararam'), findsNothing);
  });

  testWidgets('pergunta ao fechar com catálogo mantido promete continuar', (tester) async {
    for (final mode in [DemoMode.off, DemoMode.persistent]) {
      await showDialogFor(tester, mode);
      expect(find.textContaining('continuam de onde pararam'), findsOneWidget, reason: '$mode');
      expect(find.textContaining('nada será mantido'), findsNothing, reason: '$mode');
    }
  });

  testWidgets('faixa da demonstração diz se tudo é descartado ou mantido', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoBanner(mode: DemoMode.discarded)));
    expect(find.text('Modo demonstração — tudo será descartado ao fechar'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: DemoBanner(mode: DemoMode.persistent)));
    expect(find.textContaining('mantidos entre aberturas'), findsOneWidget);
  });
}
