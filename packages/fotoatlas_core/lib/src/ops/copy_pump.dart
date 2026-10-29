import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';

import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';
import '../safe_io/dest_writer.dart';
import '../safe_io/source_reader.dart';
import '../util/crashpoint.dart';

/// Resultado da cópia de um arquivo para o `.part` ou da releitura dele.
sealed class PumpResult {
  const PumpResult();
}

class PumpDone extends PumpResult {
  const PumpDone(this.sha256, this.bytes);
  final Uint8List sha256;
  final int bytes;
}

/// Parou a pedido (pausa/encerramento) no meio do arquivo.
class PumpStopped extends PumpResult {
  const PumpStopped();
}

/// Falha com um código estável (ver [PumpFailure]).
class PumpFailed extends PumpResult {
  const PumpFailed(this.failure, this.message, {this.win32});
  final PumpFailure failure;
  final String message;
  final int? win32;
}

enum PumpFailure {
  /// O arquivo não está mais no caminho (a pasta pode ter sido renomeada).
  sourceMissing,

  /// Erro de leitura, sem permissão ou bloqueado por outro programa.
  sourceUnreadable,

  /// Tamanho ou data diferentes do escaneamento, ou mudou durante a leitura.
  sourceChanged,

  /// Só na nuvem: ler dispararia o download.
  sourceCloudOnly,

  /// O disco de destino encheu.
  diskFull,

  /// O arquivo é grande demais para o sistema de arquivos do destino (FAT32).
  tooLarge,

  /// Pasta temporária inacessível (o disco de destino saiu?).
  destUnavailable,

  /// O `.part` já existia (nunca sobrescrevemos).
  partExists,

  /// Outro erro de gravação no destino.
  writeError,
}

/// Parâmetros de [copyToPart], enviáveis a outro isolate.
class PumpRequest {
  const PumpRequest({
    required this.sourcePath,
    required this.partPath,
    required this.expectedSize,
    required this.expectedMtime,
    this.crashMidWrite = false,
    this.chunkSize = 1 << 20,
  });
  final String sourcePath;
  final String partPath;
  final int expectedSize;
  final int? expectedMtime;

  /// Para no ponto `copy.mid_write` (testes de falha; o isolate principal
  /// decide qual ocorrência é a escolhida, ADR 0007).
  final bool crashMidWrite;
  final int chunkSize;
}

/// Copia um arquivo de disco para um `.part` novo (spec §11.1, passos 3–4):
/// lê a origem só para leitura, calcula o SHA-256 **durante a leitura**,
/// grava, copia a data de modificação, faz `FlushFileBuffers` e fecha. Confere
/// que a origem não mudou no meio. Não apaga nada: um `.part` parcial fica
/// para quem chamou decidir (é um arquivo do próprio FotoAtlas).
Future<PumpResult> copyToPart(
  PumpRequest r, {
  bool Function()? shouldStop,
  void Function(int bytes)? onProgress,
}) async {
  final SourceFileInfo pre;
  try {
    pre = attributesOf(r.sourcePath);
  } on Win32Exception catch (e) {
    return _readFailure(e);
  }
  if (pre.isCloudPlaceholder) {
    return const PumpFailed(PumpFailure.sourceCloudOnly, 'O arquivo está só na nuvem (não foi baixado).');
  }
  final SourceFile src;
  try {
    src = SourceFile.open(r.sourcePath);
  } on Win32Exception catch (e) {
    return _readFailure(e);
  }
  PartWriter? part;
  final buffer = calloc<Uint8>(r.chunkSize);
  try {
    final before = src.info();
    if (before.size != r.expectedSize || (r.expectedMtime != null && before.mtime != r.expectedMtime)) {
      return const PumpFailed(PumpFailure.sourceChanged, 'O arquivo mudou depois do escaneamento. Escaneie de novo.');
    }
    try {
      part = PartWriter.create(r.partPath);
    } on Win32Exception catch (e) {
      return _writeFailure(e);
    }
    final digest = _DigestSink();
    final input = sha256.startChunkedConversion(digest);
    var total = 0;
    var chunks = 0;
    while (true) {
      final int n;
      try {
        n = src.read(buffer, r.chunkSize);
      } on Win32Exception catch (e) {
        return _readFailure(e);
      }
      if (n == 0) break;
      input.add(buffer.asTypedList(n));
      try {
        part.write(buffer, n);
      } on Win32Exception catch (e) {
        return _writeFailure(e);
      }
      total += n;
      chunks++;
      if (chunks == 1 && r.crashMidWrite) crashpointNow('copy.mid_write');
      if (chunks % 8 == 0) {
        onProgress?.call(total);
        await Future<void>.delayed(Duration.zero);
        if (shouldStop?.call() ?? false) return const PumpStopped();
      }
    }
    input.close();
    final after = src.info();
    if (total != before.size || after.size != before.size || after.mtime != before.mtime) {
      return const PumpFailed(PumpFailure.sourceChanged, 'O arquivo mudou enquanto era copiado. Escaneie de novo.');
    }
    try {
      part.setModified(before.mtime);
      part.flush();
    } on Win32Exception catch (e) {
      return _writeFailure(e);
    }
    onProgress?.call(total);
    return PumpDone(Uint8List.fromList(digest.value!.bytes), total);
  } on Win32Exception catch (e) {
    return _readFailure(e);
  } finally {
    calloc.free(buffer);
    part?.close();
    src.close();
  }
}

