import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show tasksDestination;
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../tasks/copy_wizard.dart';

/// Resultado do assistente: reorganização iniciada ou "copiar para outro disco".
sealed class ReorgWizardResult {
  const ReorgWizardResult();
}

class ReorgStarted extends ReorgWizardResult {
  const ReorgStarted(this.operationId);
  final String operationId;
}

class CopyElsewhere extends ReorgWizardResult {
  const CopyElsewhere(this.folder);
  final String folder;
}

/// Abre o assistente "Reorganizar" (spec §12) para [source] e cuida do que
/// vem depois (aviso de início ou o assistente de cópia para outro disco).
Future<void> reorganizeFlow(BuildContext context, WidgetRef ref, SourceView source) async {
  final result = await showDialog<ReorgWizardResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReorgWizard(source: source),
  );
  if (!context.mounted || result == null) return;
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case ReorgStarted():
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('reorg-started'),
          content: const Text('Reorganização iniciada. Acompanhe (e desfaça, se quiser) em Tarefas.'),
          action: SnackBarAction(
            label: 'Ver em Tarefas',
            onPressed: () => ref.read(navigationIndexProvider.notifier).select(tasksDestination),
          ),
        ),
      );
    case CopyElsewhere(:final folder):
      final backend = ref.read(backendProvider);
      final primary = await backend.primarySourceId();
      if (!context.mounted) return;
      final id = await showCopyWizard(
        context,
        contents: () => backend.contentIdsIn(source.id, folder),
        destSourceId: primary == source.id ? null : primary,
        preferSourceIds: [source.id],
        origin: 'reorg',
      );
      if (id != null) {
        messenger.showSnackBar(const SnackBar(content: Text('Cópia iniciada. Acompanhe em Tarefas.')));
      }
  }
}

class ReorgWizard extends ConsumerStatefulWidget {
  const ReorgWizard({super.key, required this.source});
  final SourceView source;

  @override
  ConsumerState<ReorgWizard> createState() => _ReorgWizardState();
}

