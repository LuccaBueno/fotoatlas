import 'dart:async';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../util/clock.dart';

/// Tipo de item lógico.
enum MediaItemKind {
  /// Foto RAW e o JPEG/HEIC tirados juntos pela câmera.
  rawJpeg('raw_jpeg'),

  /// Live Photo: a foto e o vídeo curto que a acompanha.
  livePhoto('live_photo'),

  /// Agrupado à mão pelo usuário.
  manual('manual');

  const MediaItemKind(this.sql);
  final String sql;

  static MediaItemKind fromSql(String s) => values.firstWhere((k) => k.sql == s, orElse: () => manual);
}

/// Um arquivo de um item lógico.
class MediaItemMember {
  const MediaItemMember(this.contentId, this.role);
  final int contentId;

  /// 'photo', 'raw' ou 'video'.
  final String role;
}

/// Um item lógico ativo (não desagrupado).
class MediaItemView {
  const MediaItemView({required this.id, required this.kind, required this.primaryContentId, required this.members});
  final int id;
  final MediaItemKind kind;

  /// O que aparece na Biblioteca (a foto JPEG/HEIC).
  final int primaryContentId;
  final List<MediaItemMember> members;

  List<int> get contentIds => [for (final m in members) m.contentId];
}

/// Item lógico (Fase 9, ADR 0024): RAW+JPEG e Live Photos mostrados como um
/// item só na Biblioteca. **Só visual e só no catálogo**: nenhum arquivo é
/// tocado; cobertura, comparação, verificação e o diário continuam arquivo a
/// arquivo. Copiar ou reorganizar um item leva todos os arquivos dele (a
/// prévia mostra). Desagrupar grava `split_at`: o grupo não volta sozinho.
class MediaItemsService {
  MediaItemsService(this.db);
  final CatalogDatabase db;

  /// Duração máxima do vídeo de uma Live Photo reconhecida só pelo nome.
  static const liveVideoMaxMs = 5000;

  static const _videoExts = {'mov', 'mp4'};

  final _changes = StreamController<void>.broadcast();

  /// Grupos criados, desfeitos ou refeitos.
  Stream<void> get changes => _changes.stream;

  Future<void>? _running;

  /// Procura grupos novos no catálogo (mesma pasta da mesma fonte). Chamar
  /// de novo durante uma busca devolve a mesma. Devolve quantos criou.
  Future<int> detect() async {
    final running = _running;
    if (running != null) {
      await running;
      return 0;
    }
    final c = Completer<void>();
    _running = c.future;
    try {
      return await _detect();
    } finally {
      _running = null;
      c.complete();
    }
  }

