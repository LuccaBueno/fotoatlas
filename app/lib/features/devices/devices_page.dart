import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'add_device.dart';
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
        // Sem dispositivos, o botão fica só no centro da tela.
        actions: [
          if (sources.value?.isNotEmpty ?? false) ...[
            FilledButton.icon(
              key: const ValueKey('add-device'),
              onPressed: () => addDevice(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar dispositivo'),
            ),
            const SizedBox(width: 16),
          ],
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
              FilledButton.icon(
                key: const ValueKey('add-device-empty'),
                onPressed: () => addDevice(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar dispositivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
