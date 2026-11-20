# ADR 0025 — Google Takeout: `.json` só no catálogo; zip extraído pela cópia segura

- **Status:** aceita (a exceção da migração foi aprovada pelo usuário em 2026-11-18)
- **Data:** 2026-11-18

## Contexto
Item (c) da Fase 9 (spec §15: "Importação do Google Takeout (sidecars `.json`)"). O Takeout do Google Fotos entrega as fotos e, ao lado de cada uma, um `.json` com a data (`photoTakenTime`, em UTC) e o local (`geoData`). Muitas fotos baixadas assim perderam o EXIF. Condições do usuário (2026-11-15): **só leitura da pasta ou do zip** do Takeout; datas e locais dos `.json` **só no catálogo**, nunca gravados nos arquivos; arquivo **sem `.json` correspondente aparece como "hora a confirmar"**.

## Decisão
- **Takeout em pasta:** os `.json` já são catalogados pelo escaneamento (como qualquer arquivo). A fila de metadados lê, **só leitura**, os `.json` novos ou mudados (até 2 MB; os de álbum, sem `photoTakenTime`, ficam de fora) e guarda o que interessa na tabela nova `takeout_json` (schema v10): título, instante e local. Relê se o tamanho ou a data do `.json` mudar. Celulares ficam de fora.
- **Casamento** (por pasta, `takeout/takeout_match.dart`): `IMG_1.JPG.json`, `IMG_1.JPG.supplemental-metadata.json`, nomes cortados em 46 caracteres antes de `.json` (inclusive o sufixo cortado, como `supplemental-me`), duplicatas `IMG_1(1).JPG` ↔ `IMG_1.JPG(1).json`, editadas (`-editado`, `-edited`, `-bearbeitet`…) usam o `.json` da original, e por último o `title` de dentro do `.json`, quando só um tem aquele título.
- **Datas:** origem nova **"Google Fotos"** (`DateSource.takeout`), com o instante em UTC e confiança **média** (o Google às vezes usa a data do envio). Na ordem padrão fica depois do EXIF e do vídeo e antes do nome do arquivo; uma ordem salva antes ganha a origem nova logo depois do vídeo. O local do `.json` só entra quando o arquivo não tem local próprio.
- **Sem `.json`:** uma foto ou vídeo numa **pasta que tem `.json` do Takeout**, mas sem o seu, recebe a marca `DateCandidate.takeoutMissing()` (sem data). A data continua vindo do EXIF/nome/arquivo, mas a confiança fica **baixa** ("hora a confirmar"), como pediu o usuário. A marca fica nas candidatas guardadas, então sobrevive a recálculos.
- **`.json` que chega depois** (outra parte do Takeout): as candidatas das fotos da pasta são refeitas pelas guardadas, **sem ler as fotos de novo** e sem perder câmera e outros dados.
- **Takeout em zip:** catalogar o conteúdo de dentro do zip mudaria o escaneamento, a conferência, as miniaturas, a comparação, a cópia e a verificação. Em vez disso, **"Extrair zip do Google Takeout…"** (no cartão do dispositivo que tem os `takeout-….zip`): prévia (lê só o índice dos zips; quantas fotos, vídeos e `.json`, tamanho, espaço, nomes que ganham `_1`), confirmação e extração pela **cópia segura** de sempre: um item do diário por arquivo (`src_rel_path` = `zip:entrada`; `:` não existe em nomes do Windows), `.part` com `CREATE_NEW`, **CRC-32 do zip e SHA-256** calculados no caminho, releitura do `.part`, publicação sem substituir e recuperação idempotente. O zip é aberto **só para leitura** e nunca é apagado. A mesma entrada repetida em duas partes do Takeout é extraída uma vez. A pasta `Takeout/` do zip vira a pasta escolhida (padrão "Google Fotos (Takeout)"); depois disso, é um Takeout em pasta.
- **Schema v10:** `takeout_json` e o CHECK de `media_metadata.date_source` com `'takeout'`. O SQLite não muda CHECK no lugar: a tabela `media_metadata` é **refeita com os mesmos dados**, na mesma transação da migração, depois do backup `pre-migracao-v9-<data>.db`. É a **única exceção** à regra de migrações só aditivas (docs/schema-v1.md §3): nenhuma outra tabela aponta para `media_metadata` e o teste de migração confere os dados e os índices.
- **Dependência:** `archive` 4.x (MIT), que já vinha pelo `image`, agora direta no core e nos fixtures.

## Alternativas descartadas
- **Gravar a data do `.json` no EXIF** (como fazem outras ferramentas): contraria "analisar nunca modifica" e a regra de nunca alterar as fotos.
- **Ler as fotos de dentro do zip sem extrair:** o zip viraria um tipo de fonte novo em todas as partes do app (ver acima); a extração reaproveita a cópia conferida.
- **Guardar `takeout` como `exif_original` para não refazer a tabela:** a tela mentiria sobre de onde veio a hora.
- **Considerar "sem `.json`" só quando não há EXIF:** o usuário pediu "hora a confirmar" para todo arquivo sem `.json`; dá para confirmar em massa na Biblioteca.
- **Limitação:** a pausa no meio de um arquivo grande do zip só acontece no fim daquele arquivo (a descompactação roda inteira num isolate); fechar o app no meio deixa um `.part` que a recuperação descarta e refaz.
