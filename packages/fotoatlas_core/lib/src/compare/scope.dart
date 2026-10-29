import 'dart:convert';

import 'package:drift/drift.dart';

import '../library/library_filter.dart';
import '../sources/media_types.dart';

/// Uma parte de um escopo: uma fonte inteira ou uma pasta dentro dela.
class ScopeEntry {
  const ScopeEntry(this.sourceId, [this.relPath = '']);

  final String sourceId;

  /// Pasta relativa à raiz da fonte, com '/'. '' = a fonte inteira.
  final String relPath;

  bool get isWholeSource => relPath.isEmpty;

  /// Esta entrada contém [other] (mesma fonte e pasta igual ou mais funda)?
  bool contains(ScopeEntry other) =>
      sourceId == other.sourceId &&
      (relPath.isEmpty || other.relPath == relPath || other.relPath.startsWith('$relPath/'));

  @override
  bool operator ==(Object other) => other is ScopeEntry && other.sourceId == sourceId && other.relPath == relPath;

  @override
  int get hashCode => Object.hash(sourceId, relPath);

  @override
  String toString() => relPath.isEmpty ? sourceId : '$sourceId:$relPath';
}

/// Um momento como parte de um escopo (spec §9): os arquivos daquele momento
/// em qualquer dispositivo, ou só numa fonte ("momento X no celular").
class MomentScopeEntry {
  const MomentScopeEntry(this.momentId, [this.sourceId]);
  final int momentId;
  final String? sourceId;

  @override
  bool operator ==(Object other) =>
      other is MomentScopeEntry && other.momentId == momentId && other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(momentId, sourceId);
}

/// Tipos de arquivo para o filtro do escopo (pela extensão).
enum ScopeFileType { photo, raw, video, other }

/// Escopo livre de comparação (spec §9): uma ou mais pastas, fontes inteiras
/// e/ou momentos, com filtro opcional por tipo e pelos metadados (data,
/// horário, câmera… — o mesmo filtro da Biblioteca).
class Scope {
  Scope(
    Iterable<ScopeEntry> entries, {
    Set<ScopeFileType>? types,
    Iterable<MomentScopeEntry> moments = const [],
    LibraryFilter? filter,
  }) : entries = List.unmodifiable(_simplify(entries)),
       moments = List.unmodifiable(moments.toSet()),
       filter = filter == null || filter.isEmpty ? null : filter,
       types = types == null || types.isEmpty || types.length == ScopeFileType.values.length
           ? null
           : Set.unmodifiable(types);

  /// Entradas sem repetição: uma pasta dentro de outra entrada já incluída sai.
  final List<ScopeEntry> entries;

  /// Momentos (Fase 4).
  final List<MomentScopeEntry> moments;

  /// `null` = todos os tipos.
  final Set<ScopeFileType>? types;

  /// Filtro pelos metadados (`null` = nenhum).
  final LibraryFilter? filter;

  bool get isEmpty => entries.isEmpty && moments.isEmpty;
  Set<String> get sourceIds => {for (final e in entries) e.sourceId, for (final m in moments) ?m.sourceId};

