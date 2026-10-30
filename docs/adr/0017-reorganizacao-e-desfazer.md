# 0017 — Reorganização no mesmo disco, Desfazer e pastas vazias

- Status: aceita
- Data: 2026-10-30

## Contexto
A Fase 6 (spec §12 e §16) é a primeira que **move** arquivos do usuário. Antes de começar, o usuário definiu três cuidados:
1. pastas que ficam vazias nunca são apagadas automaticamente; no máximo uma ação separada, "Remover pastas vazias", que lista cada pasta, pede confirmação e só remove pastas realmente vazias (sem arquivos ocultos);
2. reorganizar só move dentro do mesmo disco; entre discos, a cópia conferida (Fase 5), com a origem intacta; celular nunca é reorganizado;
3. o Desfazer funciona depois de fechar e abrir o app e avisa com clareza se um arquivo mudou desde a reorganização; esse arquivo só volta se a pessoa confirmar.

## Decisão

### Escopo e modelo
- Uma reorganização age sobre **uma fonte** (disco ou pasta cadastrada), opcionalmente só numa pasta dela, e monta a estrutura nova dentro da mesma fonte. Fonte desconectada, celular, escaneamento em andamento ou nunca escaneada: a prévia vem bloqueada com o motivo.
- Entram fotos, RAW e vídeos com conteúdo conferido e data lida (o resto fica onde está e é contado na prévia). Acompanhantes `.xmp`/`.aae`/`.thm` com o mesmo nome (`IMG_1.xmp` ou `IMG_1.JPG.xmp`, na mesma pasta) seguem o nome final da foto.
- Modelos (`ops/names.dart`): `{ano}`, `{mes}`, `{dia}`, `{hora}`, `{minuto}`, `{segundo}` (hora efetiva do catálogo, já com as correções de relógio — spec §8.2), `{momento}`, `{tipo}`, `{dispositivo}`, `{original}`. Com `{momento}`: nome do momento; momento sem nome = início (`14h03`, dando `2024-07-13 14h03`); **os campos de data vêm do início do momento** (um momento que atravessa a meia-noite fica numa pasta só); item fora de momentos (hora a confirmar) ou sem data vai para a pasta configurável (`Sem data confirmada`). Tudo passa por `sanitizeName` (caracteres proibidos, nomes reservados, ponto/espaço no fim, comprimento). A cópia (Fase 5) usa os mesmos modelos.
- Prévia em árvore: "antes" (de onde saem, com "fica vazia — não é apagada") e "depois" (pasta nova, nomes ajustados). Nome ocupado — no disco ou no catálogo, inclusive por um arquivo que também vai sair (conservador) — ganha `_1`, `_2`… ou espera a decisão (política "perguntar"). Comparação de caminhos sem diferenciar maiúsculas; mudança só de maiúsculas conta como "já está no lugar".

### Protocolo por arquivo (`ops/reorg_service.dart`)
Reaproveita o diário da Fase 5 (`operations.kind = 'reorganize_move'`, mesmos estados): `pending → publishing → published`.
1. Confere no disco que o arquivo ainda é o do catálogo (tamanho e data de modificação). Mudou ou sumiu: `failed` (`source_changed`/`source_missing`), sem mover e sem marcar como apagado (regra 10).
2. Nome final e a data conferida (`expected_mtime`, coluna nova da v5) vão para o diário **antes** do move.
3. `MoveFileExW(MOVEFILE_WRITE_THROUGH)`: sem `REPLACE_EXISTING` (nunca sobrescreve) e **sem `COPY_ALLOWED`** — se o destino estiver em outro volume, o Windows recusa (`ERROR_NOT_SAME_DEVICE`) em vez de copiar e apagar. O teste de arquitetura confere as duas flags.
4. `published` e a atualização da `file_instance` (mesmo id, caminho novo; o conteúdo conferido continua valendo) numa transação.

Recuperação (ao abrir e antes de continuar), decidida pelo disco, para itens em `publishing`: só a origem é o arquivo esperado → volta para `pending`; só o destino é → registra como movido; outra combinação → `needs_attention` ("não foi possível confirmar onde está"). Operação `running` vira `paused`. Rodar de novo não muda nada. Testes matam a CLI em `move.after_publishing_commit`, `move.after_move`, `move.after_published_commit` (na reorganização e no Desfazer) e no meio da própria recuperação; a recuperação roda 3× sem efeito colateral.

### Desfazer
- É uma **operação nova** no diário (`kind = 'undo'`, `undo_of` = a reorganização), com um item por arquivo movido, em ordem inversa; cada item aponta o original (`undo_of_item_id`, coluna nova da v5). Tudo vem do diário: funciona depois de fechar e abrir o app.
- Antes de confirmar, a prévia do Desfazer (`undoPreview`) diz quantos voltam, quais **mudaram** desde a reorganização (tamanho ou data diferente de `expected_mtime`), quais sumiram e quais lugares antigos estão ocupados.
- Arquivo que mudou: `needs_attention` (`changed_since_reorg`); só volta com "Devolver mesmo assim". Lugar antigo ocupado: `needs_attention` (`name_conflict`); "Mover com outro nome" ou "Deixar onde está" — nunca sobrescreve. Arquivo que sumiu: `failed`, "nada a devolver".
- Ao devolver um arquivo, o item original vira `undone` na mesma transação. Reorganização ainda aberta é cancelada (o que não foi movido não é mais movido) antes de desfazer.

### Pastas vazias
- Nada apaga pasta durante a reorganização nem no Desfazer. As pastas de onde os arquivos saíram (e, depois do Desfazer, as que a reorganização criou) **ficam**.
- "Remover pastas vazias…" (Tarefas) lista, pasta por pasta, as candidatas da operação (pastas dos caminhos de origem e destino dos arquivos movidos, e as subpastas vazias delas). Vazia = sem nenhum arquivo, nem oculto nem de sistema, em lugar nenhum dentro dela; junção (reparse point) não conta. Pastas só com ocultos (ex.: `Thumbs.db`) aparecem à parte e não podem ser escolhidas.
- Só as pastas marcadas e confirmadas saem, da mais funda para a mais rasa. `safe_io/empty_dir.dart` confere de novo, na hora, que a pasta não tem **nada** dentro e só então chama `RemoveDirectoryW` — que o próprio Windows recusa em pasta com qualquer coisa. Cada remoção (e cada recusa) vira evento no diário da operação.

### Disco principal
Configuração `library.primarySourceId` (tabela `settings`): o disco marcado em Dispositivos é o destino sugerido quando a cópia não tem outro (ex.: Biblioteca, "Copiar para outro disco…" da reorganização).

## Consequências
- Schema v5, só aditivo: `operation_items.expected_mtime` e `operation_items.undo_of_item_id`. Os `kind` e o estado `undone` já existiam desde a v1.
- Arquivos que não estão no catálogo (criados depois do último escaneamento) não são movidos; a prévia pede escaneamento antes.
- Conservador com nomes: um arquivo cujo nome-alvo pertence a outro que também vai sair ganha `_1`, mesmo que o nome fique livre depois. Preferimos previsibilidade (a prévia é exatamente o que acontece) a otimizar trocas.
- Um escaneamento rodando ao mesmo tempo pode inserir uma linha no caminho novo; a atualização do catálogo usa `UPDATE OR IGNORE` e o próximo escaneamento acerta (nada se perde).