/// Relê um arquivo do destino (o `.part` ou o publicado), só para leitura, e
/// calcula o SHA-256 (spec §11.1, passo 5). `null` se não existe.
Future<PumpResult?> hashDestFile(
  String path, {
  int chunkSize = 1 << 20,
  bool Function()? shouldStop,
  void Function(int bytes)? onProgress,
}) async {
  final SourceFile file;
  try {
    file = SourceFile.open(path);
  } on Win32Exception catch (e) {
    if (e.code == errorFileNotFound) return null;
    if (e.code == errorPathNotFound) {
      return const PumpFailed(PumpFailure.destUnavailable, 'A pasta do destino não está acessível (o disco saiu?).');
    }
    return PumpFailed(PumpFailure.writeError, 'Não foi possível reler o arquivo no destino.', win32: e.code);
  }
  final buffer = calloc<Uint8>(chunkSize);
  try {
    final digest = _DigestSink();
    final input = sha256.startChunkedConversion(digest);
    var total = 0;
    var chunks = 0;
    while (true) {
      final n = file.read(buffer, chunkSize);
      if (n == 0) break;
      input.add(buffer.asTypedList(n));
      total += n;
      if (++chunks % 16 == 0) {
        onProgress?.call(total);
        await Future<void>.delayed(Duration.zero);
        if (shouldStop?.call() ?? false) return const PumpStopped();
      }
    }
    input.close();
    return PumpDone(Uint8List.fromList(digest.value!.bytes), total);
  } on Win32Exception catch (e) {
    return PumpFailed(PumpFailure.writeError, 'Erro ao reler o arquivo no destino.', win32: e.code);
  } finally {
    calloc.free(buffer);
    file.close();
  }
}

PumpFailed _readFailure(Win32Exception e) => switch (e.code) {
  errorFileNotFound || errorPathNotFound => PumpFailed(
    PumpFailure.sourceMissing,
    'O arquivo não está mais na origem (a pasta foi movida ou renomeada?).',
    win32: e.code,
  ),
  errorAccessDenied => PumpFailed(PumpFailure.sourceUnreadable, 'Sem permissão para ler o arquivo.', win32: e.code),
  errorSharingViolation || errorLockViolation => PumpFailed(
    PumpFailure.sourceUnreadable,
    'O arquivo está bloqueado por outro programa.',
    win32: e.code,
  ),
  errorNotReady || errorDevNotExist || errorInvalidDrive || errorDeviceNotConnected => PumpFailed(
    PumpFailure.sourceMissing,
    'A origem foi desconectada no meio da cópia.',
    win32: e.code,
  ),
  _ => PumpFailed(PumpFailure.sourceUnreadable, 'Erro de leitura na origem (código ${e.code}).', win32: e.code),
};

