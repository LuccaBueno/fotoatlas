import 'dart:convert';

import 'package:drift/drift.dart';

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

/// Tipos de arquivo para o filtro do escopo (pela extensão, até a Fase 4).
enum ScopeFileType { photo, raw, video, other }

/// Escopo livre de comparação (spec §9): uma ou mais pastas e/ou fontes
/// inteiras, com filtro opcional por tipo. Datas e câmera entram na Fase 4.
class Scope {
  Scope(Iterable<ScopeEntry> entries, {Set<ScopeFileType>? types})
    : entries = List.unmodifiable(_simplify(entries)),
      types = types == null || types.isEmpty || types.length == ScopeFileType.values.length
          ? null
          : Set.unmodifiable(types);

  /// Entradas sem repetição: uma pasta dentro de outra entrada já incluída sai.
  final List<ScopeEntry> entries;

  /// `null` = todos os tipos.
  final Set<ScopeFileType>? types;

  bool get isEmpty => entries.isEmpty;
  Set<String> get sourceIds => {for (final e in entries) e.sourceId};

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

  /// Formato salvo no catálogo (`saved_scopes.definition_json`).
  String toJson() => jsonEncode({
    'v': 1,
    'entries': [
      for (final e in entries) {'source': e.sourceId, 'path': e.relPath},
    ],
    if (types != null) 'types': [for (final t in types!) t.name],
  });

  factory Scope.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, Object?>;
    final entries = [
      for (final e in (map['entries'] as List<Object?>).cast<Map<String, Object?>>())
        ScopeEntry(e['source']! as String, (e['path'] as String?) ?? ''),
    ];
    final types = (map['types'] as List<Object?>?)
        ?.map((t) => ScopeFileType.values.where((v) => v.name == t))
        .expand((x) => x)
        .toSet();
    return Scope(entries, types: types);
  }

  /// Predicado SQL sobre `file_instances` com alias [alias], com as variáveis.
  (String, List<Variable<Object>>) sqlPredicate(String alias) {
    if (entries.isEmpty) return ('0', const []);
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
