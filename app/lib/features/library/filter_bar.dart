import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import 'library_controller.dart';
import 'library_strings.dart';

/// Chips de filtro (spec §3.1/§10): cada chip abre a escolha; marcado mostra
/// o que está valendo. "Filtro avançado" liga E/OU e NÃO.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);
    final c = ref.read(libraryControllerProvider.notifier);
    final facets = ref.watch(libraryFacetsProvider).value;
    final sources = {for (final s in ref.watch(sourcesProvider).value ?? const <SourceView>[]) s.id: s};
    final moments = ref.watch(momentsProvider).value ?? const <MomentView>[];
    final f = state.filter;

    String values(FilterKind k, String Function(Object v) label, {int max = 2}) {
      final cond = f.of(k);
      if (cond == null) return '';
      final list = cond.values.map(label).toList();
      final text = list.length <= max ? list.join(', ') : '${list.take(max).join(', ')} +${list.length - max}';
      return cond.negate ? 'todos menos $text' : text;
    }

    Widget chip(String key, String label, bool active, String detail, VoidCallback onTap, {FilterKind? clear}) {
      return InputChip(
        key: ValueKey('chip-$key'),
        tooltip: _chipHelp[key],
        label: Text(active ? '$label: $detail' : label),
        selected: active,
        showCheckmark: false,
        avatar: active ? null : const Icon(Icons.arrow_drop_down, size: 18),
        onPressed: onTap,
        onDeleted: active && clear != null ? () => c.setCondition(null, clear) : null,
        deleteButtonTooltipMessage: 'Tirar este filtro',
      );
    }

    final timeActive =
        f.of(FilterKind.timeRange) != null || f.of(FilterKind.periods) != null || f.of(FilterKind.weekdays) != null;
    final hourActive = [
      FilterKind.confidence,
      FilterKind.toConfirm,
      FilterKind.corrected,
      FilterKind.conflict,
    ].any((k) => f.of(k) != null);
    final moreActive = [
      FilterKind.dateRange,
      FilterKind.noDate,
      FilterKind.size,
      FilterKind.resolution,
      FilterKind.duration,
      FilterKind.gps,
      FilterKind.metaError,
      FilterKind.extensions,
    ].any((k) => f.of(k) != null);
    final momentName = {for (final m in moments) m.id: momentTitle(m)};

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(
          'year',
          'Ano',
          f.of(FilterKind.years) != null,
          values(FilterKind.years, (v) => '$v'),
          () => _pickMany<int>(context, c, f, FilterKind.years, 'Anos', [
            for (final e
                in (facets?.years.entries.toList() ?? <MapEntry<int, int>>[])..sort((a, b) => b.key.compareTo(a.key)))
              (e.key, '${e.key}', e.value),
          ]),
          clear: FilterKind.years,
        ),
        chip(
          'source',
          'Dispositivo',
          f.of(FilterKind.sources) != null,
          values(FilterKind.sources, (v) => sources[v]?.name ?? '?', max: 1),
          () => _pickMany<String>(context, c, f, FilterKind.sources, 'Dispositivos', [
            for (final s in sources.values) (s.id, s.name, facets?.sources[s.id] ?? 0),
          ]),
          clear: FilterKind.sources,
        ),
        chip(
          'camera',
          'Câmera',
          f.of(FilterKind.cameras) != null,
          values(FilterKind.cameras, (v) => cameraLabel('$v'), max: 1),
          () => _pickMany<String>(context, c, f, FilterKind.cameras, 'Câmeras e celulares (pelos dados das fotos)', [
            for (final e
                in (facets?.cameras.entries.toList() ?? <MapEntry<String, int>>[])
                  ..sort((a, b) => b.value.compareTo(a.value)))
              (e.key, cameraLabel(e.key), e.value),
          ]),
          clear: FilterKind.cameras,
        ),
        chip(
          'type',
          'Tipo',
          f.of(FilterKind.types) != null,
          values(FilterKind.types, (v) => mediaTypeLabel('$v')),
          () => _pickMany<String>(context, c, f, FilterKind.types, 'Tipos', [
            for (final t in const ['photo', 'raw', 'video']) (t, mediaTypeLabel(t), facets?.types[t] ?? 0),
          ]),
          clear: FilterKind.types,
        ),
        chip(
          'backup',
          'Situação de backup',
          f.of(FilterKind.backup) != null,
          values(FilterKind.backup, (v) => backupStateLabel(BackupState.values.byName('$v')), max: 1),
          () => _pickMany<String>(context, c, f, FilterKind.backup, 'Situação de backup', [
            for (final s in const [BackupState.single, BackupState.verified, BackupState.independent])
              (s.name, backupStateLabel(s), null),
          ]),
          clear: FilterKind.backup,
        ),
        chip(
          'time',
          'Horário do dia',
          timeActive,
          _timeSummary(f),
          () => showDialog<void>(context: context, builder: (_) => const _TimeDialog()),
        ),
        chip(
          'moment',
          'Momento',
          f.of(FilterKind.moments) != null,
          values(FilterKind.moments, (v) => momentName[v] ?? 'momento', max: 1),
          () => _pickMany<int>(context, c, f, FilterKind.moments, 'Momentos', [
            for (final m in moments.reversed) (m.id, momentTitle(m), m.itemCount),
          ], searchable: true),
          clear: FilterKind.moments,
        ),
        chip(
          'hour',
          'Hora confiável?',
          hourActive,
          _hourSummary(f),
          () => showDialog<void>(context: context, builder: (_) => const _HourDialog()),
        ),
        chip(
          'more',
          'Mais filtros',
          moreActive,
          'ativos',
          () => showDialog<void>(context: context, builder: (_) => const _MoreDialog()),
        ),
        if (!f.isEmpty) ...[
          ActionChip(
            key: const ValueKey('chip-advanced'),
            avatar: const Icon(Icons.tune, size: 18),
            label: Text(f.any ? 'Filtro avançado (OU)' : 'Filtro avançado'),
            onPressed: () => showDialog<void>(context: context, builder: (_) => const AdvancedFilterDialog()),
          ),
          TextButton(onPressed: () => c.setFilter(LibraryFilter.empty), child: const Text('Limpar filtros')),
        ],
        _SavedFiltersMenu(current: f),
      ],
    );
  }

  static String _timeSummary(LibraryFilter f) {
    final parts = <String>[];
    final t = f.of(FilterKind.timeRange);
    if (t != null) parts.add('${_hm((t.min ?? 0).toInt())}–${_hm((t.max ?? 1439).toInt())}');
    final p = f.of(FilterKind.periods);
    if (p != null) {
      parts.add(p.values.map((v) => DayPart.values.byName('$v').label.toLowerCase()).join(', '));
    }
    final w = f.of(FilterKind.weekdays);
    if (w != null) parts.add(w.values.map((v) => weekdayShort[(v as int) - 1]).join(', '));
    return parts.join(' · ');
  }

  static String _hourSummary(LibraryFilter f) {
    if (f.of(FilterKind.toConfirm) != null) return 'a confirmar';
    if (f.of(FilterKind.corrected) != null) return 'corrigidas';
    if (f.of(FilterKind.conflict) != null) return 'conflitantes';
    final c = f.of(FilterKind.confidence);
    return c == null ? '' : c.values.map((v) => confidenceLabel(DateConfidence.fromSql('$v')).toLowerCase()).join(', ');
  }

  Future<void> _pickMany<T extends Object>(
    BuildContext context,
    LibraryController c,
    LibraryFilter filter,
    FilterKind kind,
    String title,
    List<(T, String, int?)> options, {
    bool searchable = false,
  }) async {
    final current = filter.of(kind);
    final result = await showDialog<(Set<T>, bool)>(
      context: context,
      builder: (_) => _PickManyDialog<T>(
        title: title,
        options: options,
        selected: {...?current?.values.whereType<T>()},
        negate: current?.negate ?? false,
        searchable: searchable,
      ),
    );
    if (result == null) return;
    final (values, negate) = result;
    c.setCondition(values.isEmpty ? null : FilterCondition(kind, values: values.toList(), negate: negate), kind);
  }
}