  Future<int> _detect() async {
    final rows = await db.customSelect('''
      SELECT fi.content_id, fi.source_id, fi.dir_rel_path, fi.name, fi.ext, c.media_type,
             mm.content_identifier, mm.duration_ms, mm.meta_status
      FROM file_instances fi
      JOIN contents c ON c.id = fi.content_id
      JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL
      LEFT JOIN media_metadata mm ON mm.content_id = fi.content_id
      WHERE fi.availability = 'present' AND fi.hash_status = 'done' AND c.media_type IN ('photo','raw','video')
      ''').get();
    final byStem = <String, List<_File>>{};
    final byCid = <String, List<_File>>{};
    for (final r in rows) {
      final f = _File(
        r.read<int>('content_id'),
        r.read<String>('media_type'),
        r.read<String>('ext').toLowerCase(),
        r.readNullable<String>('content_identifier'),
        r.readNullable<int>('duration_ms'),
        r.readNullable<String>('meta_status') == 'full',
      );
      final place = '${r.read<String>('source_id')}|${r.read<String>('dir_rel_path').toLowerCase()}';
      (byStem['$place|${_stem(r.read<String>('name')).toLowerCase()}'] ??= []).add(f);
      if (f.cid != null && f.cid!.isNotEmpty) (byCid['$place|${f.cid}'] ??= []).add(f);
    }

    // Conteúdo → item ativo; itens automáticos ativos → membros (podem
    // crescer: RAW+JPEG que depois ganha o vídeo da Live Photo).
    final taken = <int, int>{};
    final autoMembers = <int, Set<int>>{};
    final splitSets = <String>{};
    for (final r in await db.customSelect('''
      SELECT i.split_at, i.origin, m.item_id, m.content_id FROM media_item_members m JOIN media_items i ON i.id = m.item_id
      ''').get()) {
      if (r.readNullable<int>('split_at') != null) continue;
      taken[r.read<int>('content_id')] = r.read<int>('item_id');
      if (r.read<String>('origin') == 'auto') {
        (autoMembers[r.read<int>('item_id')] ??= {}).add(r.read<int>('content_id'));
      }
    }
    final splitMembers = <int, List<int>>{};
    for (final r in await db.customSelect('''
      SELECT m.item_id, m.content_id FROM media_item_members m JOIN media_items i ON i.id = m.item_id
      WHERE i.split_at IS NOT NULL
      ''').get()) {
      (splitMembers[r.read<int>('item_id')] ??= []).add(r.read<int>('content_id'));
    }
    for (final ids in splitMembers.values) {
      splitSets.add(_setKey(ids));
    }

    final candidates = <(MediaItemKind, int, Map<int, String>)>[];
    void consider(List<_File> files, {required bool byIdentifier}) {
      final photos = {for (final f in files.where((f) => f.mediaType == 'photo')) f.contentId: f};
      if (photos.length != 1) return;
      final photo = photos.values.single;
      final raws = {for (final f in files.where((f) => f.mediaType == 'raw')) f.contentId};
      final videos = {
        for (final f in files.where((f) => f.mediaType == 'video' && _videoExts.contains(f.ext))) f.contentId: f,
      };
      final members = <int, String>{photo.contentId: 'photo'};
      if (!byIdentifier) {
        for (final r in raws) {
          members[r] = 'raw';
        }
      }
      var live = false;
      if (videos.length == 1) {
        final v = videos.values.single;
        final sameId = photo.cid != null && photo.cid == v.cid;
        final short = v.metadataRead && v.durationMs != null && v.durationMs! <= liveVideoMaxMs;
        if (sameId || (!byIdentifier && short)) {
          members[v.contentId] = 'video';
          live = true;
        }
      }
      if (members.length < 2) return;
      candidates.add((live ? MediaItemKind.livePhoto : MediaItemKind.rawJpeg, photo.contentId, members));
    }

    for (final files in byCid.values) {
      consider(files, byIdentifier: true);
    }
    for (final files in byStem.values) {
      consider(files, byIdentifier: false);
    }

    var created = 0;
    final now = nowMs();
    await db.transaction(() async {
      for (final (kind, primary, members) in candidates) {
        if (splitSets.contains(_setKey(members.keys))) continue;
        final owners = {for (final c in members.keys) ?taken[c]};
        if (owners.isNotEmpty) {
          // Só cresce um item automático que fica inteiro dentro do novo.
          if (owners.length != 1) continue;
          final owner = owners.single;
          final current = autoMembers[owner];
          if (current == null || current.length >= members.length || !members.keys.toSet().containsAll(current)) {
            continue;
          }
          await db.customStatement('UPDATE media_items SET kind = ?, primary_content_id = ? WHERE id = ?', [
            kind.sql,
            primary,
            owner,
          ]);
          for (final MapEntry(key: content, value: role) in members.entries) {
            if (current.contains(content)) continue;
            await db.customStatement('INSERT INTO media_item_members (item_id, content_id, role) VALUES (?, ?, ?)', [
              owner,
              content,
              role,
            ]);
            taken[content] = owner;
          }
          current.addAll(members.keys);
          created++;
          continue;
        }
        final id = await db.customInsert(
          "INSERT INTO media_items (kind, primary_content_id, origin, created_at) VALUES (?, ?, 'auto', ?)",
          variables: [Variable.withString(kind.sql), Variable.withInt(primary), Variable.withInt(now)],
        );
        for (final MapEntry(key: content, value: role) in members.entries) {
          await db.customStatement('INSERT INTO media_item_members (item_id, content_id, role) VALUES (?, ?, ?)', [
            id,
            content,
            role,
          ]);
        }
        for (final c in members.keys) {
          taken[c] = id;
        }
        autoMembers[id] = members.keys.toSet();
        created++;
      }
    });
    if (created > 0) _notify();
    return created;
  }

  /// Agrupa à mão (só catálogo). A primeira foto (não RAW, não vídeo) é a que
  /// aparece; os conteúdos saem de outros grupos ativos.
  Future<int> group(List<int> contentIds) async {
    final ids = contentIds.toSet().toList();
    if (ids.length < 2) throw ArgumentError('Escolha pelo menos dois itens para agrupar.');
    final types = {
      for (final r in await db.customSelect('SELECT id, media_type FROM contents WHERE id IN (${ids.join(',')})').get())
        r.read<int>('id'): r.read<String>('media_type'),
    };
    String role(int id) => switch (types[id]) {
      'raw' => 'raw',
      'video' => 'video',
      _ => 'photo',
    };
    final primary = ids.firstWhere((id) => role(id) == 'photo', orElse: () => ids.first);
    late int itemId;
    await db.transaction(() async {
      await _splitContaining(ids);
      itemId = await db.customInsert(
        "INSERT INTO media_items (kind, primary_content_id, origin, created_at) VALUES ('manual', ?, 'manual', ?)",
        variables: [Variable.withInt(primary), Variable.withInt(nowMs())],
      );
      for (final id in ids) {
        await db.customStatement('INSERT INTO media_item_members (item_id, content_id, role) VALUES (?, ?, ?)', [
          itemId,
          id,
          role(id),
        ]);
      }
    });
    _notify();
    return itemId;
  }

