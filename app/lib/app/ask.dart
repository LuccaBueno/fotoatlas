import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/backup/phone_backup_wizard.dart';
import 'providers.dart';
import 'shell.dart';

/// Para onde a resposta leva.
enum AskAction {
  phoneBackup('Fazer backup do celular'),
  home('Abrir o Início'),
  library('Abrir a Biblioteca'),
  devices('Abrir Dispositivos'),
  compare('Abrir Comparar'),
  similar('Abrir Parecidas'),
  dedupe('Abrir Limpar repetidos'),
  tasks('Abrir Tarefas'),
  settings('Abrir Configurações'),
  promises('Ver o que o FotoAtlas faz (e o que nunca faz)');

  const AskAction(this.label);
  final String label;
}

/// Uma pergunta da base embutida (offline: nada sai do computador).
class AskAnswer {
  const AskAnswer(this.id, this.question, this.answer, this.keywords, this.action);
  final String id;
  final String question;
  final String answer;

  /// Outras palavras que as pessoas usam para perguntar isso.
  final List<String> keywords;
  final AskAction action;
}

const askAnswers = [
  AskAnswer(
    'backup-celular',
    'Como faço backup do celular?',
    'No Início, clique em "Fazer backup do celular". O assistente pede o celular e o HD, conhece o HD inteiro, lê o '
        'celular, compara pelo conteúdo e copia só o que ainda não está no HD, conferindo cada cópia. Dá para pausar e '
        'continuar depois. Nada é apagado do celular.',
    ['backup', 'celular', 'copiar', 'telefone', 'iphone', 'android', 'salvar', 'passar', 'fotos do celular'],
    AskAction.phoneBackup,
  ),
  AskAnswer(
    'apaga',
    'O app apaga alguma coisa?',
    'Não sozinho. Escanear, comparar e conferir só leem. Copiar nunca sobrescreve nada. A única remoção é "Limpar '
        'repetidos", que só manda cópias repetidas para a Lixeira do Windows depois de você ver a lista e confirmar — e '
        'sempre fica uma cópia. Nada é apagado do celular, e apagar o catálogo não apaga nenhuma foto.',
    ['apagar', 'excluir', 'deletar', 'remover', 'perder', 'seguro', 'lixeira', 'some', 'sumir'],
    AskAction.promises,
  ),
  AskAnswer(
    'copia-conferida',
    'O que é "cópia conferida"?',
    'É quando o FotoAtlas leu os dois arquivos inteiros e confirmou que o conteúdo é idêntico, byte a byte (pelo '
        'SHA-256). Nome igual não basta: só conta como cópia o que foi conferido. "Backup em outro disco" é melhor ainda: '
        'a cópia conferida está num disco físico diferente.',
    ['conferida', 'conferido', 'verificada', 'cópia', 'igual', 'idêntica', 'hash', 'sha'],
    AskAction.home,
  ),
  AskAnswer(
    'incompleto',
    'Por que meu resultado está incompleto?',
    'Porque ainda há arquivos cujo conteúdo não foi conferido (a conferência está rodando ou o dispositivo está '
        'desconectado) ou pastas que não puderam ser lidas. Enquanto isso o FotoAtlas nunca diz "100%". Conecte o '
        'dispositivo e espere a conferência terminar (ou use "Conferir agora" na Comparar).',
    ['incompleto', 'resultado', 'comparação', 'faltam conferir', '100%', 'conferindo', 'pendente'],
    AskAction.compare,
  ),
  AskAnswer(
    'desfazer-reorg',
    'Como desfazer uma reorganização?',
    'Em Tarefas, no cartão da reorganização, clique em "Desfazer". Os arquivos voltam para os lugares de antes, mesmo '
        'depois de fechar o app. Se um arquivo mudou desde então, ele só volta se você confirmar.',
    ['desfazer', 'reorganização', 'reorganizar', 'voltar', 'pastas', 'mover de volta'],
    AskAction.tasks,
  ),
  AskAnswer(
    'sem-backup',
    'Quais fotos estão sem backup?',
    'No Início e no cartão de cada dispositivo, clique no número "sem backup (só em 1 lugar)": a Biblioteca abre só '
        'com essas fotos e vídeos. Para guardar uma cópia, marque-as e use "Copiar para…".',
    ['sem backup', 'só em 1 lugar', 'uma cópia', 'faltam', 'proteger', 'risco'],
    AskAction.home,
  ),
  AskAnswer(
    'comparar',
    'Como sei se o HD tem tudo o que está no outro?',
    'Em Comparar, escolha o lado A (o que você quer garantir) e o lado B (onde deveria estar). O FotoAtlas compara pelo '
        'conteúdo — nomes e pastas não importam — e diz "Sim, 100%" ou quantos arquivos faltam, com a lista.',
    ['comparar', 'tem tudo', 'falta', 'diferença', 'hd', 'disco', 'dois'],
    AskAction.compare,
  ),
  AskAnswer(
    'repetidos',
    'Como liberar espaço com fotos repetidas?',
    'Em Limpar repetidos aparecem os arquivos com o mesmo conteúdo guardados mais de uma vez no mesmo dispositivo. Você '
        'escolhe qual cópia fica, vê a prévia e confirma; as outras vão para a Lixeira do Windows.',
    ['repetidas', 'repetidos', 'duplicadas', 'duplicatas', 'espaço', 'liberar', 'limpar', 'iguais'],
    AskAction.dedupe,
  ),
  AskAnswer(
    'parecidas',
    'E fotos parecidas, mas não iguais?',
    'Em Parecidas o FotoAtlas sugere fotos que parecem a mesma (outro tamanho, mais clara, em sequência). São só '
        'sugestões: nada é apagado nem alterado.',
    ['parecidas', 'semelhantes', 'whatsapp', 'redimensionada', 'rajada', 'quase iguais'],
    AskAction.similar,
  ),
  AskAnswer(
    'adicionar',
    'Como adiciono um HD, pendrive, pasta ou celular?',
    'Em Dispositivos, clique em "Adicionar dispositivo": aparecem os celulares e as unidades conectados e a opção '
        '"Escolher uma pasta…". Depois clique em "Escanear". Cadastrar só grava no catálogo.',
    ['adicionar', 'cadastrar', 'novo', 'pendrive', 'pasta', 'hd', 'cartão', 'conectar'],
    AskAction.devices,
  ),
  AskAnswer(
    'celular-nao-aparece',
    'O celular não aparece. O que faço?',
    'Conecte pelo cabo USB e desbloqueie a tela. No Android, escolha "Transferência de arquivos" na notificação do USB; '
        'no iPhone, toque em "Confiar neste computador". Depois abra Dispositivos › Adicionar dispositivo.',
    ['não aparece', 'celular', 'iphone', 'android', 'usb', 'bloqueado', 'confiar', 'permitir'],
    AskAction.devices,
  ),
  AskAnswer(
    'qualidade',
    'O FotoAtlas muda a qualidade das fotos?',
    'Nunca. Ele não recomprime, não redimensiona e não altera os pixels. No máximo, quando você pede, muda o nome ou a '
        'pasta. Datas corrigidas ficam só no catálogo; o arquivo continua igual.',
    ['qualidade', 'comprimir', 'resolução', 'alterar', 'editar', 'pixels', 'estragar'],
    AskAction.promises,
  ),
  AskAnswer(
    'internet',
    'O FotoAtlas manda minhas fotos para a internet?',
    'Não. Tudo funciona sem internet e nenhuma foto, nome de arquivo ou catálogo sai do computador. Só a consulta de '
        'versão nova e, se você ligar, o mapa online usam a internet — e nenhum dos dois envia suas fotos.',
    ['internet', 'nuvem', 'enviar', 'privacidade', 'online', 'dados', 'offline'],
    AskAction.promises,
  ),
  AskAnswer(
    'datas',
    'A data de uma foto está errada. Como corrijo?',
    'Na Biblioteca, abra a foto e use "Corrigir a hora", ou corrija o relógio de uma câmera inteira em Configurações › '
        'Datas. A correção fica só no catálogo: o arquivo não muda.',
    ['data', 'hora', 'errada', 'corrigir', 'relógio', 'fuso'],
    AskAction.library,
  ),
  AskAnswer(
    'organizar',
    'Como organizo as pastas de um HD?',
    'Em Dispositivos, no cartão do HD, clique em "Reorganizar…": escolha o modelo (por ano e mês, por momento…), veja a '
        'prévia "antes e depois" e confirme. Move dentro do mesmo disco, sem copiar, e dá para desfazer.',
    ['organizar', 'reorganizar', 'pastas', 'ordem', 'ano', 'mês', 'bagunça'],
    AskAction.devices,
  ),
  AskAnswer(
    'corrompido',
    'O que é "possivelmente corrompido"?',
    'O conteúdo de um arquivo mudou, mas a data de modificação não — sinal de dano no disco. Ele deixa de contar como '
        'cópia. Em Tarefas, "Ver e restaurar" mostra as outras cópias conferidas para restaurar (o danificado nunca é '
        'substituído).',
    ['corrompido', 'danificado', 'estragado', 'integridade', 'verificação', 'restaurar'],
    AskAction.tasks,
  ),
  AskAnswer(
    'pausar',
    'Posso fechar o app no meio de uma cópia?',
    'Pode. Tudo o que o FotoAtlas grava passa por um diário: ao abrir de novo, ele confere no disco o que já foi feito e '
        'continua de onde parou, sem perder nem duplicar nada. Em Tarefas dá para pausar e continuar.',
    ['fechar', 'pausar', 'interromper', 'desligar', 'continuar', 'meio', 'queda de energia'],
    AskAction.tasks,
  ),
  AskAnswer(
    'catalogo',
    'O que é o catálogo? Ele guarda minhas fotos?',
    'O catálogo é o que o FotoAtlas sabe sobre os seus arquivos (onde estão, datas, conferências). Ele não guarda as '
        'fotos: apagar ou reconstruir o catálogo nunca apaga nenhuma foto. Faça backup dele em Configurações.',
    ['catálogo', 'banco', 'guarda', 'onde fica', 'backup do catálogo'],
    AskAction.settings,
  ),
  AskAnswer(
    'google',
    'Como trago as fotos do Google Fotos?',
    'Baixe pelo Google Takeout, cadastre a pasta extraída (ou a pasta com os .zip) em Dispositivos e escaneie. As datas '
        'e os locais dos .json entram só no catálogo; para os .zip, use "Extrair zip do Google Takeout…" no cartão.',
    ['google', 'takeout', 'google fotos', 'json', 'zip'],
    AskAction.devices,
  ),
];

