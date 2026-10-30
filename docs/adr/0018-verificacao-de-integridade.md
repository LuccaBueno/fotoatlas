# 0018 — Verificação periódica de integridade

- Status: aceita
- Data: 2026-10-30

## Contexto
A Fase 7 (spec §14 e §16) relê os arquivos de tempos em tempos para descobrir se algo se estragou no disco. Antes de começar, o usuário definiu os limites:
1. a verificação **não pode modificar nenhum arquivo**: só ler, comparar e relatar;
2. restaurar a partir de outra cópia conferida **só pela cópia segura da Fase 5**, com prévia e confirmação;
3. a verificação agendada deve ser **leve** (pausável, sem pesar no uso do PC) e **nunca rodar em celular** sem o usuário pedir.

## Decisão

### Leitura e classificação (`integrity/integrity_engine.dart`)
- Os arquivos são lidos pelo mesmo leitor da conferência (`hash/hash_engine.dart` → `safe_io/source_reader.dart`, `GENERIC_READ` + `OPEN_EXISTING` + `FILE_FLAG_OPEN_NO_RECALL`), em modo `observeOnly` (não exige que tamanho e data sejam os do catálogo: o objetivo é observar a mudança). Celular: `devices.hashObject` do helper (WPD só leitura, ADR 0012). Placeholder de nuvem não é lido (não dispara download).
- Classificação (`classifyCheck`, conforme a análise C7):
  - mesmo conteúdo → **inalterado** (se só a data mudou, o catálogo acompanha a data nova);
  - conteúdo e data diferentes → **alterado** (editado): o arquivo passa a valer pelo conteúdo novo, já conferido nesta leitura;
  - conteúdo diferente com a **mesma data** — ou exatamente ±1 h num disco FAT (horário de verão) — → **possivelmente corrompido**, também quando o tamanho mudou.
  - Não encontrado no caminho → "não está mais no lugar"; erro de leitura, mudança durante a leitura ou só na nuvem → "não deu para ler agora". Nenhum dos dois marca o arquivo como ausente (regras 9 e 10). Fonte que sai no meio → a rodada espera, sem registrar nada.
- **Possivelmente corrompido** no catálogo: `integrity = 'possibly_corrupt'`, `content_id = NULL`, `hash_status = 'error'` com o motivo. Assim o arquivo **deixa de contar como cópia** na cobertura, na comparação ("Resultado incompleto") e no planejador da cópia (que não o escolhe como origem nem considera o conteúdo "já no destino"). O conteúdo esperado fica em `integrity_checks.expected_content_id` (v6).
- O conteúdo danificado nunca é "aceito" sem o usuário: `hash retry`/"Conferir de novo" ignora esses arquivos, e o escaneamento mantém o estado enquanto a data não mudar (se a data mudar, o arquivo foi gravado de novo e volta a ser um arquivo comum). "A mudança é esperada…" (`acceptAsIs`) devolve o arquivo para a conferência — só catálogo.
- Cada arquivo é registrado numa transação (resultado + `integrity_checks`), com guarda: só vale se a linha ainda for a que foi lida (scan ou cópia no meio vencem; o arquivo é lido de novo).

### Rodadas (`integrity/integrity_service.dart`)
- Uma rodada (`integrity_runs`, v6) fixa a lista de arquivos ao começar (`integrity_run_items`); verificado = tem `integrity_checks` com o mesmo `run_id`. Matar o processo perde no máximo o arquivo em andamento; ao abrir, a rodada `running` vira "interrompida" e continua de onde parou, sem repetir arquivos (teste com a CLI morta em `verify.after_file_commit`).
- Uma rodada por vez. Pausar, continuar e cancelar a qualquer momento; "Pausar" logo depois de "Verificar" também vale (o estado da rodada ativa nasce antes de qualquer `await`). A do usuário passa na frente de uma periódica; duas do usuário fazem fila.
- O que entra: arquivos presentes com o conteúdo já conferido. Pela fonte (cartão em Dispositivos), por pasta (CLI) ou pelos itens marcados na Biblioteca (todas as cópias nos discos conectados). **Celular só entra quando o usuário escolhe aquele celular**; pela Biblioteca, nunca.
- Em isolate próprio para discos; celular no isolate principal (o helper é que lê), como na conferência.

