import 'dart:convert';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// De onde veio a data da captura (spec §8), na ordem padrão de prioridade.
enum DateSource {
  manual('manual'),
  exifOriginal('exif_original'),
  videoInternal('video_internal'),
  filename('filename'),
  filesystem('filesystem'),
  none('none');

  const DateSource(this.sql);
  final String sql;

  static DateSource fromSql(String? s) => values.firstWhere((v) => v.sql == s, orElse: () => none);

  /// Ordem padrão (a correção manual fica sempre acima de todas).
  static const defaultPriority = [exifOriginal, videoInternal, filename, filesystem];
}

/// Confiança da hora (spec §8.1).
enum DateConfidence {
  high,
  medium,
  low,
  none;

  static DateConfidence fromSql(String? s) => values.firstWhere((v) => v.name == s, orElse: () => none);
}

/// Hora "de relógio" (sem fuso), como a pessoa viveu. Guardada num
/// [DateTime] UTC só para aproveitar a aritmética de calendário.
typedef WallTime = DateTime;

WallTime wallTime(int y, [int mo = 1, int d = 1, int h = 0, int mi = 0, int s = 0, int ms = 0]) =>
    DateTime.utc(y, mo, d, h, mi, s, ms);

/// 'AAAA-MM-DDTHH:MM:SS' (+ '.mmm' quando houver subsegundos).
String formatWall(WallTime w) {
  String p(int v, [int n = 2]) => v.toString().padLeft(n, '0');
  final base = '${p(w.year, 4)}-${p(w.month)}-${p(w.day)}T${p(w.hour)}:${p(w.minute)}:${p(w.second)}';
  return w.millisecond == 0 ? base : '$base.${p(w.millisecond, 3)}';
}

WallTime? parseWall(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.(\d{1,3}))?$').firstMatch(s);
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  final ms = m.group(7) == null ? 0 : int.parse(m.group(7)!.padRight(3, '0'));
  return wallTime(g(1), g(2), g(3), g(4), g(5), g(6), ms);
}

/// Fusos horários (base IANA embutida no pacote `timezone`, ADR 0014).
abstract final class TimeZones {
  static bool _ready = false;
  static const defaultZone = 'America/Sao_Paulo';

  static tz.Location location(String name) {
    if (!_ready) {
      tzdata.initializeTimeZones();
      _ready = true;
    }
    return tz.getLocation(name);
  }

  static bool isValid(String name) {
    try {
      location(name);
      return true;
    } on Object {
      return false;
    }
  }

  /// Instante (UTC ms) e deslocamento (min) de uma hora local na zona [zone].
  /// Na hora que "não existe" (início do horário de verão), o pacote avança.
  static ({int utcMs, int offsetMin}) fromWall(WallTime w, String zone) {
    final t = tz.TZDateTime(location(zone), w.year, w.month, w.day, w.hour, w.minute, w.second, w.millisecond);
    return (utcMs: t.millisecondsSinceEpoch, offsetMin: t.timeZoneOffset.inMinutes);
  }

  /// Hora local e deslocamento de um instante na zona [zone].
  static ({WallTime wall, int offsetMin}) toWall(int utcMs, String zone) {
    final t = tz.TZDateTime.fromMillisecondsSinceEpoch(location(zone), utcMs);
    return (
      wall: wallTime(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond),
      offsetMin: t.timeZoneOffset.inMinutes,
    );
  }
}

/// Uma data candidata. Tem a hora local ([wall]) e, quando o arquivo diz o
/// fuso ou a data é UTC, o instante exato ([utcMs]).
class DateCandidate {
  const DateCandidate({required this.source, this.wall, this.utcMs, this.offsetMin, this.dayOnly = false, this.detail})
    : assert(wall != null || utcMs != null);

  final DateSource source;
  final WallTime? wall;
  final int? utcMs;
  final int? offsetMin;

  /// Só o dia é conhecido (ex.: WhatsApp `IMG-20190312-WA0001`).
  final bool dayOnly;

