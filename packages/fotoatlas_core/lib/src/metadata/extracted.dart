import 'capture_date.dart';

/// Metadados lidos de um arquivo (ExifTool e/ou ffprobe), antes da escolha
/// da data. Campos `null` = o arquivo não tinha.
class ExtractedMetadata {
  ExtractedMetadata({
    this.exifDate,
    this.videoDate,
    this.make,
    this.model,
    this.lens,
    this.serial,
    this.iso,
    this.aperture,
    this.exposureS,
    this.focalMm,
    this.width,
    this.height,
    this.orientation,
    this.lat,
    this.lon,
    this.durationMs,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
    this.software,
  });

  DateCandidate? exifDate;
  DateCandidate? videoDate;
  String? make;
  String? model;
  String? lens;
  String? serial;
  int? iso;
  double? aperture;
  double? exposureS;
  double? focalMm;
  int? width;
  int? height;
  int? orientation;
  double? lat;
  double? lon;
  int? durationMs;
  double? fps;
  String? videoCodec;
  String? audioCodec;
  int? bitrate;
  String? software;

  /// Junta [other] (ex.: ffprobe) só onde este não tem valor.
  void fillFrom(ExtractedMetadata other) {
    exifDate ??= other.exifDate;
    videoDate ??= other.videoDate;
    make ??= other.make;
    model ??= other.model;
    lens ??= other.lens;
    serial ??= other.serial;
    iso ??= other.iso;
    aperture ??= other.aperture;
    exposureS ??= other.exposureS;
    focalMm ??= other.focalMm;
    width ??= other.width;
    height ??= other.height;
    orientation ??= other.orientation;
    lat ??= other.lat;
    lon ??= other.lon;
    durationMs ??= other.durationMs;
    fps ??= other.fps;
    videoCodec ??= other.videoCodec;
    audioCodec ??= other.audioCodec;
    bitrate ??= other.bitrate;
    software ??= other.software;
  }

