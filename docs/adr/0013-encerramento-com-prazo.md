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
