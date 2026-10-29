# 0015 — Metadados, data efetiva, momentos e miniaturas

- Status: aceita
- Data: 2026-10-29

## Contexto
A Fase 4 (spec §8, §10, §16) pede metadados de fotos e vídeos de todos os dispositivos (inclusive celular pelo USB), data e hora da captura até os segundos com origem e confiança, momentos editáveis que sobrevivem a recálculos, correção de relógio por dispositivo reversível, miniaturas e filtros em 100 mil itens abaixo de 1 s — sem nunca modificar os arquivos.

## Decisões

### Leitura (fila de metadados)
- Por **conteúdo** (SHA-256), depois da conferência: cópias idênticas são lidas uma vez. A fila (`MetadataService`) roda no isolate principal (o trabalho pesado é dos processos externos) e começa sozinha quando a conferência termina ou uma fonte conecta.
- Lê **uma** cópia acessível: local primeiro (ExifTool em `-stay_open` com argumentos fixos de leitura + ffprobe nos vídeos); senão, do celular, **só o começo do arquivo** (`devices.readHead`, 512 KB) para a pasta de cache, lido pelo ExifTool e apagado em seguida.
- Sem nenhuma cópia acessível (ou sem ExifTool), grava as datas do **nome** e do **sistema de arquivos** (`meta_status = 'partial'`) e completa quando der. Falha de leitura local → `error` com o motivo (nunca some da Biblioteca).
- Limitação: vídeo de celular com o índice no fim do arquivo não tem a data interna no começo; fica com a data do nome (média) ou do arquivo (baixa).

### Datas
- Candidatas guardadas (`candidates_json`): EXIF `DateTimeOriginal` (+ subsegundos e `OffsetTimeOriginal`), datas internas do vídeo (QuickTime em UTC; `Keys:CreationDate` com fuso), nome do arquivo (WhatsApp só com o dia; `PXL_` em UTC; Samsung, `IMG_`, `VID_`, `Screenshot_`, Dropbox, Signal) e a data de arquivo **mais antiga** entre as cópias.
- Escolha pela prioridade configurável; confiança alta (com fuso ou UTC), média (sem fuso, no fuso padrão; nome) ou baixa (só data do arquivo). WhatsApp: se a data do arquivo cai no mesmo dia do nome, ela dá a hora (média); senão meio-dia e baixa. Conflito = candidatas de câmera/nome discordam além de 2 min (ou de dia).
- Mudar o fuso ou a prioridade recalcula pelas candidatas, **sem reler os arquivos**.
- **Data efetiva** (`eff_*`) = manual > extraída + correções de relógio. As colunas derivadas (ano, mês, dia, minuto, dia da semana) existem para os filtros por índice/varredura simples.

### Momentos
- Agrupamento puro (`groupMoments`) pela hora real, de todos os dispositivos, com limite configurável (padrão 2 h). Hora incerta fica fora até ser confirmada.
- Editar (nomear, juntar, separar) transforma o momento em `edited`: o intervalo fica fixo e os itens novos dentro dele entram nele. O recálculo só mexe nos automáticos e reaproveita o ID do automático com mais itens em comum (filtros e escopos salvos continuam valendo). Gravação em lote (100 mil itens em ~1,4 s).

### Correção de relógio
- Por dispositivo de captura (fabricante + modelo + série quando o EXIF tem), deslocamento e/ou "ano errado", período e fontes opcionais. Prévia obrigatória (itens afetados, exemplos antes → depois com o vizinho de outro dispositivo, momentos antes/depois). Aplicar só grava a correção; desfazer marca `undone_at` e recalcula. Alinhar por duas fotos (câmera × celular no mesmo instante) calcula o deslocamento.

### Biblioteca
- Consulta devolve **só o índice** (IDs, instante, dia, momento) numa linha agregada (`group_concat`), e os detalhes vêm por página — a galeria nunca carrega a biblioteca inteira e o índice não atravessa o isolate linha por linha. Situação de backup com as regras da cobertura; com fontes que não se sobrepõem, a contagem simples de cópias é equivalente e bem mais rápida.
- Medido (100 mil itens, local): consultas de 100 a 370 ms; o teste de desempenho exige < 1 s.

### Miniaturas
- Cache descartável em `%LOCALAPPDATA%\FotoAtlas\thumbs\<ab>\<sha256>_256.jpg`. Ordem: Shell do Windows pelo helper (thread STA, JPEG pelo WIC em memória; caminhos `\\?\Volume{GUID}\` trocados pela letra atual) → FFmpeg (`-n`, nunca sobrescreve) para vídeos → miniatura embutida no EXIF lida em Dart (também do celular, pelo começo do arquivo). Arquivo temporário novo + renomear para publicar.

## Consequências
- O core ganhou permissão de gravar só na pasta de cache (teste de arquitetura atualizado); o helper, só `CreateNew` dentro do `--cache-dir`.
- Itens ainda não conferidos não aparecem na Biblioteca (aviso "N arquivos ainda estão sendo conferidos"); na Comparar com filtro de metadados, eles ficam no escopo e deixam o resultado "incompleto".
- Sem tabela `thumbnail_cache`: existência do arquivo é o cache.
