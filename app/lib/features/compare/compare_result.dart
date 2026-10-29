import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/backup_state.dart';
import 'compare_controller.dart';

/// Frase principal do resultado (spec §9): nunca "100%" com pendências.
String verdictHeadline(CompareSummary r) => switch (r.verdict) {
  CompareVerdict.complete => 'Sim, 100%. B contém todo o conteúdo de A.',
  CompareVerdict.missing =>
    '${r.missing.contents == 1 ? 'Falta 1 arquivo' : 'Faltam ${formatInt(r.missing.contents)} arquivos'} '
        '(${formatBytes(r.missing.bytes)}) de A em B.',
  CompareVerdict.incomplete => 'Resultado incompleto: ainda não dá para dizer se B contém tudo de A.',
  CompareVerdict.emptyA => 'A não tem nenhum arquivo para comparar.',
};

/// Motivos de "incompleto" e avisos, em linguagem simples.
List<String> issueTexts(CompareSummary r) => [
  for (final i in r.issues)
    switch (i) {
      final UnverifiedFiles u => _unverifiedText(u),
      NeverScanned(:final side, :final sourceName, folder: null) =>
        '"$sourceName" ($side) nunca foi escaneado por completo.',
      NeverScanned(:final side, :final sourceName, :final folder?) =>
        'A pasta "${folder.isEmpty ? sourceName : folder.replaceAll('/', ' › ')}" de "$sourceName" ($side) '
            'ainda não foi escaneada (só outra parte do dispositivo foi). Escaneie o dispositivo inteiro.',
      UnreadFolders(:final side, :final sourceName, :final folders) =>
        '${plural(folders.length, 'pasta', 'pastas')} de "$sourceName" ($side) não puderam ser lidas '
            'no último escaneamento: ${folders.take(3).join(', ')}${folders.length > 3 ? '…' : ''}.',
      UnknownSource(:final side) => 'O escopo $side cita um dispositivo que foi esquecido.',
    },
];

/// "A: 5 arquivos (4 conteúdos diferentes, 1 repetido) · 6,3 KB" — para a soma
/// das abas (que contam conteúdos) fazer sentido.
String sideSummary(CompareSummary r, String side) {
  final isA = side == 'A';
  final files = isA ? r.aFiles : r.bFiles;
  final contents = isA ? r.aContents : r.bContents;
  final repeated = isA ? r.aRepeated : r.bRepeated;
  final unverified = r.issues.whereType<UnverifiedFiles>().where((u) => u.side == side).fold(0, (s, u) => s + u.total);
  final parts = [
    plural(contents, 'conteúdo diferente', 'conteúdos diferentes'),
    if (repeated > 0) plural(repeated, 'repetido', 'repetidos'),
    if (unverified > 0) plural(unverified, 'ainda não conferido', 'ainda não conferidos'),
  ];
  return '$side: ${plural(files, 'arquivo', 'arquivos')} (${parts.join(', ')}) · '
      '${formatBytes(isA ? r.aBytes : r.bBytes)}';
}

String _unverifiedText(UnverifiedFiles u) {
  final details = [
    if (u.cloudOnly > 0) '${formatInt(u.cloudOnly)} só na nuvem',
    if (u.errors > 0) '${formatInt(u.errors)} com erro de leitura',
    if (u.changed > 0) plural(u.changed, 'mudou durante a leitura', 'mudaram durante a leitura'),
  ];
  return '${plural(u.total, 'arquivo', 'arquivos')} em ${u.side} ainda sem conteúdo conferido'
      '${details.isEmpty ? '' : ' (${details.join(', ')})'}.';
}

List<String> warningTexts(CompareSummary r) => [
  for (final w in r.warnings)
    switch (w) {
      DisconnectedSource(:final side, :final sourceName, :final lastScanAt) =>
        '"$sourceName" ($side) está desconectado: resultado baseado no escaneamento'
            '${lastScanAt == null ? '' : ' de ${formatDateTime(lastScanAt)}'}.',
      ScopesOverlap(:final aName, :final bName) =>
        '"$aName" e "$bName" são a mesma área do disco: estar "nos dois" ali não é uma cópia de segurança.',
    },
];

