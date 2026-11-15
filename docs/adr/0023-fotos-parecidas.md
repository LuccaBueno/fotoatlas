# ADR 0023 — Fotos parecidas: impressão visual das miniaturas, só sugestões

- **Status:** aceita
- **Data:** 2026-11-15

## Contexto
Item (a) da Fase 9 (spec §9 e §15: "Duplicatas visuais … só sugestões com comparação lado a lado"). O usuário pediu: só sugestões, nunca ação automática, comparação lado a lado e nível de confiança. E reforçou (2026-11-15): **o app jamais altera a qualidade de uma foto**. Duplicatas exatas (mesmo SHA-256) já existem desde a Fase 2. Aqui entram fotos com **conteúdo diferente** que parecem a mesma: a mesma foto reduzida ou recomprimida (enviada por mensagem), mais clara (editada), com um pequeno corte, ou fotos em sequência.

## Decisão
- **Impressão visual**, calculada **a partir da miniatura em cache** (256 px, a mesma da Biblioteca). O arquivo de origem só é lido para gerar a miniatura, como já acontecia. Nenhuma imagem do usuário é gravada.
  - **pHash** de 64 bits (principal): grade 32×32 em tons de cinza (média por área), DCT 2D, as 8×8 frequências mais baixas sem o termo constante, bit = acima da mediana. Resiste a redução, recompressão e brilho.
  - **dHash** de 64 bits (confirmação do nível mais fraco): grade 9×8, bit = vizinho da direita mais claro.
  - **Imagem lisa** (desvio-padrão do brilho < 6 numa grade 16×16) é marcada `flat` e nunca vira sugestão (tudo preto pareceria igual).
- **Calibração** com cenas sintéticas (`tools\fixtures\lib\similar_fixtures.dart`; 80 cenas, distâncias no pHash): reduzida à metade e recomprimida com qualidade 25 ficaram em até 4; mais clara em até 6; rajada (formas 10 px deslocadas) entre 2 e 10; cortada 6% em cada borda entre 2 e 22. Entre 400 cenas diferentes, o mínimo foi 10, e nesses casos o dHash ficou em 20 ou mais. O dHash sozinho foi descartado como principal: nas áreas lisas os bits viram ruído (recompressão chegou a 24).
- **Níveis** (bits diferentes no pHash): **Quase idênticas** ≤ 4; **Muito parecidas** ≤ 8; **Talvez parecidas** ≤ 12 **e** dHash ≤ 18. Um "talvez" entre fotos com data confiável no mesmo dia sobe para "muito parecidas". Recortes grandes, rotação e espelhamento não são reconhecidos (limitação registrada no roteiro).
- **Busca sem comparar todas com todas:** multi-index hashing. Uma distância ≤ 12 garante que pelo menos uma das 4 partes de 16 bits tem distância ≤ 3; só os itens com essas partes são comparados, em tabelas de vetores (sem mapas). Medido sem AOT: 20 mil impressões em ~1,5 s e 50 mil em ~8 s, num isolate. Grupos pela união das ligações mais fortes primeiro; o nível do grupo é o da ligação mais fraca de que ele precisou; a referência da comparação é a foto com mais ligações fortes.
- **Unidade:** o conteúdo (como na Biblioteca): cópias idênticas já são uma só. Entram só fotos e RAW; vídeos ficam de fora.
- **Fila leve:** um lote de 24 por vez, que **cede a vez** a escaneamento, conferência, leitura de metadados, cópia, reorganização e verificação. Tenta de novo a cada 30 s e quando uma fonte conecta. **Nunca lê do celular** para isso: usa a miniatura só se já estiver em cache (`thumbnail(allowPhone: false)`), e essa falha não impede a Biblioteca de gerar a miniatura pelo celular depois. Pausável na tela.
- **Miniatura de último recurso:** quando o Shell do Windows e a miniatura do EXIF não servem (ex.: sem o helper), JPEG/PNG de até 40 MB são lidos em modo leitura e decodificados num isolate, e a miniatura vai **só para o cache**.
- **Decodificação:** pacote `image` 4.x (Dart puro, MIT; dependências `archive` e `posix`, MIT).
- **Catálogo (schema v8, só acréscimos):** `visual_hashes` (impressão por conteúdo, com a versão do algoritmo; mudar a versão recalcula tudo) e `visual_dismissals` (pares que o usuário marcou como "Não são parecidas"). Grupos não são gravados: são calculados na hora, num isolate.
- **Tela "Parecidas"** (novo destino da navegação): grupos com selo de confiança (ícone + texto + cor) e filtro "Só quase idênticas / Até muito parecidas / Todas, até 'talvez'" (padrão: até muito parecidas). **Comparar lado a lado:** miniatura grande, resolução, tamanho, data, câmera, quantidade de cópias, onde está cada uma e situação de backup. Ações: **Não são parecidas** (o grupo todo, com Desfazer), **Tirar do grupo** (uma foto, com Desfazer), **Copiar para…** (as fotos marcadas, pelo assistente de cópia segura, com prévia) e **Mostrar de novo as descartadas**. **Nenhuma ação apaga, move ou altera arquivo.**
- **CLI:** `similar run | groups [--level near|high|maybe] | dismiss ID ID… | restore`.

## Alternativas descartadas
- **Só dHash:** frágil em áreas lisas (ver calibração).
- **Modelos de IA:** fora do escopo deste ciclo (a IA local ficou para depois).
- **Decodificar o arquivo original:** HEIC/RAW exigiriam outros codecs e a leitura completa de cada foto; a miniatura já existe e é pequena.
- **Comparar todas com todas:** 100 mil fotos = 5 bilhões de pares.
- **Gravar os grupos:** mudariam a cada foto nova; calcular na hora é rápido e não deixa estado velho.
- **"Manter a melhor e descartar as outras":** contraria as regras 4 e 6 da spec e o pedido do usuário. O app só sugere; apagar continua fora do FotoAtlas.

## Consequências
- Testes: `packages\fotoatlas_core\test\similar\` (impressão e níveis com as variações sintéticas, cenas diferentes nunca sugeridas, imagem lisa, busca igual à força bruta, 20 mil impressões, serviço completo sem tocar nos arquivos, fila que cede a vez, pausa e retomada, celular nunca lido, "Não são parecidas"/"Tirar do grupo"/Desfazer só no catálogo, grupos exatos da demonstração); `test\catalog\migration_test.dart` (v7 → v8); `test\cli\cli_test.dart` (CLI similar); `test\architecture_test.dart` (o pacote `image` só em `thumbs/` e `similar/`; codificar imagem só no cache de miniaturas); `app\test\similar_test.dart` (tela, comparação, ações, Desfazer, fotos intactas).
- Na demonstração (`run-app.ps1 -DemoPersistente`, pasta "Fotos parecidas"): 3 grupos (praia: quase idênticas, 4 fotos; festa e viagem: muito parecidas, 2 cada); a tela preta e as fotos sozinhas não aparecem.
