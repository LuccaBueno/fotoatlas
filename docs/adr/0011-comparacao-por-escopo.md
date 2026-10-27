# 0011 — Comparação A × B com escopo livre

- Status: aceita
- Data: 2026-10-27 (requisito ajustado pelo usuário; spec §3.2, §9 e §16)

## Contexto
O usuário precisa responder "B contém todo o conteúdo de A?" com A e B formados por várias pastas e/ou dispositivos inteiros (ex.: A = pasta1 + pasta2 do HD antigo, B = pasta3 do HD novo), sempre por conteúdo, ignorando nomes e pastas. Resultado errado aqui é perigoso: um "100%" falso pode levar o usuário a apagar a origem por conta própria.

## Alternativas consideradas
- **Comparar por fonte inteira** (spec original): simples, mas não atende pastas misturadas.
- **Comparar por nome + tamanho**: rápido sem hash, mas dá falso positivo (mesmo nome, conteúdo diferente) — inaceitável.
- **Usar tamanho único (L8) para afirmar "falta"** sem hash: correto logicamente, mas a regra pedida é "só conteúdo conferido"; mantido apenas para a cobertura e para a ordem da fila.

## Decisão
- `Scope` = lista de `ScopeEntry(sourceId, relPath)` ('' = fonte inteira) + filtro opcional por tipo (extensão: foto, RAW, vídeo, outros; datas e câmera na Fase 4). Entradas contidas em outras são simplificadas. Serializado em JSON versionado (`{"v":1,…}`) na tabela nova `saved_scopes` (schema v2, migração aditiva).
- Uma consulta SQL com CTEs materializadas: instâncias de A e B (não `missing`, fontes não esquecidas; desconectadas contam pelo último scan — regra 9), conjuntos de conteúdos conferidos (`hash_status = 'done'`), e as diferenças: faltam (A − B), só em B (B − A), nos dois. Contagem por **conteúdo distinto**; o total de arquivos fica nos detalhes.
- **Veredito**: `incomplete` se houver, em qualquer lado, arquivo pendente/erro/alterado/somente na nuvem, pasta do escopo com erro no último scan completo, fonte nunca escaneada por completo ou fonte esquecida. Só sem nenhuma pendência o resultado pode ser `complete` ("Sim, 100%") ou `missing`. A vazio → `emptyA` (nunca "100%").
- Avisos que não bloqueiam: fonte desconectada (data do scan usado) e sobreposição física entre A e B (mesmo volume, caminhos aninhados).
- "Conferir agora" passa as entradas de A e B como prioridade para a fila de hash (ADR 0010); a tela refaz a comparação quando a fila termina.
- Listas paginadas (faltam, só em B, nos dois, não conferidos em A/B) com o arquivo representante de cada conteúdo.

## Consequências
- Medido: 100 mil arquivos em 3 fontes → comparação em ~0,2 s e página da lista em ~0,2 s (máquina de desenvolvimento).
- Filtros por data/câmera entram no mesmo JSON sem quebrar escopos salvos (`v` permite migrar).
- Caminhos são comparados com a caixa do catálogo; o seletor da UI usa as pastas do próprio catálogo, então não há divergência de caixa.
