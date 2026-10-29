import 'dart:convert';

import 'package:drift/drift.dart';

/// Tipos de condição dos filtros da Biblioteca (spec §10).
enum FilterKind {
  /// Anos (valores: int).
  years,

  /// Meses 'AAAA-MM'.
  months,

  /// Dias de 'AAAA-MM-DD' a 'AAAA-MM-DD' (valores: [de, até]).
  dateRange,

  /// Sem data.
  noDate,

  /// Faixa de horário em minutos do dia (min/max; min > max atravessa a meia-noite).
  timeRange,

  /// Período do dia ([DayPeriod.name]).
  periods,

  /// Dia da semana (1 = segunda … 7 = domingo).
  weekdays,

  /// Momentos (IDs).
  moments,

  /// Confiança da hora ('high', 'medium', 'low', 'none').
  confidence,

  /// Hora a confirmar (baixa confiança, não corrigida nem confirmada).
  toConfirm,

  /// Com correção (de relógio ou manual).
  corrected,

  /// Datas conflitantes (EXIF × nome etc.).
  conflict,

  /// Fontes (IDs): itens com cópia nelas.
  sources,

  /// Câmeras/celulares ('fabricante\u0001modelo').
  cameras,

  /// Tipo ('photo', 'raw', 'video').
  types,

  /// Extensão (sem ponto, minúscula).
  extensions,

  /// Tamanho em bytes (min/max).
  size,

  /// Resolução mínima em megapixels (min).
  resolution,

  /// Duração em ms (min/max).
  duration,

  /// Com GPS (valores: [true]) ou sem (valores: [false]).
  gps,

  /// Situação de backup ('single', 'verified', 'independent').
  backup,

  /// Erro ao ler os metadados.
  metaError,

  /// Texto no nome, no caminho ou no nome do momento.
  text,
}

/// Períodos do dia pela hora local (spec §10).
enum DayPeriod {
  madrugada(0, 6, 'Madrugada'),
  manha(6, 12, 'Manhã'),
  tarde(12, 18, 'Tarde'),
  noite(18, 24, 'Noite');

  const DayPeriod(this.fromHour, this.toHour, this.label);
  final int fromHour;
  final int toHour;
  final String label;
}

/// Uma condição (um chip). [negate] = NÃO.
class FilterCondition {
  const FilterCondition(this.kind, {this.values = const [], this.min, this.max, this.text, this.negate = false});

  final FilterKind kind;
  final List<Object> values;
  final num? min;
  final num? max;
  final String? text;
  final bool negate;

  FilterCondition copyWith({List<Object>? values, num? min, num? max, String? text, bool? negate}) => FilterCondition(
    kind,
    values: values ?? this.values,
    min: min ?? this.min,
    max: max ?? this.max,
    text: text ?? this.text,
    negate: negate ?? this.negate,
  );

  Map<String, Object?> toJson() => {
    't': kind.name,
    if (values.isNotEmpty) 'v': values,
    'min': ?min,
    'max': ?max,
    'text': ?text,
    if (negate) 'not': true,
  };