class _ReorgWizardState extends ConsumerState<ReorgWizard> {
  final _folder = TextEditingController();
  final _toConfirm = TextEditingController(text: undatedFolder);
  String _template = FolderTemplate.byMoment.pattern;
  ConflictPolicy _conflict = ConflictPolicy.suffix;
  bool _sidecars = true;
  ReorgPreview? _preview;
  Object? _error;
  bool _loading = true;
  bool _starting = false;
  Timer? _debounce;
  int _generation = 0;
  List<String> _topFolders = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
    ref.read(backendProvider).childFolders(widget.source.id, '').then((f) {
      if (mounted) setState(() => _topFolders = f);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _folder.dispose();
    _toConfirm.dispose();
    super.dispose();
  }

  String get _folderRel => cleanFolder(_folder.text);

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refresh);
  }

  Future<void> _refresh() async {
    final gen = ++_generation;
    setState(() => _loading = true);
    try {
      final preview = await ref
          .read(backendProvider)
          .previewReorg(
            ReorgRequest(
              sourceId: widget.source.id,
              folder: _folderRel,
              template: _template,
              conflict: _conflict,
              toConfirmFolder: _toConfirm.text.trim().isEmpty ? undatedFolder : _toConfirm.text.trim(),
              sidecars: _sidecars,
            ),
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _preview = preview;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    final preview = _preview;
    if (preview == null || !preview.canStart) return;
    setState(() => _starting = true);
    try {
      final id = await ref.read(backendProvider).startReorg(preview);
      if (mounted) Navigator.of(context).pop(ReorgStarted(id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      key: const ValueKey('reorg-wizard'),
      title: Text('Reorganizar "${widget.source.name}"'),
      content: SizedBox(
        width: width >= 1100 ? 980 : 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Os arquivos mudam de pasta dentro deste mesmo disco, sem cópia. Nada é apagado nem sobrescrito, '
                'e dá para desfazer depois em Tarefas.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Para organizar em outro disco, use a cópia conferida: a origem fica como está.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('reorg-copy-elsewhere'),
                    onPressed: _starting ? null : () => Navigator.of(context).pop(CopyElsewhere(_folderRel)),
                    icon: const Icon(Icons.copy_all),
                    label: const Text('Copiar para outro disco…'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('reorg-folder'),
                controller: _folder,
                decoration: InputDecoration(
                  labelText: 'Pasta a organizar',
                  helperText: r'Ex.: Fotos\Bagunça. Vazio = o dispositivo inteiro.',
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  prefixText: '${widget.source.name} › ',
                ),
                onChanged: (_) => _schedule(),
              ),
              if (_topFolders.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final f in _topFolders.take(12))
                      ActionChip(
                        label: Text(f.split('/').last),
                        onPressed: () {
                          _folder.text = f.replaceAll('/', r'\');
                          _refresh();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('reorg-template'),
                isExpanded: true,
                initialValue: _template,
                decoration: const InputDecoration(labelText: 'Como organizar', border: OutlineInputBorder()),
                items: [for (final t in FolderTemplate.all) DropdownMenuItem(value: t.pattern, child: Text(t.label))],
                onChanged: (v) {
                  setState(() => _template = v ?? _template);
                  _refresh();
                },
              ),
              if (templateUsesMoment(_template))
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    'Cada momento da Biblioteca vira uma pasta com o nome dele; momento sem nome usa a hora em que '
                    'começou (ex.: "2024-07-13 14h03").',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('reorg-to-confirm'),
                controller: _toConfirm,
                decoration: InputDecoration(
                  labelText: templateUsesMoment(_template)
                      ? 'Pasta para fotos fora de momentos (hora a confirmar)'
                      : 'Pasta para fotos sem data',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _schedule(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ConflictPolicy>(
                key: const ValueKey('reorg-conflict'),
                isExpanded: true,
                initialValue: _conflict,
                decoration: const InputDecoration(
                  labelText: 'Se a pasta nova já tiver um arquivo com o mesmo nome',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ConflictPolicy.suffix,
                    child: Text('Mover com outro nome (IMG_1.jpg, IMG_2.jpg…) — recomendado'),
                  ),
                  DropdownMenuItem(value: ConflictPolicy.ask, child: Text('Perguntar para cada um, na tela Tarefas')),
                ],
                onChanged: (v) {
                  setState(() => _conflict = v ?? _conflict);
                  _refresh();
                },
              ),
              CheckboxListTile(
                key: const ValueKey('reorg-sidecars'),
                contentPadding: EdgeInsets.zero,
                value: _sidecars,
                title: const Text('Levar junto os arquivos de edição (.xmp, .aae) com o mesmo nome da foto'),
                onChanged: (v) {
                  setState(() => _sidecars = v ?? true);
                  _refresh();
                },
              ),
              const Divider(),
              Text('Prévia', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_error != null)
                Text('Não foi possível montar a prévia: $_error', style: TextStyle(color: theme.colorScheme.error))
              else if (preview == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Opacity(
                  opacity: _loading ? 0.5 : 1,
                  child: ReorgPreviewView(preview: preview, wide: width >= 1100),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _starting ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          key: const ValueKey('reorg-confirm'),
          onPressed: preview != null && preview.canStart && !_loading && !_starting ? _start : null,
          icon: const Icon(Icons.drive_file_move_outline),
          label: Text(
            preview == null || preview.moves.isEmpty
                ? 'Reorganizar'
                : 'Mover ${plural(preview.moves.length, 'arquivo', 'arquivos')}',
          ),
        ),
      ],
    );
  }
}

/// Resumo em frases + árvore "antes → depois".
class ReorgPreviewView extends StatelessWidget {
  const ReorgPreviewView({super.key, required this.preview, this.wide = false});
  final ReorgPreview preview;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final p = preview;
    Widget line(IconData icon, String text, {Color? color, Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: color == null ? null : TextStyle(color: color)),
          ),
        ],
      ),
    );

    if (p.blocker != null) {
      return line(Icons.block, p.blocker!, color: colors.attention, key: const ValueKey('reorg-blocker'));
    }
    final before = ReorgTreeView(root: p.before, before: true);
    final after = ReorgTreeView(root: p.after, before: false);
    Widget panel(String title, Widget tree) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            tree,
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(
          Icons.drive_file_move_outline,
          p.moves.isEmpty
              ? 'Nada para mover: tudo já está organizado assim.'
              : 'Vai mover ${plural(p.moves.length, 'arquivo', 'arquivos')} (${formatBytes(p.totalBytes)}) '
                    'dentro de "${p.sourceName}"${p.sourceDisplay == null ? '' : ' (${p.sourceDisplay})'}. '
                    'Sem copiar: é rápido e não ocupa espaço.',
          key: const ValueKey('reorg-summary'),
        ),
        if (p.alreadyInPlace > 0)
          line(
            Icons.check_circle_outline,
            '${plural(p.alreadyInPlace, 'foto ou vídeo já está', 'fotos e vídeos já estão')} no lugar certo: '
            '${p.alreadyInPlace == 1 ? 'fica' : 'ficam'} onde ${p.alreadyInPlace == 1 ? 'está' : 'estão'}.',
            color: colors.verified,
          ),
        if (p.sidecars > 0)
          line(
            Icons.attach_file,
            '${plural(p.sidecars, 'arquivo de edição (.xmp/.aae) vai', 'arquivos de edição (.xmp/.aae) vão')} junto '
            'com a foto.',
          ),
        if (p.renamedForConflict > 0)
          line(
            Icons.drive_file_rename_outline,
            '${plural(p.renamedForConflict, 'arquivo tem', 'arquivos têm')} um nome que já existe na pasta nova: '
            '${p.renamedForConflict == 1 ? 'vai' : 'vão'} ganhar _1, _2… no fim do nome. Nada é sobrescrito.',
            color: colors.attention,
            key: const ValueKey('reorg-conflicts'),
          ),
        if (p.askConflicts > 0)
          line(
            Icons.help_outline,
            '${plural(p.askConflicts, 'arquivo tem', 'arquivos têm')} um nome que já existe na pasta nova: '
            '${p.askConflicts == 1 ? 'espera' : 'esperam'} a sua decisão na tela Tarefas.',
            color: colors.attention,
            key: const ValueKey('reorg-conflicts'),
          ),
        if (p.toConfirm > 0)
          line(
            Icons.event_busy,
            '${plural(p.toConfirm, 'foto ou vídeo', 'fotos e vídeos')} sem hora confiável '
            '${p.toConfirm == 1 ? 'vai' : 'vão'} para "${cleanFolder(p.request.toConfirmFolder).replaceAll('/', ' › ')}". '
            'Confira em Biblioteca › Hora a confirmar e reorganize de novo depois.',
            key: const ValueKey('reorg-to-confirm-line'),
          ),
        if (p.lowConfidence > 0)
          line(
            Icons.schedule,
            '${plural(p.lowConfidence, 'item tem', 'itens têm')} a hora com pouca confiança (veio do nome ou da data do '
            'arquivo): pode cair na pasta errada.',
          ),
        if (p.sanitized > 0)
          line(
            Icons.text_fields,
            '${plural(p.sanitized, 'nome foi ajustado', 'nomes foram ajustados')} para o Windows aceitar '
            '(caracteres como : ? * viram _).',
          ),
        if (p.notReady > 0)
          line(
            Icons.hourglass_empty,
            '${plural(p.notReady, 'foto ou vídeo ainda não teve', 'fotos e vídeos ainda não tiveram')} a data lida: '
            '${p.notReady == 1 ? 'fica' : 'ficam'} onde ${p.notReady == 1 ? 'está' : 'estão'} por enquanto.',
            color: colors.attention,
          ),
        if (p.otherFiles > 0)
          line(
            Icons.description_outlined,
            '${plural(p.otherFiles, 'arquivo que não é foto nem vídeo fica', 'arquivos que não são foto nem vídeo ficam')} '
            'onde ${p.otherFiles == 1 ? 'está' : 'estão'}.',
          ),
        line(
          Icons.folder_off_outlined,
          'Pastas que ficarem vazias não são apagadas. Depois, em Tarefas, dá para revisar e remover só as vazias.',
        ),
        if (p.moves.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: panel('Antes (de onde saem)', before)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(child: panel('Depois (para onde vão)', after)),
              ],
            )
          else ...[
            panel('Antes (de onde saem)', before),
            const Center(child: Icon(Icons.arrow_downward)),
            panel('Depois (para onde vão)', after),
          ],
        ],
      ],
    );
  }
}

