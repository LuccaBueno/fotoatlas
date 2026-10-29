import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../l10n/strings.dart';
import '../widgets/backup_state.dart';
import 'providers.dart';

/// Ajuda curta de cada tela (botão "?"): o que é, o que dá para fazer e o
/// significado das cores e dos selos (spec §3.1).
class HelpTopic {
  const HelpTopic(this.title, this.what, this.canDo, {this.backupLegend = false, this.extraLegend = const []});
  final String title;
  final String what;
  final List<String> canDo;
  final bool backupLegend;

  /// (ícone, nome, explicação).
  final List<(IconData, String, String)> extraLegend;
}

/// Na ordem dos destinos da navegação lateral.
const helpTopics = [
  HelpTopic('Início', 'Um resumo do que tem e do que não tem backup em todos os seus dispositivos.', [
    'Ver quantas fotos e vídeos estão sem backup (só em 1 lugar).',
    'Acompanhar a conferência do conteúdo e o escaneamento.',
    'Ir direto para os dispositivos ou para a comparação.',
  ], backupLegend: true),
  HelpTopic(
    'Biblioteca',
    'Todas as suas fotos e vídeos juntos, na ordem em que foram tirados — de todos os dispositivos ao mesmo tempo. '
        'Conteúdo idêntico em vários lugares aparece uma vez só.',
    [
      'Trocar entre linha do tempo (por dia e momento), grade e lista.',
      'Filtrar por ano, dispositivo, câmera, tipo, situação de backup, horário do dia, momento e muito mais.',
      'Marcar vários itens (clique, Ctrl+clique, Shift+clique, Ctrl+A) e confirmar ou corrigir a hora.',
      'Dar nome a um momento, juntar ou separar momentos (clique com o botão direito no cabeçalho).',
      'Corrigir o relógio de uma câmera que estava com a hora errada (Mais ações).',
      'Clicar num item para ver onde ele está, quando foi tirado e por qual câmera.',
    ],
    backupLegend: true,
    extraLegend: [
      (Icons.help_outline, 'hora incerta', 'Não dá para ter certeza da hora (ex.: veio só da data do arquivo).'),
      (Icons.play_arrow, 'vídeo', 'Mostra a duração do vídeo.'),
      (Icons.collections_outlined, 'momento', 'Fotos tiradas perto umas das outras, agrupadas sozinhas.'),
      (Icons.push_pin_outlined, 'momento fixo', 'Você deu nome, juntou ou separou: fica assim nos recálculos.'),
    ],
  ),
  HelpTopic(
    'Dispositivos',
    'Os celulares, HDs, pendrives e pastas que o FotoAtlas conhece. Ele só lê: nada é apagado ou movido.',
    [
      'Adicionar um dispositivo (celular, unidade ou pasta).',
      'Escanear tudo ou só algumas pastas, pausar e retomar depois.',
      'Ver o que cada dispositivo tem e quanto disso tem backup.',
    ],
    backupLegend: true,
    extraLegend: [
      (Icons.link, 'Conectado', 'Dá para escanear e conferir agora.'),
      (Icons.link_off, 'Desconectado', 'O FotoAtlas lembra o último escaneamento; nada foi apagado.'),
    ],
  ),
  HelpTopic(
    'Comparar',
    'Responde "o lugar B tem tudo o que está no lugar A?", comparando o conteúdo (não o nome) de cada arquivo.',
    [
      'Montar A e B com pastas, dispositivos inteiros e momentos.',
      'Ver o que falta em B, o que só está em B e o que está nos dois.',
      'Salvar um escopo com nome para usar de novo.',
    ],
  ),
  HelpTopic('Tarefas', 'Cópias em andamento e o histórico de tudo o que o FotoAtlas gravou.', [
    'Acompanhar, pausar, continuar ou cancelar uma cópia (o que já foi copiado fica).',
    'Decidir o que fazer quando um nome já existe no destino.',
    'Tentar de novo os arquivos que não foram copiados e exportar o relatório.',
  ]),
  HelpTopic('Configurações', 'Ajustes do FotoAtlas. Nada aqui mexe nos seus arquivos.', [
    'Fazer backup do catálogo (o que o FotoAtlas sabe sobre seus arquivos).',
    'Escolher o intervalo dos momentos, o fuso e de onde tirar a data.',
    'Desfazer correções de relógio.',
  ]),
];

