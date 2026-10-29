@Tags(['slow'])
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

/// Biblioteca com 100 mil itens (spec §16, Fase 4): filtros por data,
/// câmera, fonte, situação de backup, faixa de horário, período do dia, dia
/// da semana e momento respondendo em menos de 1 s. Só o catálogo é usado:
/// as linhas são inseridas direto, sem arquivos no disco.
void main() {
  test('100 mil itens: filtros da Biblioteca em menos de 1 s', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final hd2 = env.addVolume('HD2');
    final celular = await env.addFolder('Celular');
    final backup = await env.addFolder('Backup', volume: hd2);
    final db = env.db;
    const n = 100000;
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random(7);
    const cameras = [
      ('samsung', 'SM-M546B'),
      ('Canon', 'Canon EOS X'),
      ('Apple', 'iPhone 13'),
      ('Google', 'Pixel 9'),
      ('NIKON', 'D7500'),
    ];
    final start = DateTime.utc(2018, 1, 1).millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.batch((b) {
        var t = start;
        for (var i = 1; i <= n; i++) {
          // Rajadas de fotos com intervalos maiores entre elas (momentos).
          t += random.nextInt(10) == 0 ? random.nextInt(3 * 86400) * 1000 : random.nextInt(600) * 1000;
          final wall = DateTime.fromMillisecondsSinceEpoch(t - 3 * 3600000, isUtc: true);
          final local = formatWall(wall);
          final cam = cameras[i % cameras.length];
          final conf = i % 20 == 0 ? 'low' : (i % 7 == 0 ? 'high' : 'medium');
          final sha = Uint8List(32)..buffer.asByteData().setUint32(0, i);
          b
            ..customStatement(
              'INSERT INTO contents (id, sha256, size_bytes, media_type, created_at) VALUES (?, ?, ?, ?, ?)',
              [i, sha, 100000 + i, i % 10 == 0 ? 'video' : 'photo', now],
            )
            ..customStatement(
              'INSERT INTO media_metadata (content_id, capture_utc_ms, capture_local, tz_offset_min, date_source, '
              'date_confidence, make, model, width, height, meta_status, eff_utc_ms, eff_local, eff_offset_min, '
              'eff_source, eff_confidence, eff_year, eff_month, eff_day, eff_minute, eff_weekday) '
              "VALUES (?, ?, ?, -180, 'exif_original', ?, ?, ?, 4000, 3000, 'full', ?, ?, -180, 'exif_original', ?, ?, ?, ?, ?, ?)",
              [
                i,
                t,
                local,
                conf,
                cam.$1,
                cam.$2,
                t,
                local,
                conf,
                wall.year,
                wall.month,
                local.substring(0, 10),
                wall.hour * 60 + wall.minute,
                wall.weekday,
              ],
            )
            ..customStatement(
              'INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, mtime, '
              "content_id, hash_status, availability) VALUES (?, ?, ?, ?, 'jpg', ?, 1, ?, 'done', 'present')",
              [celular, 'DCIM/${i % 300}/IMG_$i.jpg', 'DCIM/${i % 300}', 'IMG_$i.jpg', 100000 + i, i],
            );
          // Um terço também no HD de backup.
          if (i % 3 == 0) {
            b.customStatement(
              'INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, mtime, '
              "content_id, hash_status, availability) VALUES (?, ?, ?, ?, 'jpg', ?, 1, ?, 'done', 'present')",
              [backup, 'Fotos/${i % 50}/foto $i.jpg', 'Fotos/${i % 50}', 'foto $i.jpg', 100000 + i, i],
            );
          }
        }
      });
    });

    final sw = Stopwatch()..start();
    await env.core.moments.recompute();
    final momentsMs = sw.elapsedMilliseconds;
    final moments = await env.core.moments.list();
    expect(moments.length, greaterThan(100));

    final library = env.core.library;
    final cases = <String, LibraryFilter>{
      'tudo': LibraryFilter.empty,
      'ano': const LibraryFilter([
        FilterCondition(FilterKind.years, values: [2020]),
      ]),
      'mês': const LibraryFilter([
        FilterCondition(FilterKind.months, values: ['2021-07']),
      ]),
      'câmera': const LibraryFilter([
        FilterCondition(FilterKind.cameras, values: ['Canon\u0001Canon EOS X']),
      ]),
      'fonte': LibraryFilter([
        FilterCondition(FilterKind.sources, values: [backup]),
      ]),
      'backup': const LibraryFilter([
        FilterCondition(FilterKind.backup, values: ['single']),
      ]),
      'faixa de horário': const LibraryFilter([FilterCondition(FilterKind.timeRange, min: 18 * 60, max: 23 * 60 + 59)]),
      'período do dia': LibraryFilter([
        FilterCondition(FilterKind.periods, values: [DayPeriod.madrugada.name]),
      ]),
      'dia da semana': const LibraryFilter([
        FilterCondition(FilterKind.weekdays, values: [6, 7]),
      ]),
      'momento': LibraryFilter([
        FilterCondition(FilterKind.moments, values: [moments[moments.length ~/ 2].id]),
      ]),
      'hora a confirmar': const LibraryFilter([FilterCondition(FilterKind.toConfirm)]),
      'texto': const LibraryFilter([FilterCondition(FilterKind.text, text: 'IMG_4242')]),
      'combinado': LibraryFilter([
        const FilterCondition(FilterKind.years, values: [2019, 2020]),
        const FilterCondition(FilterKind.periods, values: ['tarde', 'noite']),
        const FilterCondition(FilterKind.cameras, values: ['samsung\u0001SM-M546B'], negate: true),
        FilterCondition(FilterKind.sources, values: [celular]),
      ]),
    };
    final times = <String, int>{};
    for (final e in cases.entries) {
      // Primeira consulta (cache frio do SQLite) já conta.
      sw.reset();
      final index = await library.index(e.value);
      final first = await library.items(index.ids.take(120).toList());
      times[e.key] = sw.elapsedMilliseconds;
      expect(index.length, greaterThan(0), reason: e.key);
      expect(first, isNotEmpty, reason: e.key);
    }
    expect((await library.index(LibraryFilter.empty)).length, n);
    // ignore: avoid_print
    print(
      'momentos (recálculo): $momentsMs ms · ${[for (final e in times.entries) '${e.key}: ${e.value} ms'].join(' · ')}',
    );
    for (final e in times.entries) {
      expect(e.value, lessThan(1000), reason: '${e.key} levou ${e.value} ms');
    }
  });
}
