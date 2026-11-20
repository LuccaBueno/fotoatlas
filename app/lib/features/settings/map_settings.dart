import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../library/library_map.dart';

/// O que o mapa online envia (o mesmo texto no cartão e na confirmação).
const onlineMapWhatIsSent =
    'Ligado, o FotoAtlas pede ao OpenStreetMap (servidores na internet, de uma fundação sem fins lucrativos) as '
    'imagens do mapa da região que você está olhando. Cada pedido leva só a posição e o nível de aproximação dessa '
    'região, junto com o endereço de internet do seu computador, como qualquer site. Os locais das fotos, os nomes '
    'dos arquivos e o catálogo nunca são enviados — mas olhar uma região de perto pode revelar onde as fotos foram '
    'tiradas.';

/// Configurações → "Mapa": offline por padrão; o mapa online (OpenStreetMap)
/// só liga com confirmação (ADR 0026).
class MapSettingsCard extends ConsumerWidget {
  const MapSettingsCard({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, bool enabled) async {
    if (enabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ligar o mapa online?'),
          content: const SizedBox(width: 480, child: Text(onlineMapWhatIsSent)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              key: const ValueKey('map-online-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ligar o mapa online'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(libraryBackendProvider).setOnlineMapEnabled(enabled);
    ref.invalidate(onlineMapProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setting = ref.watch(onlineMapProvider);
    final enabled = setting.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mapa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'O mapa da Biblioteca funciona sem internet, com os contornos de países e estados que vêm com o '
              'FotoAtlas (Natural Earth). Nada sai do computador. Se quiser ver ruas e cidades, ligue o mapa online.',
            ),
            const SizedBox(height: 8),
            if (setting.hasError)
              const Text('Não foi possível ler esta configuração agora. O mapa continua sem internet.')
            else if (enabled == null)
              const LinearProgressIndicator()
            else
              SwitchListTile(
                key: const ValueKey('map-online'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar o mapa online (OpenStreetMap)'),
                subtitle: const Text(onlineMapWhatIsSent),
                value: enabled,
                onChanged: (v) => _set(context, ref, v),
              ),
          ],
        ),
      ),
    );
  }
}