String _hm(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Escolha de vários valores, com "NÃO" (excluir os marcados).
class _PickManyDialog<T extends Object> extends StatefulWidget {
  const _PickManyDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.negate,
    this.searchable = false,
  });
  final String title;
  final List<(T, String, int?)> options;
  final Set<T> selected;
  final bool negate;
  final bool searchable;

  @override
  State<_PickManyDialog<T>> createState() => _PickManyDialogState<T>();
}

class _PickManyDialogState<T extends Object> extends State<_PickManyDialog<T>> {
  late final Set<T> _sel = {...widget.selected};
  late bool _negate = widget.negate;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final shown = widget.options.where((o) => _query.isEmpty || o.$2.toLowerCase().contains(_query.toLowerCase()));
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            if (widget.searchable)
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Procurar'),
                onChanged: (v) => setState(() => _query = v),
              ),
            if (widget.options.isEmpty)
              const Expanded(child: Center(child: Text('Nada para escolher ainda.')))
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final o in shown)
                      CheckboxListTile(
                        dense: true,
                        value: _sel.contains(o.$1),
                        title: Text(o.$2),
                        secondary: o.$3 == null ? null : Text(plural(o.$3!, 'foto ou vídeo', 'fotos e vídeos')),
                        onChanged: (v) => setState(() => v! ? _sel.add(o.$1) : _sel.remove(o.$1)),
                      ),
                  ],
                ),
              ),
            SwitchListTile(
              dense: true,
              title: const Text('Mostrar tudo, menos os marcados'),
              subtitle: const Text('Em vez de mostrar só os marcados (filtro NÃO).'),
              value: _negate,
              onChanged: (v) => setState(() => _negate = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, (<T>{}, false)), child: const Text('Tirar filtro')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, (_sel, _negate)), child: const Text('Aplicar')),
      ],
    );
  }
}