class CompareResultView extends ConsumerWidget {
  const CompareResultView({super.key, required this.result});
  final CompareSummary result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final r = result;
    final (icon, color) = switch (r.verdict) {
      CompareVerdict.complete => (Icons.verified_outlined, colors.verified),
      CompareVerdict.missing => (Icons.error_outline, colors.single),
      CompareVerdict.incomplete => (Icons.hourglass_top, colors.attention),
      CompareVerdict.emptyA => (Icons.info_outline, colors.unknown),
    };
    final hashing = ref.watch(hashStatusProvider).value?.running ?? false;
    final issues = issueTexts(r);
    final warnings = warningTexts(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const ValueKey('verdict'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('B contém todo o conteúdo de A?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Text(verdictHeadline(r), style: theme.textTheme.headlineSmall)),
                  ],
                ),
                if (r.verdict == CompareVerdict.incomplete && r.missing.contents > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Pelo que já foi conferido, faltam pelo menos ${plural(r.missing.contents, 'arquivo', 'arquivos')} '
                    '(${formatBytes(r.missing.bytes)}).',
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Comparação pelo conteúdo: nomes e pastas diferentes não importam.',
                  style: theme.textTheme.bodySmall,
                ),
                Text(sideSummary(r, 'A'), key: const ValueKey('summary-A'), style: theme.textTheme.bodySmall),
                Text(sideSummary(r, 'B'), key: const ValueKey('summary-B'), style: theme.textTheme.bodySmall),
                Text(
                  'As abas contam conteúdos: arquivos repetidos entram uma vez só '
                  '(Faltam em B + Nos dois = conteúdos de A; Só em B + Nos dois = conteúdos de B).',
                  style: theme.textTheme.bodySmall,
                ),
                for (final t in issues)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.hourglass_empty, size: 18, color: colors.attention),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t)),
                      ],
                    ),
                  ),
                for (final t in warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: colors.disconnected),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t)),
                      ],
                    ),
                  ),
                if (r.unverifiedTotal > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: hashing ? null : () => ref.read(compareControllerProvider.notifier).verifyNow(),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Conferir agora'),
                      ),
                      const SizedBox(width: 12),
                      if (hashing) const Expanded(child: HashProgressBar()),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ResultTabs(result: r),
      ],
    );
  }
}