### Verificação periódica
- Configuração `integrity.schedule` (`settings`): ligada por padrão, a cada 90 dias (30/90/180/365 nas Configurações). O app liga o agendador (`scheduleIntegrity`); a cada 10 min (o primeiro passo 2 min depois de abrir) ele:
  1. não faz nada se houver outra tarefa pesada (escaneamento, conferência, leitura de metadados, cópia, reorganização) ou uma verificação rodando;
  2. continua uma periódica que estava esperando (nunca uma do usuário, que espera "Continuar");
  3. senão, começa uma rodada com o que não é conferido há mais do que o intervalo (`COALESCE(last_verified_at, hashed_at)`), **só nos discos conectados**.
- **Leve**: lê a ~24 MB/s (`lightBytesPerSecond`, pausa entre blocos de 1 MB), uma fração do que um HD USB entrega, e **cede a vez**: se outra tarefa pesada começar, a rodada pausa sozinha em até 1 s ("Esperando outras tarefas terminarem") e continua no próximo passo. Fechar o app no meio é seguro (o encerramento tem prazo, ADR 0013).
- **Celulares nunca** entram na periódica (rodada marcada com celular não é continuada pelo agendador).
- Não usamos prioridade de E/S do Windows (`THREAD_MODE_BACKGROUND_BEGIN`): o isolate do Dart não fica preso a uma thread do sistema, então a prioridade não seria confiável. O limite de vazão e a pausa automática são determinísticos e testáveis.

### Restaurar
- `restoreRequest` monta um **pedido de cópia segura** (Fase 5): conteúdo esperado → mesma fonte e **mesma pasta** do arquivo danificado, origem preferida = a cópia escolhida, com o **nome do arquivo danificado** (`CopyRequest.fileNames`, novo). Como o nome está ocupado pelo danificado, a cópia vira `foto_1.jpg`: **o danificado nunca é substituído nem apagado**; o usuário decide depois.
- O app mostra a prévia da cópia segura (onde vai gravar, espaço) e só grava com "Restaurar (cópia conferida)". A cópia segura confere a origem com o conteúdo do catálogo antes de publicar: se a "cópia boa" também se estragou, a restauração falha sem gravar nada no destino.
- Celular não é destino (a cópia segura recusa); arquivo danificado no celular só pode ser copiado de outra cópia para um disco.

### Interface
- Tarefas: "Possivelmente corrompidos" (cada arquivo com as outras cópias conferidas — dispositivo, caminho, conectado, mesmo disco, quando foi conferida — e "Restaurar desta cópia…") e "Verificações de integridade" (progresso, "lendo devagar", pausar/continuar/cancelar, "Ver arquivos").
- Dispositivos › Mais opções › "Verificar integridade…" (com "Tudo" ou "Só o que não é conferido há mais de N dias"; no celular, aviso de leitura lenta). Biblioteca: "Verificar…" para os itens marcados.
- Início: aviso de arquivos possivelmente corrompidos e de discos não verificados há mais do que o intervalo ("Verificar agora").
- Configurações: "Verificação periódica" (ligar/desligar, intervalo).

### Schema v6 (aditivo)
`integrity_runs`, `integrity_run_items`; em `integrity_checks`: `run_id`, `expected_content_id`, `reason`; índice `ix_ic_run`. Migração testada a partir dos snapshots v1–v5, com backup antes.

## Consequências
- O teste de arquitetura garante que `lib/src/integrity/` não usa nenhuma API de gravação nem de cópia e lê pelo leitor da conferência.
- Um arquivo legitimamente regravado por um programa que preserva a data de modificação aparece como "possivelmente corrompido" (falso positivo). É o limite da regra da spec; "A mudança é esperada…" resolve sem tocar no arquivo.
- A verificação leve de um disco grande leva horas (1 TB ≈ 12 h a 24 MB/s) e só anda com o app aberto; como cede a vez e continua de onde parou, isso é aceitável. Verificações pedidas pelo usuário rodam sem limite de vazão.
