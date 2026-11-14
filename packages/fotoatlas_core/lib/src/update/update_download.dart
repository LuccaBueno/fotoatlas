import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'update_check.dart';

/// Por que "Atualizar agora" não baixou o instalador. Em todos os casos o
/// download (se houver) é apagado e nada mais é tocado.
enum UpdateDownloadFailure {
  /// Sem internet, GitHub fora do ar ou demorando demais.
  network,

  /// A conexão caiu no meio (veio menos do que o tamanho anunciado).
  interrupted,

  /// A release não tem o `.sha256` do instalador (ou ele é ilegível).
  checksumMissing,

  /// O SHA-256 do arquivo baixado não é o do `.sha256` da release.
  hashMismatch,

  /// Não deu para gravar na pasta temporária (disco cheio, permissão).
  disk,

  /// O usuário clicou em "Cancelar".
  cancelled,
}

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.failure, [this.detail = '']);
  final UpdateDownloadFailure failure;
  final String detail;

  @override
  String toString() => 'UpdateDownloadException(${failure.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// "Cancelar" do download.
class UpdateCancelToken {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completa quando o usuário cancela.
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// Instalador baixado e conferido (SHA-256 igual ao do `.sha256` da release).
class DownloadedInstaller {
  const DownloadedInstaller({required this.file, required this.version, required this.sha256});
  final File file;
  final AppVersion version;

  /// Em hexadecimal minúsculo.
  final String sha256;
}

/// Argumentos com que o app chama o instalador ao atualizar: progresso visível
/// sem perguntas, sem reiniciar o Windows, e `/ATUALIZARDOAPP=1`, que faz o
/// instalador esperar o app fechar e abri-lo de novo no fim (ver
/// `installer\fotoatlas.iss`).
const installerUpdateArguments = ['/SILENT', '/NORESTART', '/ATUALIZARDOAPP=1'];

/// Pasta onde os instaladores são baixados (só arquivos do FotoAtlas).
Directory defaultUpdateDownloadDir() => Directory(p.join(Directory.systemTemp.path, 'FotoAtlas-atualizacao'));

const _downloadPrefix = 'download-';

/// Lê o conteúdo de um `.sha256` (`<64 hex>  <nome>`, como o do
/// `build-installer.ps1` e o do `sha256sum`). Se trouxer nome, tem de ser o do
/// instalador. `null` = ilegível.
String? parseChecksumFile(String text, String expectedName) {
  final line = text.replaceFirst('﻿', '').trim().split(RegExp(r'\r?\n')).first.trim();
  final m = RegExp(r'^([0-9a-fA-F]{64})(?:\s+\*?(.+))?$').firstMatch(line);
  if (m == null) return null;
  final name = m[2]?.trim();
  if (name != null && name != expectedName) return null;
  return m[1]!.toLowerCase();
}

/// Baixa o instalador de uma versão nova e confere o SHA-256 com o `.sha256`
/// da mesma release. Só grava numa subpasta própria da pasta temporária; se
/// qualquer coisa falhar (ou o usuário cancelar), apaga essa subpasta e lança
/// [UpdateDownloadException]. Nunca toca no catálogo nem nas configurações.
class UpdateDownloader {
  UpdateDownloader({
    Directory? baseDir,
    HttpClient Function()? clientFactory,
    this.connectTimeout = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 30),
  }) : baseDir = baseDir ?? defaultUpdateDownloadDir(),
       _clientFactory = clientFactory ?? HttpClient.new;

  final Directory baseDir;
  final HttpClient Function() _clientFactory;
  final Duration connectTimeout;

  /// Tempo máximo sem receber nada antes de considerar a conexão caída.
  final Duration idleTimeout;

  /// Apaga downloads de vezes anteriores (o instalador não consegue apagar a si
  /// mesmo). Só subpastas `download-*` criadas aqui; o que estiver em uso (um
  /// instalador ainda rodando) fica para a próxima.
  Future<void> cleanup() async {
    if (!await baseDir.exists()) return;
    try {
      await for (final e in baseDir.list(followLinks: false)) {
        if (e is Directory && p.basename(e.path).startsWith(_downloadPrefix)) {
          try {
            await e.delete(recursive: true);
          } on FileSystemException {
            // Em uso: fica para a próxima.
          }
        }
      }
    } on FileSystemException {
      // Pasta inacessível: nada a limpar.
    }
  }