PumpFailed _writeFailure(Win32Exception e) => switch (e.code) {
  errorDiskFull ||
  errorHandleDiskFull => PumpFailed(PumpFailure.diskFull, 'O disco de destino ficou sem espaço.', win32: e.code),
  errorFileTooLarge => PumpFailed(
    PumpFailure.tooLarge,
    'O arquivo é grande demais para o disco de destino (FAT32 aceita até 4 GB por arquivo).',
    win32: e.code,
  ),
  errorFileExists ||
  errorAlreadyExists => PumpFailed(PumpFailure.partExists, 'O arquivo temporário já existia.', win32: e.code),
  errorPathNotFound || errorNotReady || errorDevNotExist || errorInvalidDrive || errorDeviceNotConnected => PumpFailed(
    PumpFailure.destUnavailable,
    'O disco de destino não está acessível (foi desconectado?).',
    win32: e.code,
  ),
  _ => PumpFailed(PumpFailure.writeError, 'Erro ao gravar no destino (código ${e.code}).', win32: e.code),
};

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Roda [copyToPart] num isolate próprio (as chamadas de arquivo são
/// síncronas e não podem travar a interface). [stop] pede para parar no meio.
Future<PumpResult> copyToPartInIsolate(
  PumpRequest r, {
  required Future<void> stop,
  void Function(int bytes)? onProgress,
}) => _inWorker<PumpResult>(r, stop: stop, onProgress: onProgress);

/// [hashDestFile] num isolate próprio.
Future<PumpResult?> hashDestFileInIsolate(String path, {required Future<void> stop, void Function(int)? onProgress}) =>
    _inWorker<PumpResult?>(path, stop: stop, onProgress: onProgress);

/// Ponto de entrada do isolate: só recebe dados (o trabalho é [job]: um
/// [PumpRequest] copia, uma `String` relê), nada do isolate principal.
Future<void> _workerMain((Object, SendPort) message) async {
  final (job, out) = message;
  final inbox = ReceivePort();
  var stopped = false;
  inbox.listen((_) => stopped = true);
  out.send(inbox.sendPort);
  try {
    final Object? value = switch (job) {
      final PumpRequest r => await copyToPart(r, shouldStop: () => stopped, onProgress: out.send),
      final String path => await hashDestFile(path, shouldStop: () => stopped, onProgress: out.send),
      _ => throw ArgumentError(job),
    };
    out.send((const _Ok(), value));
  } catch (e, st) {
    out.send((const _Err(), e.toString(), st.toString()));
  } finally {
    inbox.close();
  }
}

Future<T> _inWorker<T>(Object job, {required Future<void> stop, void Function(int bytes)? onProgress}) async {
  final events = ReceivePort();
  final done = Completer<T>();
  SendPort? control;
  var stopRequested = false;
  unawaited(
    stop.then((_) {
      stopRequested = true;
      control?.send('stop');
    }),
  );
  events.listen((message) {
    switch (message) {
      case final SendPort port:
        control = port;
        if (stopRequested) port.send('stop');
      case final int bytes:
        onProgress?.call(bytes);
      case (_Ok(), final Object? value):
        if (!done.isCompleted) done.complete(value as T);
      case (_Err(), final Object error, final String stack):
        if (!done.isCompleted) done.completeError(error, StackTrace.fromString(stack));
    }
  });
  final out = events.sendPort;
  try {
    await Isolate.spawn(_workerMain, (job, out));
    return await done.future;
  } finally {
    events.close();
  }
}

class _Ok {
  const _Ok();
}

class _Err {
  const _Err();
}
