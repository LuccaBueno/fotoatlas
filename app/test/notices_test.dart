import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas/features/update/update_notice.dart';
import 'package:fotoatlas/widgets/task_notice.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'support/fake_backend.dart';

/// Tela mínima com um botão que mostra o aviso de tarefa (e o destino atual).
Widget _noticeHarness() => ProviderScope(
  child: MaterialApp(
    home: Consumer(
      builder: (context, ref, _) => Scaffold(
        body: Column(
          children: [
            Text('destino ${ref.watch(navigationIndexProvider)}'),
            ElevatedButton(
              onPressed: () => showTaskStartedNotice(
                ScaffoldMessenger.of(context),
                ref,
                'Cópia iniciada. Acompanhe em Tarefas.',
                key: const ValueKey('copy-started'),
              ),
              child: const Text('copiar'),
            ),
          ],
        ),
      ),
    ),
  ),
);

final _release = ReleaseInfo(version: const AppVersion(1, 2, 0), pageUrl: Uri.parse('$releasesPage/tag/v1.2.0'));

Widget _shell(FakeBackend backend, {String version = '1.1.0', List<Uri>? opened}) => ProviderScope(
  overrides: [
    backendProvider.overrideWithValue(backend),
    currentVersionProvider.overrideWithValue(version),
    releasePageOpenerProvider.overrideWithValue((uri) async => opened?.add(uri)),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
  });

  group('aviso "Acompanhe em Tarefas"', () {
    testWidgets('some sozinho depois de alguns segundos', (tester) async {
      await tester.pumpWidget(_noticeHarness());
      await tester.tap(find.text('copiar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('copy-started')), findsOneWidget);
      expect(find.text('Ver em Tarefas'), findsOneWidget);

      await tester.pump(taskNoticeDuration - const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('copy-started')), findsOneWidget, reason: 'dá tempo de ler');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('copy-started')), findsNothing);
    });

    testWidgets('"Ver em Tarefas" fecha o aviso e vai para Tarefas', (tester) async {
      await tester.pumpWidget(_noticeHarness());
      await tester.tap(find.text('copiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver em Tarefas'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('copy-started')), findsNothing);
      expect(find.text('destino $tasksDestination'), findsOneWidget);
    });
  });

  group('versão nova', () {
    testWidgets('aviso discreto com "Baixar" (abre a página) e "Agora não"', (tester) async {
      final backend = FakeBackend()..latestRelease = _release;
      final opened = <Uri>[];
      await tester.pumpWidget(_shell(backend, opened: opened));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('update-check:1.1.0'));
      expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
      expect(find.textContaining('Versão 1.2.0 do FotoAtlas disponível'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update-download')));
      await tester.pump();
      expect(opened, [Uri.parse('$releasesPage/tag/v1.2.0')]);
      expect(backend.calls.where((c) => c.startsWith('update-check')), hasLength(1), reason: 'consulta uma vez só');

      await tester.tap(find.byKey(const ValueKey('update-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
      // Trocar de tela não traz o aviso de volta nem consulta de novo.
      await tester.tap(find.text('Tarefas').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
      expect(backend.calls.where((c) => c.startsWith('update-check')), hasLength(1));
    });

    testWidgets('sem versão nova (ou sem internet): nenhum aviso', (tester) async {
      await tester.pumpWidget(_shell(FakeBackend()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    });

    testWidgets('Configurações: explica, ligado por padrão e desliga', (tester) async {
      final backend = FakeBackend();
      await tester.pumpWidget(_shell(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurações').first);
      await tester.pumpAndSettle();
      expect(find.text('Atualizações'), findsOneWidget);
      expect(find.textContaining('Nenhuma informação sua é enviada'), findsOneWidget);
      expect(find.textContaining('nunca baixa nem instala nada sozinho'), findsOneWidget);
      final toggle = find.byKey(const ValueKey('update-enabled'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(backend.calls, contains('update-enabled:false'));
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    });
  });
}
