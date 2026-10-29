# 0013 — Encerramento com prazo: fechar o app sempre funciona

- Status: aceita
- Data: 2026-10-29

## Contexto
No teste do usuário (app com `-Demo`, celular real conectado, depois de escanear), clicar no X deixava o botão vermelho e a janela não fechava. O handler `onExitRequested` esperava `core.close()`, que esperava sem prazo por várias coisas:

1. **Causa confirmada:** `await controller.close()` dos streams de progresso (scan, fila de hash, fontes, helper). No Dart, `close()` de um `StreamController` com um ouvinte **pausado** nunca termina — e o Riverpod 3 pausa as assinaturas das telas que não estão visíveis. Bastava estar numa tela que não mostra a fila de hash para o app nunca fechar. Reproduzido em teste (o encerramento esperava o prazo estourar) e num script isolado.
2. Esperas de até 10 s **por worker** (hash e scan, em sequência), mais o backup do catálogo e o `close()` do catálogo sem prazo.
3. Uma leitura WPD presa no helper (arquivo grande pelo USB) só obedecia ao `system.shutdown` depois de terminar.

Depois da primeira correção, a CI mostrou mais dois pontos:

4. O `db.close()` do drift **também** espera os streams de consultas reativas (`watch()`) fecharem — de novo, com ouvinte pausado pelo Riverpod, nunca termina. Reproduzido no core com um `watch()` pausado (5 s, até o prazo estourar).
5. O `shutdownAll()` do drift responde **antes** de o isolate do banco fechar o arquivo do SQLite: reabrir o catálogo logo em seguida, no mesmo processo, deu "database is locked" na CI.

## Decisão
- Nenhum `close()` de stream é aguardado no encerramento (`unawaited`), e emitir num stream fechado é ignorado.
- `Catalog.close()` não espera o `db.close()` (pelo item 4): pede o `shutdownAll()` e espera o **isolate do banco sair**, o que só acontece depois de ele fechar o SQLite (item 5). O catálogo tem prazo próprio de 5 s e a trava de processo único só é liberada se ele fechou de fato.
- `FotoAtlasCore.close()` roda etapas com **prazo** (3 s cada por padrão) e relata o que falta (`ShutdownStep`): pausar scans e fila de conferência (em paralelo) → esperar o backup do catálogo → encerrar o helper → fechar o catálogo → soltar a trava. Prazo estourado ou erro numa etapa: segue para a próxima. Chamar `close()` de novo devolve o mesmo encerramento.
- Helper: `system.shutdown` com prazo de 1 s; se o processo não sair em mais 1 s, é **finalizado** (`kill`); pedidos em voo falham como `helper_closed` (tratado como "dispositivo indisponível", nunca como ausência).
- App: ao pedir para fechar, mostra **"Encerrando com segurança…"** com as etapas (✓ quando concluídas) e bloqueia cliques; depois de no máximo 12 s sai de qualquer jeito. Clicar no X de novo não recomeça.

## Por que é seguro sair sem esperar tudo
Tudo que é gravação já é transacional e recuperável (regra 7): scan que não parou a tempo fica `running` e vira `interrupted` ao abrir (retoma das pastas pendentes, sem confirmar ausências); arquivo cuja conferência não terminou continua `pending`; um backup do catálogo pela metade é um `.tmp` nunca publicado, apagado numa rotação seguinte; o SQLite (WAL + `synchronous=FULL`) não perde transações confirmadas. A trava de processo único é liberada pelo Windows quando o processo sai.

## Consequências
- Fechar leva poucos segundos no pior caso e quase nada no caso comum.
- Testes: core (ouvintes pausados com prazo padrão — falha com o código antigo; celular travado no scan e na conferência → fecha e retoma exato; scan e hash em isolates; helper falso que trava no shutdown é finalizado) e app (fechar com a conferência travada mostra o que falta e sai).
- Fase 5 (cópia segura): o diário de operações precisa entrar no mesmo encerramento com prazo; uma cópia interrompida é retomada pela recuperação idempotente, nunca esperada indefinidamente.

## Atualização (2026-10-29) — exceção solta do helper e pergunta antes de fechar

**Achado no teste com celular real:** o encerramento funcionava, mas o terminal mostrava `Unhandled Exception: HelperException(helper_crashed): O helper encerrou inesperadamente.` Causa: `HelperClient.call()` registrava o pedido como pendente **antes** de escrevê-lo no stdin do helper. Durante o encerramento o stdin já está fechado; a escrita falhava ("StreamSink is closed"), o `call()` lançava outro erro e o pedido ficava pendente **sem ninguém esperando**. Quando o helper era finalizado, esse pedido órfão recebia `helper_crashed` e virava exceção não tratada. O pedido tardio vem da própria conferência: ao fechar a sessão WPD, a leitura presa falha com `not_found` e o core tenta achar o arquivo de novo pelo caminho. Reproduzido em teste com o `HelperClient` real e um helper falso que faz o mesmo (falha com a mensagem exata antes da correção).

**Decisão:**
- `call()` escreve antes de registrar; se a escrita falhar, devolve `helper_unavailable` (tratado). Com o encerramento em andamento, nenhum pedido novo vai para o helper (`helper_closed`). Erros assíncronos do stdin são ignorados (a saída do processo já é tratada).
- Fora do encerramento, a queda do helper segue tratada: pedidos em voo falham como "dispositivo indisponível", o scan fica `interrupted` (retoma em "Retomar"), a conferência deixa o arquivo `pending` (sem erro) e recomeça sozinha quando o celular reaparece, o helper reinicia e a interface avisa (`FotoAtlasCore.helperStatus` → aviso "A leitura de dispositivos parou inesperadamente…").
- **Conferência do celular grava cada arquivo na hora** (antes: em lotes de 32). Pelo USB um arquivo pode levar minutos; fechar (ou o aparelho sair) no meio do lote refazia tudo o que já tinha sido lido. Teste: lê 3, fecha, reabre → os 3 continuam conferidos e só o resto é lido; confirmado também com o helper real (celular simulado com leitura lenta).
- **Pergunta antes de fechar:** com tarefas em andamento (`FotoAtlasCore.runningTasks()`: escaneamentos, conferência, backup do catálogo; cópias na Fase 5), o X mostra "Há tarefas em andamento: …" com o progresso, e "Continuar trabalhando" (padrão: foco, Esc, clique fora) ou "Fechar mesmo assim". Sem tarefas, fecha direto. Depois de confirmar, segue o "Encerrando com segurança…".
