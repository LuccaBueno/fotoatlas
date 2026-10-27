import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compare_controller.dart';
import 'compare_result.dart';
import 'scope_editor.dart';

/// Comparar (spec §3.2 item 4 e §9): dois escopos livres e a pergunta
/// "B contém todo o conteúdo de A?". Somente leitura.
class ComparePage extends ConsumerWidget {
  const ComparePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(compareControllerProvider);
    final controller = ref.read(compareControllerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    const a = ScopeEditor(
      side: CompareSide.a,
      title: 'A — o que você quer garantir',
      subtitle: 'Ex.: as pastas do celular antigo',
    );
    const b = ScopeEditor(
      side: CompareSide.b,
      title: 'B — onde deveria estar',
      subtitle: 'Ex.: a pasta de backup no HD',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Escolha uma ou mais pastas ou dispositivos em cada lado. O FotoAtlas compara pelo conteúdo — '
            'nomes e pastas diferentes não importam — e nada é alterado.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (wide)
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: a),
                  SizedBox(width: 16),
                  Expanded(child: b),
                ],
              ),
            )
          else ...[
            a,
            const SizedBox(height: 16),
            b,
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                key: const ValueKey('compare-run'),
                onPressed: state.canCompare ? controller.run : null,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Comparar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.a.isEmpty && state.b.isEmpty ? null : controller.swap,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Trocar A e B'),
              ),
              const SizedBox(width: 16),
              if (state.running) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (state.result != null) ...[const SizedBox(height: 24), CompareResultView(result: state.result!)],
        ],
      ),
    );
  }
}
