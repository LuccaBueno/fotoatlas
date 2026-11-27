# 0027 — Limpar repetidos: mesmo conteúdo no mesmo dispositivo, só para a Lixeira

- Status: aceita (a migração v10 → v11, segunda exceção às migrações só aditivas, foi aprovada pelo usuário em 2026-11-27)
- Data: 2026-11-27

## Contexto
Pedido do usuário (Fase 9, item e): remover arquivos com conteúdo idêntico (mesmo SHA-256) guardados mais de uma vez no **mesmo** dispositivo. É a primeira função do FotoAtlas que tira um arquivo do usuário do lugar sem que ele continue em outro caminho do mesmo disco. A regra 4 ("nada é excluído automaticamente") continua valendo: nada sai sem a pessoa ver e confirmar. As condições do usuário:
- cada grupo aparece com todas as cópias lado a lado (miniatura grande, nome, caminho completo, pasta, data, tamanho, resolução), com "Abrir a foto" e "Mostrar na pasta";
- o app sugere qual cópia fica (regra configurável: pasta mais organizada/caminho mais curto, ou a mais antiga); a pessoa troca ou não mexe no grupo; por padrão **nenhum grupo vem marcado**;
- prévia com a lista, a quantidade e o espaço liberado, confirmação explícita e **reconferência do SHA-256** da cópia que fica e das que saem na hora; se algo mudou, o grupo é pulado e avisado;
- remoção **sempre para a Lixeira do Windows** (nunca definitiva), no diário e no histórico de Tarefas, com relatório CSV;
- nunca a última cópia de um conteúdo; nunca celular; nunca entre dispositivos diferentes.

## Decisão

### Grupos e sugestão (`dedupe/dedupe_service.dart`, só catálogo)
- Um grupo = arquivos de **uma fonte** (dispositivo ou pasta cadastrada) com o mesmo `content_id`, cada um com conteúdo conferido e ainda válido (`hash_status = 'done'`, tamanho e data iguais aos da conferência), presente, não "possivelmente corrompido", foto, RAW ou vídeo, tamanho > 0. Duas ou mais cópias. Fontes diferentes nunca se misturam (mesmo que estejam no mesmo disco físico).
- Regra "a da pasta mais organizada" (padrão): numa pasta de data (`2024`, `2024-07`, `2024-07-13 Praia`…), sem "(1)"/"cópia"/"copy" no nome, com menos pastas no caminho, com o caminho mais curto e, no empate, a primeira em ordem alfabética. Regra "a mais antiga": criada primeiro neste disco (`ctime`), depois a de modificação mais antiga. A regra fica em `settings` (`dedupe.keepRule`). Cada grupo traz a frase do porquê.

### Prévia e confirmação
- `preview(fonte, escolhas)` relê os grupos e devolve exatamente o que vai para a Lixeira (arquivo e a cópia que fica no lugar dele), quantos e o espaço. Escolha cujo grupo mudou desde a tela (cópia sumiu, ainda conferindo, "a que fica" não é do grupo) sai da prévia com o motivo.
- Bloqueado com o motivo: celular; pendrive e cartão de memória (no Windows eles não têm Lixeira); dispositivo desconectado; escaneamento em andamento nele; outra limpeza aberta no mesmo dispositivo; Lixeira indisponível (sem o helper).
- `start` confere de novo o bloqueio e que nenhuma "cópia que fica" está entre as que saem (uma prévia adulterada é recusada), e grava operação e itens numa transação: `operations.kind = 'dedupe_trash'`; um item por arquivo que sai, com `expected_sha256` (o conteúdo do grupo), `expected_size`, `expected_mtime` e `dst_rel_path_planned` = a cópia que fica.

### Execução, grupo por grupo
1. A cópia que fica: existe, o SHA-256 relido é o do grupo, e a identidade física (série do volume + índice do arquivo) é lida.
2. Cada cópia que sai: mesmo tamanho e data da prévia, SHA-256 relido igual e **outro arquivo físico** (o mesmo arquivo com outro nome — maiúsculas, link físico — não é uma cópia).
3. Qualquer diferença: **o grupo inteiro é pulado** (`failed`, "Grupo pulado: … Nada deste grupo foi para a Lixeira agora."), sem tocar em nada.
4. Para cada cópia que sai: confere que a que fica não mudou (tamanho e data), grava a intenção no diário (`pending → publishing`, com o SHA-256 e a data conferidos) e só então manda para a Lixeira; foi → `published` e o arquivo vira `missing` no catálogo, na mesma transação.

