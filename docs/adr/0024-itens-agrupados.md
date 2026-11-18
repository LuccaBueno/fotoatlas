# ADR 0024 — Itens agrupados: RAW+JPEG e Live Photos como um item só, só no catálogo

- **Status:** aceita
- **Data:** 2026-11-18

## Contexto
Item (b) da Fase 9 (spec §15: "Item lógico: RAW+JPEG, Live Photo"). Câmeras gravam a mesma foto em RAW e JPEG; o iPhone grava a Live Photo como uma foto (HEIC/JPG) e um vídeo curto (MOV). Na Biblioteca isso vira dois ou três quadrinhos para a mesma foto. Condições do usuário (2026-11-15): agrupar é **só visual, no catálogo**; copiar, comparar, reorganizar e verificar continuam tratando **cada arquivo físico**; ao copiar ou reorganizar um item agrupado, **todos os arquivos do grupo vão juntos e a prévia mostra isso**; dá para desagrupar.

## Decisão
- **Catálogo (schema v9, só acréscimos):** `media_items` (tipo `raw_jpeg`, `live_photo` ou `manual`; foto principal; origem `auto` ou `manual`; `split_at` quando o usuário desagrupa) e `media_item_members` (conteúdo e papel `photo`, `raw` ou `video`). Mais a coluna `media_metadata.content_identifier`. Nenhum arquivo é tocado; o grupo é por **conteúdo** (como a Biblioteca), então vale para todas as cópias idênticas.
- **Detecção automática** (depois da leitura dos metadados e no "Atualizar"; idempotente), sempre **na mesma pasta da mesma fonte** e com exatamente **uma foto** (JPEG/HEIC…) no conjunto:
  - **RAW+JPEG:** mesmo nome sem a extensão (`IMG_0001.JPG` + `IMG_0001.CR2`).
  - **Live Photo pelo identificador:** o mesmo `ContentIdentifier` da Apple na foto (`Apple:ContentIdentifier`) e no vídeo (`Keys:ContentIdentifier`), lido pelo ExifTool **só leitura** (mais um `-Tag` na lista de leitura; o teste de arquitetura continua impedindo opções de gravação). Vale mesmo com nomes diferentes.
  - **Live Photo pelo nome:** mesmo nome e um vídeo `.mov`/`.mp4` de **até 5 s** (duração já lida). Vídeo mais longo com o mesmo nome fica sozinho.
  - Um grupo automático pode **crescer** (RAW+JPEG que depois ganha o vídeo quando a duração é lida), mas nunca rouba arquivo de outro grupo. Um conjunto que o usuário desagrupou **não volta** sozinho.
- **Agrupar à mão** (2+ itens marcados → **Agrupar**): grupo `manual`; a primeira foto (não RAW, não vídeo) é a que aparece; os arquivos saem de outros grupos.
- **Biblioteca:** a grade, a contagem e as facetas de ano, câmera, "hora a confirmar" e "sem data" mostram o item uma vez, pela foto principal, com o selo **RAW+JPEG**, **Live** ou **Agrupado** (ícone + texto + explicação). A situação de backup do item é a **pior entre os arquivos** (um RAW sem backup não se esconde atrás de um JPEG com backup). Filtros **por arquivo** (tipo, extensão, situação de backup) mostram cada arquivo sozinho. Os detalhes listam os arquivos do item e têm **Desagrupar**.
- **Cópia:** escolher um arquivo de um item agrupado traz os outros (`CopyRequest.keepGroups`, padrão sim). Todos vão para a **pasta da foto principal** e, se um nome já existir no destino, ganham **o mesmo sufixo** (`IMG_0001_1.JPG` e `IMG_0001_1.CR2`). Cada arquivo continua com seu item no diário, cópia `.part`, conferência por SHA-256 e publicação sem substituir. O que o destino já tem não é copiado de novo. A prévia diz quantos arquivos vão junto e quantos não estavam marcados (`PlannedCopy.groupedWith`, `addedForGroup`). A **restauração** de um arquivo danificado leva só aquele arquivo.
- **Reorganização:** o RAW e o vídeo seguem a foto principal da mesma pasta, como os acompanhantes `.xmp`: mesma pasta nova e, com o mesmo nome base, o mesmo nome final (inclusive o sufixo de conflito). Se a foto principal fica (já no lugar ou sem data lida), o grupo todo fica. A prévia mostra quantos vão junto (`PlannedMove.groupOf`).
- **Comparação, cobertura e verificação de integridade:** sem mudança, por arquivo.
- **CLI:** `items detect | list | split ITEM | group ID ID…`.

## Alternativas descartadas
- **Agrupar só por horário de captura:** juntaria fotos diferentes da mesma rajada.
- **Gravar o vínculo nos arquivos (XMP):** contraria "analisar nunca modifica".
- **Grupo por arquivo (instância) em vez de conteúdo:** a mesma foto em dois discos viraria dois grupos e a Biblioteca, que é por conteúdo, não saberia qual mostrar.
- **Copiar só a foto escolhida:** separaria RAW e vídeo do JPEG no backup, o contrário do que o usuário pediu.
- **Verificar o grupo todo ao verificar um item:** o usuário pediu verificação por arquivo; a verificação por disco já lê todos.