  /// Ex.: o tag ou o padrão de nome.
  final String? detail;

  Map<String, Object?> toJson() => {
    'source': source.sql,
    if (wall != null) 'local': formatWall(wall!),
    if (utcMs != null) 'utc': utcMs,
    if (offsetMin != null) 'offset': offsetMin,
    if (dayOnly) 'dayOnly': true,
    if (detail != null) 'detail': detail,
  };

  static DateCandidate fromJson(Map<String, Object?> j) => DateCandidate(
    source: DateSource.fromSql(j['source'] as String?),
    wall: parseWall(j['local'] as String?),
    utcMs: j['utc'] as int?,
    offsetMin: j['offset'] as int?,
    dayOnly: j['dayOnly'] == true,
    detail: j['detail'] as String?,
  );
}

/// Data e hora da captura escolhida.
class ResolvedDate {
  const ResolvedDate({
    required this.utcMs,
    required this.wall,
    required this.offsetMin,
    required this.source,
    required this.confidence,
    this.conflict = false,
  });

  final int utcMs;
  final WallTime wall;
  final int offsetMin;
  final DateSource source;
  final DateConfidence confidence;

  /// Candidatas confiáveis discordam (ex.: EXIF × nome do arquivo).
  final bool conflict;
}

/// Data no nome do arquivo (spec §8: `IMG_20190312_…`, `IMG-20190312-WA0001`,
/// `VID_…`, `Screenshot_…`, `PXL_…`, Samsung `20190312_101112`).
DateCandidate? filenameDate(String name) {
  final base = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
  for (final p in _patterns) {
    final m = p.re.firstMatch(base);
    if (m == null) continue;
    int g(String n) => int.parse(m.namedGroup(n)!);
    final y = g('y'), mo = g('mo'), d = g('d');
    if (!_validDate(y, mo, d)) continue;
    if (p.dayOnly) {
      return DateCandidate(source: DateSource.filename, wall: wallTime(y, mo, d), dayOnly: true, detail: p.name);
    }
    final h = g('h'), mi = g('mi'), s = g('s');
    if (h > 23 || mi > 59 || s > 59) continue;
    final msText = m.groupNames.contains('ms') ? m.namedGroup('ms') : null;
    final ms = msText == null ? 0 : int.parse(msText.padRight(3, '0').substring(0, 3));
    final wall = wallTime(y, mo, d, h, mi, s, ms);
    if (p.utc) {
      // Pixel (PXL_…) nomeia pela hora UTC.
      return DateCandidate(source: DateSource.filename, utcMs: wall.millisecondsSinceEpoch, detail: p.name);
    }
    return DateCandidate(source: DateSource.filename, wall: wall, detail: p.name);
  }
  return null;
}

bool _validDate(int y, int mo, int d) {
  if (y < 1990 || y > 2100 || mo < 1 || mo > 12 || d < 1) return false;
  return d <= DateTime.utc(y, mo + 1, 0).day;
}

class _NamePattern {
  const _NamePattern(this.name, String re, {this.dayOnly = false, this.utc = false}) : _re = re;
  final String name;
  final String _re;
  final bool dayOnly;
  final bool utc;
  RegExp get re => RegExp(_re, caseSensitive: false);
}

