import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../catalog/catalog_database.dart';
import '../devices/devices.dart';
import '../helper/helper_client.dart';
import '../metadata/external_tools.dart';
import '../safe_io/source_reader.dart';
import '../sources/sources_service.dart';
import '../util/uuid.dart';

/// Miniaturas em cache (`%LOCALAPPDATA%\FotoAtlas\thumbs`, descartável).
///
/// Ordem: Shell do Windows pelo helper (os mesmos codecs do Explorador) →
/// FFmpeg para vídeos → miniatura embutida no EXIF (fotos, inclusive do
/// celular, lendo só o começo do arquivo). A origem só é lida; o cache é a
/// única pasta gravada, sempre num arquivo novo e depois renomeado.
class ThumbnailService {
  ThumbnailService(this.db, this.sources, {required this.cacheDir, this.helper, this.tools = ExternalTools.none})
    : assert(cacheDir.isNotEmpty);

  final CatalogDatabase db;
  final SourcesService sources;
  final String cacheDir;
  final HelperClient? helper;
  final ExternalTools tools;

  static const size = 256;
  static const _concurrency = 3;

  final Map<int, Future<String?>> _inflight = {};
  final Set<int> _failed = {};
  int _running = 0;
  final _waiting = <Completer<void>>[];
  bool _closed = false;

  /// Caminho do arquivo da miniatura (pode ainda não existir).
  String pathFor(String sha256Hex) => p.join(cacheDir, sha256Hex.substring(0, 2), '${sha256Hex}_$size.jpg');

  /// Miniatura do conteúdo (gera se preciso); `null` se não deu.
  Future<String?> thumbnail(int contentId) {
    if (_failed.contains(contentId) || _closed) return Future.value();
    // Bloco (não seta): devolver o futuro removido faria o whenComplete esperar por ele mesmo.
    return _inflight[contentId] ??= _generate(contentId).whenComplete(() {
      _inflight.remove(contentId);
    });
  }

  /// Esquece as falhas (ex.: um dispositivo conectou).
  void retryFailed() => _failed.clear();

