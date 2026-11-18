import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../sources/sources_service.dart';
import '../util/clock.dart';
import 'takeout_match.dart';

/// O que o Takeout diz de um conteúdo.
class TakeoutInfo {
  const TakeoutInfo(this.json);

  /// `null` = está numa pasta do Takeout, mas sem `.json` correspondente.
  final TakeoutSidecar? json;
}

/// Uma cópia de um conteúdo (para casar com os `.json` da mesma pasta).
typedef TakeoutInstance = ({int contentId, String sourceId, String relPath, String name});

/// Google Takeout (Fase 9, ADR 0025): lê os `.json` que acompanham as fotos,
/// **só leitura**. Datas e locais ficam só no catálogo (`takeout_json` e as
/// candidatas de data); nenhum arquivo é alterado.
class TakeoutService {
  TakeoutService(this.db, this.sources);
  final CatalogDatabase db;
  final SourcesService sources;

  /// `.json` maiores que isso não são de foto (ex.: listas de álbuns enormes).
  static const maxJsonBytes = 2 * 1024 * 1024;

  /// Lê os `.json` novos ou mudados das fontes conectadas (celulares ficam de
  /// fora) e devolve as fotos e vídeos das pastas deles, para as datas serem
  /// refeitas. Um `.json` ilegível fica marcado como inválido (tenta de novo
  /// se mudar).
  Future<Set<int>> sync() async {
    final rows = await db.customSelect('''
      SELECT fi.id, fi.source_id, fi.rel_path, fi.dir_rel_path, fi.name, fi.size_bytes, fi.mtime
      FROM file_instances fi
      JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL AND s.kind <> 'phone'
      LEFT JOIN takeout_json t ON t.instance_id = fi.id
      WHERE fi.ext = 'json' AND fi.availability = 'present'
        AND (t.instance_id IS NULL OR t.size_bytes <> fi.size_bytes OR t.mtime IS NOT fi.mtime)
      ''').get();
    if (rows.isEmpty) return const {};
    final dirs = <(String, String)>{};
    final now = nowMs();
    final parsed = <(int, int, int?, TakeoutSidecar?)>[];
    for (final r in rows) {
      final source = await sources.byId(r.read<String>('source_id'));
      final root = source == null ? null : sources.accessRoot(source);
      if (root == null) continue;
      final size = r.read<int>('size_bytes');
      TakeoutSidecar? j;
      if (size <= maxJsonBytes) {
        try {
          final bytes = await File(_join(root, r.read<String>('rel_path'))).readAsBytes();
          j = TakeoutSidecar.parse(r.read<String>('name'), utf8.decode(bytes, allowMalformed: true));
        } on FileSystemException {
          continue; // Falha de leitura não é "não tem": tenta de novo depois.
        }
      }
      parsed.add((r.read<int>('id'), size, r.readNullable<int>('mtime'), j));
      if (j != null) dirs.add((r.read<String>('source_id'), r.read<String>('dir_rel_path')));
    }
    await db.transaction(() async {
      for (final (id, size, mtime, j) in parsed) {
        await db.customStatement(
          'INSERT INTO takeout_json (instance_id, size_bytes, mtime, valid, title, taken_utc_ms, lat, lon, read_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(instance_id) DO UPDATE SET size_bytes = excluded.size_bytes, '
          'mtime = excluded.mtime, valid = excluded.valid, title = excluded.title, taken_utc_ms = excluded.taken_utc_ms, '
          'lat = excluded.lat, lon = excluded.lon, read_at = excluded.read_at',
          [id, size, mtime, j == null ? 0 : 1, j?.title, j?.takenUtcMs, j?.lat, j?.lon, now],
        );
      }
    });
    final affected = <int>{};
    for (final (source, dir) in dirs) {
      for (final r
          in await db
              .customSelect(
                'SELECT DISTINCT fi.content_id FROM file_instances fi JOIN contents c ON c.id = fi.content_id '
                "WHERE fi.source_id = ? AND fi.dir_rel_path = ? AND c.media_type IN ('photo','raw','video')",
                variables: [Variable.withString(source), Variable.withString(dir)],
              )
              .get()) {
        affected.add(r.read<int>('content_id'));
      }
    }
    return affected;
  }

  /// Para cada conteúdo de [instances] numa pasta do Takeout: o `.json`
  /// casado (o primeiro encontrado entre as cópias) ou a marca "sem `.json`".
  /// Conteúdos fora de pastas do Takeout não aparecem.
  Future<Map<int, TakeoutInfo>> forInstances(Iterable<TakeoutInstance> instances) async {
    final byDir = <(String, String), List<TakeoutInstance>>{};
    for (final i in instances) {
      final slash = i.relPath.lastIndexOf('/');
      (byDir[(i.sourceId, slash < 0 ? '' : i.relPath.substring(0, slash))] ??= []).add(i);
    }
    final out = <int, TakeoutInfo>{};
    for (final MapEntry(key: (source, dir), value: list) in byDir.entries) {
      final jsons = [
        for (final r
            in await db
                .customSelect(
                  'SELECT fi.name, t.title, t.taken_utc_ms, t.lat, t.lon FROM takeout_json t '
                  'JOIN file_instances fi ON fi.id = t.instance_id '
                  "WHERE t.valid = 1 AND fi.source_id = ? AND fi.dir_rel_path = ? AND fi.availability = 'present'",
                  variables: [Variable.withString(source), Variable.withString(dir)],
                )
                .get())
          TakeoutSidecar(
            fileName: r.read<String>('name'),
            title: r.readNullable<String>('title'),
            takenUtcMs: r.readNullable<int>('taken_utc_ms'),
            lat: r.readNullable<double>('lat'),
            lon: r.readNullable<double>('lon'),
          ),
      ];
      if (jsons.isEmpty) continue;
      final matched = matchTakeout(list.map((i) => i.name), jsons);
      for (final i in list) {
        final j = matched[i.name];
        final prev = out[i.contentId];
        if (prev == null || (prev.json == null && j != null)) out[i.contentId] = TakeoutInfo(j);
      }
    }
    return out;
  }

  static String _join(String root, String rel) {
    final base = root.endsWith(r'\') ? root.substring(0, root.length - 1) : root;
    return '$base\\${rel.replaceAll('/', r'\')}';
  }
}
