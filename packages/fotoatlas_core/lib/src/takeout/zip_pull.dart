import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';

import '../platform/win_fs.dart';
import '../safe_io/dest_writer.dart';

/// Separador entre o caminho do zip e o da entrada no diário
/// (`Downloads/takeout-001.zip:Takeout/Google Fotos/IMG_1.JPG`). Nomes do
/// Windows não têm `:`, então não há confusão com um arquivo comum.
const zipEntrySeparator = ':';

/// `(zip, entrada)` de um caminho de item do diário; `null` se for arquivo comum.
(String, String)? splitZipEntry(String srcRelPath) {
  final i = srcRelPath.indexOf(zipEntrySeparator);
  if (i < 0) return null;
  return (srcRelPath.substring(0, i), srcRelPath.substring(i + 1));
}

sealed class ZipPullResult {
  const ZipPullResult();
}

class ZipPullDone extends ZipPullResult {
  const ZipPullDone(this.sha256, this.bytes);
  final Uint8List sha256;
  final int bytes;
}

class ZipPullFailed extends ZipPullResult {
  const ZipPullFailed(this.code, this.message);

  /// `entry_missing`, `zip_crc` ou `read_error`.
  final String code;
  final String message;
}

/// Descompacta a entrada [entry] do zip [zipPath] (aberto **só para leitura**)
/// para o `.part` novo [partPath], calculando o SHA-256 e conferindo o CRC-32
/// do zip. Roda num isolate próprio (descompactar usa CPU).
Future<ZipPullResult> pullZipEntry(String zipPath, String entry, String partPath) =>
    Isolate.run(() => pullZipEntrySync(zipPath, entry, partPath));

ZipPullResult pullZipEntrySync(String zipPath, String entry, String partPath) {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final file = archive.findFile(entry);
    if (file == null || !file.isFile) {
      return const ZipPullFailed('entry_missing', 'O arquivo não está mais dentro do zip.');
    }
    final writer = PartWriter.create(partPath);
    final sink = _PartSink(writer);
    try {
      file.writeContent(sink);
      sink.flush();
      writer.flush();
    } finally {
      sink.free();
      writer.close();
    }
    final digest = sink.finish();
    if (file.crc32 != null && file.crc32 != sink.crc) {
      return const ZipPullFailed('zip_crc', 'O conteúdo dentro do zip está danificado (o CRC não confere).');
    }
    return ZipPullDone(digest, sink.length);
  } on Win32Exception catch (e) {
    return ZipPullFailed('read_error', 'Não foi possível gravar no destino: $e');
  } on Object catch (e) {
    return ZipPullFailed('read_error', 'Não foi possível ler o zip: $e');
  } finally {
    input.closeSync();
  }
}

/// Saída do descompactador que vai direto para o `.part` (em blocos), com o
/// SHA-256 e o CRC-32 calculados no caminho.
class _PartSink extends OutputStream {
  _PartSink(this._writer) : super(byteOrder: ByteOrder.littleEndian);

  final PartWriter _writer;
  static const _chunk = 1 << 20;
  final _buffer = calloc<Uint8>(_chunk);
  var _used = 0;
  var _length = 0;
  int crc = 0;
  final _digest = _DigestSink();
  late final _hash = sha256.startChunkedConversion(_digest);

  @override
  int get length => _length;

  @override
  void clear() {}

  @override
  void flush() {
    if (_used == 0) return;
    _writer.write(_buffer, _used);
    _used = 0;
  }

  @override
  void writeByte(int value) => writeBytes([value]);

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final n = length ?? bytes.length;
    final data = bytes is Uint8List ? Uint8List.sublistView(bytes, 0, n) : Uint8List.fromList(bytes.sublist(0, n));
    _hash.add(data);
    crc = getCrc32(data, crc);
    _length += n;
    var offset = 0;
    while (offset < n) {
      final take = (n - offset) < (_chunk - _used) ? n - offset : _chunk - _used;
      _buffer.asTypedList(_chunk).setRange(_used, _used + take, data, offset);
      _used += take;
      offset += take;
      if (_used == _chunk) flush();
    }
  }

  /// Os bytes já foram para o disco: o inflate não pede de volta (tem a própria janela).
  @override
  Uint8List subset(int start, [int? end]) => throw UnsupportedError('saída gravada direto no .part');

  @override
  void writeStream(InputStream stream) => writeBytes(stream.toUint8List());

  Uint8List finish() {
    _hash.close();
    return Uint8List.fromList(_digest.value!.bytes);
  }

  void free() => calloc.free(_buffer);
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
