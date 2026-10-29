import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import 'dates_settings.dart';

/// Configurações. Na Fase 2: backup do catálogo. Biblioteca principal,
/// modelos de organização e verificação periódica chegam nas próximas fases.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final info = await ref.read(backendProvider).backupCatalogNow();
      messenger.showSnackBar(SnackBar(content: Text('Backup do catálogo feito (${formatBytes(info.sizeBytes)}).')));
    } on CatalogBackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backups = ref.read(backendProvider).catalogBackups();
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backup do catálogo', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'O catálogo guarda o que o FotoAtlas sabe sobre seus arquivos (não guarda as fotos). '
                    'Uma cópia conferida é feita automaticamente a cada dia em que o app abre; as 10 mais novas ficam guardadas.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    backups.isEmpty
                        ? 'Nenhum backup ainda.'
                        : 'Último backup: ${formatDateTime(backups.first.createdAt)} '
                              '(${formatBytes(backups.first.sizeBytes)}) · ${plural(backups.length, 'backup guardado', 'backups guardados')}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _backupNow,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.backup_outlined),
                    label: const Text('Fazer backup agora'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DatesSettingsCard(),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Em breve'),
              subtitle: const Text('Biblioteca principal, modelos de organização e verificação periódica.'),
            ),
          ),
        ],
      ),
    );
  }
}