/// Tira acentos e deixa minúsculo ("Cópia" → "copia").
String normalizeAsk(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}

const _stopwords = {
  'a',
  'o',
  'as',
  'os',
  'de',
  'do',
  'da',
  'dos',
  'das',
  'e',
  'em',
  'no',
  'na',
  'nos',
  'nas',
  'um',
  'uma',
  'que',
  'como',
  'faco',
  'fazer',
  'eu',
  'meu',
  'minha',
  'meus',
  'minhas',
  'por',
  'para',
  'pra',
  'com',
  'se',
  'ao',
  'qual',
  'quais',
  'onde',
  'isso',
  'esta',
  'estao',
  'tem',
  'app',
  'fotoatlas',
  'alguma',
  'coisa',
  'posso',
  'ser',
};

List<String> _words(String s) =>
    normalizeAsk(s).split(RegExp('[^a-z0-9%]+')).where((w) => w.length > 1 && !_stopwords.contains(w)).toList();

/// As respostas que combinam com [query], da mais para a menos provável
/// (no máximo [limit]). Busca simples por palavras, sem internet.
List<AskAnswer> searchAnswers(String query, {int limit = 3}) {
  final words = _words(query);
  if (words.isEmpty) return const [];
  final scored = <(AskAnswer, int)>[];
  for (final a in askAnswers) {
    final question = _words(a.question).toSet();
    final keys = a.keywords.map(normalizeAsk).toList();
    final body = _words(a.answer).toSet();
    var score = 0;
    for (final w in words) {
      final stem = w.length > 4 ? w.substring(0, w.length - 1) : w;
      if (question.any((q) => q.startsWith(stem))) score += 3;
      if (keys.any((k) => k.split(' ').any((p) => p.startsWith(stem)))) score += 3;
      if (body.any((b) => b.startsWith(stem))) score += 1;
    }
    // Frase inteira de uma palavra-chave ("sem backup", "google fotos").
    final q = normalizeAsk(query);
    for (final k in keys) {
      if (k.contains(' ') && q.contains(k)) score += 4;
    }
    if (score > 0) scored.add((a, score));
  }
  scored.sort((x, y) => y.$2.compareTo(x.$2));
  return [for (final (a, _) in scored.take(limit)) a];
}