  /// Desagrupa (só catálogo): cada arquivo volta a aparecer sozinho e o grupo
  /// não é refeito pela detecção automática.
  Future<void> split(int itemId) async {
    await db.customStatement('UPDATE media_items SET split_at = ? WHERE id = ? AND split_at IS NULL', [
      nowMs(),
      itemId,
    ]);
    _notify();
  }

  Future<void> _splitContaining(List<int> contentIds) => db.customStatement(
    'UPDATE media_items SET split_at = ? WHERE split_at IS NULL AND id IN '
    '(SELECT item_id FROM media_item_members WHERE content_id IN (${contentIds.join(',')}))',
    [nowMs()],
  );

  /// Itens ativos que contêm algum de [contentIds].
  Future<List<MediaItemView>> itemsFor(Iterable<int> contentIds) async {
    final ids = contentIds.toSet();
    if (ids.isEmpty) return const [];
    final rows = <QueryRow>[];
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
      rows.addAll(
        await db.customSelect('''
          SELECT i.id, i.kind, i.primary_content_id, m.content_id, m.role
          FROM media_items i JOIN media_item_members m ON m.item_id = i.id
          WHERE i.split_at IS NULL AND i.id IN
            (SELECT item_id FROM media_item_members WHERE content_id IN (${chunk.join(',')}))
          ORDER BY i.id, m.role = 'photo' DESC, m.content_id
          ''').get(),
      );
    }
    return _views(rows);
  }

  /// Todos os itens ativos.
  Future<List<MediaItemView>> all() async => _views(
    await db.customSelect('''
      SELECT i.id, i.kind, i.primary_content_id, m.content_id, m.role
      FROM media_items i JOIN media_item_members m ON m.item_id = i.id
      WHERE i.split_at IS NULL ORDER BY i.id, m.role = 'photo' DESC, m.content_id
      ''').get(),
  );

  List<MediaItemView> _views(List<QueryRow> rows) {
    final out = <int, MediaItemView>{};
    for (final r in rows) {
      final id = r.read<int>('id');
      final view = out[id] ??= MediaItemView(
        id: id,
        kind: MediaItemKind.fromSql(r.read<String>('kind')),
        primaryContentId: r.read<int>('primary_content_id'),
        members: [],
      );
      if (view.members.every((m) => m.contentId != r.read<int>('content_id'))) {
        view.members.add(MediaItemMember(r.read<int>('content_id'), r.read<String>('role')));
      }
    }
    return out.values.toList();
  }

  /// [contentIds] mais os outros arquivos dos itens a que pertencem (copiar
  /// ou reorganizar um item leva o grupo todo). Devolve também, para cada
  /// conteúdo acrescentado, o principal do grupo (para a prévia).
  Future<(List<int>, Map<int, int>)> expand(List<int> contentIds) async {
    final out = [...contentIds];
    final seen = contentIds.toSet();
    final addedFor = <int, int>{};
    for (final item in await itemsFor(contentIds)) {
      for (final m in item.members) {
        if (seen.add(m.contentId)) {
          out.add(m.contentId);
          addedFor[m.contentId] = item.primaryContentId;
        }
      }
    }
    return (out, addedFor);
  }

  /// Arquivos secundários (RAW, vídeo da Live Photo) → o principal do grupo.
  Future<Map<int, int>> secondaryToPrimary() async => {
    for (final r in await db.customSelect('''
      SELECT m.content_id, i.primary_content_id FROM media_item_members m JOIN media_items i ON i.id = m.item_id
      WHERE i.split_at IS NULL AND m.content_id <> i.primary_content_id
      ''').get())
      r.read<int>('content_id'): r.read<int>('primary_content_id'),
  };

  void _notify() {
    // As consultas da Biblioteca observam a tabela (os comandos SQL soltos
    // acima não avisam sozinhos).
    db.notifyUpdates({TableUpdate.onTable(db.mediaItems, kind: UpdateKind.update)});
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _running;
    await _changes.close();
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static String _setKey(Iterable<int> ids) => (ids.toList()..sort()).join(',');
}

class _File {
  _File(this.contentId, this.mediaType, this.ext, this.cid, this.durationMs, this.metadataRead);
  final int contentId;
  final String mediaType;
  final String ext;
  final String? cid;
  final int? durationMs;
  final bool metadataRead;
}