class HelpDialog extends ConsumerWidget {
  const HelpDialog({super.key, required this.topic});
  final HelpTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('help-dialog'),
      title: Text('Ajuda: ${topic.title}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic.what),
              const SizedBox(height: 12),
              Text('O que dá para fazer', style: theme.textTheme.titleSmall),
              for (final c in topic.canDo)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(c)),
                    ],
                  ),
                ),
              if (topic.backupLegend || topic.extraLegend.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Cores e selos', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
              ],
              if (topic.backupLegend)
                for (final s in const [
                  BackupState.single,
                  BackupState.verified,
                  BackupState.independent,
                  BackupState.probable,
                  BackupState.unknown,
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 240, child: BackupStateBadge(s)),
                        Expanded(child: Text(backupStateHint(s), style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
              for (final (icon, name, text) in topic.extraLegend)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 240,
                        child: Row(children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(name)]),
                      ),
                      Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('reopen-guide'),
          onPressed: () {
            Navigator.pop(context);
            showFirstRunGuide(context, ref);
          },
          child: const Text('Ver o guia de primeiros passos'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
      ],
    );
  }
}

class _Step {
  const _Step(this.icon, this.title, this.text, this.destination);
  final IconData icon;
  final String title;
  final String text;

  /// Destino da navegação ligado ao passo.
  final int destination;
}

const _steps = [
  _Step(
    Icons.add_circle_outline,
    '1. Adicione um dispositivo',
    'Em "Dispositivos", toque em "Adicionar dispositivo" e escolha o celular, o HD, o pendrive ou uma pasta. '
        'O FotoAtlas só lê: nada é apagado, movido ou alterado.',
    2,
  ),
  _Step(
    Icons.search,
    '2. Escaneie',
    'Toque em "Escanear" (tudo ou só algumas pastas). Depois, o FotoAtlas confere o conteúdo de cada arquivo '
        'sozinho, em segundo plano. Dá para pausar e continuar quando quiser.',
    2,
  ),
  _Step(
    Icons.error_outline,
    '3. Veja o que não tem backup',
    'No "Início" e na "Biblioteca", o selo vermelho "Sem backup (só em 1 lugar)" mostra o que se perde se aquele '
        'dispositivo falhar. Na Biblioteca, filtre por "Situação de backup".',
    0,
  ),
  _Step(
    Icons.compare_arrows,
    '4. Compare',
    'Em "Comparar", escolha o lugar A (ex.: o celular) e o lugar B (ex.: o HD de backup) para saber se B já tem '
        'tudo o que está em A — e a lista do que falta.',
    3,
  ),
];

/// Guia de primeiros passos (spec §3.3): pode ser pulado e reaberto pelo "?".
Future<void> showFirstRunGuide(BuildContext context, WidgetRef ref) async {
  // Lidos antes de esperar: quem chama pode ser um diálogo que já está fechando.
  final backend = ref.read(backendProvider);
  final navigation = ref.read(navigationIndexProvider.notifier);
  final navigator = Navigator.of(context);
  final destination = await showDialog<int>(
    context: navigator.context,
    barrierDismissible: false,
    builder: (_) => const _FirstRunGuide(),
  );
  await backend.setFirstRunGuideDone();
  if (destination != null) navigation.select(destination);
}

class _FirstRunGuide extends StatefulWidget {
  const _FirstRunGuide();

  @override
  State<_FirstRunGuide> createState() => _FirstRunGuideState();
}

class _FirstRunGuideState extends State<_FirstRunGuide> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_page];
    final last = _page == _steps.length - 1;
    return AlertDialog(
      key: const ValueKey('first-run-guide'),
      title: const Text('Bem-vindo ao FotoAtlas'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ele mostra onde estão suas fotos e vídeos e o que ainda não tem backup — sem mexer em nada.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(step.icon, size: 40, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(step.title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.text, key: ValueKey('guide-step-$_page')),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dá para rever este guia a qualquer momento pelo botão "?" no canto da tela.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('guide-skip'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Pular'),
        ),
        if (_page > 0) TextButton(onPressed: () => setState(() => _page--), child: const Text('Voltar')),
        FilledButton(
          key: const ValueKey('guide-next'),
          onPressed: () => last ? Navigator.pop(context, 2) : setState(() => _page++),
          child: Text(last ? 'Começar: adicionar dispositivo' : 'Avançar'),
        ),
      ],
    );
  }
}
