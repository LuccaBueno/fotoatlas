import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';
import '../support/tools.dart';

/// O que a pasta de demonstração (`run-app.ps1 -DemoPersistente`) mostra no
/// mapa: o roteiro `docs\roteiro-teste-fase-9.md` descreve exatamente isto.
void main() {
  test('demonstração "Viagens (mapa)": os pontos do roteiro de teste', () async {
    final env = await TestEnv.open();
    generateMapDemo(p.join(env.volumeDir.path, 'Viagens (mapa)'));
    final source = await env.addFolder('Viagens (mapa)');
    await env.scan(source);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();

    expect(await env.core.library.count(LibraryFilter.empty), 12);
    final all = await env.core.library.mapPoints(LibraryFilter.empty);
    expect(all.length, 10, reason: 'as 2 de "Sem local" não aparecem');
    Future<int> inArea(List<double> v) async =>
        env.core.library.count(LibraryFilter([FilterCondition(FilterKind.area, values: v)]));
    expect(await inArea([-34, 5, -74, -34]), 5, reason: 'Brasil: Rio e São Paulo');
    expect(await inArea([-23.1, -22.8, -43.4, -43.0]), 3, reason: 'só o Rio');
    expect(await inArea([-20, -15, 178, -178]), 2, reason: 'Fiji, atravessando a linha de data');
    // Afastado (mundo de 256 px): Brasil (5) e Lisboa (2) viram grupos; Tóquio
    // sozinha; Fiji fica nas duas pontas do mapa (uma de cada lado da linha de data).
    final world = clusterMapPoints(all, worldPx: 256);
    expect(world.map((c) => c.count).toList()..sort(), [1, 1, 1, 2, 5]);
  }, skip: skipWithoutTool(ExternalTools.locate().exiftool, 'ExifTool'));
}
