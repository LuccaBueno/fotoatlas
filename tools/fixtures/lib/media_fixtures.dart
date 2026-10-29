/// Mídia sintética com metadados (Fase 4): JPEG com EXIF montado byte a byte
/// e MP4 mínimo com a data interna do QuickTime. Nada vem de fotos reais.
library;

import 'dart:convert';
import 'dart:typed_data';

/// JPEGs base 32×24 de uma cor só (gerados uma vez com o FFmpeg, sem metadados).
const _baseJpegs = [
  '/9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAgQEBMQExYWFhYWFhoYGhsbGxoaGhobGxsdHR0iIiIdHR0bGx0dICAiIiUmJSMjIiMmJigoKDAwLi44ODpFRVP/xABMAAEBAAAAAAAAAAAAAAAAAAAABAEBAQAAAAAAAAAAAAAAAAAAAAYQAQAAAAAAAAAAAAAAAAAAAAARAQAAAAAAAAAAAAAAAAAAAAD/wAARCAAYACADASIAAhEAAxEA/9oADAMBAAIRAxEAPwCEBbpcAAAAAB//2Q==',
  '/9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAgQEBMQExYWFhYWFhoYGhsbGxoaGhobGxsdHR0iIiIdHR0bGx0dICAiIiUmJSMjIiMmJigoKDAwLi44ODpFRVP/xABNAAEBAAAAAAAAAAAAAAAAAAAABQEBAQEAAAAAAAAAAAAAAAAAAAUGEAEAAAAAAAAAAAAAAAAAAAAAEQEAAAAAAAAAAAAAAAAAAAAA/8AAEQgAGAAgAwEiAAIRAAMRAP/aAAwDAQACEQMRAD8AqgIDagAAAAAP/9k=',
  '/9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAgQEBMQExYWFhYWFhoYGhsbGxoaGhobGxsdHR0iIiIdHR0bGx0dICAiIiUmJSMjIiMmJigoKDAwLi44ODpFRVP/xABNAAEBAAAAAAAAAAAAAAAAAAAABgEBAQEAAAAAAAAAAAAAAAAAAAMFEAEAAAAAAAAAAAAAAAAAAAAAEQEAAAAAAAAAAAAAAAAAAAAA/8AAEQgAGAAgAwEiAAIRAAMRAP/aAAwDAQACEQMRAD8AoQE2QAAAAAA//9k=',
  '/9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAgQEBMQExYWFhYWFhoYGhsbGxoaGhobGxsdHR0iIiIdHR0bGx0dICAiIiUmJSMjIiMmJigoKDAwLi44ODpFRVP/xABNAAEBAAAAAAAAAAAAAAAAAAAABwEBAQEAAAAAAAAAAAAAAAAAAAUGEAEAAAAAAAAAAAAAAAAAAAAAEQEAAAAAAAAAAAAAAAAAAAAA/8AAEQgAGAAgAwEiAAIRAAMRAP/aAAwDAQACEQMRAD8AqADNK4AAAAAD/9k=',
];

/// JPEG base (sem EXIF) de uma das 4 cores.
Uint8List baseJpeg([int color = 0]) => base64Decode(_baseJpegs[color % _baseJpegs.length]);

/// O que vai no EXIF. Datas são a hora do relógio da câmera (sem fuso).
class ExifSpec {
  const ExifSpec({
    this.dateTimeOriginal,
    this.subSecMs,
    this.offset,
    this.make,
    this.model,
    this.serial,
    this.lat,
    this.lon,
    this.orientation = 1,
    this.thumbnail = true,
    this.color = 0,
    this.uniqueId,
  });

  /// Lida como hora local da câmera (os campos de [DateTime] são usados tal como estão).
  final DateTime? dateTimeOriginal;
  final int? subSecMs;

  /// `OffsetTimeOriginal`, ex.: '-03:00'.
  final String? offset;
  final String? make;
  final String? model;

  /// `BodySerialNumber`.
  final String? serial;
  final double? lat;
  final double? lon;
  final int orientation;

  /// Miniatura embutida (IFD1), como a de celulares e câmeras.
  final bool thumbnail;
  final int color;