### A Lixeira (`safe_io/recycle_bin.dart` + helper `files.recycle`)
- O core não remove arquivo nenhum diretamente. A Lixeira de verdade é o `IFileOperation` do Shell no helper (`FOF_ALLOWUNDO | FOFX_RECYCLEONDELETE`, sem nenhuma janela), com um ouvinte (`IFileOperationProgressSink`) que **recusa** a remoção no `PreDeleteItem` quando o Windows avisa que apagaria de vez (sem `TSF_DELETE_RECYCLE_IF_POSSIBLE`: unidade sem Lixeira, rede, arquivo maior que a Lixeira, Lixeira desligada). Resposta `no_recycle_bin`; o arquivo fica. Só conta como feito se o Windows devolver o item criado na Lixeira.
- O helper confere de novo tamanho e data antes de chamar o Shell (`changed`). Pasta, atalho, caminho relativo ou com `..` são recusados.
- `no_recycle_bin` vale para o dispositivo inteiro: o resto da operação fica, com o motivo. Helper fora do ar: o arquivo volta para a fila e a operação pausa.
- Testes do helper usam a Lixeira real com arquivos sintéticos no temporário (e tiram de lá o que puseram) e uma unidade `subst` (sem Lixeira) para provar a recusa. Os testes do core e os de falha da CLI usam uma "Lixeira" de teste (`FolderRecycleBin`, `--test-recycle-dir`): move para uma pasta `fotoatlas_test*` no temporário, e recusa qualquer outra.

### Recuperação (ao abrir, idempotente)
Operação aberta vira pausada. Item em `publishing`, decidido pelo disco: o arquivo ainda está lá e igual → volta para a fila (será conferido de novo do zero, com a cópia que fica); não está mais lá → foi para a Lixeira (registrado); está lá mas diferente → fica, com o motivo. Testes matam a CLI em `dedupe.after_check`, `dedupe.after_publishing_commit`, `dedupe.after_recycle`, `dedupe.after_published_commit` e no meio da recuperação; a recuperação roda 3× sem efeito colateral e, em todo momento, HD + Lixeira têm exatamente o conteúdo de antes e cada cópia que fica continua no lugar.

### Schema v11 (segunda exceção às migrações só aditivas)
O CHECK de `operations.kind` ganha `'dedupe_trash'`. O SQLite não muda CHECK no lugar: a tabela `operations` é refeita com os mesmos dados (`TableMigration` do drift), na transação da migração, depois do backup `pre-migracao-v10-<data>.db`. Como `operation_items`, `operation_events`, `integrity_checks` e o próprio `undo_of` apontam para ela, o `alterTable` desliga as chaves estrangeiras só durante a troca; ao fim, `PRAGMA foreign_key_check` precisa vir vazio (senão a migração falha e nada muda) e as chaves voltam a valer ao abrir. O teste `v10 → v11` confere o histórico inteiro, as referências e o tipo novo.

### Tela e relatório
- Tela **Repetidos**: dispositivo, regra da sugestão, "Aceitar as sugestões de todos", "Desmarcar todos", "Todos os grupos" ou "Um grupo por vez" (com "Limpar este grupo e ir para o próximo" e "Não mexer e ir para o próximo"); rodapé fixo com o que sairia; "Revisar e enviar para a Lixeira…" abre a prévia, que só libera o botão depois de "Entendi". "Abrir a foto" e "Mostrar na pasta" chamam o Explorador (`explorer.exe` / `explorer.exe /select,`), só para ver.
- Tarefas: cartão da limpeza (pausar, continuar, cancelar o resto, tentar de novo os que ficaram, ver arquivo por arquivo com o motivo) e **Exportar relatório (CSV)**: grupo, situação, arquivo, cópia que ficou, tamanho, SHA-256 e motivo.

## Consequências
- O helper deixa de ser "nunca apaga": `files.recycle` é a única exceção, sempre para a Lixeira, com a recusa da remoção definitiva testada. O teste de arquitetura confere que o serviço só chama a Lixeira (uma vez, depois das reconferências e da intenção no diário) e que o helper não tem outra forma de apagar.
- Pequena janela entre a reconferência e o envio para a Lixeira: o helper confere tamanho e data imediatamente antes; um arquivo alterado nesse instante sem mudar tamanho nem data iria para a Lixeira, de onde dá para restaurar — e a cópia que fica foi conferida.
- Desfazer é pela Lixeira do Windows ("Restaurar"); o FotoAtlas não restaura sozinho. Depois de restaurar, o próximo escaneamento encontra o arquivo de novo.
- Pendrive e cartão de memória ficam de fora por padrão (sem Lixeira no Windows); um HD externo cuja Lixeira esteja desligada é recusado pelo helper.
- Catálogo v11: um catálogo aberto pela 1.3.0-beta.5 não abre nas betas anteriores (elas recusam catálogo mais novo, sem modificá-lo).
