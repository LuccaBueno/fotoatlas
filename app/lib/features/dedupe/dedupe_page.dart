import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/task_notice.dart';
import '../library/item_tile.dart';

/// Nome de cada regra de sugestão, em palavras simples.
String keepRuleLabel(KeepRule rule) => switch (rule) {
  KeepRule.organized => 'A da pasta mais organizada',
  KeepRule.oldest => 'A mais antiga',
};

/// Dispositivos com repetidos (recalculado quando algo muda).
final dedupeSummariesProvider = FutureProvider<List<DedupeSourceSummary>>((ref) {
  ref.watch(dedupeChangesProvider);
  return ref.watch(dedupeBackendProvider).summaries();
});

/// Regra salva de qual cópia sugerir.
final dedupeRuleProvider = FutureProvider<KeepRule>((ref) => ref.watch(dedupeBackendProvider).keepRule());

/// Dispositivo escolhido (`null` = o primeiro da lista).
class DedupeSource extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final dedupeSourceProvider = NotifierProvider<DedupeSource, String?>(DedupeSource.new);

/// O dispositivo em uso: o escolhido (`null` se ele não tem repetidos que dê
/// para limpar) ou, sem escolha, o primeiro.
final dedupeCurrentSourceProvider = Provider<DedupeSourceSummary?>((ref) {
  final list = ref.watch(dedupeSummariesProvider).value ?? const [];
  final chosen = ref.watch(dedupeSourceProvider);
  if (chosen != null) return list.where((s) => s.sourceId == chosen).firstOrNull;
  return list.firstOrNull;
});

final dedupeGroupsProvider = FutureProvider<List<DedupeGroup>>((ref) async {
  ref.watch(dedupeChangesProvider);
  final source = ref.watch(dedupeCurrentSourceProvider);
  final rule = await ref.watch(dedupeRuleProvider.future);
  if (source == null) return const [];
  return ref.watch(dedupeBackendProvider).groups(source.sourceId, rule);
});

/// O que a pessoa marcou: grupos para limpar e, por grupo, qual cópia fica
/// (sem escolha = a sugerida). Nada vem marcado.
class DedupeChoices {
  const DedupeChoices({this.marked = const {}, this.keep = const {}, this.oneByOne = false, this.index = 0});
  final Set<int> marked;
  final Map<int, int> keep;
  final bool oneByOne;
  final int index;

  int keepOf(DedupeGroup g) {
    final k = keep[g.contentId];
    return k != null && g.copies.any((c) => c.instanceId == k) ? k : g.suggestedKeepId;
  }

  DedupeChoices copyWith({Set<int>? marked, Map<int, int>? keep, bool? oneByOne, int? index}) => DedupeChoices(
    marked: marked ?? this.marked,
    keep: keep ?? this.keep,
    oneByOne: oneByOne ?? this.oneByOne,
    index: index ?? this.index,
  );
}

class DedupeChoicesNotifier extends Notifier<DedupeChoices> {
  @override
  DedupeChoices build() {
    // Outro dispositivo: começa do zero (nada marcado).
    ref.watch(dedupeCurrentSourceProvider.select((s) => s?.sourceId));
    return const DedupeChoices();
  }

  void mark(int contentId, bool value) =>
      state = state.copyWith(marked: value ? {...state.marked, contentId} : ({...state.marked}..remove(contentId)));

  void keep(int contentId, int instanceId) => state = state.copyWith(keep: {...state.keep, contentId: instanceId});

  /// "Aceitar as sugestões de todos": marca todos com a cópia sugerida.
  void acceptAll(List<DedupeGroup> groups) =>
      state = state.copyWith(marked: {for (final g in groups) g.contentId}, keep: const {});

  void clear() => state = state.copyWith(marked: const {}, keep: const {});
  void setOneByOne(bool v) => state = state.copyWith(oneByOne: v, index: 0);
  void go(int index) => state = state.copyWith(index: index);
}

final dedupeChoicesProvider = NotifierProvider<DedupeChoicesNotifier, DedupeChoices>(DedupeChoicesNotifier.new);