  /// [onProgress] recebe os bytes recebidos e o total (`null` se o servidor não
  /// informar).
  Future<DownloadedInstaller> download(
    ReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
    UpdateCancelToken? cancel,
  }) async {
    final installerUrl = release.installerUrl;
    final checksumUrl = release.checksumUrl;
    if (installerUrl == null || checksumUrl == null) {
      throw const UpdateDownloadException(UpdateDownloadFailure.checksumMissing, 'release sem instalador');
    }
    final name = installerFileName(release.version);
    final client = _clientFactory()..connectionTimeout = connectTimeout;
    // Cancelar derruba a conexão; o erro que isso causa vira "cancelado".
    unawaited(cancel?.whenCancelled.then((_) => client.close(force: true)));
    Directory? dir;
    try {
      await cleanup();
      try {
        await baseDir.create(recursive: true);
        dir = await baseDir.createTemp(_downloadPrefix);
      } on FileSystemException catch (e) {
        throw UpdateDownloadException(UpdateDownloadFailure.disk, e.message);
      }

      final checksumText = await _getSmall(client, checksumUrl, cancel);
      final expected = parseChecksumFile(checksumText, name);
      if (expected == null) {
        throw const UpdateDownloadException(UpdateDownloadFailure.checksumMissing, '.sha256 ilegível');
      }

      final part = File(p.join(dir.path, '$name.part'));
      await _getToFile(client, installerUrl, part, onProgress, cancel);
      _throwIfCancelled(cancel);

      // Confere o que ficou no disco (não o que passou pela rede).
      final actual = await _sha256Of(part);
      if (actual != expected) {
        throw UpdateDownloadException(UpdateDownloadFailure.hashMismatch, 'esperado $expected, veio $actual');
      }
      _throwIfCancelled(cancel);
      final file = await part.rename(p.join(dir.path, name));
      return DownloadedInstaller(file: file, version: release.version, sha256: actual);
    } on Object catch (e) {
      if (dir != null) {
        try {
          await dir.delete(recursive: true);
        } on FileSystemException {
          // Fica para a limpeza da próxima vez.
        }
      }
      if (cancel?.isCancelled ?? false) throw const UpdateDownloadException(UpdateDownloadFailure.cancelled);
      if (e is UpdateDownloadException) rethrow;
      if (e is FileSystemException) throw UpdateDownloadException(UpdateDownloadFailure.disk, e.message);
      throw UpdateDownloadException(UpdateDownloadFailure.network, '$e');
    } finally {
      client.close(force: true);
    }
  }

  void _throwIfCancelled(UpdateCancelToken? cancel) {
    if (cancel?.isCancelled ?? false) throw const UpdateDownloadException(UpdateDownloadFailure.cancelled);
  }

  Future<HttpClientResponse> _get(HttpClient client, Uri uri, UpdateCancelToken? cancel) async {
    _throwIfCancelled(cancel);
    final request = await client.getUrl(uri).timeout(connectTimeout);
    request.followRedirects = true; // o GitHub redireciona os arquivos da release
    request.headers.set(HttpHeaders.userAgentHeader, 'FotoAtlas');
    final response = await request.close().timeout(connectTimeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().catchError((_) {});
      throw UpdateDownloadException(
        response.statusCode == HttpStatus.notFound && uri.path.endsWith('.sha256')
            ? UpdateDownloadFailure.checksumMissing
            : UpdateDownloadFailure.network,
        'HTTP ${response.statusCode} em $uri',
      );
    }
    return response;
  }

  Future<String> _getSmall(HttpClient client, Uri uri, UpdateCancelToken? cancel) async {
    final response = await _get(client, uri, cancel);
    final bytes = <int>[];
    await for (final chunk in response.timeout(idleTimeout)) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) {
        throw const UpdateDownloadException(UpdateDownloadFailure.checksumMissing, '.sha256 grande demais');
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> _getToFile(
    HttpClient client,
    Uri uri,
    File target,
    void Function(int received, int? total)? onProgress,
    UpdateCancelToken? cancel,
  ) async {
    final response = await _get(client, uri, cancel);
    final total = response.contentLength >= 0 ? response.contentLength : null;
    final sink = target.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    var sinkClosed = false;
    try {
      onProgress?.call(0, total);
      try {
        await for (final chunk in response.timeout(idleTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } on FileSystemException {
        rethrow;
      } on Object catch (e) {
        // Conexão caiu ou parou de mandar dados no meio.
        _throwIfCancelled(cancel);
        throw UpdateDownloadException(UpdateDownloadFailure.interrupted, '$e');
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      if (total != null && received != total) {
        throw UpdateDownloadException(UpdateDownloadFailure.interrupted, 'recebidos $received de $total bytes');
      }
    } finally {
      if (!sinkClosed) {
        try {
          await sink.close();
        } on Object {
          // O erro que importa é o de cima.
        }
      }
    }
  }
}

Future<String> _sha256Of(File file) async => (await sha256.bind(file.openRead()).first).toString();

/// Confere de novo o instalador (pode ter ficado um tempo na pasta temporária
/// enquanto o usuário decidia) e o inicia, desvinculado do app, com
/// [installerUpdateArguments]. Devolve `false` sem iniciar nada se o arquivo
/// sumiu ou mudou.
Future<bool> startInstaller(DownloadedInstaller installer) async {
  try {
    if (await _sha256Of(installer.file) != installer.sha256) return false;
    await Process.start(installer.file.path, installerUpdateArguments, mode: ProcessStartMode.detached);
    return true;
  } on Object {
    return false;
  }
}
