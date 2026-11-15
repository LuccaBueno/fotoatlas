import 'dart:convert';
import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

String _release(String tag, {String? html, bool prerelease = false}) =>
    jsonEncode({'tag_name': tag, 'html_url': ?html, 'draft': false, 'prerelease': prerelease});

void main() {
  group('AppVersion', () {
    test('lê com e sem "v", guarda o pré-lançamento e ignora o build', () {
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.10.0+5'), const AppVersion(1, 10, 0));
      expect(AppVersion.tryParse('2.0.0-beta'), const AppVersion(2, 0, 0, 'beta'));
      expect(AppVersion.tryParse('v1.3.0-beta.1+0'), const AppVersion(1, 3, 0, 'beta.1'));
      expect(AppVersion.tryParse('1.3.0-beta.1')!.isPreRelease, isTrue);
      expect(AppVersion.tryParse('1.3.0')!.isPreRelease, isFalse);
      expect(AppVersion.tryParse('1.3.0-beta.1').toString(), '1.3.0-beta.1');
      expect(AppVersion.tryParse('1.3.0-'), isNull);
      expect(AppVersion.tryParse('1.3.0-beta..1'), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('1.2'), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
    });

    test('compara número a número (1.10 > 1.9)', () {
      expect(const AppVersion(1, 10, 0) > const AppVersion(1, 9, 9), isTrue);
      expect(const AppVersion(2, 0, 0) > const AppVersion(1, 99, 99), isTrue);
      expect(const AppVersion(1, 0, 1) > const AppVersion(1, 0, 0), isTrue);
      expect(const AppVersion(1, 0, 0) > const AppVersion(1, 0, 0), isFalse);
    });

    test('pré-lançamento vem antes da estável da mesma versão e depois da anterior', () {
      final ordem = [
        '1.2.1',
        '1.3.0-alpha',
        '1.3.0-beta',
        '1.3.0-beta.1',
        '1.3.0-beta.2',
        '1.3.0-beta.10',
        '1.3.0-rc.1',
        '1.3.0',
        '1.3.1-beta.1',
      ].map((t) => AppVersion.tryParse(t)!).toList();
      for (var i = 0; i < ordem.length; i++) {
        for (var j = 0; j < ordem.length; j++) {
          expect(ordem[i].compareTo(ordem[j]).sign, (i - j).sign, reason: ' × ');
        }
      }
      expect(AppVersion.tryParse('1.3.0-beta.1+7'), AppVersion.tryParse('1.3.0-beta.1'));
    });
  });

  group('parseLatestRelease', () {
    test('usa a página da release do repositório oficial', () {
      final r = parseLatestRelease(
        _release('v1.1.0', html: 'https://github.com/LuccaBueno/fotoatlas/releases/tag/v1.1.0'),
      )!;
      expect(r.version, const AppVersion(1, 1, 0));
      expect(r.pageUrl.toString(), 'https://github.com/LuccaBueno/fotoatlas/releases/tag/v1.1.0');
    });

    test('endereço de fora do repositório oficial é trocado pelo montado', () {
      for (final html in ['https://exemplo.invalid/x', 'http://github.com/LuccaBueno/fotoatlas/releases/tag/v1.1.0']) {
        final r = parseLatestRelease(_release('v1.1.0', html: html))!;
        expect(r.pageUrl.toString(), 'https://github.com/LuccaBueno/fotoatlas/releases/tag/v1.1.0');
      }
    });

    test('com o instalador e o .sha256 na release: endereços montados no repositório oficial', () {
      final json = jsonEncode({
        'tag_name': 'v1.2.0',
        'assets': [
          {'name': 'FotoAtlas-1.2.0-instalador.exe', 'browser_download_url': 'https://exemplo.invalid/mal.exe'},
          {'name': 'FotoAtlas-1.2.0-instalador.exe.sha256', 'browser_download_url': 'https://exemplo.invalid/x'},
        ],
      });
      final r = parseLatestRelease(json)!;
      expect(r.canInstall, isTrue);
      expect(
        r.installerUrl.toString(),
        'https://github.com/LuccaBueno/fotoatlas/releases/download/v1.2.0/FotoAtlas-1.2.0-instalador.exe',
      );
      expect(
        r.checksumUrl.toString(),
        'https://github.com/LuccaBueno/fotoatlas/releases/download/v1.2.0/FotoAtlas-1.2.0-instalador.exe.sha256',
      );
    });

    test('sem o .sha256 (ou sem o instalador): só "Baixar"', () {
      for (final names in [
        ['FotoAtlas-1.2.0-instalador.exe'],
        ['FotoAtlas-1.2.0-instalador.exe.sha256'],
        ['FotoAtlas-1.1.0-instalador.exe', 'FotoAtlas-1.1.0-instalador.exe.sha256'],
      ]) {
        final json = jsonEncode({
          'tag_name': 'v1.2.0',
          'assets': [
            for (final n in names) {'name': n},
          ],
        });
        final r = parseLatestRelease(json)!;
        expect(r.canInstall, isFalse, reason: '$names');
        expect(r.installerUrl, isNull);
      }
      expect(parseLatestRelease(_release('v1.2.0'))!.canInstall, isFalse);
    });

    test('resposta estranha, pré-lançamento ou sem versão: nada', () {
      expect(parseLatestRelease('não é json'), isNull);
      expect(parseLatestRelease('[]'), isNull);
      expect(parseLatestRelease(_release('nightly')), isNull);
      expect(parseLatestRelease(_release('v9.0.0', prerelease: true)), isNull);
      // Tag com sufixo, mesmo sem a marca de pré-lançamento: também não.
      expect(parseLatestRelease(_release('v9.0.0-beta.1')), isNull);
      expect(parseLatestRelease(jsonEncode({'tag_name': 'v9.0.0', 'draft': true})), isNull);
    });
  });

  group('fetchLatestRelease', () {
    Future<HttpServer> serve(void Function(HttpRequest) handler) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen(handler);
      return server;
    }

    Uri at(HttpServer s) => Uri.parse('http://${s.address.address}:${s.port}/latest');

    test('pergunta só pela última versão estável (releases/latest) e descarta pré-lançamento', () async {
      expect(latestReleaseApi.toString(), 'https://api.github.com/repos/LuccaBueno/fotoatlas/releases/latest');
      final server = await serve((r) {
        r.response
          ..write(_release('v9.0.0-beta.1', prerelease: true))
          ..close();
      });
      expect(await fetchLatestRelease(uri: at(server)), isNull);
    });

    test('só pede (sem corpo, sem dados) e lê a resposta', () async {
      HttpHeaders? headers;
      String? method;
      var body = '';
      final server = await serve((req) async {
        headers = req.headers;
        method = req.method;
        body = await utf8.decoder.bind(req).join();
        req.response
          ..headers.contentType = ContentType.json
          ..write(_release('v1.1.0'));
        await req.response.close();
      });
      final r = await fetchLatestRelease(uri: at(server));
      expect(r?.version, const AppVersion(1, 1, 0));
      expect(method, 'GET');
      expect(body, isEmpty);
      expect(headers!.value(HttpHeaders.userAgentHeader), 'FotoAtlas');
      expect(headers!.value(HttpHeaders.cookieHeader), isNull);
    });

    test('erro do servidor, demora ou sem conexão: null, em silêncio', () async {
      final failing = await serve((req) async {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
      });
      expect(await fetchLatestRelease(uri: at(failing)), isNull);

      final slow = await serve((_) {}); // nunca responde
      expect(await fetchLatestRelease(uri: at(slow), timeout: const Duration(milliseconds: 200)), isNull);

      final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = at(closed);
      await closed.close(force: true);
      expect(await fetchLatestRelease(uri: uri, timeout: const Duration(seconds: 2)), isNull);
    });
  });

  group('UpdateChecker', () {
    const day = 24 * 60 * 60 * 1000;
    final newer = ReleaseInfo(version: const AppVersion(1, 1, 0), pageUrl: Uri.parse('$releasesPage/tag/v1.1.0'));

    test('consulta no máximo uma vez por dia e só avisa de versão mais nova', () async {
      final env = await TestEnv.open();
      var now = 10 * day;
      var calls = 0;
      ReleaseInfo? answer = newer;
      final checker = UpdateChecker(
        SettingsStore(env.db),
        fetch: () async {
          calls++;
          return answer;
        },
        now: () => now,
      );

      expect((await checker.checkIfDue('1.0.0'))?.version, const AppVersion(1, 1, 0));
      expect(calls, 1);
      now += day - 1;
      expect(await checker.checkIfDue('1.0.0'), isNull, reason: 'menos de um dia: nem consulta');
      expect(calls, 1);
      now += 1;
      expect(await checker.checkIfDue('1.1.0'), isNull, reason: 'já está na mais nova');
      expect(calls, 2);
      now += day;
      answer = null; // sem internet
      expect(await checker.checkIfDue('1.0.0'), isNull);
      expect(calls, 3);
      expect(await checker.checkIfDue('1.0.0'), isNull, reason: 'a tentativa sem internet também conta');
      expect(calls, 3);
    });

    test('desligado ou sem versão (desenvolvimento): nunca consulta', () async {
      final env = await TestEnv.open();
      var calls = 0;
      final checker = UpdateChecker(
        SettingsStore(env.db),
        fetch: () async {
          calls++;
          return newer;
        },
      );
      expect(await checker.isEnabled(), isTrue, reason: 'ligado por padrão');
      expect(await checker.checkIfDue(''), isNull);
      await checker.setEnabled(false);
      expect(await checker.isEnabled(), isFalse);
      expect(await checker.checkIfDue('1.0.0'), isNull);
      expect(calls, 0);
    });

    test('"Procurar agora": consulta mesmo desligado e diz o resultado', () async {
      final env = await TestEnv.open();
      var calls = 0;
      Object? answer = newer;
      final checker = UpdateChecker(
        SettingsStore(env.db),
        fetch: () async {
          calls++;
          if (answer is Exception) throw answer;
          return answer as ReleaseInfo?;
        },
        now: () => 5 * day,
      );
      await checker.setEnabled(false);
      expect(await checker.checkNow(''), isA<UpdateCheckUnavailable>());
      expect(calls, 0, reason: 'versão de desenvolvimento não consulta');

      final available = await checker.checkNow('1.0.0');
      expect(available, isA<UpdateAvailable>());
      expect((available as UpdateAvailable).release.version, const AppVersion(1, 1, 0));
      final upToDate = await checker.checkNow('1.1.0');
      expect((upToDate as UpToDate).latest, const AppVersion(1, 1, 0));
      answer = null;
      expect(await checker.checkNow('1.0.0'), isA<UpdateCheckFailed>());
      answer = const SocketException('sem rede');
      expect(await checker.checkNow('1.0.0'), isA<UpdateCheckFailed>());
      expect(calls, 4);
      expect(await checker.isEnabled(), isFalse, reason: 'não religa a consulta ao abrir');
      expect(await SettingsStore(env.db).get(UpdateSettingKeys.lastCheckMs), 5 * day);
    });

    test('só versões estáveis: pré-lançamento nunca é oferecido, nem no aviso nem no "Procurar agora"', () async {
      final env = await TestEnv.open();
      final stable = ReleaseInfo(version: const AppVersion(1, 3, 0), pageUrl: Uri.parse('$releasesPage/tag/v1.3.0'));
      final old = ReleaseInfo(version: const AppVersion(1, 2, 1), pageUrl: Uri.parse('$releasesPage/tag/v1.2.1'));
      final beta = ReleaseInfo(
        version: const AppVersion(1, 4, 0, 'beta.1'),
        pageUrl: Uri.parse('$releasesPage/tag/v1.4.0-beta.1'),
      );
      var now = 10 * day;
      ReleaseInfo? answer = beta;
      final checker = UpdateChecker(SettingsStore(env.db), fetch: () async => answer, now: () => now);

      // Mesmo que a consulta devolvesse um pré-lançamento, ele é ignorado.
      expect(await checker.checkIfDue('1.2.1'), isNull);
      expect(await checker.checkNow('1.2.1'), isA<UpdateCheckFailed>());

      // Quem usa um pré-lançamento recebe a estável da mesma versão…
      answer = stable;
      now += day;
      expect((await checker.checkIfDue('1.3.0-beta.2'))?.version, const AppVersion(1, 3, 0));
      expect(await checker.checkNow('1.3.0-beta.2'), isA<UpdateAvailable>());
      // …mas nunca uma estável mais velha que ele.
      answer = old;
      now += day;
      expect(await checker.checkIfDue('1.3.0-beta.2'), isNull);
      expect((await checker.checkNow('1.3.0-beta.2') as UpToDate).latest, const AppVersion(1, 2, 1));
    });

    test('falha na consulta não escapa', () async {
      final env = await TestEnv.open();
      final checker = UpdateChecker(SettingsStore(env.db), fetch: () async => throw const SocketException('sem rede'));
      expect(await checker.checkIfDue('1.0.0'), isNull);
    });
  });
}
