import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/connection_badge.dart';

/// O que foi escolhido na janela "Adicionar dispositivo".
sealed class _Choice {
  const _Choice();
}

class _PhoneChoice extends _Choice {
  const _PhoneChoice(this.device);
  final DeviceInfo device;
}

class _DriveChoice extends _Choice {
  const _DriveChoice(this.volume);
  final VolumeInfo volume;
}

class _FolderChoice extends _Choice {
  const _FolderChoice();
}

/// "Adicionar dispositivo": uma janela só que lista o que está conectado
/// (celulares e unidades) e a opção "Escolher uma pasta…". Cadastra o
/// escolhido e devolve o id da fonte (ou `null`).
///
/// Cadastrar só grava no catálogo do FotoAtlas: nada é gravado no dispositivo.
Future<String?> addDevice(BuildContext context, WidgetRef ref, {String? addedMessage}) async {
  final choice = await showDialog<_Choice>(context: context, builder: (_) => const AddDeviceDialog());
  if (choice == null || !context.mounted) return null;
  final backend = ref.read(backendProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    switch (choice) {
      case _PhoneChoice(:final device):
        final result = await backend.addPhone(device.deviceId);
        final added =
            addedMessage ??
            (device.isReady
                ? 'Celular adicionado. Clique em "Escanear" para ver o que tem nele.'
                : 'Celular adicionado. ${phoneStatusMessage(device)}');
        messenger.showSnackBar(SnackBar(content: Text([added, ...result.warnings].join('\n'))));
        return result.sourceId;
      case _DriveChoice(:final volume):
        return await _addPath(messenger, ref, volume.displayMount!, addedMessage);
      case _FolderChoice():
        final path = await getDirectoryPath(confirmButtonText: 'Escolher esta pasta');
        if (path == null) return null;
        return await _addPath(messenger, ref, path, addedMessage);
    }
  } on SourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

Future<String> _addPath(ScaffoldMessengerState messenger, WidgetRef ref, String path, String? addedMessage) async {
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
}

class AddDeviceDialog extends ConsumerStatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  ConsumerState<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends ConsumerState<AddDeviceDialog> {
  List<(DeviceInfo, String?)>? _phones;
  List<(VolumeInfo, String?)>? _drives;
  String? _phonesError;
  String? _drivesError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _phones = _drives = null;
      _phonesError = _drivesError = null;
    });
    final backend = ref.read(backendProvider);
    // Os dois ao mesmo tempo; um falhar não esconde o outro.
    await Future.wait([
      () async {
        try {
          _phones = await backend.listDevices();
        } on Object catch (e) {
          _phones = const [];
          _phonesError = 'Não foi possível procurar celulares: $e';
        }
      }(),
      () async {
        try {
          _drives = await backend.listDrives();
        } on Object catch (e) {
          _drives = const [];
          _drivesError = 'Não foi possível procurar unidades: $e';
        }
      }(),
    ]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phones = _phones, drives = _drives;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Adicionar dispositivo')),
          IconButton(
            key: const ValueKey('add-device-refresh'),
            tooltip: 'Procurar de novo',
            onPressed: phones == null || drives == null ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: ListView(
          shrinkWrap: true,
          children: [
            _Section('Celulares'),
            if (phones == null)
              const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())
            else ...[
              if (_phonesError != null) _Hint(_phonesError!),
              if (phones.isEmpty && _phonesError == null)
                const _Hint(
                  'Nenhum celular encontrado. Ligue o celular pelo cabo USB, desbloqueie a tela e, '
                  'no Android, escolha "Transferência de arquivos" no aviso de USB.',
                  key: ValueKey('no-phones'),
                ),
              for (final (d, sourceId) in phones) _phoneTile(theme, d, sourceId),
            ],
            const SizedBox(height: 8),
            _Section('Unidades (HD, SSD, pendrive, cartão)'),
            if (drives == null)
              const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())
            else ...[
              if (_drivesError != null) _Hint(_drivesError!),
              if (drives.isEmpty && _drivesError == null)
                const _Hint('Nenhuma unidade encontrada além do disco do Windows.', key: ValueKey('no-drives')),
              for (final (v, sourceId) in drives) _driveTile(v, sourceId),
            ],
            const SizedBox(height: 8),
            _Section('Pasta'),
            ListTile(
              key: const ValueKey('add-folder'),
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Escolher uma pasta…'),
              subtitle: const Text('Uma pasta de qualquer unidade, inclusive do disco do Windows'),
              onTap: () => Navigator.pop(context, const _FolderChoice()),
            ),
            const SizedBox(height: 8),
            Text(
              'O FotoAtlas só lê os dispositivos: nada é gravado, movido ou apagado neles.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }

  Widget _phoneTile(ThemeData theme, DeviceInfo d, String? sourceId) {
    final notReady = sourceId == null ? phoneStatusMessage(d) : null;
    return ListTile(
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
          if (notReady != null) Text(notReady, style: theme.textTheme.bodySmall),
          if (d.isIphone) Text(iphoneOriginalsHint, style: theme.textTheme.bodySmall),
        ],
      ),
      isThreeLine: d.isIphone || notReady != null,
      onTap: sourceId == null ? () => Navigator.pop(context, _PhoneChoice(d)) : null,
    );
  }

  Widget _driveTile(VolumeInfo v, String? sourceId) {
    final kind = SourcesService.kindForVolume(v);
    return ListTile(
      key: ValueKey('drive-${v.displayMount}'),
      leading: Icon(sourceKindIcon(kind)),
      enabled: sourceId == null,
      title: Text('${v.label?.isNotEmpty == true ? v.label : 'Unidade sem nome'} (${v.displayMount})'),
      subtitle: Text(
        sourceId != null
            ? 'Já cadastrada'
            : [
                sourceKindLabel(kind),
                '${formatBytes(v.freeBytes)} livres de ${formatBytes(v.totalBytes)}',
                if (v.isBoot) 'disco do Windows',
              ].join(' · '),
      ),
      onTap: sourceId == null ? () => Navigator.pop(context, _DriveChoice(v)) : null,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(text));
}