  static FilterCondition? fromJson(Map<String, Object?> j) {
    final kind = FilterKind.values.where((k) => k.name == j['t']).firstOrNull;
    if (kind == null) return null; // condição de uma versão mais nova: ignorada
    return FilterCondition(
      kind,
      values: [...(j['v'] as List<Object?>? ?? const []).nonNulls],
      min: j['min'] as num?,
      max: j['max'] as num?,
      text: j['text'] as String?,
      negate: j['not'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is FilterCondition && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Filtro da Biblioteca: condições ligadas por E (padrão) ou OU, cada uma
/// podendo ser negada (spec §3.1 "construtor avançado E/OU/NÃO").
class LibraryFilter {
  const LibraryFilter([this.conditions = const [], this.any = false]);

  final List<FilterCondition> conditions;

  /// `true` = basta uma condição (OU).
  final bool any;

  static const empty = LibraryFilter();
  bool get isEmpty => conditions.isEmpty;

  LibraryFilter withCondition(FilterCondition c) =>
      LibraryFilter([...conditions.where((x) => x.kind != c.kind), c], any);
  LibraryFilter without(FilterKind kind) => LibraryFilter([...conditions.where((x) => x.kind != kind)], any);
  FilterCondition? of(FilterKind kind) => conditions.where((c) => c.kind == kind).firstOrNull;

  String toJson() => jsonEncode({
    'v': 1,
    if (any) 'any': true,
    'conds': [for (final c in conditions) c.toJson()],
  });

  factory LibraryFilter.fromJson(String json) {
    final m = jsonDecode(json) as Map<String, Object?>;
    return LibraryFilter([
      for (final c in (m['conds'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
        ?FilterCondition.fromJson(c),
    ], m['any'] == true);
  }

  /// Predicado SQL sobre `contents` [c] e `media_metadata` [mm] (LEFT JOIN).
  /// [simpleCopies]: as fontes cadastradas não se sobrepõem (nenhuma está
  /// dentro de outra), então cada cópia é um arquivo físico diferente e a
  /// contagem simples basta (bem mais rápida em 100 mil itens).
  (String, List<Variable<Object>>) toSql({String c = 'c', String mm = 'mm', bool simpleCopies = false}) {
    if (conditions.isEmpty) return ('1', const []);
    final vars = <Variable<Object>>[];
    final parts = <String>[];
    for (final cond in conditions) {
      final sql = _cond(cond, c, mm, vars, simpleCopies);
      parts.add(cond.negate ? 'NOT COALESCE(($sql), 0)' : 'COALESCE(($sql), 0)');
    }
    return ('(${parts.join(any ? ' OR ' : ' AND ')})', vars);
  }

  static String _in(Iterable<Object> values, List<Variable<Object>> vars) {
    if (values.isEmpty) return '(NULL)';
    for (final v in values) {
      vars.add(switch (v) {
        final int i => Variable.withInt(i),
        final num n => Variable.withReal(n.toDouble()),
        final bool b => Variable.withBool(b),
        _ => Variable.withString(v.toString()),
      });
    }
    return '(${List.filled(values.length, '?').join(',')})';
  }

  static String _like(String text) => '%${text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';

  static String _cond(FilterCondition f, String c, String mm, List<Variable<Object>> vars, bool simpleCopies) {
    String range(String col) {
      final p = <String>[];
      if (f.min != null) {
        p.add('$col >= ?');
        vars.add(Variable.withReal(f.min!.toDouble()));
      }
      if (f.max != null) {
        p.add('$col <= ?');
        vars.add(Variable.withReal(f.max!.toDouble()));
      }
      return p.isEmpty ? '1' : p.join(' AND ');
    }

    const present = "fi.availability = 'present'";
    switch (f.kind) {
      case FilterKind.years:
        return '$mm.eff_year IN ${_in(f.values, vars)}';
      case FilterKind.months:
        return "printf('%04d-%02d', $mm.eff_year, $mm.eff_month) IN ${_in(f.values, vars)}";
      case FilterKind.dateRange:
        final from = f.values.isNotEmpty ? f.values[0] : null;
        final to = f.values.length > 1 ? f.values[1] : null;
        final p = <String>['$mm.eff_day IS NOT NULL'];
        if (from != null) {
          p.add('$mm.eff_day >= ?');
          vars.add(Variable.withString('$from'));
        }
        if (to != null) {
          p.add('$mm.eff_day <= ?');
          vars.add(Variable.withString('$to'));
        }
        return p.join(' AND ');
      case FilterKind.noDate:
        return '$mm.eff_utc_ms IS NULL';
      case FilterKind.timeRange:
        final from = (f.min ?? 0).toInt(), to = (f.max ?? 1439).toInt();
        vars
          ..add(Variable.withInt(from))
          ..add(Variable.withInt(to));
        return from <= to
            ? '$mm.eff_minute BETWEEN ? AND ?'
            : '($mm.eff_minute >= ? OR $mm.eff_minute <= ?)'; // atravessa a meia-noite
      case FilterKind.periods:
        final ps = [for (final v in f.values) ...DayPeriod.values.where((d) => d.name == v)];
        if (ps.isEmpty) return '0';
        return ps
            .map((d) => '($mm.eff_minute >= ${d.fromHour * 60} AND $mm.eff_minute < ${d.toHour * 60})')
            .join(' OR ');
      case FilterKind.weekdays:
        return '$mm.eff_weekday IN ${_in(f.values, vars)}';
      case FilterKind.moments:
        return '$mm.moment_id IN ${_in(f.values, vars)}';
      case FilterKind.confidence:
        return "COALESCE($mm.eff_confidence, 'none') IN ${_in(f.values, vars)}";
      case FilterKind.toConfirm:
        return "COALESCE($mm.eff_confidence, 'none') IN ('low','none') AND COALESCE($mm.eff_source, '') != 'manual'";
      case FilterKind.corrected:
        return "($mm.clock_correction_id IS NOT NULL OR $mm.eff_source = 'manual')";
      case FilterKind.conflict:
        return '$mm.date_conflict = 1';
      case FilterKind.sources:
        return 'EXISTS (SELECT 1 FROM file_instances fi WHERE fi.content_id = $c.id AND $present '
            'AND fi.source_id IN ${_in(f.values, vars)})';
      case FilterKind.cameras:
        final p = <String>[];
        for (final v in f.values) {
          final parts = '$v'.split('\u0001');
          p.add("(COALESCE($mm.make, '') = ? AND COALESCE($mm.model, '') = ?)");
          vars
            ..add(Variable.withString(parts[0]))
            ..add(Variable.withString(parts.length > 1 ? parts[1] : ''));
        }
        return p.isEmpty ? '0' : p.join(' OR ');
      case FilterKind.types:
        return '$c.media_type IN ${_in(f.values, vars)}';
      case FilterKind.extensions:
        return 'EXISTS (SELECT 1 FROM file_instances fi WHERE fi.content_id = $c.id AND $present '
            'AND fi.ext IN ${_in([for (final e in f.values) '$e'.toLowerCase()], vars)})';
      case FilterKind.size:
        return range('$c.size_bytes');
      case FilterKind.resolution:
        if (f.min == null) return '1';
        vars.add(Variable.withReal(f.min!.toDouble() * 1e6));
        return '$mm.width * $mm.height >= ?';
      case FilterKind.duration:
        return '$mm.duration_ms IS NOT NULL AND ${range('$mm.duration_ms')}';
      case FilterKind.gps:
        final has = f.values.isEmpty || f.values.first == true;
        return has ? '$mm.lat IS NOT NULL' : '$mm.lat IS NULL';
      case FilterKind.backup:
        return '$c.id IN (SELECT content_id FROM (${backupStatesSql(simpleCopies: simpleCopies)}) WHERE state IN ${_in(f.values, vars)})';
      case FilterKind.metaError:
        return "$mm.meta_status = 'error'";
      case FilterKind.text:
        final t = f.text?.trim() ?? '';
        if (t.isEmpty) return '1';
        vars
          ..add(Variable.withString(_like(t)))
          ..add(Variable.withString(_like(t)));
        return "EXISTS (SELECT 1 FROM file_instances fi WHERE fi.content_id = $c.id AND fi.rel_path LIKE ? ESCAPE '\\') "
            "OR $mm.moment_id IN (SELECT id FROM moments WHERE name LIKE ? ESCAPE '\\')";
    }
  }

  /// (content_id, copies, disks, state) dos conteúdos conferidos: mesmas
  /// regras da cobertura (cópia = instância `present` de fonte não esquecida;
  /// o mesmo arquivo físico visto por duas fontes conta uma vez; "disco
  /// independente" só com discos de identidade confiável).
  static String backupStatesSql({String? onlyIds, bool simpleCopies = false}) =>
      '''
      SELECT content_id, copies, disks,
        CASE WHEN disks >= 2 THEN 'independent' WHEN copies >= 2 THEN 'verified' ELSE 'single' END AS state
      FROM (
        SELECT fi.content_id,
          ${simpleCopies ? 'COUNT(*)' : _physCount} AS copies,
          COUNT(DISTINCT CASE WHEN d.identity_confidence = 'reliable' OR d.user_confirmed THEN d.id END) AS disks
        FROM file_instances fi
        JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL
        LEFT JOIN physical_disks d ON d.id = s.physical_disk_id
        WHERE fi.availability = 'present' AND fi.hash_status = 'done' AND fi.content_id IS NOT NULL
          ${onlyIds == null ? '' : 'AND fi.content_id IN ($onlyIds)'}
        GROUP BY fi.content_id
      )
      ''';
}

/// Cópias físicas distintas: o mesmo arquivo visto por duas fontes
/// sobrepostas (pasta dentro de outra fonte) conta uma vez.
const _physCount =
    "COUNT(DISTINCT COALESCE(lower(s.volume_guid), s.id) || '|' || "
    "lower(CASE WHEN s.root_rel_path = '' THEN fi.rel_path ELSE s.root_rel_path || '/' || fi.rel_path END))";