/// Faixa de horário, período do dia e dia da semana (pela hora local).
class _TimeDialog extends ConsumerStatefulWidget {
  const _TimeDialog();

  @override
  ConsumerState<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends ConsumerState<_TimeDialog> {
  late final LibraryFilter _f = ref.read(libraryControllerProvider).filter;
  late TimeOfDay? _from = _time(_f.of(FilterKind.timeRange)?.min);
  late TimeOfDay? _to = _time(_f.of(FilterKind.timeRange)?.max);
  late final Set<String> _periods = {...?_f.of(FilterKind.periods)?.values.map((v) => '$v')};
  late final Set<int> _days = {...?_f.of(FilterKind.weekdays)?.values.whereType<int>()};

  static TimeOfDay? _time(num? m) => m == null ? null : TimeOfDay(hour: m.toInt() ~/ 60, minute: m.toInt() % 60);

  Future<void> _pick(bool from) async {
    final t = await showTimePicker(
      context: context,
      initialTime:
          (from ? _from : _to) ?? (from ? const TimeOfDay(hour: 18, minute: 0) : const TimeOfDay(hour: 23, minute: 59)),
      helpText: from ? 'A partir de' : 'Até',
    );
    if (t != null) setState(() => from ? _from = t : _to = t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Horário do dia em que foi tirada'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Faixa de horário (hora local de quem tirou a foto):'),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  key: const ValueKey('time-from'),
                  onPressed: () => _pick(true),
                  child: Text(_from == null ? 'De…' : 'De ${_hm(_from!.hour * 60 + _from!.minute)}'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('time-to'),
                  onPressed: () => _pick(false),
                  child: Text(_to == null ? 'Até…' : 'Até ${_hm(_to!.hour * 60 + _to!.minute)}'),
                ),
                if (_from != null || _to != null)
                  IconButton(
                    tooltip: 'Sem faixa',
                    onPressed: () => setState(() => _from = _to = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (_from != null && _to != null && _from!.hour * 60 + _from!.minute > _to!.hour * 60 + _to!.minute)
              const Text('Atravessa a meia-noite.', style: TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            const Text('Período do dia:'),
            Wrap(
              spacing: 8,
              children: [
                for (final p in DayPart.values)
                  FilterChip(
                    label: Text('${p.label} (${p.fromHour}–${p.toHour} h)'),
                    selected: _periods.contains(p.name),
                    onSelected: (v) => setState(() => v ? _periods.add(p.name) : _periods.remove(p.name)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Dia da semana:'),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayLong[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('time-apply'),
          onPressed: () {
            var f = ref.read(libraryControllerProvider).filter;
            f = _from == null && _to == null
                ? f.without(FilterKind.timeRange)
                : f.withCondition(
                    FilterCondition(
                      FilterKind.timeRange,
                      min: _from == null ? 0 : _from!.hour * 60 + _from!.minute,
                      max: _to == null ? 1439 : _to!.hour * 60 + _to!.minute,
                    ),
                  );
            f = _periods.isEmpty
                ? f.without(FilterKind.periods)
                : f.withCondition(FilterCondition(FilterKind.periods, values: _periods.toList()));
            f = _days.isEmpty
                ? f.without(FilterKind.weekdays)
                : f.withCondition(FilterCondition(FilterKind.weekdays, values: (_days.toList()..sort())));
            ref.read(libraryControllerProvider.notifier).setFilter(f);
            Navigator.pop(context);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

/// Confiança da hora, "hora a confirmar", corrigidas e conflitantes.
class _HourDialog extends ConsumerStatefulWidget {
  const _HourDialog();

  @override
  ConsumerState<_HourDialog> createState() => _HourDialogState();
}

class _HourDialogState extends ConsumerState<_HourDialog> {
  late final LibraryFilter _f = ref.read(libraryControllerProvider).filter;
  late final Set<String> _conf = {...?_f.of(FilterKind.confidence)?.values.map((v) => '$v')};
  late bool _toConfirm = _f.of(FilterKind.toConfirm) != null;
  late bool _corrected = _f.of(FilterKind.corrected) != null;
  late bool _conflict = _f.of(FilterKind.conflict) != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('A hora é confiável?'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confiança da hora:'),
            Wrap(
              spacing: 8,
              children: [
                for (final c in DateConfidence.values)
                  FilterChip(
                    avatar: Icon(confidenceIcon(c), size: 16),
                    label: Text(confidenceLabel(c)),
                    selected: _conf.contains(c.name),
                    onSelected: (v) => setState(() => v ? _conf.add(c.name) : _conf.remove(c.name)),
                  ),
              ],
            ),
            CheckboxListTile(
              key: const ValueKey('only-to-confirm'),
              title: const Text('Só "hora a confirmar"'),
              subtitle: const Text('Hora incerta que ainda não foi confirmada nem corrigida.'),
              value: _toConfirm,
              onChanged: (v) => setState(() => _toConfirm = v!),
            ),
            CheckboxListTile(
              title: const Text('Só com hora corrigida'),
              subtitle: const Text('Pelo relógio do dispositivo ou à mão.'),
              value: _corrected,
              onChanged: (v) => setState(() => _corrected = v!),
            ),
            CheckboxListTile(
              title: const Text('Só com datas conflitantes'),
              subtitle: const Text('A data da foto e a do nome do arquivo não batem.'),
              value: _conflict,
              onChanged: (v) => setState(() => _conflict = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('hour-apply'),
          onPressed: () {
            var f = ref.read(libraryControllerProvider).filter;
            LibraryFilter put(LibraryFilter f, FilterKind k, bool on, [List<Object> values = const []]) =>
                on ? f.withCondition(FilterCondition(k, values: values)) : f.without(k);
            f = put(f, FilterKind.confidence, _conf.isNotEmpty, _conf.toList());
            f = put(f, FilterKind.toConfirm, _toConfirm);
            f = put(f, FilterKind.corrected, _corrected);
            f = put(f, FilterKind.conflict, _conflict);
            ref.read(libraryControllerProvider.notifier).setFilter(f);
            Navigator.pop(context);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

/// Período de datas, sem data, tamanho, resolução, duração, GPS e erros.
class _MoreDialog extends ConsumerStatefulWidget {
  const _MoreDialog();

  @override
  ConsumerState<_MoreDialog> createState() => _MoreDialogState();
}

class _MoreDialogState extends ConsumerState<_MoreDialog> {
  late final LibraryFilter _f = ref.read(libraryControllerProvider).filter;
  late final _from = TextEditingController(text: _f.of(FilterKind.dateRange)?.values.elementAtOrNull(0)?.toString());
  late final _to = TextEditingController(text: _f.of(FilterKind.dateRange)?.values.elementAtOrNull(1)?.toString());
  late final _minMb = TextEditingController(text: _mb(_f.of(FilterKind.size)?.min));
  late final _maxMb = TextEditingController(text: _mb(_f.of(FilterKind.size)?.max));
  late final _mp = TextEditingController(text: _f.of(FilterKind.resolution)?.min?.toString());
  late final _minS = TextEditingController(text: _s(_f.of(FilterKind.duration)?.min));
  late final _maxS = TextEditingController(text: _s(_f.of(FilterKind.duration)?.max));
  late bool? _gps = switch (_f.of(FilterKind.gps)) {
    null => null,
    final c => c.values.firstOrNull != false,
  };
  late bool _noDate = _f.of(FilterKind.noDate) != null;
  late bool _errors = _f.of(FilterKind.metaError) != null;
  String? _error;

  static String? _mb(num? b) => b == null ? null : (b / (1024 * 1024)).toStringAsFixed(1);
  static String? _s(num? ms) => ms == null ? null : (ms / 1000).toStringAsFixed(0);
  static double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  void dispose() {
    for (final c in [_from, _to, _minMb, _maxMb, _mp, _minS, _maxS]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {String? hint}) => SizedBox(
    width: 150,
    child: TextField(
      controller: c,
      decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mais filtros'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Período (datas):'),
              Wrap(
                spacing: 12,
                children: [
                  _field(_from, 'De', hint: 'AAAA-MM-DD'),
                  _field(_to, 'Até', hint: 'AAAA-MM-DD'),
                ],
              ),
              CheckboxListTile(
                title: const Text('Só sem data'),
                value: _noDate,
                onChanged: (v) => setState(() => _noDate = v!),
              ),
              const Divider(),
              const Text('Tamanho (MB):'),
              Wrap(spacing: 12, children: [_field(_minMb, 'Mínimo'), _field(_maxMb, 'Máximo')]),
              const SizedBox(height: 8),
              _field(_mp, 'Resolução mínima (megapixels)'),
              const SizedBox(height: 8),
              const Text('Duração do vídeo (segundos):'),
              Wrap(spacing: 12, children: [_field(_minS, 'Mínimo'), _field(_maxS, 'Máximo')]),
              const SizedBox(height: 8),
              const Text('Localização (GPS):'),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Tanto faz')),
                  ButtonSegment(value: 1, label: Text('Com GPS')),
                  ButtonSegment(value: 2, label: Text('Sem GPS')),
                ],
                selected: {_gps == null ? 0 : (_gps! ? 1 : 2)},
                onSelectionChanged: (s) => setState(
                  () => _gps = switch (s.first) {
                    1 => true,
                    2 => false,
                    _ => null,
                  },
                ),
              ),
              CheckboxListTile(
                title: const Text('Só os que deram erro ao ler os dados'),
                value: _errors,
                onChanged: (v) => setState(() => _errors = v!),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final from = _from.text.trim(), to = _to.text.trim();
            if ((from.isNotEmpty && !_date.hasMatch(from)) || (to.isNotEmpty && !_date.hasMatch(to))) {
              setState(() => _error = 'Use datas no formato AAAA-MM-DD (ex.: 2024-05-01).');
              return;
            }
            var f = ref.read(libraryControllerProvider).filter;
            LibraryFilter range(LibraryFilter f, FilterKind k, double? min, double? max, double scale) =>
                min == null && max == null
                ? f.without(k)
                : f.withCondition(
                    FilterCondition(k, min: min == null ? null : min * scale, max: max == null ? null : max * scale),
                  );
            f = from.isEmpty && to.isEmpty
                ? f.without(FilterKind.dateRange)
                : f.withCondition(
                    FilterCondition(
                      FilterKind.dateRange,
                      values: [from.isEmpty ? '0000-01-01' : from, if (to.isNotEmpty) to else '9999-12-31'],
                    ),
                  );
            f = _noDate ? f.withCondition(const FilterCondition(FilterKind.noDate)) : f.without(FilterKind.noDate);
            f = range(f, FilterKind.size, _num(_minMb), _num(_maxMb), 1024 * 1024);
            f = _num(_mp) == null
                ? f.without(FilterKind.resolution)
                : f.withCondition(FilterCondition(FilterKind.resolution, min: _num(_mp)));
            f = range(f, FilterKind.duration, _num(_minS), _num(_maxS), 1000);
            f = _gps == null
                ? f.without(FilterKind.gps)
                : f.withCondition(FilterCondition(FilterKind.gps, values: [_gps!]));
            f = _errors
                ? f.withCondition(const FilterCondition(FilterKind.metaError))
                : f.without(FilterKind.metaError);
            ref.read(libraryControllerProvider.notifier).setFilter(f);
            Navigator.pop(context);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

String conditionLabel(FilterCondition c) => switch (c.kind) {
  FilterKind.years => 'Ano: ${c.values.join(', ')}',
  FilterKind.months => 'Mês: ${c.values.join(', ')}',
  FilterKind.dateRange => 'Período: ${c.values.join(' a ')}',
  FilterKind.noDate => 'Sem data',
  FilterKind.timeRange => 'Horário do dia: ${_hm((c.min ?? 0).toInt())}–${_hm((c.max ?? 1439).toInt())}',
  FilterKind.periods => 'Período do dia: ${c.values.map((v) => DayPart.values.byName('$v').label).join(', ')}',
  FilterKind.weekdays => 'Dia da semana: ${c.values.map((v) => weekdayShort[(v as int) - 1]).join(', ')}',
  FilterKind.moments => 'Momento (${c.values.length})',
  FilterKind.confidence =>
    'Confiança: ${c.values.map((v) => confidenceLabel(DateConfidence.fromSql('$v'))).join(', ')}',
  FilterKind.toConfirm => 'Hora a confirmar',
  FilterKind.corrected => 'Hora corrigida',
  FilterKind.conflict => 'Datas conflitantes',
  FilterKind.sources => 'Dispositivo (${c.values.length})',
  FilterKind.cameras => 'Câmera: ${c.values.map((v) => cameraLabel('$v')).join(', ')}',
  FilterKind.types => 'Tipo: ${c.values.map((v) => mediaTypeLabel('$v')).join(', ')}',
  FilterKind.extensions => 'Extensão: ${c.values.join(', ')}',
  FilterKind.size => 'Tamanho',
  FilterKind.resolution => 'Resolução ≥ ${c.min} MP',
  FilterKind.duration => 'Duração',
  FilterKind.gps => c.values.firstOrNull == false ? 'Sem GPS' : 'Com GPS',
  FilterKind.backup => 'Backup: ${c.values.map((v) => backupStateLabel(BackupState.values.byName('$v'))).join(', ')}',
  FilterKind.metaError => 'Erro ao ler os dados',
  FilterKind.text => 'Texto: "${c.text}"',
};

/// Construtor avançado: todas (E) ou qualquer (OU) condição, cada uma com NÃO.
class AdvancedFilterDialog extends ConsumerStatefulWidget {
  const AdvancedFilterDialog({super.key});

  @override
  ConsumerState<AdvancedFilterDialog> createState() => _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends ConsumerState<AdvancedFilterDialog> {
  late final LibraryFilter _initial = ref.read(libraryControllerProvider).filter;
  late final List<FilterCondition> _conds = [..._initial.conditions];
  late bool _any = _initial.any;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtro avançado'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              key: const ValueKey('advanced-mode'),
              segments: const [
                ButtonSegment(value: false, label: Text('Todas as condições (E)')),
                ButtonSegment(value: true, label: Text('Qualquer condição (OU)')),
              ],
              selected: {_any},
              onSelectionChanged: (s) => setState(() => _any = s.first),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _conds.length; i++)
              ListTile(
                dense: true,
                title: Text(conditionLabel(_conds[i])),
                leading: FilterChip(
                  key: ValueKey('not-$i'),
                  label: const Text('NÃO'),
                  selected: _conds[i].negate,
                  onSelected: (v) => setState(() => _conds[i] = _conds[i].copyWith(negate: v)),
                ),
                trailing: IconButton(
                  tooltip: 'Tirar',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _conds.removeAt(i)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('advanced-apply'),
          onPressed: () {
            ref.read(libraryControllerProvider.notifier).setFilter(LibraryFilter(_conds, _any));
            Navigator.pop(context);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _SavedFiltersMenu extends ConsumerWidget {
  const _SavedFiltersMenu({required this.current});
  final LibraryFilter current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedFiltersProvider).value ?? const <SavedFilter>[];
    final backend = ref.read(libraryBackendProvider);
    return PopupMenuButton<String>(
      key: const ValueKey('saved-filters'),
      tooltip: 'Filtros salvos',
      icon: const Icon(Icons.bookmarks_outlined),
      onSelected: (v) async {
        if (v == 'save') {
          final name = await _askName(context);
          if (name == null) return;
          await backend.saveFilter(name, current);
          ref.invalidate(savedFiltersProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Filtro "$name" salvo.')));
          }
        } else if (v.startsWith('del:')) {
          await backend.deleteFilter(int.parse(v.substring(4)));
          ref.invalidate(savedFiltersProvider);
        } else {
          final f = saved.firstWhere((s) => 'use:${s.id}' == v);
          ref.read(libraryControllerProvider.notifier).setFilter(f.filter);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'save', enabled: !current.isEmpty, child: const Text('Salvar este filtro…')),
        if (saved.isNotEmpty) const PopupMenuDivider(),
        for (final s in saved) PopupMenuItem(value: 'use:${s.id}', child: Text('Usar "${s.name}"')),
        if (saved.isNotEmpty) const PopupMenuDivider(),
        for (final s in saved) PopupMenuItem(value: 'del:${s.id}', child: Text('Apagar "${s.name}"')),
      ],
    );
  }

  Future<String?> _askName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar filtro'),
        content: TextField(
          key: const ValueKey('filter-name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome (ex.: "Noites de 2024")'),
          onSubmitted: (v) => Navigator.pop(context, v.trim().isEmpty ? null : v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

/// Dica de cada chip de filtro, em linguagem simples.
const _chipHelp = {
  'year': 'Mostrar só as fotos e vídeos tirados nestes anos.',
  'source': 'Mostrar só o que tem cópia nestes dispositivos (celular, HD, pasta…).',
  'camera': 'Mostrar só o que foi tirado por estas câmeras ou celulares (pelos dados gravados na foto).',
  'type': 'Fotos, fotos RAW (de câmeras profissionais) ou vídeos.',
  'backup': 'Filtrar pela situação de backup: sem backup, com cópia conferida ou com backup em outro disco.',
  'time': 'Filtrar pela hora do dia em que foi tirada (ex.: só à noite, só aos sábados).',
  'moment': 'Momentos são grupos de fotos tiradas perto umas das outras (ex.: uma festa, um passeio).',
  'hour': 'Filtrar pela confiança na hora: confiável, provável ou incerta (ex.: a confirmar).',
  'more': 'Período de datas, tamanho, resolução, duração do vídeo, localização e erros de leitura.',
};
