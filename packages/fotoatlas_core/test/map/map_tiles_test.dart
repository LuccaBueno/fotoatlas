import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

void main() {
  late TestEnv env;
  late HttpServer server;
  final requests = <HttpRequest>[];
  var status = HttpStatus.ok;
  var type = ContentType('image', 'png');

  setUp(() async {
    env = await TestEnv.open(tools: ExternalTools.none);
    requests.clear();
    status = HttpStatus.ok;
    type = ContentType('image', 'png');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      requests.add(r);
      r.response
        ..statusCode = status
        ..headers.contentType = type
        ..add([0x89, 0x50, 0x4e, 0x47, r.uri.pathSegments.length])
        ..close();
    });
  });
  tearDown(() => server.close(force: true));

  OnlineMapTiles tiles() => OnlineMapTiles(
    SettingsStore(env.db),
    urlTemplate: 'http://127.0.0.1:${server.port}/{z}/{x}/{y}.png',
    userAgent: 'FotoAtlas-teste',
  );

  test('desligado por padrão: nenhum pedido sai do computador', () async {
    final t = tiles();
    expect(await t.isEnabled(), isFalse);
    expect(await t.tile(3, 4, 2), isNull);
    expect(requests, isEmpty);
  });

  test('ligado: pede só z/x/y, com o nome do app, e guarda em memória', () async {
    final t = tiles();
    await t.setEnabled(true);
    expect(await tiles().isEnabled(), isTrue, reason: 'a escolha fica no catálogo');
    final a = await t.tile(3, 4, 2);
    expect(a, isNotNull);
    expect(await t.tile(3, 4, 2), same(a), reason: 'do cache, sem novo pedido');
    expect(await t.tile(3, 12, 2), isNotNull, reason: 'x dá a volta no globo: 12 = 4');
    expect(requests, hasLength(1));
    expect(requests.single.uri.path, '/3/4/2.png');
    expect(requests.single.uri.query, isEmpty);
    expect(requests.single.headers.value(HttpHeaders.userAgentHeader), 'FotoAtlas-teste');
    expect(requests.single.headers.value(HttpHeaders.cookieHeader), isNull);
    expect(await t.tile(3, 0, 8), isNull, reason: 'y fora do mapa');
    expect(await t.tile(20, 0, 0), isNull, reason: 'acima do nível máximo');
    expect(requests, hasLength(1));

    await t.setEnabled(false);
    expect(await t.tile(3, 4, 2), isNull, reason: 'desligado: nem do cache');
    expect(requests, hasLength(1));
    t.close();
  });

  test('erro do servidor, resposta que não é imagem e servidor fora do ar viram nada', () async {
    final t = tiles();
    await t.setEnabled(true);
    status = HttpStatus.forbidden;
    expect(await t.tile(1, 0, 0), isNull);
    status = HttpStatus.ok;
    type = ContentType.html;
    expect(await t.tile(1, 1, 0), isNull);
    await server.close(force: true);
    expect(await t.tile(1, 1, 1), isNull);
    t.close();
  });
}
