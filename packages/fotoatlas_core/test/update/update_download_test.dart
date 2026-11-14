import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _version = AppVersion(1, 2, 0);
final _name = installerFileName(_version);

/// "Instalador" sintético (bytes determinísticos).
Uint8List _bytes(int size) => Uint8List.fromList(List.generate(size, (i) => (i * 31 + 7) & 0xff));

String _hex(List<int> bytes) => sha256.convert(bytes).toString();

void main() {
  late Directory base;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('fotoatlas-update-test-');
    addTearDown(() => base.delete(recursive: true));
  });

  /// Pastas de download que sobraram (tem de ser nenhuma depois de falhar).
  List<String> leftovers() => base.existsSync() ? [for (final e in base.listSync()) p.basename(e.path)] : [];

  Future<HttpServer> serve(Future<void> Function(HttpRequest) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) => handler(req).catchError((_) {}));
    return server;
  }

  ReleaseInfo releaseAt(HttpServer s) {
    final root = 'http://${s.address.address}:${s.port}/download/v$_version';
    return ReleaseInfo(
      version: _version,
      pageUrl: Uri.parse('$releasesPage/tag/v$_version'),
      installerUrl: Uri.parse('$root/$_name'),
      checksumUrl: Uri.parse('$root/$_name.sha256'),
    );
  }

  /// Servidor com o instalador [body] e o `.sha256` [checksum] (padrão: o certo).
  Future<HttpServer> release(Uint8List body, {String? checksum, int? checksumStatus}) => serve((req) async {
    if (req.uri.path.endsWith('.sha256')) {
      req.response.statusCode = checksumStatus ?? HttpStatus.ok;
      req.response.write(checksum ?? '${_hex(body)}  $_name\n');
    } else {
      req.response.contentLength = body.length;
      req.response.add(body);
    }
    await req.response.close();
  });

  UpdateDownloader downloader() => UpdateDownloader(
    baseDir: base,
    connectTimeout: const Duration(seconds: 3),
    idleTimeout: const Duration(seconds: 3),
  );

  Future<UpdateDownloadFailure> failureOf(Future<Object?> f) async {
    try {
      await f;
    } on UpdateDownloadException catch (e) {
      return e.failure;
    }
    fail('deveria ter falhado');
  }

  test('baixa, confere o SHA-256 no disco e mostra o progresso', () async {
    final body = _bytes(700 * 1024);
    final server = await release(body);
    final progress = <(int, int?)>[];
    final result = await downloader().download(releaseAt(server), onProgress: (r, t) => progress.add((r, t)));

    expect(p.basename(result.file.path), 'FotoAtlas-1.2.0-instalador.exe');
    expect(p.isWithin(base.path, result.file.path), isTrue, reason: 'só grava na pasta de downloads');
    expect(await result.file.readAsBytes(), body);
    expect(result.sha256, _hex(body));
    expect(result.version, _version);
    expect(File('${result.file.path}.part').existsSync(), isFalse);
    expect(progress.first, (0, body.length));
    expect(progress.last, (body.length, body.length));
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
    }
  });

  test('SHA-256 errado: apaga o download e avisa', () async {
    final server = await release(_bytes(200 * 1024), checksum: '${'ab' * 32}  $_name');
    expect(await failureOf(downloader().download(releaseAt(server))), UpdateDownloadFailure.hashMismatch);
    expect(leftovers(), isEmpty);
  });

  test('arquivo trocado no caminho (mesmo tamanho, outro conteúdo): SHA-256 não bate', () async {
    final good = _bytes(64 * 1024);
    final bad = Uint8List.fromList(good)..[1000] ^= 0xff;
    final server = await release(bad, checksum: '${_hex(good)}  $_name');
    expect(await failureOf(downloader().download(releaseAt(server))), UpdateDownloadFailure.hashMismatch);
    expect(leftovers(), isEmpty);
  });

  test('download interrompido no meio: apaga o pedaço baixado e avisa', () async {
    final body = _bytes(1024 * 1024);
    final server = await serve((req) async {
      if (req.uri.path.endsWith('.sha256')) {
        req.response.write('${_hex(body)}  $_name');
        await req.response.close();
        return;
      }
      req.response.contentLength = body.length;
      req.response.add(body.sublist(0, 300 * 1024));
      await req.response.flush();
      // A conexão cai sem mandar o resto.
      final socket = await req.response.detachSocket(writeHeaders: false);
      socket.destroy();
    });
    expect(await failureOf(downloader().download(releaseAt(server))), UpdateDownloadFailure.interrupted);
    expect(leftovers(), isEmpty);
  });

  test('servidor que para de mandar dados: interrompido depois do prazo', () async {
    final body = _bytes(100 * 1024);
    final server = await serve((req) async {
      if (req.uri.path.endsWith('.sha256')) {
        req.response.write('${_hex(body)}  $_name');
        await req.response.close();
        return;
      }
      req.response.contentLength = body.length;
      req.response.add(body.sublist(0, 1024));
      await req.response.flush();
      // Fica mudo.
    });
    final d = UpdateDownloader(baseDir: base, idleTimeout: const Duration(milliseconds: 300));
    expect(await failureOf(d.download(releaseAt(server))), UpdateDownloadFailure.interrupted);
    expect(leftovers(), isEmpty);
  });

  test('cancelar no meio: para, apaga o que baixou e não é tratado como erro de rede', () async {
    final body = _bytes(512 * 1024);
    final server = await serve((req) async {
      if (req.uri.path.endsWith('.sha256')) {
        req.response.write('${_hex(body)}  $_name');
        await req.response.close();
        return;
      }
      req.response.contentLength = body.length;
      // Manda devagar, em pedaços.
      for (var i = 0; i < body.length; i += 16 * 1024) {
        req.response.add(body.sublist(i, (i + 16 * 1024).clamp(0, body.length)));
        await req.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await req.response.close();
    });
    final cancel = UpdateCancelToken();
    var lastReceived = 0;
    final future = downloader().download(
      releaseAt(server),
      cancel: cancel,
      onProgress: (received, _) {
        lastReceived = received;
        if (received > 0) cancel.cancel();
      },
    );
    expect(await failureOf(future), UpdateDownloadFailure.cancelled);
    expect(lastReceived, lessThan(body.length));
    expect(leftovers(), isEmpty);
  });

  test('cancelar antes de começar: nada é baixado', () async {
    var requests = 0;
    final server = await serve((req) async {
      requests++;
      await req.response.close();
    });
    final cancel = UpdateCancelToken()..cancel();
    expect(await failureOf(downloader().download(releaseAt(server), cancel: cancel)), UpdateDownloadFailure.cancelled);
    expect(requests, 0);
    expect(leftovers(), isEmpty);
  });

  test('sem internet: avisa e não deixa nada', () async {
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final r = releaseAt(closed);
    await closed.close(force: true);
    expect(await failureOf(downloader().download(r)), UpdateDownloadFailure.network);
    expect(leftovers(), isEmpty);
  });

  test('instalador fora do ar (erro do servidor): rede, nada fica', () async {
    final server = await serve((req) async {
      if (req.uri.path.endsWith('.sha256')) {
        req.response.write('${'ab' * 32}  $_name');
      } else {
        req.response.statusCode = HttpStatus.internalServerError;
      }
      await req.response.close();
    });
    expect(await failureOf(downloader().download(releaseAt(server))), UpdateDownloadFailure.network);
    expect(leftovers(), isEmpty);
  });

  test('sem .sha256, ilegível ou de outro arquivo: não baixa o instalador', () async {
    var installerRequests = 0;
    Future<HttpServer> withChecksum(String text, {int status = HttpStatus.ok}) => serve((req) async {
      if (req.uri.path.endsWith('.sha256')) {
        req.response.statusCode = status;
        req.response.write(text);
      } else {
        installerRequests++;
        req.response.add(_bytes(10));
      }
      await req.response.close();
    });
    for (final server in [
      await withChecksum('não encontrado', status: HttpStatus.notFound),
      await withChecksum('isto não é um hash'),
      await withChecksum('${'ab' * 32}  FotoAtlas-1.1.0-instalador.exe'),
    ]) {
      expect(await failureOf(downloader().download(releaseAt(server))), UpdateDownloadFailure.checksumMissing);
    }
    expect(installerRequests, 0);
    expect(leftovers(), isEmpty);
  });

  test('release sem instalador: nem tenta', () async {
    final r = ReleaseInfo(version: _version, pageUrl: Uri.parse('$releasesPage/tag/v$_version'));
    expect(r.canInstall, isFalse);
    expect(await failureOf(downloader().download(r)), UpdateDownloadFailure.checksumMissing);
  });

  test('limpa downloads de vezes anteriores, e só eles', () async {
    final old = Directory(p.join(base.path, 'download-antigo'))..createSync();
    File(p.join(old.path, _name)).writeAsStringSync('velho');
    final other = File(p.join(base.path, 'outro-arquivo.txt'))..writeAsStringSync('não é nosso');
    await downloader().cleanup();
    expect(old.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('startInstaller não inicia nada se o arquivo mudou depois de conferido', () async {
    final file = File(p.join(base.path, _name))..writeAsBytesSync(_bytes(100));
    final installer = DownloadedInstaller(file: file, version: _version, sha256: _hex(_bytes(100)));
    file.writeAsBytesSync(_bytes(101));
    expect(await startInstaller(installer), isFalse);
    await file.delete();
    expect(await startInstaller(installer), isFalse);
  });

  group('parseChecksumFile', () {
    test('formato do build-installer.ps1 e do sha256sum', () {
      final hash = 'AB' * 32;
      expect(parseChecksumFile('$hash  $_name\n', _name), 'ab' * 32);
      expect(parseChecksumFile('$hash *$_name', _name), 'ab' * 32);
      expect(parseChecksumFile(hash, _name), 'ab' * 32);
      expect(parseChecksumFile('﻿$hash  $_name\r\n', _name), 'ab' * 32, reason: 'com BOM do PowerShell');
    });

    test('ilegível ou de outro arquivo: null', () {
      expect(parseChecksumFile('', _name), isNull);
      expect(parseChecksumFile('abc  $_name', _name), isNull);
      expect(parseChecksumFile('${'ab' * 32}  outro.exe', _name), isNull);
    });
  });

  test('argumentos do instalador batem com o fotoatlas.iss', () {
    final iss = File(p.join('..', '..', 'installer', 'fotoatlas.iss')).readAsStringSync();
    expect(installerUpdateArguments, contains('/ATUALIZARDOAPP=1'));
    expect(iss, contains('{param:ATUALIZARDOAPP|0}'));
  });
}