const _ymd = r'(?<y>\d{4})(?<mo>\d\d)(?<d>\d\d)';
const _hms = r'(?<h>\d\d)(?<mi>\d\d)(?<s>\d\d)';
const _patterns = [
  // WhatsApp: só o dia.
  _NamePattern('whatsapp', '^(?:IMG|VID|AUD|PTT|STK|DOC)-$_ymd-WA\\d+', dayOnly: true),
  _NamePattern('pixel', '^PXL_${_ymd}_$_hms(?<ms>\\d{1,3})?', utc: true),
  _NamePattern('camera', '^(?:IMG|VID|MVIMG|PANO|BURST\\d*)_${_ymd}_$_hms(?<ms>\\d{1,3})?'),
  _NamePattern('screenshot', '^Screenshot_$_ymd[-_]$_hms'),
  _NamePattern('screenshot', r'^Screenshot_(?<y>\d{4})-(?<mo>\d\d)-(?<d>\d\d)-(?<h>\d\d)-(?<mi>\d\d)-(?<s>\d\d)'),
  _NamePattern('signal', r'^signal-(?<y>\d{4})-(?<mo>\d\d)-(?<d>\d\d)-(?<h>\d\d)(?<mi>\d\d)(?<s>\d\d)'),
  // Samsung e outros: 20190312_101112 (com sufixos como "(1)" ou "_001").
  _NamePattern('timestamp', '^${_ymd}_$_hms'),
  // Dropbox/Camera Uploads: "2019-03-12 10.11.12".
  _NamePattern('timestamp', r'^(?<y>\d{4})-(?<mo>\d\d)-(?<d>\d\d)[ _](?<h>\d\d)[.\-](?<mi>\d\d)[.\-](?<s>\d\d)'),
];

/// "2024:05:01 14:03:12" (EXIF/QuickTime), com subsegundos e fuso opcionais.
/// Datas zeradas ("0000:00:00 00:00:00") ou inválidas → `null`.
({WallTime wall, int? offsetMin})? parseExifDate(String? text, {String? subSec, String? offset}) {
  if (text == null) return null;
  final m = RegExp(r'^(\d{4}):(\d\d):(\d\d)[ T](\d\d):(\d\d):(\d\d)(?:\.(\d+))?\s*(Z|[+-]\d\d:?\d\d)?')
      .firstMatch(text.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  final y = g(1), mo = g(2), d = g(3), h = g(4), mi = g(5), s = g(6);
  if (!_validDate(y, mo, d) || h > 23 || mi > 59 || s > 59) return null;
  final frac = m.group(7) ?? subSec?.trim();
  final ms = frac == null || frac.isEmpty || int.tryParse(frac) == null
      ? 0
      : int.parse(frac.padRight(3, '0').substring(0, 3));
  final off = parseOffset(m.group(8) ?? offset);
  return (wall: wallTime(y, mo, d, h, mi, s, ms), offsetMin: off);
}

/// '+02:00', '-0300', 'Z' → minutos.
int? parseOffset(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t == 'Z') return 0;
  final m = RegExp(r'^([+-])(\d\d):?(\d\d)$').firstMatch(t);
  if (m == null) return null;
  final v = int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!);
  return m.group(1) == '-' ? -v : v;
}

/// Estratégia de data (spec §8): escolhe a candidata pela prioridade e
/// calcula o instante, a hora local, a confiança e se há conflito.
class DateStrategy {
  const DateStrategy({this.zone = TimeZones.defaultZone, this.priority = DateSource.defaultPriority});

  /// Fuso padrão para datas sem fuso.
  final String zone;
  final List<DateSource> priority;

  /// Tolerância para dizer que duas candidatas discordam.
  static const conflictTolerance = Duration(minutes: 2);

