import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../devices/add_device.dart' show addDevice;

/// Assistente "Copiar para…" (spec §3.3): destino → organização → prévia →
/// confirmar. Nada é gravado antes do botão de confirmar (regra 6).
///
/// [contents] devolve os conteúdos escolhidos (a Comparação pode buscar "todos
/// os resultados" só aqui). Devolve o id da operação criada, ou `null`.
Future<String?> showCopyWizard(
  BuildContext context, {
  required Future<List<int>> Function() contents,
  String? destSourceId,
  String destFolder = '',
  List<String> preferSourceIds = const [],
  required String origin,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => CopyWizard(
    contents: contents,
    destSourceId: destSourceId,
    destFolder: destFolder,
    preferSourceIds: preferSourceIds,
    origin: origin,
  ),
);

/// Textos dos modelos de organização.
String templateLabel(String pattern) => FolderTemplate.byPattern(pattern)?.label ?? pattern;

class CopyWizard extends ConsumerStatefulWidget {
  const CopyWizard({
    super.key,
    required this.contents,
    this.destSourceId,
    this.destFolder = '',
    this.preferSourceIds = const [],
    required this.origin,
  });

  final Future<List<int>> Function() contents;
  final String? destSourceId;
  final String destFolder;
  final List<String> preferSourceIds;
  final String origin;

  @override
  ConsumerState<CopyWizard> createState() => _CopyWizardState();
}

class _CopyWizardState extends ConsumerState<CopyWizard> {
  List<int>? _ids;
  String? _dest;
  late final TextEditingController _folder = TextEditingController(text: widget.destFolder.replaceAll('/', r'\'));
  String _template = FolderTemplate.byMonth.pattern;
  ConflictPolicy _conflict = ConflictPolicy.suffix;
  CopyPreview? _preview;
  Object? _error;
  bool _loading = true;
  bool _starting = false;
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _dest = widget.destSourceId;
    widget.contents().then(
      (ids) {
        if (!mounted) return;
        setState(() => _ids = ids);
        _refresh();
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _folder.dispose();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refresh);
  }

  Future<void> _refresh() async {
    final ids = _ids, dest = _dest;
    if (ids == null || dest == null) {
      setState(() => _loading = false);
      return;
    }
    final gen = ++_generation;
    setState(() => _loading = true);
    try {
      final preview = await ref
          .read(backendProvider)
          .previewCopy(
            CopyRequest(
              contentIds: ids,
              destSourceId: dest,
              destFolder: _folder.text.trim().replaceAll(r'\', '/'),
              template: _template,
              conflict: _conflict,
              preferSourceIds: widget.preferSourceIds,
              origin: widget.origin,
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

  /// "Adicionar dispositivo" a partir do assistente: um disco novo vira o destino.
  Future<void> _addDestination() async {
    final id = await addDevice(context, ref);
    if (id == null || !mounted) return;
    ref.invalidate(sourcesProvider);
    final added = (await ref.read(sourcesProvider.future)).where((s) => s.id == id).firstOrNull;
    if (!mounted || added == null || added.isPhone || !added.isConnected) return;
    setState(() => _dest = id);
    _refresh();
  }

  Future<void> _start() async {
    final preview = _preview;
    if (preview == null || !preview.canStart) return;
    setState(() => _starting = true);
    try {
      final id = await ref.read(backendProvider).startCopy(preview);
      if (mounted) Navigator.of(context).pop(id);
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
    final sources = ref.watch(sourcesProvider).value ?? const <SourceView>[];
    final targets = [
      for (final s in sources)
        if (!s.isPhone && s.isConnected) s,
    ];
    if (_dest != null && !targets.any((s) => s.id == _dest)) {
      // Destino sugerido desconectado (ou celular): a pessoa escolhe outro.
      final suggested = sources.where((s) => s.id == _dest).firstOrNull;
      if (suggested != null && suggested.isPhone) _dest = null;
    }
    final ids = _ids;
    final preview = _preview;
    final destPath = targets.where((s) => s.id == _dest).firstOrNull?.displayPath;
    return AlertDialog(
      key: const ValueKey('copy-wizard'),
      title: Text(
        ids == null ? 'Copiar com conferência' : 'Copiar ${plural(ids.length, 'item', 'itens')} com conferência',
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A origem não é alterada. Cada arquivo é gravado numa pasta temporária, conferido pelo conteúdo e só '
                'então aparece no destino. Nada é sobrescrito.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('copy-dest'),
                isExpanded: true,
                initialValue: targets.any((s) => s.id == _dest) ? _dest : null,
                decoration: const InputDecoration(labelText: 'Para onde', border: OutlineInputBorder()),
                hint: Text(targets.isEmpty ? 'Conecte o disco de destino' : 'Escolha o disco de destino'),
                itemHeight: null,
                // Fechado mostra só o nome; o caminho completo vem logo abaixo.
                selectedItemBuilder: (_) => [for (final s in targets) Text(s.name, overflow: TextOverflow.ellipsis)],
                items: [
                  for (final s in targets)
                    DropdownMenuItem(
                      value: s.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('${s.name}${s.displayPath == null ? '' : '\n${s.displayPath}'}'),
                      ),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _dest = v);
                  _refresh();
                },
              ),
              if (destPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Tooltip(
                    message: destPath,
                    child: Text(
                      'Caminho: $destPath',
                      key: const ValueKey('copy-dest-path'),
                      softWrap: true,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              if (targets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nenhum disco de destino conectado. Conecte o HD ou pendrive (cadastrado em Dispositivos). '
                    'Celulares não podem ser destino: o FotoAtlas só lê do celular.',
                    style: TextStyle(color: StatusColors.of(context).attention),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('copy-folder'),
                controller: _folder,
                decoration: const InputDecoration(
                  labelText: 'Pasta dentro do destino',
                  helperText: r'Ex.: Backup\Fotos. Vazio = a raiz do disco (ou da pasta cadastrada).',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _schedule(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('copy-template'),
                isExpanded: true,
                initialValue: _template,
                decoration: const InputDecoration(labelText: 'Como organizar', border: OutlineInputBorder()),
                items: [for (final t in FolderTemplate.all) DropdownMenuItem(value: t.pattern, child: Text(t.label))],
                onChanged: (v) {
                  setState(() => _template = v ?? _template);
                  _refresh();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ConflictPolicy>(
                key: const ValueKey('copy-conflict'),
                isExpanded: true,
                initialValue: _conflict,
                decoration: const InputDecoration(
                  labelText: 'Se já existir um arquivo com o mesmo nome',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ConflictPolicy.suffix,
                    child: Text('Copiar com outro nome (IMG_1.jpg, IMG_2.jpg…) — recomendado'),
                  ),
                  DropdownMenuItem(value: ConflictPolicy.ask, child: Text('Perguntar para cada um, na tela Tarefas')),
                ],
                onChanged: (v) {
                  setState(() => _conflict = v ?? _conflict);
                  _refresh();
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text('Prévia', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_error != null)
                Text('Não foi possível montar a prévia: $_error', style: TextStyle(color: theme.colorScheme.error))
              else if (ids == null || (_loading && preview == null))
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_dest == null)
                const Text('Escolha o destino para ver a prévia.')
              else if (preview != null)
                Opacity(
                  opacity: _loading ? 0.5 : 1,
                  child: CopyPreviewView(
                    preview: preview,
                    otherTargets: targets.where((s) => s.id != _dest).length,
                    onAddDevice: _addDestination,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _starting ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          key: const ValueKey('copy-confirm'),
          onPressed: preview != null && preview.canStart && !_loading && !_starting && _dest != null ? _start : null,
          icon: const Icon(Icons.copy_all),
          label: Text(
            preview == null || preview.items.isEmpty
                ? 'Copiar'
                : 'Copiar ${plural(preview.items.length, 'arquivo', 'arquivos')} (${formatBytes(preview.totalBytes)})',
          ),
        ),
      ],
    );
  }
}

/// O que vai acontecer, em frases simples.
class CopyPreviewView extends StatelessWidget {
  const CopyPreviewView({super.key, required this.preview, this.otherTargets = 0, this.onAddDevice});
  final CopyPreview preview;

  /// Outros discos conectados que podem ser destino (para sugerir o próximo passo).
  final int otherTargets;
  final VoidCallback? onAddDevice;

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
      return line(Icons.block, p.blocker!, color: colors.attention, key: const ValueKey('copy-blocker'));
    }
    final free = p.freeBytes;
    final example = p.items.isEmpty ? null : p.items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(
          Icons.copy_all,
          p.items.isEmpty
              ? 'Nada para copiar.'
              : 'Vai copiar ${plural(p.items.length, 'arquivo', 'arquivos')} (${formatBytes(p.totalBytes)}) para '
                    '"${p.destName}".',
          key: const ValueKey('copy-summary'),
        ),
        if (p.alreadyThere > 0)
          line(
            Icons.check_circle_outline,
            '${plural(p.alreadyThere, 'item já está', 'itens já estão')} em "${p.destName}" '
            '(mesmo conteúdo, talvez com outro nome): não serão copiados de novo.',
            color: colors.verified,
          ),
        if (p.items.isEmpty && p.alreadyThere > 0 && p.unavailable.isEmpty && p.tooLargeForFat32.isEmpty) ...[
          line(
            Icons.lightbulb_outline,
            'Tudo o que você escolheu já está em "${p.destName}". Para ter mais uma cópia, escolha outro destino'
            '${otherTargets > 0 ? ' em "Para onde", lá em cima,' : ''} ou adicione outro disco.',
            key: const ValueKey('copy-next-step'),
          ),
          if (onAddDevice != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 26, top: 4),
                child: OutlinedButton.icon(
                  key: const ValueKey('copy-add-device'),
                  onPressed: onAddDevice,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar dispositivo…'),
                ),
              ),
            ),
        ],
        if (free != null)
          p.enoughSpace
              ? line(
                  Icons.storage,
                  'Espaço livre no destino: ${formatBytes(free)}. Depois da cópia sobram '
                  '${formatBytes(free - p.totalBytes)}.',
                  key: const ValueKey('copy-space'),
                )
              : line(
                  Icons.warning_amber,
                  'Falta espaço: precisa de ${formatBytes(p.totalBytes + p.reserveBytes)} '
                  '(com uma pequena margem) e o destino tem ${formatBytes(free)}. Libere espaço ou escolha outro destino.',
                  color: colors.single,
                  key: const ValueKey('copy-space'),
                ),
        if (p.renamedForConflict > 0)
          line(
            Icons.drive_file_rename_outline,
            '${plural(p.renamedForConflict, 'arquivo tem', 'arquivos têm')} um nome que já existe no destino '
            '(com outro conteúdo): ${p.renamedForConflict == 1 ? 'vai' : 'vão'} ganhar _1, _2… no fim do nome. '
            'O arquivo que já está lá não é mexido.',
            color: colors.attention,
            key: const ValueKey('copy-conflicts'),
          ),
        if (p.askConflicts > 0)
          line(
            Icons.help_outline,
            '${plural(p.askConflicts, 'arquivo tem', 'arquivos têm')} um nome que já existe no destino: depois de '
            'copiados e conferidos, ${p.askConflicts == 1 ? 'ele espera' : 'eles esperam'} a sua decisão na tela Tarefas.',
            color: colors.attention,
            key: const ValueKey('copy-conflicts'),
          ),
        if (p.tooLargeForFat32.isNotEmpty)
          line(
            Icons.block,
            '${plural(p.tooLargeForFat32.length, 'arquivo fica', 'arquivos ficam')} de fora: '
            '${p.tooLargeForFat32.length == 1 ? 'tem' : 'têm'} mais de 4 GB e o destino (FAT32) não aceita arquivos assim. '
            'Use um disco formatado em exFAT ou NTFS para ${p.tooLargeForFat32.length == 1 ? 'ele' : 'eles'}.',
            color: colors.single,
            key: const ValueKey('copy-fat32'),
          ),
        if (p.unavailable.isNotEmpty)
          line(
            Icons.link_off,
            '${plural(p.unavailable.length, 'item não pode', 'itens não podem')} ser copiado${p.unavailable.length == 1 ? '' : 's'} '
            'agora: ${p.unavailable.first.reason}${p.unavailable.length > 1 ? ' (e outros)' : ''}',
            color: colors.attention,
          ),
        if (p.sanitized > 0)
          line(
            Icons.text_fields,
            '${plural(p.sanitized, 'nome foi ajustado', 'nomes foram ajustados')} para o Windows aceitar '
            '(caracteres como : ? * viram _). O nome original fica no histórico.',
          ),
        if (p.undated > 0)
          line(
            Icons.event_busy,
            '${plural(p.undated, 'item sem', 'itens sem')} data da captura ${p.undated == 1 ? 'vai' : 'vão'} para a pasta '
            '"$undatedFolder".',
          ),
        if (p.lowConfidence > 0)
          line(
            Icons.schedule,
            '${plural(p.lowConfidence, 'item tem', 'itens têm')} a hora com pouca confiança (veio do nome ou da data do '
            'arquivo): pode cair no mês errado. Confira em Biblioteca › Hora a confirmar.',
          ),
        if (example != null) ...[
          const SizedBox(height: 8),
          Text(
            'Exemplo: ${p.destName} › ${folderLabel(example.dstRelPath)}',
            key: const ValueKey('copy-example'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (p.folders.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Pastas no destino', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final f in p.folders.take(8))
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '${f.relPath.isEmpty ? '(raiz)' : folderLabel(f.relPath)} — '
                '${plural(f.files, 'arquivo', 'arquivos')}, ${formatBytes(f.bytes)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (p.folders.length > 8)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                'e mais ${plural(p.folders.length - 8, 'pasta', 'pastas')}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
