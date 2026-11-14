import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/app_info.dart';
import '../../app/providers.dart';

/// Versão em uso (substituível em testes; vazia fora do instalador).
final currentVersionProvider = Provider<String>((ref) => appVersion);

/// Abre a página da versão no navegador padrão. Só abre páginas do
/// repositório oficial (o endereço já vem conferido do core).
final releasePageOpenerProvider = Provider<Future<void> Function(Uri)>((ref) => _openInBrowser);

Future<void> _openInBrowser(Uri page) async {
  if (page.scheme != 'https' || !page.toString().startsWith('$releasesPage/')) return;
  try {
    await Process.start('explorer.exe', [page.toString()]);
  } on ProcessException {
    // Sem navegador: nada a fazer.
  }
}

/// Versão nova publicada, consultada uma vez ao abrir (o core limita a uma
/// consulta por dia e respeita a configuração). Falha = nenhum aviso.
final availableUpdateProvider = FutureProvider<ReleaseInfo?>((ref) async {
  try {
    return await ref.read(backendProvider).checkForUpdate(ref.read(currentVersionProvider));
  } on Object {
    return null;
  }
});

/// Faixa discreta no topo do conteúdo: "versão nova disponível", com
/// "Baixar" (abre a página da versão) e "Agora não". Nunca baixa nem instala.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(availableUpdateProvider).value;
    if (release == null || _dismissed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('update-banner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.system_update_alt, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Versão ${release.version} do FotoAtlas disponível. Seus dados continuam onde estão ao atualizar.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              key: const ValueKey('update-download'),
              onPressed: () => ref.read(releasePageOpenerProvider)(release.pageUrl),
              child: const Text('Baixar'),
            ),
            IconButton(
              key: const ValueKey('update-dismiss'),
              tooltip: 'Agora não',
              iconSize: 18,
              onPressed: () => setState(() => _dismissed = true),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

final _updateEnabledProvider = FutureProvider<bool>((ref) => ref.watch(backendProvider).updateCheckEnabled());

/// Configurações → "Atualizações".
class UpdateSettingsCard extends ConsumerWidget {
  const UpdateSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(_updateEnabledProvider).value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atualizações', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Ao abrir, no máximo uma vez por dia, o FotoAtlas pergunta ao GitHub (onde ele é publicado) qual é a '
              'versão mais nova. Nenhuma informação sua é enviada. Se houver versão nova, aparece um aviso com o botão '
              '"Baixar", que abre a página da versão no navegador: o FotoAtlas nunca baixa nem instala nada sozinho. '
              'Sem internet, nada acontece.',
            ),
            const SizedBox(height: 8),
            if (enabled == null)
              const LinearProgressIndicator()
            else
              SwitchListTile(
                key: const ValueKey('update-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Procurar versão nova ao abrir'),
                value: enabled,
                onChanged: (v) async {
                  await ref.read(backendProvider).setUpdateCheckEnabled(v);
                  ref.invalidate(_updateEnabledProvider);
                },
              ),
          ],
        ),
      ),
    );
  }
}