  /// `ImageUniqueID`: deixa o conteúdo diferente mesmo com o resto igual.
  final String? uniqueId;
}

/// JPEG com segmento APP1/EXIF logo depois do SOI.
Uint8List jpegWithExif(ExifSpec spec) {
  final base = baseJpeg(spec.color);
  final tiff = _tiff(spec);
  final app1 = BytesBuilder()
    ..add([0xFF, 0xE1])
    ..add(_be16(2 + 6 + tiff.length))
    ..add(ascii.encode('Exif'))
    ..add([0, 0])
    ..add(tiff);
  return (BytesBuilder()
        ..add(base.sublist(0, 2))
        ..add(app1.takeBytes())
        ..add(base.sublist(2)))
      .takeBytes();
}

String _exifDate(DateTime d) =>
    '${_p(d.year, 4)}:${_p(d.month)}:${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}:${_p(d.second)}';

String _p(int v, [int w = 2]) => v.toString().padLeft(w, '0');

Uint8List _tiff(ExifSpec s) {
  final ifd0 = <_Entry>[
    if (s.make != null) _Entry.ascii(0x010F, s.make!),
    if (s.model != null) _Entry.ascii(0x0110, s.model!),
    _Entry.shorts(0x0112, [s.orientation]),
  ];
  final exif = <_Entry>[
    if (s.dateTimeOriginal != null) _Entry.ascii(0x9003, _exifDate(s.dateTimeOriginal!)),
    if (s.dateTimeOriginal != null) _Entry.ascii(0x9004, _exifDate(s.dateTimeOriginal!)),
    if (s.offset != null) _Entry.ascii(0x9011, s.offset!),
    if (s.subSecMs != null) _Entry.ascii(0x9291, _p(s.subSecMs!, 3)),
    if (s.uniqueId != null) _Entry.ascii(0xA420, s.uniqueId!),
    if (s.serial != null) _Entry.ascii(0xA431, s.serial!),
  ];
  final gps = <_Entry>[
    if (s.lat != null) ...[
      _Entry.ascii(0x0001, s.lat! < 0 ? 'S' : 'N'),
      _Entry.rationals(0x0002, _dms(s.lat!.abs())),
      _Entry.ascii(0x0003, s.lon! < 0 ? 'W' : 'E'),
      _Entry.rationals(0x0004, _dms(s.lon!.abs())),
    ],
  ];
  final thumb = s.thumbnail ? baseJpeg(s.color + 1) : null;
  final ifd1 = <_Entry>[
    if (thumb != null) ...[
      _Entry.shorts(0x0103, [6]),
      _Entry.longs(0x0201, [0]), // offset preenchido abaixo
      _Entry.longs(0x0202, [thumb.length]),
    ],
  ];
  // Ponteiros para as sub-IFDs (valores preenchidos depois de saber os tamanhos).
  final exifPtr = _Entry.longs(0x8769, [0]);
  final gpsPtr = _Entry.longs(0x8825, [0]);
  ifd0
    ..add(exifPtr)
    ..addAll(gps.isEmpty ? const [] : [gpsPtr])
    ..sort((a, b) => a.tag.compareTo(b.tag));

  var offset = 8;
  final ifd0At = offset;
  offset += _Entry.ifdSize(ifd0);
  final exifAt = offset;
  offset += _Entry.ifdSize(exif);
  final gpsAt = offset;
  if (gps.isNotEmpty) offset += _Entry.ifdSize(gps);
  final ifd1At = ifd1.isEmpty ? 0 : offset;
  if (ifd1.isNotEmpty) offset += _Entry.ifdSize(ifd1);
  final thumbAt = offset;
  exifPtr.values = [exifAt];
  gpsPtr.values = [gpsAt];
  if (thumb != null) ifd1[1].values = [thumbAt];

  final out = BytesBuilder()
    ..add(ascii.encode('II'))
    ..add(_le16(42))
    ..add(_le32(ifd0At))
    ..add(_Entry.encodeIfd(ifd0, ifd0At, ifd1At))
    ..add(_Entry.encodeIfd(exif, exifAt, 0));
  if (gps.isNotEmpty) out.add(_Entry.encodeIfd(gps, gpsAt, 0));
  if (ifd1.isNotEmpty) out.add(_Entry.encodeIfd(ifd1, ifd1At, 0));
  if (thumb != null) out.add(thumb);
  return out.takeBytes();
}

