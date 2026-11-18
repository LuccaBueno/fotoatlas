import 'dart:convert';

/// Dados de um `.json` do Google Takeout (só o que o FotoAtlas usa).
class TakeoutSidecar {
  const TakeoutSidecar({required this.fileName, this.title, this.takenUtcMs, this.lat, this.lon});

  /// Nome do próprio `.json` (ex.: `IMG_1234.JPG.supplemental-metadata(1).json`).
  final String fileName;

  /// Nome original da foto no Google Fotos.
  final String? title;
  final int? takenUtcMs;
  final double? lat;
  final double? lon;

  /// Lê o conteúdo; `null` se não for um `.json` de foto do Takeout.
  static TakeoutSidecar? parse(String fileName, String text) {
    Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (j is! Map<String, Object?>) return null;
    final taken = _timestamp(j['photoTakenTime']);
    final title = j['title'] is String ? j['title']! as String : null;
    // Os `.json` de álbum (`metadados.json`) também têm `title`, mas não a data da foto.
    if (j['photoTakenTime'] is! Map) return null;
    // (0, 0) é o que o Takeout grava quando não há local.
    (double, double)? geo(Object? g) {
      if (g is! Map<String, Object?>) return null;
      final la = g['latitude'], lo = g['longitude'];
      if (la is! num || lo is! num) return null;
      if (la == 0 && lo == 0) return null;
      if (la.abs() > 90 || lo.abs() > 180) return null;
      return (la.toDouble(), lo.toDouble());
    }

    final g = geo(j['geoData']) ?? geo(j['geoDataExif']);
    return TakeoutSidecar(fileName: fileName, title: title, takenUtcMs: taken, lat: g?.$1, lon: g?.$2);
  }

  static int? _timestamp(Object? t) {
    if (t is! Map<String, Object?>) return null;
    final v = t['timestamp'];
    final s = v is num ? v.toInt() : int.tryParse('$v');
    // Antes de 1990 ou zero: não é uma data de captura.
    if (s == null || s < 631152000) return null;
    return s * 1000;
  }
}

/// Sufixos que o Google Fotos põe nas cópias editadas (o `.json` é o da original).
const editedSuffixes = ['-editado', '-edited', '-bearbeitet', '-modifié', '-modificato', '-editada', '-editar'];

/// Comprimento máximo do nome de um `.json` do Takeout sem a extensão.
const _jsonBaseMax = 46;

/// Casa as fotos e vídeos de **uma pasta** com os `.json` dela. Devolve
/// nome da mídia → `.json`. Regras do Takeout:
///
/// - `IMG_1.JPG.json` ou `IMG_1.JPG.supplemental-metadata.json` (nomes
///   longos cortados em 46 caracteres antes do `.json`);
/// - duplicatas: `IMG_1(1).JPG` ↔ `IMG_1.JPG(1).json`;
/// - editadas: `IMG_1-editado.JPG` usa o `.json` de `IMG_1.JPG`;
/// - na dúvida, o `title` de dentro do `.json` (nome original).
Map<String, TakeoutSidecar> matchTakeout(Iterable<String> mediaNames, Iterable<TakeoutSidecar> jsons) {
  final byKey = <String, TakeoutSidecar>{};
  final list = jsons.toList();
  for (final j in list) {
    final (base, n) = _jsonBase(j.fileName);
    byKey.putIfAbsent('${base.toLowerCase()}#$n', () => j);
  }
  final byTitle = <String, List<TakeoutSidecar>>{};
  for (final j in list) {
    final t = j.title?.toLowerCase();
    if (t != null) (byTitle[t] ??= []).add(j);
  }

  final out = <String, TakeoutSidecar>{};
  for (final name in mediaNames) {
    final (original, n) = _original(name);
    final lower = original.toLowerCase();
    final full = '$lower.supplemental-metadata';
    TakeoutSidecar? found;
    for (final key in [lower, full, _cut(full), _cut(lower)]) {
      found = byKey['$key#$n'];
      if (found != null) break;
    }
    // Nome cortado com outra variação do sufixo ("supplemental-me").
    if (found == null) {
      for (final MapEntry(:key, :value) in byKey.entries) {
        final hash = key.lastIndexOf('#');
        final base = key.substring(0, hash);
        if (key.substring(hash + 1) != '$n') continue;
        if (base.length >= lower.length && full.startsWith(base)) {
          found = value;
          break;
        }
      }
    }
    // Pelo título, quando só existe um `.json` com ele.
    if (found == null) {
      final same = byTitle[lower];
      if (same != null && same.length == 1 && n == 0) found = same.single;
    }
    if (found != null) out[name] = found;
  }
  return out;
}

String _cut(String s) => s.length <= _jsonBaseMax ? s : s.substring(0, _jsonBaseMax);

/// `IMG_1.JPG(1).json` → (`IMG_1.JPG`, 1); `IMG_1.JPG.json` → (`IMG_1.JPG`, 0).
(String, int) _jsonBase(String fileName) {
  var base = fileName.toLowerCase().endsWith('.json') ? fileName.substring(0, fileName.length - 5) : fileName;
  final m = RegExp(r'\((\d+)\)$').firstMatch(base);
  if (m != null) return (base.substring(0, m.start), int.parse(m.group(1)!));
  return (base, 0);
}

/// `IMG_1(1).JPG` → (`IMG_1.JPG`, 1); `IMG_1-editado.JPG` → (`IMG_1.JPG`, 0).
(String, int) _original(String name) {
  final dot = name.lastIndexOf('.');
  var stem = dot <= 0 ? name : name.substring(0, dot);
  final ext = dot <= 0 ? '' : name.substring(dot);
  for (final s in editedSuffixes) {
    if (stem.toLowerCase().endsWith(s)) {
      stem = stem.substring(0, stem.length - s.length);
      break;
    }
  }
  final m = RegExp(r'\((\d+)\)$').firstMatch(stem);
  if (m != null) return ('${stem.substring(0, m.start)}$ext', int.parse(m.group(1)!));
  return ('$stem$ext', 0);
}