  /// Monta a partir de um objeto do `exiftool -json -n -G1`.
  factory ExtractedMetadata.fromExifTool(Map<String, Object?> j) {
    Object? pick(List<String> keys) {
      for (final k in keys) {
        if (k.contains(':')) {
          final v = j[k];
          if (v != null && v != '') return v;
          continue;
        }
        // Sem grupo: qualquer grupo com esse tag.
        for (final e in j.entries) {
          if (e.key.endsWith(':$k') && e.value != null && e.value != '') return e.value;
        }
      }
      return null;
    }

    String? str(List<String> keys) {
      final v = pick(keys);
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    double? number(List<String> keys) {
      final v = pick(keys);
      if (v is num) return v.toDouble();
      return v == null ? null : double.tryParse(v.toString().split(' ').first);
    }

    int? integer(List<String> keys) => number(keys)?.round();

    // Foto: DateTimeOriginal (+ subsegundos e fuso do EXIF).
    DateCandidate? exif;
    for (final (tag, sub, off) in [
      ('ExifIFD:DateTimeOriginal', 'ExifIFD:SubSecTimeOriginal', 'ExifIFD:OffsetTimeOriginal'),
      ('ExifIFD:CreateDate', 'ExifIFD:SubSecTimeDigitized', 'ExifIFD:OffsetTimeDigitized'),
      ('XMP-exif:DateTimeOriginal', null, null),
      ('XMP-photoshop:DateCreated', null, null),
    ]) {
      final d = parseExifDate(
        str([tag]),
        subSec: sub == null ? null : str([sub]),
        offset: off == null ? null : (str([off]) ?? str(['ExifIFD:OffsetTime'])),
      );
      if (d != null) {
        exif = DateCandidate(source: DateSource.exifOriginal, wall: d.wall, offsetMin: d.offsetMin, detail: tag);
        break;
      }
    }

    // Vídeo: Keys:CreationDate (Apple, com fuso) > QuickTime CreateDate (UTC) >
    // datas de faixa (UTC) > RIFF (AVI, hora local) > Matroska (UTC).
    DateCandidate? video;
    final keys = parseExifDate(str(['Keys:CreationDate', 'UserData:CreationDate']));
    if (keys != null && keys.offsetMin != null) {
      video = DateCandidate(
        source: DateSource.videoInternal,
        wall: keys.wall,
        offsetMin: keys.offsetMin,
        detail: 'Keys:CreationDate',
      );
    } else {
      for (final tag in ['QuickTime:CreateDate', 'QuickTime:MediaCreateDate', 'QuickTime:TrackCreateDate']) {
        final d = parseExifDate(str([tag]));
        if (d != null) {
          video = DateCandidate(
            source: DateSource.videoInternal,
            utcMs: d.wall.millisecondsSinceEpoch - (d.offsetMin ?? 0) * 60000,
            detail: tag,
          );
          break;
        }
      }
      if (video == null) {
        final riff = parseExifDate(str(['RIFF:DateTimeOriginal']));
        final mkv = parseExifDate(str(['Matroska:DateTimeOriginal']));
        if (riff != null) {
          video = DateCandidate(source: DateSource.videoInternal, wall: riff.wall, offsetMin: riff.offsetMin);
        } else if (mkv != null) {
          video = DateCandidate(
            source: DateSource.videoInternal,
            utcMs: mkv.wall.millisecondsSinceEpoch - (mkv.offsetMin ?? 0) * 60000,
          );
        }
      }
    }

    final durationS = number(['QuickTime:Duration', 'Composite:Duration', 'Duration']);
    final lat = number(['Composite:GPSLatitude']);
    final lon = number(['Composite:GPSLongitude']);
    return ExtractedMetadata(
      exifDate: exif,
      videoDate: video,
      make: str(['IFD0:Make', 'Make']),
      model: str(['IFD0:Model', 'Model']),
      lens: str(['ExifIFD:LensModel', 'LensModel', 'Lens']),
      serial: str(['ExifIFD:SerialNumber', 'SerialNumber', 'InternalSerialNumber']),
      iso: integer(['ExifIFD:ISO', 'ISO']),
      aperture: number(['ExifIFD:FNumber', 'FNumber']),
      exposureS: number(['ExifIFD:ExposureTime', 'ExposureTime']),
      focalMm: number(['ExifIFD:FocalLength', 'FocalLength']),
      width: integer(['ExifIFD:ExifImageWidth', 'File:ImageWidth', 'ImageWidth']),
      height: integer(['ExifIFD:ExifImageHeight', 'File:ImageHeight', 'ImageHeight']),
      orientation: integer(['IFD0:Orientation', 'Orientation']),
      // (0, 0) costuma ser "sem GPS" gravado pela câmera.
      lat: lat == 0 && lon == 0 ? null : lat,
      lon: lat == 0 && lon == 0 ? null : lon,
      durationMs: durationS == null ? null : (durationS * 1000).round(),
      fps: number(['VideoFrameRate']),
      videoCodec: str(['CompressorID']),
      audioCodec: str(['AudioFormat']),
      bitrate: integer(['AvgBitrate']),
      software: str(['IFD0:Software', 'Software']),
    );
  }

  /// Monta a partir do `ffprobe -print_format json -show_format -show_streams`.
  factory ExtractedMetadata.fromFfprobe(Map<String, Object?> j) {
    final streams = (j['streams'] as List<Object?>? ?? const []).cast<Map<String, Object?>>();
    final format = (j['format'] as Map<String, Object?>?) ?? const {};
    // Capa embutida (attached_pic) não é o vídeo.
    final v = streams
        .where((s) => s['codec_type'] == 'video' && (s['disposition'] as Map?)?['attached_pic'] != 1)
        .firstOrNull;
    final a = streams.where((s) => s['codec_type'] == 'audio').firstOrNull;
    double? fps(String? r) {
      if (r == null) return null;
      final parts = r.split('/');
      if (parts.length != 2) return double.tryParse(r);
      final n = double.tryParse(parts[0]), d = double.tryParse(parts[1]);
      return n == null || d == null || d == 0 ? null : n / d;
    }

    final tags = (format['tags'] as Map<String, Object?>?) ?? const {};
    final created = tags['creation_time'] as String?;
    final createdAt = created == null ? null : DateTime.tryParse(created);
    final duration = double.tryParse('${format['duration'] ?? v?['duration'] ?? ''}');
    return ExtractedMetadata(
      videoDate: createdAt == null || createdAt.year < 1971
          ? null
          : DateCandidate(
              source: DateSource.videoInternal,
              utcMs: createdAt.toUtc().millisecondsSinceEpoch,
              detail: 'ffprobe:creation_time',
            ),
      width: v?['width'] as int?,
      height: v?['height'] as int?,
      durationMs: duration == null ? null : (duration * 1000).round(),
      fps: fps(v?['avg_frame_rate'] as String?) ?? fps(v?['r_frame_rate'] as String?),
      videoCodec: v?['codec_name'] as String?,
      audioCodec: a?['codec_name'] as String?,
      bitrate: int.tryParse('${format['bit_rate'] ?? ''}'),
    );
  }
}
