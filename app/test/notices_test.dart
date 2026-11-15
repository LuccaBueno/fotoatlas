import 'dart:async';
import 'dart:io';

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

final _installable = ReleaseInfo(
  version: const AppVersion(1, 2, 0),
  pageUrl: Uri.parse('$releasesPage/tag/v1.2.0'),
  installerUrl: releaseAssetUrl(const AppVersion(1, 2, 0), 'FotoAtlas-1.2.0-instalador.exe'),
  checksumUrl: releaseAssetUrl(const AppVersion(1, 2, 0), 'FotoAtlas-1.2.0-instalador.exe.sha256'),
);

Widget _shell(
  FakeBackend backend, {
  String version = '1.1.0',
  List<Uri>? opened,
  List<DownloadedInstaller>? launched,
  bool launchResult = true,
}) => ProviderScope(
  overrides: [
    backendProvider.overrideWithValue(backend),
    currentVersionProvider.overrideWithValue(version),
    releasePageOpenerProvider.overrideWithValue((uri) async => opened?.add(uri)),
    updateInstallerLauncherProvider.overrideWithValue((installer) async {
      launched?.add(installer);
      return launchResult;
    }),
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

    testWidgets('sem o arquivo de conferência na release: só "Baixar"', (tester) async {
      await tester.pumpWidget(_shell(FakeBackend()..latestRelease = _release));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('update-install')), findsNothing);
      expect(find.byKey(const ValueKey('update-download')), findsOneWidget);
    });

    testWidgets('ao abrir, apaga instaladores baixados antes', (tester) async {
      final backend = FakeBackend();
      await tester.pumpWidget(_shell(backend));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('update-cleanup'));
    });

    testWidgets('"Atualizar agora": baixa com progresso, pergunta (com as tarefas) e só então entrega ao instalador', (
      tester,
    ) async {
      final progress = Completer<void>();
      final backend = FakeBackend()
        ..latestRelease = _installable
        ..running = const [RunningTask(RunningTaskKind.copy, done: 3, total: 10)]
        ..downloadImpl = (release, onProgress, cancel) async {
          onProgress?.call(0, 4 * 1024 * 1024);
          onProgress?.call(1024 * 1024, 4 * 1024 * 1024);
          await progress.future;
          onProgress?.call(4 * 1024 * 1024, 4 * 1024 * 1024);
          return DownloadedInstaller(
            file: File('FotoAtlas-1.2.0-instalador.exe'),
            version: release.version,
            sha256: 'ab' * 32,
          );
        };
      final launched = <DownloadedInstaller>[];
      await tester.pumpWidget(_shell(backend, launched: launched));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-install')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update-install')));
      await tester.pump();
      expect(find.byKey(const ValueKey('update-downloading')), findsOneWidget);
      expect(find.text('Baixando a versão 1.2.0'), findsOneWidget);
      expect(find.text('1,0 MB de 4,0 MB'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('update-progress'))).value, 0.25);
      expect(find.byKey(const ValueKey('update-cancel')), findsOneWidget);
      expect(launched, isEmpty);

      progress.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-downloading')), findsNothing);
      expect(find.byKey(const ValueKey('update-confirm')), findsOneWidget);
      expect(find.text('Instalar a versão 1.2.0 agora?'), findsOneWidget);
      expect(find.textContaining('O catálogo e as configurações não são tocados'), findsOneWidget);
      expect(find.text('Copiando com conferência — 3 de 10 arquivos'), findsOneWidget);
      expect(find.textContaining('pausadas com segurança'), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byKey(const ValueKey('update-later'))).autofocus,
        isTrue,
        reason: '"Agora não" é o padrão',
      );
      expect(launched, isEmpty, reason: 'nada é instalado sem confirmar');

      await tester.tap(find.byKey(const ValueKey('update-close-and-install')));
      await tester.pumpAndSettle();
      expect(launched.single.version, const AppVersion(1, 2, 0));
      expect(launched.single.sha256, 'ab' * 32);
    });

    testWidgets('"Agora não" na pergunta: nada é instalado nem fechado', (tester) async {
      final backend = FakeBackend()..latestRelease = _installable;
      final launched = <DownloadedInstaller>[];
      await tester.pumpWidget(_shell(backend, launched: launched));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-install')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-confirm')), findsOneWidget);
      expect(find.textContaining('Há tarefas em andamento'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('update-later')));
      await tester.pumpAndSettle();
      expect(launched, isEmpty);
      expect(find.byKey(const ValueKey('update-banner')), findsOneWidget, reason: 'dá para atualizar depois');
    });

    for (final (failure, text) in [
      (UpdateDownloadFailure.hashMismatch, 'não é idêntico ao publicado'),
      (UpdateDownloadFailure.interrupted, 'interrompido antes de terminar'),
      (UpdateDownloadFailure.network, 'sem internet'),
      (UpdateDownloadFailure.checksumMissing, 'sem o arquivo de conferência'),
      (UpdateDownloadFailure.disk, 'disco cheio'),
    ]) {
      testWidgets('falha no download (${failure.name}): avisa e não mexe em nada', (tester) async {
        final backend = FakeBackend()
          ..latestRelease = _installable
          ..downloadImpl = (release, onProgress, cancel) async {
            onProgress?.call(10, 100);
            throw UpdateDownloadException(failure);
          };
        final launched = <DownloadedInstaller>[];
        await tester.pumpWidget(_shell(backend, launched: launched));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('update-install')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('update-failed')), findsOneWidget);
        expect(find.textContaining(text), findsOneWidget);
        expect(find.textContaining('Nada foi alterado'), findsOneWidget);
        expect(find.textContaining('catálogo e as configurações como estavam'), findsOneWidget);
        expect(find.textContaining('hash'), findsNothing, reason: 'sem jargão na tela');
        expect(find.byKey(const ValueKey('update-confirm')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('update-failed-close')));
        await tester.pumpAndSettle();
        expect(launched, isEmpty);
        expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
      });
    }

    testWidgets('"Cancelar" para o download, fecha a janela e não instala nada', (tester) async {
      UpdateCancelToken? token;
      final backend = FakeBackend()
        ..latestRelease = _installable
        ..downloadImpl = (release, onProgress, cancel) async {
          token = cancel;
          onProgress?.call(10, 100);
          await cancel!.whenCancelled;
          throw const UpdateDownloadException(UpdateDownloadFailure.cancelled);
        };
      final launched = <DownloadedInstaller>[];
      await tester.pumpWidget(_shell(backend, launched: launched));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-install')));
      await tester.pump();
      expect(find.byKey(const ValueKey('update-downloading')), findsOneWidget);
      expect(token!.isCancelled, isFalse);

      await tester.tap(find.byKey(const ValueKey('update-cancel')));
      await tester.pumpAndSettle();
      expect(token!.isCancelled, isTrue);
      expect(find.byKey(const ValueKey('update-downloading')), findsNothing);
      expect(find.byKey(const ValueKey('update-failed')), findsNothing, reason: 'cancelar não é erro');
      expect(find.byKey(const ValueKey('update-confirm')), findsNothing);
      expect(launched, isEmpty);
    });

    testWidgets('instalador não iniciou: avisa e o app continua', (tester) async {
      final backend = FakeBackend()..latestRelease = _installable;
      await tester.pumpWidget(_shell(backend, launchResult: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-install')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-close-and-install')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-start-failed')), findsOneWidget);
      expect(find.textContaining('Nada foi alterado'), findsOneWidget);
    });

    testWidgets('Configurações: "Procurar atualização agora" diz o resultado e mostra o aviso', (tester) async {
      final backend = FakeBackend()..updateEnabled = false;
      final launched = <DownloadedInstaller>[];
      await tester.pumpWidget(_shell(backend, launched: launched));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurações').first);
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('update-check-now'));
      Future<String> check(UpdateCheckResult result) async {
        backend.checkNowResult = result;
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        return tester.widget<Text>(find.byKey(const ValueKey('update-check-result'))).data!;
      }

      expect(await check(const UpToDate(AppVersion(1, 1, 0))), 'Você já tem a versão mais nova (1.1.0).');
      expect(await check(const UpdateCheckFailed()), contains('Não foi possível consultar agora'));
      expect(await check(const UpdateCheckUnavailable()), contains('Versão de desenvolvimento'));
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
      expect(
        backend.calls,
        contains('update-check-now:1.1.0'),
        reason: 'procura mesmo com a consulta ao abrir desligada',
      );

      expect(await check(UpdateAvailable(_installable)), 'Versão 1.2.0 disponível.');
      expect(find.byKey(const ValueKey('update-banner')), findsOneWidget, reason: 'o aviso aparece no topo');
      await tester.ensureVisible(find.byKey(const ValueKey('update-check-install')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-check-install')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-close-and-install')));
      await tester.pumpAndSettle();
      expect(launched.single.version, const AppVersion(1, 2, 0));
    });

    testWidgets('num pré-lançamento, "Procurar agora" explica que só versões estáveis são oferecidas', (tester) async {
      final backend = FakeBackend()..checkNowResult = const UpToDate(AppVersion(1, 2, 1));
      await tester.pumpWidget(_shell(backend, version: '1.3.0-beta.2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurações').first);
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('update-check-now'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.byKey(const ValueKey('update-check-result'))).data!;
      expect(text, contains('pré-lançamento (1.3.0-beta.2)'));
      expect(text, contains('Só versões estáveis são oferecidas'));
      expect(text, contains('1.2.1'));
      expect(backend.calls, contains('update-check-now:1.3.0-beta.2'));
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    });

    test('mensagem de "já está na mais nova": estável × pré-lançamento', () {
      expect(upToDateMessage('1.2.1', const AppVersion(1, 2, 1)), 'Você já tem a versão mais nova (1.2.1).');
      expect(
        upToDateMessage('1.3.0-beta.1', const AppVersion(1, 2, 1)),
        startsWith('Você está usando um pré-lançamento'),
      );
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
