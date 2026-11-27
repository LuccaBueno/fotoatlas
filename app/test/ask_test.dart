import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/ask.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/shell.dart';
import 'package:fotoatlas/app/theme.dart';

import 'support/fake_backend.dart';

Widget _app(FakeBackend backend) => ProviderScope(
  overrides: [backendProvider.overrideWithValue(backend)],
  child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
);

void main() {
  test('as perguntas de exemplo têm a resposta certa em primeiro lugar', () {
    for (final (q, id) in [
      ('como faço backup do celular?', 'backup-celular'),
      ('o app apaga alguma coisa?', 'apaga'),
      ('o que é cópia conferida?', 'copia-conferida'),
      ('por que meu resultado está incompleto?', 'incompleto'),
      ('como desfazer uma reorganização?', 'desfazer-reorg'),
      ('quero liberar espaço com fotos duplicadas', 'repetidos'),
      ('manda minhas fotos pra internet?', 'internet'),
      ('Google Fotos', 'google'),
    ]) {
      expect(searchAnswers(q).first.id, id, reason: q);
    }
    expect(searchAnswers('   '), isEmpty);
    expect(searchAnswers('xyzw qwerty'), isEmpty);
    expect(normalizeAsk('Cópia CONFERIDA, ação'), 'copia conferida, acao');
    // Cada resposta tem uma ação e ids únicos.
    expect(askAnswers.map((a) => a.id).toSet(), hasLength(askAnswers.length));
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
  });

  testWidgets('"?" de cada tela: Pergunte ao FotoAtlas responde e leva à tela certa; página do que nunca faz', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeBackend()));
    await tester.pumpAndSettle();
    Future<void> ask(String q) async {
      await tester.tap(find.byKey(const ValueKey('help-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ask-field')), q);
      await tester.pumpAndSettle();
    }

    // "Como desfazer uma reorganização?" → Tarefas.
    await ask('como desfazer uma reorganização?');
    expect(find.text('Como desfazer uma reorganização?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ask-go-desfazer-reorg')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('help-dialog')), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(navigationIndexProvider), tasksDestination);

    // Sem resposta: diz e sugere palavras.
    await ask('xyzw');
    expect(find.byKey(const ValueKey('ask-none')), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    // "O app apaga alguma coisa?" → a página do que o FotoAtlas nunca faz.
    await ask('o app apaga alguma coisa?');
    await tester.tap(find.byKey(const ValueKey('ask-go-apaga')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('promises')), findsOneWidget);
    expect(find.text('Nunca apaga nada sozinho, e nunca apaga nada do celular.'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // A mesma página pelo botão do "?".
    await tester.tap(find.byKey(const ValueKey('help-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-promises')));
    await tester.pumpAndSettle();
    expect(find.text('O que o FotoAtlas faz (e o que nunca faz)'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // "Como faço backup do celular?" → o assistente.
    await ask('como faço backup do celular?');
    await tester.tap(find.byKey(const ValueKey('ask-go-backup-celular')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-backup')), findsOneWidget);
    expect(find.text('Passo 1 de 6: Escolher o celular e o HD'), findsOneWidget);
  });
}