class _ResultTabs extends StatelessWidget {
  const _ResultTabs({required this.result});
  final CompareSummary result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final unverifiedA = r.issues
        .whereType<UnverifiedFiles>()
        .where((u) => u.side == 'A')
        .fold(0, (s, u) => s + u.total);
    final unverifiedB = r.issues
        .whereType<UnverifiedFiles>()
        .where((u) => u.side == 'B')
        .fold(0, (s, u) => s + u.total);
    final tabs = [
      ('Faltam em B (${formatInt(r.missing.contents)})', CompareList.missing),
      ('Só em B (${formatInt(r.onlyInB.contents)})', CompareList.onlyInB),
      ('Nos dois (${formatInt(r.inBoth.contents)})', CompareList.inBoth),
      if (unverifiedA > 0) ('Não conferidos em A (${formatInt(unverifiedA)})', CompareList.unverifiedA),
      if (unverifiedB > 0) ('Não conferidos em B (${formatInt(unverifiedB)})', CompareList.unverifiedB),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Card(
        child: Column(
          children: [
            TabBar(isScrollable: true, tabs: [for (final t in tabs) Tab(text: t.$1)]),
            SizedBox(
              height: 460,
              child: TabBarView(
                children: [
                  for (final t in tabs)
                    _ItemList(
                      key: ValueKey('${t.$2.name}-${r.computedAt.microsecondsSinceEpoch}'),
                      list: t.$2,
                      totals: switch (t.$2) {
                        CompareList.missing => r.missing,
                        CompareList.onlyInB => r.onlyInB,
                        CompareList.inBoth => r.inBoth,
                        _ => null,
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista paginada; na aba "Faltam em B" os itens são selecionáveis.
class _ItemList extends ConsumerStatefulWidget {
  const _ItemList({super.key, required this.list, required this.totals});
  final CompareList list;
  final ContentTotals? totals;

  @override
  ConsumerState<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends ConsumerState<_ItemList> {
  static const _page = 200;
  final _items = <CompareItem>[];
  bool _loading = false;
  bool _end = false;
  final _selected = <int>{};
  bool _all = false;

  bool get _selectable => widget.list == CompareList.missing;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading || _end) return;
    final state = ref.read(compareControllerProvider);
    final a = state.resultA, b = state.resultB;
    if (a == null || b == null) return;
    setState(() => _loading = true);
    final page = await ref.read(backendProvider).compareItems(a, b, widget.list, offset: _items.length, limit: _page);
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _end = page.length < _page;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = {for (final s in ref.watch(sourcesProvider).value ?? const <SourceView>[]) s.id: s.name};
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Text(switch (widget.list) {
          CompareList.missing => 'Nada falta em B.',
          CompareList.onlyInB => 'B não tem nada além do que está em A.',
          CompareList.inBoth => 'Nenhum conteúdo em comum.',
          _ => 'Todos conferidos.',
        }),
      );
    }
    final totals = widget.totals;
    final selectedCount = _all ? (totals?.contents ?? 0) : _selected.length;
    final selectedBytes = _all
        ? (totals?.bytes ?? 0)
        : _items.where((i) => _selected.contains(i.contentId)).fold<int>(0, (s, i) => s + i.sizeBytes);
    return Column(
      children: [
        if (_selectable)
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Selecione o que quer levar para B.'
                          : '${plural(selectedCount, 'item', 'itens')} · ${formatBytes(selectedBytes)}',
                      key: const ValueKey('selection-bar'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _all = !_all;
                      _selected.clear();
                    }),
                    child: Text(_all ? 'Limpar seleção' : 'Selecionar todos os resultados'),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'A cópia segura (com conferência) chega na próxima fase.',
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Copiar para B…'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 400) _more();
              return false;
            },
            child: ListView.builder(
              itemCount: _items.length + (_end ? 0 : 1),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final item = _items[i];
                final where = displayPath(sources[item.sourceId] ?? '?', item.relPath);
                final subtitle = switch (widget.list) {
                  CompareList.inBoth =>
                    'Em B: ${displayPath(sources[item.otherSourceId] ?? '?', item.otherRelPath ?? '?')}',
                  CompareList.unverifiedA || CompareList.unverifiedB => item.hashError ?? _pendingLabel(item),
                  _ => item.copies > 1 ? '${item.copies} arquivos com este conteúdo' : null,
                };
                final checked = _all || _selected.contains(item.contentId);
                return ListTile(
                  dense: true,
                  leading: _selectable
                      ? Checkbox(
                          value: checked,
                          onChanged: (_) => setState(() {
                            if (_all) {
                              // Sai do "todos" mantendo a página carregada marcada, menos este.
                              _all = false;
                              _selected.addAll(_items.map((x) => x.contentId!));
                            }
                            if (!_selected.remove(item.contentId)) _selected.add(item.contentId!);
                          }),
                        )
                      : Icon(
                          widget.list == CompareList.inBoth
                              ? backupStateIcon(BackupState.verified)
                              : Icons.description_outlined,
                        ),
                  title: Text(where, overflow: TextOverflow.ellipsis),
                  subtitle: subtitle == null ? null : Text(subtitle, overflow: TextOverflow.ellipsis),
                  trailing: Text(formatBytes(item.sizeBytes)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static String _pendingLabel(CompareItem i) => switch ((i.availability, i.hashStatus)) {
    ('cloud_only', _) => 'Só na nuvem (não é baixado para conferir).',
    (_, 'pending') => 'Na fila para conferir.',
    (_, 'error') => 'Não deu para ler.',
    (_, 'changed_during_read') => 'Mudou durante a leitura; escaneie de novo.',
    _ => 'Ainda não conferido.',
  };
}