  static List<ScopeEntry> _simplify(Iterable<ScopeEntry> input) {
    final list = <ScopeEntry>[];
    for (final e in input) {
      final rel = e.relPath.replaceAll(r'\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
      final entry = ScopeEntry(e.sourceId, rel);
      if (list.any((x) => x.contains(entry))) continue;
      list
        ..removeWhere(entry.contains)
        ..add(entry);
    }
    return list;
  }

  /// Formato salvo no catálogo (`saved_scopes.definition_json`). Escopos só
  /// com pastas e tipo continuam em `v: 1` (o formato antigo).
  String toJson() => jsonEncode({
    'v': moments.isEmpty && filter == null ? 1 : 2,
    'entries': [
      for (final e in entries) {'source': e.sourceId, 'path': e.relPath},
    ],
    if (moments.isNotEmpty)
      'moments': [
        for (final m in moments) {'moment': m.momentId, 'source': ?m.sourceId},
      ],
    if (types != null) 'types': [for (final t in types!) t.name],
    if (filter != null) 'filter': jsonDecode(filter!.toJson()),
  });

  factory Scope.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, Object?>;
    final entries = [
      for (final e in (map['entries'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
        ScopeEntry(e['source']! as String, (e['path'] as String?) ?? ''),
    ];
    final moments = [
      for (final m in (map['moments'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
        MomentScopeEntry(m['moment']! as int, m['source'] as String?),
    ];
    final types = (map['types'] as List<Object?>?)
        ?.map((t) => ScopeFileType.values.where((v) => v.name == t))
        .expand((x) => x)
        .toSet();
    final filter = map['filter'];
    return Scope(
      entries,
      types: types,
      moments: moments,
      filter: filter == null ? null : LibraryFilter.fromJson(jsonEncode(filter)),
    );
  }

  /// Predicado SQL sobre `file_instances` com alias [alias], com as variáveis.
  (String, List<Variable<Object>>) sqlPredicate(String alias) {
    if (isEmpty) return ('0', const []);
    final vars = <Variable<Object>>[];
    final parts = <String>[];
    for (final e in entries) {
      if (e.isWholeSource) {
        parts.add('$alias.source_id = ?');
        vars.add(Variable.withString(e.sourceId));
      } else {
        parts.add('($alias.source_id = ? AND ($alias.dir_rel_path = ? OR substr($alias.dir_rel_path, 1, ?) = ?))');
        vars
          ..add(Variable.withString(e.sourceId))
          ..add(Variable.withString(e.relPath))
          ..add(Variable.withInt(e.relPath.length + 1))
          ..add(Variable.withString('${e.relPath}/'));
      }
    }
    for (final m in moments) {
      final src = m.sourceId;
      parts.add(
        '($alias.content_id IN (SELECT content_id FROM media_metadata WHERE moment_id = ?)'
        '${src == null ? '' : ' AND $alias.source_id = ?'})',
      );
      vars.add(Variable.withInt(m.momentId));
      if (src != null) vars.add(Variable.withString(src));
    }
    var sql = '(${parts.join(' OR ')})';
    final t = types;
    if (t != null) {
      final typeParts = <String>[
        if (t.contains(ScopeFileType.photo)) '$alias.ext IN ${MediaTypes.sqlList(MediaTypes.photo)}',
        if (t.contains(ScopeFileType.raw)) '$alias.ext IN ${MediaTypes.sqlList(MediaTypes.raw)}',
        if (t.contains(ScopeFileType.video)) '$alias.ext IN ${MediaTypes.sqlList(MediaTypes.video)}',
        if (t.contains(ScopeFileType.other)) '$alias.ext NOT IN ${MediaTypes.sqlList(MediaTypes.media)}',
      ];
      sql = '($sql AND (${typeParts.join(' OR ')}))';
    }
    final f = filter;
    if (f != null) {
      // Arquivo ainda sem conteúdo conferido não tem metadados: fica no
      // escopo e deixa o resultado "incompleto" até ser conferido (nunca
      // some calado da comparação).
      final (fs, fv) = f.toSql();
      sql =
          '($sql AND ($alias.content_id IS NULL OR $alias.hash_status != \'done\' OR $alias.content_id IN '
          '(SELECT c.id FROM contents c LEFT JOIN media_metadata mm ON mm.content_id = c.id WHERE $fs)))';
      vars.addAll(fv);
    }
    return (sql, vars);
  }
}

/// Escopo salvo com nome (ex.: "Fotos do celular antigo").
class SavedScope {
  const SavedScope({required this.id, required this.name, required this.scope, required this.updatedAt});
  final int id;
  final String name;
  final Scope scope;
  final DateTime updatedAt;
}