List<(int, int)> _dms(double v) {
  final d = v.floor();
  final mFull = (v - d) * 60;
  final m = mFull.floor();
  final s = ((mFull - m) * 60 * 1000).round();
  return [(d, 1), (m, 1), (s, 1000)];
}

class _Entry {
  _Entry(this.tag, this.type, this.values, this.text);
  _Entry.ascii(int tag, String text) : this(tag, 2, const [], text);
  _Entry.shorts(int tag, List<int> v) : this(tag, 3, v, null);
  _Entry.longs(int tag, List<int> v) : this(tag, 4, v, null);
  _Entry.rationals(int tag, List<(int, int)> v)
    : this(tag, 5, [
        for (final r in v) ...[r.$1, r.$2],
      ], null);

  final int tag;
  final int type;
  List<int> values;
  final String? text;

  int get count => switch (type) {
    2 => ascii.encode(text!).length + 1,
    5 => values.length ~/ 2,
    _ => values.length,
  };

  Uint8List get data {
    final b = BytesBuilder();
    switch (type) {
      case 2:
        b
          ..add(ascii.encode(text!))
          ..addByte(0);
      case 3:
        for (final v in values) {
          b.add(_le16(v));
        }
      default:
        for (final v in values) {
          b.add(_le32(v));
        }
    }
    return b.takeBytes();
  }

  static int _padded(int n) => n + (n.isOdd ? 1 : 0);

  static int ifdSize(List<_Entry> entries) =>
      2 + 12 * entries.length + 4 + entries.fold(0, (a, e) => a + (e.data.length > 4 ? _padded(e.data.length) : 0));

  static Uint8List encodeIfd(List<_Entry> entries, int at, int next) {
    final head = BytesBuilder()..add(_le16(entries.length));
    final tail = BytesBuilder();
    var dataAt = at + 2 + 12 * entries.length + 4;
    for (final e in entries) {
      final d = e.data;
      head
        ..add(_le16(e.tag))
        ..add(_le16(e.type))
        ..add(_le32(e.count));
      if (d.length <= 4) {
        head.add([...d, ...List.filled(4 - d.length, 0)]);
      } else {
        head.add(_le32(dataAt));
        tail.add(d);
        if (d.length.isOdd) tail.addByte(0);
        dataAt += _padded(d.length);
      }
    }
    head
      ..add(_le32(next))
      ..add(tail.takeBytes());
    return head.takeBytes();
  }
}

List<int> _le16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _le32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
List<int> _be16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
List<int> _be32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

/// MP4 mínimo (ftyp + moov/mvhd) com a data de criação em UTC, como gravam
/// celulares e câmeras (QuickTime `CreateDate`). [salt] muda o conteúdo.
Uint8List mp4WithCreationTime(DateTime utc, {int durationMs = 3000, int salt = 0}) {
  final secs = utc.toUtc().difference(DateTime.utc(1904)).inSeconds;
  List<int> box(String type, List<int> body) => [..._be32(8 + body.length), ...ascii.encode(type), ...body];
  final mvhd = box('mvhd', [
    0, 0, 0, 0, // versão 0 + flags
    ..._be32(secs), // creation_time
    ..._be32(secs), // modification_time
    ..._be32(1000), // timescale
    ..._be32(durationMs),
    0, 1, 0, 0, // rate 1.0
    1, 0, // volume 1.0
    ...List.filled(10, 0), // reservado
    // matriz identidade
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0x40, 0, 0, 0,
    ...List.filled(24, 0), // pre_defined
    ..._be32(2), // next_track_ID
  ]);
  final free = box('free', _be32(salt));
  return Uint8List.fromList([
    ...box('ftyp', [...ascii.encode('isom'), ..._be32(0x200), ...ascii.encode('isomiso2mp41')]),
    ...box('moov', mvhd),
    ...free,
  ]);
}
