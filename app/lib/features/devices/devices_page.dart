import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import 'source_card.dart';

/// Dispositivos: fontes cadastradas, conectadas ou não (spec §3.2).
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    final progress = ref.watch(scanProgressProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        actions: [
          TextButton.icon(
            onPressed: () => addFolder(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Adicionar pasta'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => addDrive(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar unidade'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível carregar os dispositivos: $e')),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => SourceCard(source: list[i], progress: progress[list[i].id]),
              ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storage, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Nenhum dispositivo cadastrado', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Cadastre os HDs, pendrives e pastas onde estão suas fotos. O FotoAtlas só lê: '
                'nada é alterado, movido ou apagado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => addFolder(context, ref),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Adicionar pasta'),
                  ),
                  FilledButton.icon(
                    onPressed: () => addDrive(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar unidade'),
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

/// Escolhe uma pasta e a cadastra.
Future<void> addFolder(BuildContext context, WidgetRef ref) async {
  final path = await getDirectoryPath(confirmButtonText: 'Escolher esta pasta');
  if (path == null || !context.mounted) return;
  await _add(context, ref, path);
}

/// Lista as unidades conectadas e cadastra a escolhida.
Future<void> addDrive(BuildContext context, WidgetRef ref) async {
  final backend = ref.read(backendProvider);
  await backend.refreshDevices();
  if (!context.mounted) return;
  final volumes = backend.volumes.where((v) => !v.isSystem && v.displayMount != null).toList();
  final chosen = await showDialog<VolumeInfo>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Qual unidade você quer adicionar?'),
      children: [
        if (volumes.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma unidade encontrada.')),
        for (final v in volumes)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, v),
            child: ListTile(
              leading: Icon(v.driveType == 'removable' ? Icons.usb : Icons.save),
              title: Text('${v.label?.isNotEmpty == true ? v.label : 'Unidade sem nome'} (${v.displayMount})'),
              subtitle: Text(
                '${formatBytes(v.freeBytes)} livres de ${formatBytes(v.totalBytes)}'
                '${v.isBoot ? ' · disco do Windows' : ''}',
              ),
            ),
          ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  await _add(context, ref, chosen.displayMount!);
}

Future<void> _add(BuildContext context, WidgetRef ref, String path) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await ref.read(backendProvider).addPath(path);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.warnings.isEmpty
              ? 'Dispositivo adicionado. Clique em "Escanear" para ver o que tem nele.'
              : result.warnings.join('\n'),
        ),
      ),
    );
  } on SourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