/// Leva à tela ou ação de [action] (fechando a ajuda antes).
void runAskAction(BuildContext context, WidgetRef ref, AskAction action) {
  // Tudo lido antes de fechar a ajuda (depois, este widget já saiu da tela).
  final navigator = Navigator.of(context);
  final host = navigator.context;
  final nav = ref.read(navigationIndexProvider.notifier);
  navigator.pop();
  switch (action) {
    case AskAction.phoneBackup:
      nav.select(0);
      showPhoneBackupWizard(host);
    case AskAction.promises:
      showPromises(host);
    case AskAction.home:
      nav.select(0);
    case AskAction.library:
      nav.select(libraryDestination);
    case AskAction.devices:
      nav.select(devicesDestination);
    case AskAction.compare:
      nav.select(compareDestination);
    case AskAction.similar:
      nav.select(similarDestination);
    case AskAction.dedupe:
      nav.select(dedupeDestination);
    case AskAction.tasks:
      nav.select(tasksDestination);
    case AskAction.settings:
      nav.select(settingsDestination);
  }
}

/// "Pergunte ao FotoAtlas": campo de busca no "?" de cada tela.
class AskPanel extends ConsumerStatefulWidget {
  const AskPanel({super.key});

  @override
  ConsumerState<AskPanel> createState() => _AskPanelState();
}

