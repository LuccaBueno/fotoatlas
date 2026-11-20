import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../library/library_service.dart';

/// Latitude máxima da projeção de Mercator (o mapa é um quadrado).
const mercatorMaxLat = 85.05112878;

/// Longitude → 0..1 (oeste → leste), projeção de Mercator da web.
double mercatorX(double lon) => (lon + 180) / 360;

/// Latitude → 0..1 (norte → sul).
double mercatorY(double lat) {
  final l = lat.clamp(-mercatorMaxLat, mercatorMaxLat) * math.pi / 180;
  return (1 - math.log(math.tan(l) + 1 / math.cos(l)) / math.pi) / 2;
}

/// 0..1 → longitude (fora de 0..1 dá voltas no globo; normalize depois).
double mercatorLon(double x) => x * 360 - 180;

/// 0..1 → latitude.
double mercatorLat(double y) {
  final n = math.pi * (1 - 2 * y);
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
}

/// Longitude em -180..180.
double normalizeLon(double lon) {
  final l = (lon + 180) % 360;
  return (l < 0 ? l + 360 : l) - 180;
}

/// Área do mapa no formato do filtro [sul, norte, oeste, leste]: oeste >
/// leste atravessa a linha de data; uma janela com mais de uma volta vira o
/// globo todo.
List<double> mapAreaValues({required double west, required double east, required double south, required double north}) {
  final s = south.clamp(-90.0, 90.0), n = north.clamp(-90.0, 90.0);
  if (east - west >= 360) return [s, n, -180, 180];
  return [s, n, normalizeLon(west), normalizeLon(east)];
}

/// Contorno de um país ou estado: anéis em coordenadas 0..1 de Mercator
/// (x, y intercalados) e a caixa que os contém.
class MapShape {
  MapShape(this.name, this.code, this.rings) : bounds = _bounds(rings);
  final String name;

  /// Código do país (ISO de duas letras), quando há.
  final String code;
  final List<Float32List> rings;

  /// [xMin, yMin, xMax, yMax] em 0..1.
  final Float32List bounds;

  static Float32List _bounds(List<Float32List> rings) {
    var x0 = 1.0, y0 = 1.0, x1 = 0.0, y1 = 0.0;
    for (final r in rings) {
      for (var i = 0; i < r.length; i += 2) {
        x0 = math.min(x0, r[i]);
        x1 = math.max(x1, r[i]);
        y0 = math.min(y0, r[i + 1]);
        y1 = math.max(y1, r[i + 1]);
      }
    }
    return Float32List.fromList([x0, y0, x1, y1]);
  }
}

/// Contornos embutidos (Natural Earth, domínio público): países e estados.
/// Gerados por `tools\fixtures\bin\build_map_data.dart`.
class MapContours {
  MapContours(this.countries, this.states, this.source);
  final List<MapShape> countries;
  final List<MapShape> states;
  final String source;

  /// Lê o `contornos.json` (centésimos de grau; anel = primeiro ponto
  /// absoluto e os outros como diferença do anterior).
  factory MapContours.decode(String json) {
    final j = jsonDecode(json) as Map<String, Object?>;
    final scale = (j['escala'] as num?)?.toDouble() ?? 100;
    List<Float32List> rings(List<Object?> list) => [
      for (final ring in list.cast<List<Object?>>())
        () {
          final out = Float32List(ring.length);
          var lon = 0, lat = 0;
          for (var i = 0; i + 1 < ring.length; i += 2) {
            lon += ring[i]! as int;
            lat += ring[i + 1]! as int;
            out[i] = mercatorX(lon / scale);
            out[i + 1] = mercatorY(lat / scale);
          }
          return out;
        }(),
    ];
    return MapContours(
      [
        for (final c in (j['paises']! as List).cast<List<Object?>>())
          MapShape(c[0]! as String, c[1]! as String, rings(c[2]! as List<Object?>)),
      ],
      [
        for (final s in (j['estados']! as List).cast<List<Object?>>())
          MapShape(s[1]! as String, s[0]! as String, rings(s[2]! as List<Object?>)),
      ],
      j['fonte'] as String? ?? '',
    );
  }
}

/// Um grupo de pontos próximos no nível de aproximação atual.
class MapCluster {
  MapCluster({
    required this.x,
    required this.y,
    required this.count,
    required this.firstId,
    required this.west,
    required this.east,
    required this.south,
    required this.north,
  });

  /// Centro (média) em 0..1 de Mercator.
  final double x, y;
  final int count;

  /// Um dos conteúdos (o único, quando [count] é 1).
  final int firstId;

  /// Caixa dos pontos, em graus.
  final double west, east, south, north;
}

/// Agrupa os pontos numa grade de [cellPx] pixels quando o mundo inteiro
/// mede [worldPx] pixels. Linear no número de pontos.
List<MapCluster> clusterMapPoints(MapPoints points, {required double worldPx, double cellPx = 56}) {
  final cells = math.max(1, (worldPx / cellPx).floor());
  final acc = <int, _Acc>{};
  for (var i = 0; i < points.length; i++) {
    final lat = points.lat[i], lon = points.lon[i];
    final x = mercatorX(normalizeLon(lon)), y = mercatorY(lat);
    final cx = math.min(cells - 1, (x * cells).floor());
    final cy = math.min(cells - 1, math.max(0, (y * cells).floor()));
    (acc[cy * cells + cx] ??= _Acc(points.ids[i], lon, lat)).add(x, y, lon, lat);
  }
  return [
    for (final a in acc.values)
      MapCluster(
        x: a.sx / a.n,
        y: a.sy / a.n,
        count: a.n,
        firstId: a.firstId,
        west: a.w,
        east: a.e,
        south: a.s,
        north: a.nn,
      ),
  ];
}

class _Acc {
  _Acc(this.firstId, double lon, double lat) : w = lon, e = lon, s = lat, nn = lat;
  final int firstId;
  int n = 0;
  double sx = 0, sy = 0;
  double w, e, s, nn;

  void add(double x, double y, double lon, double lat) {
    n++;
    sx += x;
    sy += y;
    w = math.min(w, lon);
    e = math.max(e, lon);
    s = math.min(s, lat);
    nn = math.max(nn, lat);
  }
}