/// "Limpar repetidos": o mesmo conteúdo guardado mais de uma vez no mesmo
/// dispositivo. Nada sai sem a pessoa ver e confirmar; o que sai vai para a
/// Lixeira do Windows, e uma cópia de cada sempre fica.
class DedupePage extends ConsumerWidget {
  const DedupePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaries = ref.watch(dedupeSummariesProvider);
    final groups = ref.watch(dedupeGroupsProvider).value ?? const <DedupeGroup>[];
    final choices = ref.watch(dedupeChoicesProvider);
    final current = ref.watch(dedupeCurrentSourceProvider);
    final visible = choices.oneByOne && groups.isNotEmpty
        ? [groups[choices.index.clamp(0, groups.length - 1)]]
        : groups;
    return Scaffold(
      appBar: AppBar(title: const Text('Limpar repetidos')),
      bottomNavigationBar: summaries.value?.isNotEmpty ?? false ? _ActionBar(groups: groups) : null,
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível procurar os repetidos: $e')),
        data: (list) => ListView.builder(
          key: const ValueKey('dedupe-list'),
          padding: const EdgeInsets.all(24),
          itemCount: visible.length + 1,
          itemBuilder: (context, i) {
            if (i > 0) {
              final g = visible[i - 1];
              return _GroupCard(key: ValueKey('dedupe-group-${g.contentId}'), group: g);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arquivos com exatamente o mesmo conteúdo guardados mais de uma vez no mesmo dispositivo. Nada sai '
                  'sem você ver e confirmar: você escolhe qual cópia fica, e as outras vão para a Lixeira do Windows '
                  '(dá para restaurar por lá). Nada é feito entre dispositivos diferentes, e o celular nunca entra.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  Padding(
                    key: const ValueKey('dedupe-empty'),
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum arquivo repetido no mesmo dispositivo. Arquivos novos entram aqui depois de escaneados '
                      'e conferidos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                else ...[
                  _Toolbar(summaries: list, groups: groups),
                  if (current == null)
                    Card(
                      key: const ValueKey('dedupe-none-for-source'),
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text(
                          'Este dispositivo não tem fotos ou vídeos repetidos que dê para limpar agora. Só entram '
                          'fotos, RAW e vídeos com o conteúdo já conferido.',
                        ),
                        trailing: TextButton(
                          onPressed: () => ref.read(dedupeSourceProvider.notifier).select(list.first.sourceId),
                          child: const Text('Ver outro dispositivo'),
                        ),
                      ),
                    ),
                  if (current?.blocker != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      key: const ValueKey('dedupe-blocker'),
                      color: theme.colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.block),
                        title: Text(current!.blocker!),
                        subtitle: const Text('Você pode ver os grupos, mas nada sai deste dispositivo agora.'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (choices.oneByOne && groups.isNotEmpty) _OneByOneBar(groups: groups),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.summaries, required this.groups});
  final List<DedupeSourceSummary> summaries;
  final List<DedupeGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(dedupeCurrentSourceProvider);
    final rule = ref.watch(dedupeRuleProvider).value ?? KeepRule.organized;
    final choices = ref.watch(dedupeChoicesProvider);
    final notifier = ref.read(dedupeChoicesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Dispositivo:'),
            DropdownButton<String>(
              key: const ValueKey('dedupe-source'),
              value: current?.sourceId,
              items: [
                for (final s in summaries)
                  DropdownMenuItem(
                    value: s.sourceId,
                    child: Text(
                      '${s.name} — ${plural(s.groups, 'grupo', 'grupos')}, '
                      '${formatBytes(s.reclaimableBytes)} repetidos',
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) ref.read(dedupeSourceProvider.notifier).select(id);
              },
            ),
            const Text('Sugerir que fique:'),
            SegmentedButton<KeepRule>(
              key: const ValueKey('dedupe-rule'),
              segments: [for (final r in KeepRule.values) ButtonSegment(value: r, label: Text(keepRuleLabel(r)))],
              selected: {rule},
              onSelectionChanged: (s) async {
                await ref.read(dedupeBackendProvider).setKeepRule(s.single);
                ref.invalidate(dedupeRuleProvider);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('dedupe-accept-all'),
              onPressed: groups.isEmpty ? null : () => notifier.acceptAll(groups),
              icon: const Icon(Icons.done_all),
              label: const Text('Aceitar as sugestões de todos'),
            ),
            TextButton.icon(
              key: const ValueKey('dedupe-clear'),
              onPressed: choices.marked.isEmpty ? null : notifier.clear,
              icon: const Icon(Icons.clear),
              label: const Text('Desmarcar todos'),
            ),
            SegmentedButton<bool>(
              key: const ValueKey('dedupe-view'),
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.view_list), label: Text('Todos os grupos')),
                ButtonSegment(value: true, icon: Icon(Icons.view_carousel_outlined), label: Text('Um grupo por vez')),
              ],
              selected: {choices.oneByOne},
              onSelectionChanged: (s) => notifier.setOneByOne(s.single),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rodapé sempre visível: quantos grupos estão marcados, o que sairia e o
/// botão da prévia.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.groups});
  final List<DedupeGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(dedupeCurrentSourceProvider);
    final choices = ref.watch(dedupeChoicesProvider);
    final marked = groups.where((g) => choices.marked.contains(g.contentId)).toList();
    final files = marked.fold(0, (s, g) => s + g.copies.length - 1);
    final bytes = marked.fold(0, (s, g) => s + g.reclaimableBytes);
    return Material(
      elevation: 3,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.cleaning_services_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                key: const ValueKey('dedupe-summary'),
                marked.isEmpty
                    ? '${plural(groups.length, 'grupo', 'grupos')} de repetidos. Nenhum marcado: nada vai sair.'
                    : '${formatInt(marked.length)} de ${plural(groups.length, 'grupo marcado', 'grupos marcados')}'
                          ' — ${plural(files, 'arquivo iria', 'arquivos iriam')} para a Lixeira '
                          '(${formatBytes(bytes)}).',
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('dedupe-review'),
              onPressed: marked.isEmpty || current == null || current.blocker != null
                  ? null
                  : () => _review(context, ref, current.sourceId, marked, choices),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Revisar e enviar para a Lixeira…'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String sourceId,
    List<DedupeGroup> marked,
    DedupeChoices choices,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final backend = ref.read(dedupeBackendProvider);
    final preview = await backend.preview(sourceId, [
      for (final g in marked) DedupeChoice(g.contentId, choices.keepOf(g)),
    ]);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DedupePreviewDialog(preview: preview),
    );
    if (ok != true) return;
    try {
      await backend.start(preview);
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.read(dedupeChoicesProvider.notifier).clear();
    showTaskStartedNotice(
      messenger,
      ref,
      'Limpeza iniciada: cada grupo é conferido de novo antes de ir para a Lixeira. Acompanhe em Tarefas.',
      key: const ValueKey('dedupe-started'),
    );
  }
}

/// "Grupo 3 de 12" com Anterior/Próximo e as decisões rápidas.
class _OneByOneBar extends ConsumerWidget {
  const _OneByOneBar({required this.groups});
  final List<DedupeGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(dedupeChoicesProvider);
    final notifier = ref.read(dedupeChoicesProvider.notifier);
    final i = choices.index.clamp(0, groups.length - 1);
    final g = groups[i];
    void next() {
      if (i < groups.length - 1) notifier.go(i + 1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('dedupe-prev'),
            tooltip: 'Grupo anterior',
            onPressed: i == 0 ? null : () => notifier.go(i - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Grupo ${formatInt(i + 1)} de ${formatInt(groups.length)}', key: const ValueKey('dedupe-position')),
          IconButton(
            key: const ValueKey('dedupe-next'),
            tooltip: 'Próximo grupo',
            onPressed: i >= groups.length - 1 ? null : () => notifier.go(i + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('dedupe-mark-next'),
            onPressed: () {
              notifier.mark(g.contentId, true);
              next();
            },
            icon: const Icon(Icons.check),
            label: const Text('Limpar este grupo e ir para o próximo'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('dedupe-skip-next'),
            onPressed: () {
              notifier.mark(g.contentId, false);
              next();
            },
            icon: const Icon(Icons.do_not_disturb_on_outlined),
            label: const Text('Não mexer e ir para o próximo'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({super.key, required this.group});
  final DedupeGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final g = group;
    final choices = ref.watch(dedupeChoicesProvider);
    final marked = choices.marked.contains(g.contentId);
    final keep = choices.keepOf(g);
    final details = [
      plural(g.copies.length, 'cópia igual', 'cópias iguais'),
      '${formatBytes(g.sizeBytes)} cada',
      if (g.width != null && g.height != null) '${g.width} × ${g.height} px',
      if (g.captureLocal != null) 'tirada em ${formatWallDateTime(DateTime.parse(g.captureLocal!))}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: marked ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  key: ValueKey('dedupe-mark-${g.contentId}'),
                  value: marked,
                  onChanged: (v) => ref.read(dedupeChoicesProvider.notifier).mark(g.contentId, v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marked
                            ? 'Limpar este grupo: ${plural(g.copies.length - 1, 'cópia vai', 'cópias vão')} para a '
                                  'Lixeira (libera ${formatBytes(g.reclaimableBytes)})'
                            : 'Não mexer neste grupo (marque para limpar)',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(details, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  g.suggestedKeepId == keep ? g.reason : 'Você escolheu qual fica.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 470,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: g.copies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _CopyCard(
                  key: ValueKey('dedupe-copy-${g.copies[i].instanceId}'),
                  group: g,
                  copy: g.copies[i],
                  keeps: g.copies[i].instanceId == keep,
                  leaves: marked && g.copies[i].instanceId != keep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyCard extends ConsumerWidget {
  const _CopyCard({super.key, required this.group, required this.copy, required this.keeps, required this.leaves});
  final DedupeGroup group;
  final DedupeCopy copy;
  final bool keeps;
  final bool leaves;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final backend = ref.read(dedupeBackendProvider);
    final source = ref.watch(dedupeCurrentSourceProvider);
    final path = copy.fullPath ?? displayPath(source?.name ?? '', copy.relPath);
    final lines = <(String, String)>[
      ('Nome', copy.name),
      ('Caminho completo', path),
      ('Pasta', copy.folder.isEmpty ? '(raiz do dispositivo)' : copy.folder.replaceAll('/', ' › ')),
      if (copy.mtime != null) ('Modificado em', formatDateTime(fileTimeToDateTime(copy.mtime!))),
      ('Tamanho', formatBytes(copy.sizeBytes)),
      (
        'Resolução',
        group.width != null && group.height != null ? '${group.width} × ${group.height} px' : 'desconhecida',
      ),
    ];
    final video = group.mediaType == 'video';
    return SizedBox(
      width: 300,
      child: Card(
        color: keeps ? theme.colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Thumbnail(contentId: group.contentId, mediaType: group.mediaType, size: 276),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    key: ValueKey('dedupe-keep-${copy.instanceId}'),
                    selected: keeps,
                    showCheckmark: false,
                    avatar: Icon(keeps ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
                    label: Text(keeps ? 'Fica esta' : 'Ficar com esta'),
                    onSelected: (_) => ref.read(dedupeChoicesProvider.notifier).keep(group.contentId, copy.instanceId),
                  ),
                  if (leaves)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: colors.attention),
                        const SizedBox(width: 4),
                        Text(
                          'Vai para a Lixeira',
                          style: theme.textTheme.labelMedium?.copyWith(color: colors.attention),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final (k, v) in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '$k: ', style: theme.textTheme.bodySmall),
                              TextSpan(text: v),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    key: ValueKey('dedupe-open-${copy.instanceId}'),
                    onPressed: copy.fullPath == null ? null : () => backend.openFile(copy.fullPath!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(video ? 'Abrir o vídeo' : 'Abrir a foto'),
                  ),
                  TextButton.icon(
                    key: ValueKey('dedupe-reveal-${copy.instanceId}'),
                    onPressed: copy.fullPath == null ? null : () => backend.showInFolder(copy.fullPath!),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Mostrar na pasta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prévia antes de qualquer remoção: o que vai para a Lixeira, quantos, o
/// espaço liberado e a confirmação explícita. Devolve `true` para começar.
class DedupePreviewDialog extends StatefulWidget {
  const DedupePreviewDialog({super.key, required this.preview});
  final DedupePreview preview;

  @override
  State<DedupePreviewDialog> createState() => _DedupePreviewDialogState();
}

class _DedupePreviewDialogState extends State<DedupePreviewDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.preview;
    return AlertDialog(
      key: const ValueKey('dedupe-preview'),
      title: const Text('Enviar para a Lixeira do Windows'),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key: const ValueKey('dedupe-preview-summary'),
              '${plural(p.files, 'arquivo vai', 'arquivos vão')} para a Lixeira, de '
              '${plural(p.groups, 'grupo', 'grupos')} em "${p.sourceName}". Libera ${formatBytes(p.bytes)}. '
              'Em cada grupo, uma cópia fica.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Na hora, o FotoAtlas confere de novo o conteúdo da cópia que fica e de cada uma que sai. Se algo mudou, '
              'aquele grupo fica como está e você é avisado em Tarefas. Dá para restaurar qualquer arquivo pela '
              'Lixeira do Windows.',
            ),
            if (p.blocker != null) ...[
              const SizedBox(height: 8),
              Text(p.blocker!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            for (final s in p.skipped) ...[
              const SizedBox(height: 8),
              Text(s, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in p.removals)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.delete_outline),
                      title: Text(r.relPath.replaceAll('/', ' › ')),
                      subtitle: Text('Fica: ${r.keepRelPath.replaceAll('/', ' › ')} · ${formatBytes(r.sizeBytes)}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('dedupe-understood'),
              value: _understood,
              onChanged: p.canStart ? (v) => setState(() => _understood = v ?? false) : null,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Entendi: ${plural(p.files, 'este arquivo vai', 'estes arquivos vão')} para a Lixeira do Windows.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
        FilledButton.icon(
          key: const ValueKey('dedupe-confirm'),
          onPressed: p.canStart && _understood ? () => Navigator.pop(context, true) : null,
          icon: const Icon(Icons.delete_outline),
          label: Text('Enviar ${plural(p.files, 'arquivo', 'arquivos')} para a Lixeira'),
        ),
      ],
    );
  }
}