class _AskPanelState extends ConsumerState<AskPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = searchAnswers(_query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pergunte ao FotoAtlas', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        TextField(
          key: const ValueKey('ask-field'),
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Ex.: como faço backup do celular?',
            helperText: 'As respostas vêm do próprio app, sem internet.',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        if (_query.trim().isNotEmpty && results.isEmpty)
          const Padding(
            key: ValueKey('ask-none'),
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Não encontrei uma resposta para isso. Tente outras palavras (por exemplo: backup, apagar, repetidas, '
              'comparar, desfazer).',
            ),
          ),
        for (final a in results)
          Card(
            key: ValueKey('ask-${a.id}'),
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.question, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(a.answer),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      key: ValueKey('ask-go-${a.id}'),
                      onPressed: () => runAskAction(context, ref, a.action),
                      child: Text(a.action.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// O que o FotoAtlas faz (e o que nunca faz) — as regras da spec §2, em
/// palavras simples.
const promisesDoes = [
  'Mostra o que você tem em cada celular, HD, pendrive e pasta, e o que já tem backup.',
  'Compara dispositivos pelo conteúdo: a mesma foto com outro nome ou em outra pasta conta como cópia.',
  'Copia o que falta, conferindo cada cópia byte a byte antes de ela aparecer no destino.',
  'Organiza as pastas de um disco quando você pede, com prévia e Desfazer.',
  'Sugere fotos repetidas e parecidas; as repetidas só saem para a Lixeira se você confirmar.',
  'Verifica de tempos em tempos se algum arquivo se danificou, só lendo.',
  'Funciona sem internet.',
];

const promisesNever = [
  'Nunca apaga nada sozinho, e nunca apaga nada do celular.',
  'Nunca sobrescreve um arquivo que já existe.',
  'Nunca move arquivos de um dispositivo para outro: copiar é copiar, o original fica.',
  'Nunca muda a qualidade de uma foto (não recomprime nem redimensiona).',
  'Nunca grava nada sem mostrar uma prévia e pedir sua confirmação.',
  'Nunca trata um dispositivo desconectado, ou um arquivo que não pôde ser lido, como "apagado".',
  'Nunca diz "cópia conferida" sem ter lido os dois arquivos inteiros.',
  'Nunca envia suas fotos, nomes de arquivos ou o catálogo para a internet.',
];

Future<void> showPromises(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final theme = Theme.of(context);
    Widget item(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return AlertDialog(
      key: const ValueKey('promises'),
      title: const Text('O que o FotoAtlas faz (e o que nunca faz)'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O que ele faz', style: theme.textTheme.titleSmall),
              for (final t in promisesDoes) item(Icons.check_circle_outline, theme.colorScheme.primary, t),
              const SizedBox(height: 16),
              Text('O que ele nunca faz', style: theme.textTheme.titleSmall),
              for (final t in promisesNever) item(Icons.block, theme.colorScheme.error, t),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    );
  },
);