/// Árvore de pastas da prévia, expansível, com as contagens e os destaques.
class ReorgTreeView extends StatelessWidget {
  const ReorgTreeView({super.key, required this.root, required this.before});
  final TreeNode root;
  final bool before;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final c in root.children) _Node(node: c, before: before, depth: 0),
      ..._files(context, root, before, 0),
    ],
  );
}

List<Widget> _files(BuildContext context, TreeNode node, bool before, int depth) {
  final theme = Theme.of(context);
  final colors = StatusColors.of(context);
  return [
    for (final f in node.files)
      Padding(
        padding: EdgeInsets.only(left: 16.0 * depth + 28, top: 1, bottom: 1),
        child: Tooltip(
          message: before ? 'Vai para: ${f.other.replaceAll('/', ' › ')}' : 'Vem de: ${f.other.replaceAll('/', ' › ')}',
          child: Text(
            before
                ? '${f.name} → ${f.other.replaceAll('/', ' › ')}'
                : '${f.name}${f.conflict ? ' (nome ajustado: já existia)' : ''}',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: f.conflict ? colors.attention : null),
          ),
        ),
      ),
    if (node.count > node.files.length)
      Padding(
        padding: EdgeInsets.only(left: 16.0 * depth + 28),
        child: Text(
          'e mais ${plural(node.count - node.files.length, 'arquivo', 'arquivos')}',
          style: theme.textTheme.bodySmall,
        ),
      ),
  ];
}

class _Node extends StatelessWidget {
  const _Node({required this.node, required this.before, required this.depth});
  final TreeNode node;
  final bool before;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final n = node;
    final tags = [
      plural(n.totalCount, before ? 'sai' : 'chega', before ? 'saem' : 'chegam'),
      if (!before && n.isNew) 'pasta nova',
      if (before && n.becomesEmpty) 'fica vazia (não é apagada)',
      if (!before && n.totalConflicts > 0) plural(n.totalConflicts, 'nome ajustado', 'nomes ajustados'),
    ];
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * depth),
      child: ExpansionTile(
        key: ValueKey('tree-${before ? 'before' : 'after'}-${n.relPath}'),
        dense: true,
        tilePadding: const EdgeInsets.only(left: 4, right: 8),
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: depth < 1,
        leading: Icon(
          before ? Icons.folder_outlined : (n.isNew ? Icons.create_new_folder_outlined : Icons.folder),
          size: 20,
        ),
        title: Text(n.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          tags.join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: n.totalConflicts > 0 && !before ? colors.attention : null),
        ),
        children: [
          for (final c in n.children) _Node(node: c, before: before, depth: depth + 1),
          ..._files(context, n, before, depth),
        ],
      ),
    );
  }
}
