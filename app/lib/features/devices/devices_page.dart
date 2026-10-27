import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
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
          TextButton.icon(
            onPressed: () => addPhone(context, ref),
            icon: const Icon(Icons.smartphone),
            label: const Text('Adicionar celular'),
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
                'Cadastre os celulares, HDs, pendrives e pastas onde estão suas fotos. O FotoAtlas só lê: '
                'nada é alterado, movido ou apagado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => addPhone(context, ref),
                    icon: const Icon(Icons.smartphone),
                    label: const Text('Adicionar celular'),
                  ),
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

/// Escolhe uma pasta e a cadastra. Devolve a fonte cadastrada (ou null).
Future<String?> addFolder(BuildContext context, WidgetRef ref, {String? addedMessage}) async {
  final path = await getDirectoryPath(confirmButtonText: 'Escolher esta pasta');
  if (path == null || !context.mounted) return null;
  return _add(context, ref, path, addedMessage);
}

/// Lista as unidades conectadas e cadastra a escolhida. Devolve a fonte (ou null).
Future<String?> addDrive(BuildContext context, WidgetRef ref, {String? addedMessage}) async {
  final backend = ref.read(backendProvider);
  await backend.refreshDevices();
  if (!context.mounted) return null;
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
  if (chosen == null || !context.mounted) return null;
  return _add(context, ref, chosen.displayMount!, addedMessage);
}

Future<String?> _add(BuildContext context, WidgetRef ref, String path, String? addedMessage) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await ref.read(backendProvider).addPath(path);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.warnings.isEmpty
              ? addedMessage ?? 'Dispositivo adicionado. Clique em "Escanear" para ver o que tem nele.'
              : result.warnings.join('\n'),
        ),
      ),
    );
    return result.sourceId;
  } on SourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

/// Lista os celulares conectados e cadastra o escolhido. Devolve a fonte (ou null).
///
/// Cadastrar só grava no catálogo do FotoAtlas: nada é gravado no celular.
Future<String?> addPhone(BuildContext context, WidgetRef ref, {String? addedMessage}) async {
  final backend = ref.read(backendProvider);
  final messenger = ScaffoldMessenger.of(context);
  final List<(DeviceInfo, String?)> devices;
  try {
    devices = await backend.listDevices();
  } on Exception catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Não foi possível procurar celulares: $e')));
    return null;
  }
  if (!context.mounted) return null;
  final chosen = await showDialog<DeviceInfo>(
    context: context,
    builder: (context) => _PhonePickerDialog(devices: devices),
  );
  if (chosen == null || !context.mounted) return null;
  try {
    final result = await backend.addPhone(chosen.deviceId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            addedMessage ??
                (chosen.isReady
                    ? 'Celular adicionado. Clique em "Escanear" para ver o que tem nele.'
                    : 'Celular adicionado. ${phoneStatusMessage(chosen)}'),
            ...result.warnings,
          ].join('\n'),
        ),
      ),
    );
    return result.sourceId;
  } on SourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

class _PhonePickerDialog extends StatelessWidget {
  const _PhonePickerDialog({required this.devices});
  final List<(DeviceInfo, String?)> devices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Qual celular você quer adicionar?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum celular encontrado. Ligue o celular pelo cabo USB, desbloqueie a tela e, '
                  'no Android, escolha "Transferência de arquivos" no aviso de USB.',
                  key: ValueKey('no-phones'),
                ),
              ),
            for (final (d, sourceId) in devices)
              ListTile(
                key: ValueKey('phone-${d.deviceId}'),
                leading: const Icon(Icons.smartphone),
                enabled: sourceId == null,
                title: Text('${d.friendlyName}${d.simulated ? ' (simulado)' : ''}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceId != null
                          ? 'Já cadastrado'
                          : [
                              deviceStatusLabel(d.status),
                              if (d.storages.isNotEmpty) d.storages.map((s) => s.name).join(', '),
                            ].join(' · '),
                    ),
                    if (sourceId == null && phoneStatusMessage(d) != null)
                      Text(phoneStatusMessage(d)!, style: theme.textTheme.bodySmall),
                    if (d.isIphone) Text(iphoneOriginalsHint, style: theme.textTheme.bodySmall),
                  ],
                ),
                isThreeLine: d.isIphone || (sourceId == null && !d.isReady),
                onTap: sourceId == null ? () => Navigator.pop(context, d) : null,
              ),
            const SizedBox(height: 8),
            Text(
              'O FotoAtlas só lê o celular: nada é gravado, movido ou apagado nele.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}
