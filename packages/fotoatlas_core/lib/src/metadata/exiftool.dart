import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'extracted.dart';

/// Resultado da leitura de um arquivo: metadados ou o motivo da falha.
class ExtractResult {
  const ExtractResult.ok(ExtractedMetadata this.metadata) : error = null;
  const ExtractResult.failed(String this.error) : metadata = null;
  final ExtractedMetadata? metadata;
  final String? error;
}

/// ExifTool em modo `-stay_open` (ADR 0004): um processo, lotes de arquivos,
/// **só leitura**. Os argumentos são fixos ([readArgs]); nenhum argumento de
/// escrita é montado (conferido em teste).
class ExifTool {
  ExifTool(this.executable, {this.batchTimeout = const Duration(seconds: 60)});

  final String executable;
  final Duration batchTimeout;

  /// Argumentos de cada lote: JSON, valores numéricos, grupo no nome do tag,
  /// sem varrer até o fim do JPEG, nomes em UTF-8 e só os tags usados.
  static const readArgs = [
    '-json',
    '-n',
    '-G1',
    '-fast',
    '-charset',
    'filename=utf8',
    '-api',
    'LargeFileSupport=1',
    '-Error',
    '-DateTimeOriginal',
    '-SubSecTimeOriginal',
    '-OffsetTimeOriginal',
    '-OffsetTime',
    '-CreateDate',
    '-SubSecTimeDigitized',
    '-OffsetTimeDigitized',
    '-DateCreated',
    '-CreationDate',
    '-MediaCreateDate',
    '-TrackCreateDate',
    '-Make',
    '-Model',
    '-LensModel',
    '-Lens',
    '-SerialNumber',
    '-InternalSerialNumber',
    '-ISO',
    '-FNumber',
    '-ExposureTime',
    '-FocalLength',
    '-ImageWidth',
    '-ImageHeight',
    '-ExifImageWidth',
    '-ExifImageHeight',
    '-Orientation',
    '-GPSLatitude',
    '-GPSLongitude',
    '-Duration',
    '-VideoFrameRate',
    '-CompressorID',
    '-AudioFormat',
    '-AvgBitrate',
    '-Software',
  ];

  /// Opções que gravariam algo: nunca podem aparecer (teste de arquitetura).
  static const forbiddenOptions = {
    '-o',
    '-out',
    '-w',
    '-W',
    '-overwrite_original',
    '-overwrite_original_in_place',
    '-tagsfromfile',
    '-delete_original',
    '-restore_original',
    '-geotag',
    '-srcfile',
    '-k', // espera Enter (travaria o processo)
  };

  Process? _process;
  StreamIterator<String>? _out;
  final _stderr = StringBuffer();
  int _seq = 0;
  Future<void> _queue = Future.value();
  String? _version;

  /// Ex.: 'exiftool 13.60'.
  String get name => _version == null ? 'exiftool' : 'exiftool $_version';

  Future<void> _ensureStarted() async {
    if (_process != null) return;
    final proc = await Process.start(executable, ['-stay_open', 'True', '-@', '-']);
    _process = proc;
    _out = StreamIterator(proc.stdout.transform(utf8.decoder).transform(const LineSplitter()));
    proc.stderr.transform(utf8.decoder).listen(_stderr.write);
    unawaited(proc.exitCode.then((_) => _process == proc ? _process = null : null));
    if (_version == null) {
      final v = await _execute(['-ver']);
      _version = v.trim();
    }
  }

  /// Envia um comando e lê até `{readyN}`.
  Future<String> _execute(List<String> args) async {
    final proc = _process!;
    final n = ++_seq;
    final buf = StringBuffer();
    proc.stdin.add(utf8.encode('${[...args, '-execute$n'].join('\n')}\n'));
    await proc.stdin.flush();
    final out = _out!;
    while (await out.moveNext()) {
      final line = out.current;
      if (line == '{ready$n}') return buf.toString();
      buf.writeln(line);
    }
    throw const ProcessException('exiftool', [], 'O ExifTool fechou inesperadamente.');
  }

  /// Lê [paths] (locais, só leitura). Arquivo que o ExifTool não conseguiu
  /// ler volta com o motivo; um lote que trava passa do prazo e o processo é
  /// reiniciado no próximo.
  Future<Map<String, ExtractResult>> extract(List<String> paths) {
    final run = _queue.then((_) => _extract(paths));
    _queue = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<Map<String, ExtractResult>> _extract(List<String> paths) async {
    if (paths.isEmpty) return const {};
    try {
      await _ensureStarted().timeout(batchTimeout);
      _stderr.clear();
      final text = await _execute([...readArgs, ...paths]).timeout(batchTimeout + Duration(seconds: paths.length));
      final results = <String, ExtractResult>{};
      final byKey = {for (final p in paths) _key(p): p};
      if (text.trim().isNotEmpty) {
        for (final obj in (jsonDecode(text) as List<Object?>).cast<Map<String, Object?>>()) {
          final path = byKey[_key(obj['SourceFile']?.toString() ?? '')];
          if (path == null) continue;
          final error = obj['ExifTool:Error'];
          results[path] = error != null
              ? ExtractResult.failed(error.toString())
              : ExtractResult.ok(ExtractedMetadata.fromExifTool(obj));
        }
      }
      final err = _stderr.toString().trim();
      for (final p in paths) {
        results[p] ??= ExtractResult.failed(err.isEmpty ? 'O ExifTool não leu o arquivo.' : _firstLine(err));
      }
      return results;
    } on Object catch (e) {
      await _kill();
      return {for (final p in paths) p: ExtractResult.failed('Falha ao ler metadados: $e')};
    }
  }

  /// O ExifTool devolve `SourceFile` com '/', no Windows.
  static String _key(String path) => path.replaceAll('/', r'\').toLowerCase();

  static String _firstLine(String s) => s.split('\n').first.trim();

  Future<void> _kill() async {
    final proc = _process;
    _process = null;
    if (proc == null) return;
    proc.kill();
    await _out?.cancel();
  }

  /// Pede para sair; se não sair em 2 s, finaliza.
  Future<void> close() async {
    final proc = _process;
    if (proc == null) return;
    try {
      proc.stdin.add(utf8.encode('-stay_open\nFalse\n'));
      await proc.stdin.flush();
      await proc.stdin.close();
      await proc.exitCode.timeout(const Duration(seconds: 2));
    } on Object {
      proc.kill();
    }
    _process = null;
    await _out?.cancel();
  }
}

/// ffprobe (ADR 0005): um processo por vídeo, só leitura.
class Ffprobe {
  Ffprobe(this.executable, {this.timeout = const Duration(seconds: 30)});
  final String executable;
  final Duration timeout;

  static const args = ['-v', 'error', '-print_format', 'json', '-show_format', '-show_streams'];

  Future<ExtractResult> probe(String path) async {
    Process? proc;
    try {
      proc = await Process.start(executable, [...args, path]);
      final out = proc.stdout.transform(utf8.decoder).join();
      final err = proc.stderr.transform(utf8.decoder).join();
      // Travou (arquivo estranho): finaliza em vez de deixar o processo solto.
      final code = await proc.exitCode.timeout(timeout);
      if (code != 0) {
        final e = (await err).trim();
        return ExtractResult.failed(e.isEmpty ? 'O ffprobe não leu o vídeo.' : e.split('\n').first);
      }
      return ExtractResult.ok(ExtractedMetadata.fromFfprobe(jsonDecode(await out) as Map<String, Object?>));
    } on Object catch (e) {
      proc?.kill();
      return ExtractResult.failed('Falha ao ler o vídeo: $e');
    }
  }
}
