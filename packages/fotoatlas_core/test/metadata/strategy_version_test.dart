import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_core/src/metadata/metadata_service.dart' show MetadataSettingKeys;
import 'package:fotoatlas_fixtures/media_fixtures.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

void main() {
  test('regras de data novas: ao abrir, o catálogo reescolhe as datas e tira o relógio zerado dos momentos', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final src = await env.addFolder('F');
    env
      ..write('F/IMG_20230101_000000.jpg', jpegWithExif(const ExifSpec(uniqueId: 'a')))
      ..write('F/IMG_20230101_000500.jpg', jpegWithExif(const ExifSpec(uniqueId: 'b')));
    await env.scan(src);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    // Simula um catálogo da regra antiga: data aceita como provável e dentro de um momento.
    await env.db.customStatement(
      "UPDATE media_metadata SET date_confidence = 'medium', eff_confidence = 'medium' "
      "WHERE capture_local = '2023-01-01T00:00:00'",
    );
    await env.core.moments.recompute();
    expect(await env.count('SELECT COUNT(*) FROM media_metadata WHERE moment_id IS NOT NULL'), 2);
    await SettingsStore(env.db).set(MetadataSettingKeys.strategyVersion, 1);

    await env.reopen();
    await env.core.moments.waitIdle();
    await env.core.moments.recompute();
    expect(
      await env.count("SELECT COUNT(*) FROM media_metadata WHERE eff_confidence = 'low' AND moment_id IS NULL"),
      1,
      reason: 'relógio zerado vai para "Hora a confirmar"',
    );
    expect(await env.count('SELECT COUNT(*) FROM media_metadata WHERE moment_id IS NOT NULL'), 1);
  });
}
