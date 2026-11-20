import 'dart:io';
import 'dart:typed_data';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

MapPoints points(List<(int, double, double)> list) => MapPoints(
  Int64List.fromList([for (final e in list) e.$1]),
  Float64List.fromList([for (final e in list) e.$2]),
  Float64List.fromList([for (final e in list) e.$3]),
);

void main() {
  test('projeção de Mercator: ida e volta e limites', () {
    for (final (lat, lon) in [(0.0, 0.0), (-22.9, -43.2), (35.68, 139.69), (60.0, -179.9)]) {
      expect(mercatorLat(mercatorY(lat)), closeTo(lat, 1e-9));
      expect(mercatorLon(mercatorX(lon)), closeTo(lon, 1e-9));
    }
    expect(mercatorY(0), closeTo(0.5, 1e-12));
    expect(mercatorY(90), closeTo(0, 1e-6), reason: 'polo fica no limite, sem infinito');
    expect(normalizeLon(190), closeTo(-170, 1e-9));
    expect(normalizeLon(-540), closeTo(-180, 1e-9));
  });

  test('área do filtro: normal, atravessando a linha de data e mais de uma volta', () {
    expect(mapAreaValues(west: -74, east: -34, south: -34, north: 5), [-34, 5, -74, -34]);
    expect(mapAreaValues(west: 170, east: 190, south: -30, north: -10), [-30, -10, 170, -170]);
    expect(mapAreaValues(west: -300, east: 200, south: -95, north: 95), [-90, 90, -180, 180]);
  });

  test('pontos próximos viram um grupo; aproximando, se separam', () {
    final pts = points([(1, -22.90, -43.20), (2, -22.91, -43.21), (3, -23.55, -46.63), (4, 38.72, -9.14)]);
    final world = clusterMapPoints(pts, worldPx: 256);
    expect(world.fold<int>(0, (s, c) => s + c.count), 4);
    final rio = world.firstWhere((c) => c.count >= 2);
    expect(rio.south, lessThanOrEqualTo(-22.91));
    final close = clusterMapPoints(pts, worldPx: 256.0 * (1 << 14));
    expect(close.length, 4);
    expect(close.where((c) => c.count == 1).map((c) => c.firstId).toSet(), {1, 2, 3, 4});
    expect(clusterMapPoints(points([]), worldPx: 512), isEmpty);
  });

  test('contornos embutidos (Natural Earth) são lidos', () {
    final file = File(p.join('..', '..', 'app', 'assets', 'map', 'contornos.json'));
    final contours = MapContours.decode(file.readAsStringSync());
    expect(contours.source, contains('Natural Earth'));
    expect(contours.countries.length, greaterThan(150));
    final brasil = contours.countries.firstWhere((c) => c.code == 'BR');
    // Brasília dentro da caixa do Brasil.
    expect(brasil.bounds[0], lessThan(mercatorX(-47.9)));
    expect(brasil.bounds[2], greaterThan(mercatorX(-47.9)));
    expect(brasil.bounds[1], lessThan(mercatorY(-15.8)));
    expect(brasil.bounds[3], greaterThan(mercatorY(-15.8)));
    expect(contours.states.where((s) => s.code == 'BR').length, 27);
  });
}