  ResolvedDate? resolve(List<DateCandidate> candidates) {
    if (candidates.isEmpty) return null;
    int rank(DateSource s) {
      final i = priority.indexOf(s);
      return i < 0 ? priority.length : i;
    }

    final sorted = [...candidates]..sort((a, b) => rank(a.source).compareTo(rank(b.source)));
    var chosen = sorted.first;
    var confidence = _confidence(chosen);

    // WhatsApp: o nome só tem o dia. Se a data do arquivo cai no mesmo dia,
    // ela dá a hora (média); senão, meio-dia daquele dia e hora incerta.
    if (chosen.dayOnly) {
      final day = chosen.wall!;
      final fs = sorted.where((c) => c.source == DateSource.filesystem && c.utcMs != null).firstOrNull;
      final fsWall = fs == null ? null : TimeZones.toWall(fs.utcMs!, zone).wall;
      if (fsWall != null && fsWall.year == day.year && fsWall.month == day.month && fsWall.day == day.day) {
        final at = TimeZones.toWall(fs!.utcMs!, zone);
        return ResolvedDate(
          utcMs: fs.utcMs!,
          wall: at.wall,
          offsetMin: at.offsetMin,
          source: DateSource.filename,
          confidence: DateConfidence.medium,
        );
      }
      chosen = DateCandidate(source: DateSource.filename, wall: wallTime(day.year, day.month, day.day, 12));
      confidence = DateConfidence.low;
    }

    final at = _instant(chosen);
    final conflict = _conflict(chosen, at.utcMs, sorted);
    // 1º de janeiro à meia-noite em ponto: é a data que câmeras e celulares
    // gravam com o relógio zerado. Fica como hora incerta ("Hora a confirmar").
    if (looksLikeClockReset(at.wall)) confidence = DateConfidence.low;
    return ResolvedDate(
      utcMs: at.utcMs,
      wall: at.wall,
      offsetMin: at.offsetMin,
      source: chosen.source,
      confidence: confidence,
      conflict: conflict,
    );
  }

  ({int utcMs, WallTime wall, int offsetMin}) _instant(DateCandidate c) {
    final wall = c.wall;
    final off = c.offsetMin;
    if (wall != null && off != null) {
      return (utcMs: wall.millisecondsSinceEpoch - off * 60000, wall: wall, offsetMin: off);
    }
    if (wall != null) {
      final at = TimeZones.fromWall(wall, zone);
      return (utcMs: at.utcMs, wall: wall, offsetMin: at.offsetMin);
    }
    final at = TimeZones.toWall(c.utcMs!, zone);
    return (utcMs: c.utcMs!, wall: at.wall, offsetMin: at.offsetMin);
  }

  static DateConfidence _confidence(DateCandidate c) => switch (c.source) {
    DateSource.manual => DateConfidence.high,
    // Com fuso (EXIF) ou em UTC (vídeo): instante conhecido.
    DateSource.exifOriginal => c.offsetMin != null ? DateConfidence.high : DateConfidence.medium,
    DateSource.videoInternal => c.utcMs != null || c.offsetMin != null ? DateConfidence.high : DateConfidence.medium,
    DateSource.filename => c.dayOnly ? DateConfidence.low : DateConfidence.medium,
    DateSource.filesystem => DateConfidence.low,
    DateSource.none => DateConfidence.none,
  };

  /// Conflito: outra candidata de câmera/nome (não a do sistema de arquivos,
  /// que muda a cada cópia) discorda da escolhida além da tolerância.
  bool _conflict(DateCandidate chosen, int chosenUtc, List<DateCandidate> all) {
    if (chosen.source == DateSource.filesystem) return false;
    for (final c in all) {
      if (identical(c, chosen) || c.source == DateSource.filesystem || c.source == chosen.source) continue;
      if (c.dayOnly) {
        final w = TimeZones.toWall(chosenUtc, zone).wall;
        final d = c.wall!;
        if (w.year != d.year || w.month != d.month || w.day != d.day) return true;
        continue;
      }
      final other = _instant(c).utcMs;
      if ((other - chosenUtc).abs() > conflictTolerance.inMilliseconds) return true;
    }
    return false;
  }

  static String candidatesJson(List<DateCandidate> c) => jsonEncode([for (final x in c) x.toJson()]);

  static List<DateCandidate> candidatesFromJson(String? json) => json == null
      ? const []
      : [for (final m in (jsonDecode(json) as List<Object?>).cast<Map<String, Object?>>()) DateCandidate.fromJson(m)];
}

/// Data típica de relógio zerado: 1º de janeiro, 00:00:00 em ponto.
bool looksLikeClockReset(WallTime w) =>
    w.month == 1 && w.day == 1 && w.hour == 0 && w.minute == 0 && w.second == 0 && w.millisecond == 0;