  Future<String?> _generate(int contentId) async {
    final row = await db
        .customSelect(
          'SELECT hex(sha256) AS sha, media_type FROM contents WHERE id = ?',
          variables: [Variable.withInt(contentId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final sha = row.read<String>('sha').toLowerCase();
    final media = row.read<String>('media_type');
    final target = pathFor(sha);
    if (File(target).existsSync()) return target;

    await _slot();
    try {
      if (File(target).existsSync()) return target;
      Directory(p.dirname(target)).createSync(recursive: true);
      final instances = await db
          .customSelect(
            "SELECT fi.source_id, fi.rel_path, fi.ext, fi.device_object_id, s.kind FROM file_instances fi "
            "JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL "
            "WHERE fi.content_id = ? AND fi.availability = 'present' AND fi.hash_status = 'done' ORDER BY s.kind = 'phone', fi.id",
            variables: [Variable.withInt(contentId)],
          )
          .get();
      for (final i in instances) {
        if (_closed) break;
        final sourceId = i.read<String>('source_id');
        final rel = i.read<String>('rel_path');
        if (i.read<String>('kind') == 'phone') {
          if (media == 'video') continue;
          final ok = await _fromPhone(
            sourceId,
            rel,
            i.read<String>('ext'),
            i.readNullable<String>('device_object_id'),
            target,
          );
          if (ok) return target;
          continue;
        }
        final src = await sources.byId(sourceId);
        final root = src == null ? null : sources.accessRoot(src);
        if (root == null) continue;
        final path = '${root.endsWith(r'\') ? root.substring(0, root.length - 1) : root}\\${rel.replaceAll('/', r'\')}';
        if (await _fromShell(path, target)) return target;
        if (media == 'video' && await _fromFfmpeg(path, target)) return target;
        if (media != 'video' && await _fromExifLocal(path, target)) return target;
      }
      _failed.add(contentId);
      return null;
    } on Object {
      _failed.add(contentId);
      return null;
    } finally {
      _release();
    }
  }

  String _tmp(String target) => '$target.${uuidV4().substring(0, 8)}.tmp';

  /// Publica o temporário no nome final (outro pedido pode ter chegado antes).
  bool _publish(String tmp, String target) {
    try {
      if (File(target).existsSync()) {
        File(tmp).deleteSync();
        return true;
      }
      File(tmp).renameSync(target);
      return true;
    } on FileSystemException {
      _delete(tmp);
      return File(target).existsSync();
    }
  }

  void _delete(String path) {
    assert(p.isWithin(cacheDir, path));
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // Sobra no cache (descartável).
    }
  }

  Future<bool> _fromShell(String path, String target) async {
    final h = helper;
    if (h == null || h.status == HelperStatus.stopped) return false;
    final tmp = _tmp(target);
    try {
      await h.call(
        'thumbnails.get',
        params: {'path': path, 'outPath': tmp, 'size': size},
        timeout: const Duration(seconds: 30),
      );
      return _publish(tmp, target);
    } on HelperException {
      _delete(tmp);
      return false;
    }
  }

  Future<bool> _fromFfmpeg(String path, String target) async {
    final exe = tools.ffmpeg;
    if (exe == null) return false;
    for (final at in ['1', '0']) {
      final tmp = _tmp(target);
      Process? proc;
      try {
        // -n: nunca sobrescreve; a saída é sempre um arquivo novo no cache.
        proc = await Process.start(exe, [
          '-v',
          'error',
          '-n',
          '-ss',
          at,
          '-i',
          path,
          '-frames:v',
          '1',
          '-vf',
          'scale=$size:$size:force_original_aspect_ratio=decrease',
          '-q:v',
          '5',
          '-f',
          'mjpeg',
          tmp,
        ]);
        unawaited(proc.stdout.drain<void>());
        unawaited(proc.stderr.drain<void>());
        final code = await proc.exitCode.timeout(const Duration(seconds: 30));
        if (code == 0 && File(tmp).existsSync() && File(tmp).lengthSync() > 0) return _publish(tmp, target);
      } on Object {
        proc?.kill();
      }
      _delete(tmp);
    }
    return false;
  }

  /// Miniatura embutida no EXIF, lendo só o começo do arquivo (somente leitura).
  Future<bool> _fromExifLocal(String path, String target) async {
    final head = _readHead(path, 256 * 1024);
    final thumb = head == null ? null : exifThumbnail(head);
    if (thumb == null) return false;
    final tmp = _tmp(target);
    File(tmp).writeAsBytesSync(thumb, flush: true);
    return _publish(tmp, target);
  }

  static Uint8List? _readHead(String path, int max) {
    SourceFile? f;
    final buf = calloc<Uint8>(max);
    try {
      f = SourceFile.open(path);
      var total = 0;
      while (total < max) {
        final n = f.read(buf + total, max - total);
        if (n == 0) break;
        total += n;
      }
      return Uint8List.fromList(buf.asTypedList(total));
    } on Object {
      return null;
    } finally {
      f?.close();
      calloc.free(buf);
    }
  }

  Future<bool> _fromPhone(String sourceId, String relPath, String ext, String? objectId, String target) async {
    final backend = sources.devices;
    final device = sources.deviceFor(sourceId);
    if (backend == null || device == null || !device.isReady) return false;
    final head = '${_tmp(target)}.$ext';
    try {
      final resolver = PhonePathResolver(backend, device.deviceId);
      for (var attempt = 0; attempt < 2; attempt++) {
        final id = attempt == 0 ? objectId : await resolver.file(relPath);
        if (id == null) continue;
        try {
          await backend.readHead(device.deviceId, id, head, maxBytes: 256 * 1024);
          break;
        } on DeviceException catch (e) {
          _delete(head);
          if (e.code != 'not_found') return false;
        }
      }
      if (!File(head).existsSync()) return false;
      final thumb = exifThumbnail(File(head).readAsBytesSync());
      if (thumb == null) return false;
      final tmp = _tmp(target);
      File(tmp).writeAsBytesSync(thumb, flush: true);
      return _publish(tmp, target);
    } on Object {
      return false;
    } finally {
      _delete(head);
    }
  }

  Future<void> _slot() async {
    if (_running < _concurrency) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  void close() {
    _closed = true;
    for (final c in _waiting) {
      c.complete();
    }
    _waiting.clear();
  }
}

/// Miniatura JPEG embutida no EXIF (IFD1) de um JPEG; `null` se não houver.
Uint8List? exifThumbnail(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) return null;
  var i = 2;
  while (i + 4 <= jpeg.length) {
    if (jpeg[i] != 0xFF) return null;
    final marker = jpeg[i + 1];
    if (marker == 0xDA || marker == 0xD9) return null; // começo da imagem: sem APP1 antes
    final len = (jpeg[i + 2] << 8) | jpeg[i + 3];
    final start = i + 4;
    if (marker == 0xE1 &&
        start + 6 <= jpeg.length &&
        String.fromCharCodes(jpeg.sublist(start, start + 4)) == 'Exif' &&
        jpeg[start + 4] == 0 &&
        jpeg[start + 5] == 0) {
      final end = (start + len - 2).clamp(0, jpeg.length);
      return _thumbFromTiff(ByteData.sublistView(jpeg, start + 6, end));
    }
    i = start + len - 2;
  }
  return null;
}

Uint8List? _thumbFromTiff(ByteData t) {
  if (t.lengthInBytes < 8) return null;
  final Endian e;
  if (t.getUint8(0) == 0x49 && t.getUint8(1) == 0x49) {
    e = Endian.little;
  } else if (t.getUint8(0) == 0x4D && t.getUint8(1) == 0x4D) {
    e = Endian.big;
  } else {
    return null;
  }
  int u16(int o) => t.getUint16(o, e);
  int u32(int o) => t.getUint32(o, e);
  bool ok(int o, int n) => o >= 0 && o + n <= t.lengthInBytes;
  final ifd0 = u32(4);
  if (!ok(ifd0, 2)) return null;
  final n0 = u16(ifd0);
  final nextAt = ifd0 + 2 + n0 * 12;
  if (!ok(nextAt, 4)) return null;
  final ifd1 = u32(nextAt);
  if (ifd1 == 0 || !ok(ifd1, 2)) return null;
  final n1 = u16(ifd1);
  int? offset, length;
  for (var k = 0; k < n1; k++) {
    final entry = ifd1 + 2 + k * 12;
    if (!ok(entry, 12)) return null;
    final tag = u16(entry);
    final value = u32(entry + 8);
    if (tag == 0x0201) offset = value;
    if (tag == 0x0202) length = value;
  }
  if (offset == null || length == null || length <= 0 || !ok(offset, length)) return null;
  final bytes = Uint8List.sublistView(t, offset, offset + length);
  if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  return Uint8List.fromList(bytes);
}
