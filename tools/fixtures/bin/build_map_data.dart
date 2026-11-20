import 'dart:convert';
import 'dart:io';

/// Gera `app\assets\map\contornos.json` a partir do Natural Earth (domínio
/// público, https://www.naturalearthdata.com): países (110m) e estados (50m).
///
/// Uso:
///   dart run bin/build_map_data.dart PAISES.geojson ESTADOS.geojson SAIDA.json
///
/// Formato: coordenadas em centésimos de grau (inteiros), cada anel com o
/// primeiro ponto absoluto e os outros como diferença do anterior.
void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('Uso: dart run bin/build_map_data.dart PAISES.geojson ESTADOS.geojson SAIDA.json');
    exit(64);
  }
  final countries = _features(args[0]);
  final states = _features(args[1]);
  final out = {
    'fonte': 'Natural Earth 5.1.2 — Admin 0 Countries (1:110m) e Admin 1 States/Provinces (1:50m). Domínio público.',
    'escala': 100,
    'paises': [
      for (final f in countries)
        [
          f.props['ADMIN'] ?? f.props['NAME'] ?? '',
          f.props['ISO_A2_EH'] ?? f.props['ISO_A2'] ?? '',
          _rings(f.geometry, 10),
        ],
    ],
    'estados': [
      for (final f in states) [f.props['iso_a2'] ?? '', f.props['name'] ?? '', _rings(f.geometry, 1)],
    ],
  };
  File(args[2])
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(out));
  stdout.writeln(
    '${countries.length} países, ${states.length} estados → ${args[2]} (${File(args[2]).lengthSync()} bytes)',
  );
}

class _Feature {
  _Feature(this.props, this.geometry);
  final Map<String, Object?> props;
  final Map<String, Object?> geometry;
}

List<_Feature> _features(String path) {
  final j = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
  return [
    for (final f in (j['features']! as List).cast<Map<String, Object?>>())
      if (f['geometry'] != null)
        _Feature((f['properties']! as Map).cast<String, Object?>(), (f['geometry']! as Map).cast<String, Object?>()),
  ];
}

/// Anéis externos e internos de Polygon/MultiPolygon, quantizados em
/// [step] centésimos de grau, em diferenças.
List<List<int>> _rings(Map<String, Object?> g, int step) {
  final polys = switch (g['type']) {
    'Polygon' => [g['coordinates']! as List<Object?>],
    'MultiPolygon' => (g['coordinates']! as List<Object?>).cast<List<Object?>>(),
    _ => const <List<Object?>>[],
  };
  final out = <List<int>>[];
  for (final poly in polys) {
    for (final ring in poly.cast<List<Object?>>()) {
      final pts = <(int, int)>[];
      for (final c in ring.cast<List<Object?>>()) {
        final x = ((c[0] as num) * 100 / step).round() * step;
        final y = ((c[1] as num) * 100 / step).round() * step;
        if (pts.isEmpty || pts.last != (x, y)) pts.add((x, y));
      }
      if (pts.length < 4) continue;
      final enc = <int>[pts.first.$1, pts.first.$2];
      for (var i = 1; i < pts.length; i++) {
        enc
          ..add(pts[i].$1 - pts[i - 1].$1)
          ..add(pts[i].$2 - pts[i - 1].$2);
      }
      out.add(enc);
    }
  }
  return out;
}
