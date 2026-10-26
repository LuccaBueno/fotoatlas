# Análise da especificação v4.1 — contradições, riscos e lacunas

- Data: 2026-10-26 (Etapa 0)
- Escopo: leitura integral de `FOTOATLAS_SPEC.md`, `CLAUDE.md` e `ROADMAP.md`.
- Cada item traz uma **proposta**. Itens marcados com ❓ precisam de decisão do usuário.

---

## 1. Contradições

| # | Onde | Problema | Proposta |
|---|---|---|---|
| C1 | §11.1 passo 8 × lista de estados | O passo 8 diz "registrar `verificado`", mas a lista de estados termina em `publicado` e não tem `verificado`. | Estados canônicos (em inglês no código, rótulo PT-BR na UI): `pending → copying → copied → verifying → verified → publishing → published`, mais `failed`, `needs_attention`, `skipped_identical`. "Conferido" = `verified`; o passo 8 corresponde a `published`. Ver `schema-v1.md`. |
| C2 | §3.1 (5 estados na UI) × §9 (4 níveis de cobertura) | Os níveis não se encaixam um a um nos ícones. Pior: pela regra 11, toda cópia feita pelo FotoAtlas já é conferida, então não fica claro quando aparece 🟡 "Copiado, falta conferir". | Mapeamento definido na seção 4.6 de `arquitetura.md`: 🟡 = existe provável cópia (mesmo tamanho e nome em outra fonte), mas o conteúdo de um dos lados ainda não foi lido por completo. Isso é útil logo depois da listagem, antes da fila de hash terminar. |
| C3 | §11.2 × §11.1 | A recuperação manda "conferir o `.part` com a origem", mas a origem pode estar desconectada (celular). | Gravar o hash da origem no diário quando o item entra em `copied`. A recuperação compara o `.part` com esse hash gravado, sem precisar reler a origem. |
| C4 | §11.3 (`%APPDATA%`) × §16 Fase 8 (MSIX) | Apps empacotados em MSIX têm as gravações em `%APPDATA%` redirecionadas para uma pasta virtual do pacote, que **é apagada na desinstalação**. Além disso, `%APPDATA%` é o perfil *Roaming*. | O catálogo continua em `%APPDATA%\FotoAtlas\`, como diz a spec. Cache de miniaturas e logs vão para `%LOCALAPPDATA%\FotoAtlas\` (o cache é grande e não deve ir no perfil roaming). Instalador recomendado: **Inno Setup** (ver ❓Q3). |
| C5 | CLAUDE.md (licenças permitidas) × §19 (ExifTool decidido) | O ExifTool é distribuído "nos mesmos termos do Perl" (Artistic License **ou** GPL), que não está na lista MIT/BSD/Apache/LGPL. | Ele roda como **executável separado** (agregação, sem linkagem), então não contamina a licença MIT do FotoAtlas. Mesmo assim, a regra do CLAUDE.md manda perguntar → ❓Q4. ADR 0004 fica como "proposta" até a resposta. |
| C6 | §6 (ordem de confiança) | O GUID de volume é atribuído **por computador** pelo Mount Manager. No mesmo PC ele é estável, mas o mesmo HD ligado em outro PC recebe outro GUID. | Como o catálogo vive em um PC só, a ordem da spec funciona. A identificação usa pontuação (ADR 0009), e o caso de "vários PCs" fica registrado como fora do MVP (L6). |
| C7 | §14 "alterado legitimamente (mtime mudou)" | Se o mtime mudou mas o conteúdo é o mesmo, o resultado é "inalterado". E em FAT32 o mtime "anda" 1 h quando muda o horário de verão (ver R4). | Classificação: conteúdo igual → *inalterado* (atualiza o mtime no catálogo); conteúdo diferente com mtime diferente → *alterado*; conteúdo diferente com mtime igual (ou diferente em exatamente ±3600 s em FAT) → *possivelmente corrompido*. |
| C8 | §2 regra 2 "analisar nunca modifica" | Abrir um arquivo para leitura pode atualizar o *last access time* do NTFS, e não dá para evitar sem abrir o arquivo para escrita. | Limitação aceita e documentada: o conteúdo e o mtime nunca são tocados. O FotoAtlas nunca abre um arquivo de origem com permissão de escrita. |

## 2. Riscos

| # | Risco | Impacto | Mitigação |
|---|---|---|---|
| R1 | **Identidade do disco físico em gavetas USB** costuma ser falsa: a ponte USB-SATA informa o serial dela ou nenhum, e gavetas iguais podem repetir o serial. | Mostrar 🔵 "Backup em disco independente" sem que seja verdade. | Política conservadora: só conta "discos diferentes" quando os dois discos têm identidade confiável e diferente. Na dúvida, o nível cai para 🟢. A UI permite que o usuário confirme "este é outro HD físico". |
| R2 | **WPD/MTP**: interop COM no .NET 10 (sem PIA), IDs de objeto do Android instáveis entre sessões, mtime ausente ou errado, leitura lenta pelo USB, iPhone expõe só o DCIM e pode converter HEIC→JPG. | Fase 3 mais longa; scan incremental do celular menos eficiente. | Interfaces COM com `[GeneratedComInterface]` (compatível com AOT). Avaliar a biblioteca MediaDevices (MIT) num ADR da Fase 3. Incremental no celular por (caminho, tamanho, data); se a data faltar, refaz o hash. O hash é calculado **dentro do helper**, sem transferir os bytes pelo pipe. |
| R3 | **Queda de energia ≠ processo morto.** Os testes da spec matam o processo, mas isso não simula a perda do cache de escrita do SO nem um disco USB que "mente" sobre o flush. | Pode haver um cenário real que os testes não cobrem. | `FlushFileBuffers` + `MoveFileExW(MOVEFILE_WRITE_THROUGH)` + `synchronous=FULL`; a recuperação nunca confia só no diário e sempre confere o hash do que está no disco. Limitação documentada em `docs/backup-e-restauracao.md` (Fase 5). |
| R4 | **FAT32/exFAT** (pendrives, cartões): sem journaling, renomear não é atômico em caso de queda, mtime com resolução de 2 s (FAT32) guardado em horário local (pula 1 h no horário de verão), limite de 4 GB, nomes reservados. | Falso "alterado"; publicação interrompida deixa o arquivo pela metade com o nome final. | A recuperação sempre confere o hash do destino publicado. Tolerância de ±3600 s com tamanho igual → refaz o hash em vez de concluir. Checagem de 4 GB. Teste com VHD formatado em FAT32 na CI (opcional, precisa de admin). |
| R5 | **Desempenho**: 100 mil itens com filtros em menos de 1 s; busca por texto em caminhos. | Fase 4 lenta. | Índices desenhados no schema v1; FTS5 com tokenizador trigram na Fase 4; paginação por *keyset* (nunca `OFFSET` grande). |
| R6 | **`sqlite3` com native assets** (build hooks) no Flutter Windows e na CI. | Build quebrado logo no começo. | É a primeira tarefa técnica da Fase 1 (smoke test na CI antes de qualquer outra coisa). |
| R7 | **Antivírus e indexador** abrem o `.part` logo após a escrita, causando `ERROR_SHARING_VIOLATION` na publicação. | Falhas intermitentes. | Novas tentativas com espera crescente, só para esses códigos de erro, registradas no diário. |
| R8 | **Unicode e caixa**: nomes NFD vindos de Mac/iPhone; NTFS sem distinção de maiúsculas, mas pastas com distinção podem existir (WSL). | Duplicar ou deixar de achar um arquivo. | Caminho guardado exatamente como o SO devolve; normalização só para busca e exibição, nunca para operações de arquivo. |
| R9 | **OneDrive / "Arquivos sob demanda"**: a pasta Imagens costuma ficar dentro do OneDrive. | Abrir o arquivo dispara download ou falha offline. | Listagem com `FindFirstFileExW` (não dispara recall); atributos `RECALL_ON_DATA_ACCESS`/`RECALL_ON_OPEN`/`OFFLINE` → `cloud_only`, sem abrir. Esses arquivos não contam como cópia. |
| R10 | **Tamanho do helper**: um .NET *self-contained* tem dezenas de MB. | Instalador grande. | Código compatível com Native AOT desde o início (sem reflection, COM via source generator). A decisão final fica para a Fase 8. |
| R11 | **SmartScreen**: um instalador sem assinatura mostra alerta. | Atrito na instalação. | Documentar; certificado de assinatura é decisão da Fase 8. |
| R12 | **Repositório público**: fixtures, logs da CI e exemplos podem vazar dados. | Privacidade. | Fixtures 100% sintéticos e determinísticos; `.gitignore` já cobre bancos, mídia e logs; os testes nunca imprimem caminhos fora do temp. |

## 3. Lacunas (a spec não diz) e propostas

| # | Lacuna | Proposta |
|---|---|---|
| L1 | Não existe estado entre "conferido" e "publicado". Uma queda entre o `MoveFileExW` e o commit deixa a recuperação sem saber o nome final. | Estado `publishing`: o nome final é gravado no diário **antes** do move. Na recuperação: se o destino existe e o hash bate, vai para `published`; se só o `.part` existe, publica de novo; se os dois existem, aplica a política de conflito. |
| L2 | O nome já existe no destino **com o mesmo conteúdo**. | Não é conflito: o item vira `skipped_identical` ("já estava lá, conteúdo idêntico") e não se cria `_1`. |
| L3 | Nomes inválidos no Windows ou no destino (`:`, `?`, `CON`, ponto ou espaço no final), vindos do celular. | Sanitização determinística na prévia (mostrada ao usuário) e nome original guardado no diário. |
| L4 | "Conferida recentemente" sem prazo definido. | Padrão de **180 dias**, configurável (combina com o alerta de "6 meses" da §3.2). |
| L5 | Pastas de rede / NAS. | Fora do MVP (sem identidade de disco e com flush/rename menos confiáveis no SMB). Registrado para a Fase 9+. |
| L6 | Vários PCs com o mesmo HD. | Um catálogo por PC no MVP. |
| L7 | Celular com mais de um armazenamento (interno + cartão SD). | Uma fonte por celular; o caminho relativo começa pelo nome do armazenamento. |
| L8 | Ordem do hash em discos com milhões de bytes. | **Poda por tamanho**: arquivos com tamanho único no catálogo não podem ter cópia idêntica e já são "só 1 cópia" sem ler o conteúdo. A fila prioriza tamanhos que colidem e a fonte que o usuário está comparando. Fica para a Fase 2. |
| L9 | Concorrência de leitura. | No máximo um leitor por disco físico (HD mecânico sofre com leitura paralela), com paralelismo entre discos diferentes. |
| L10 | O que não escanear. | Lista padrão: `$RECYCLE.BIN`, `System Volume Information`, `.fotoatlas-tmp`, `Windows`, `Program Files*`, `AppData`; reparse points (junctions/symlinks) não são seguidos. Não recomendar `C:\` como fonte, e sim pastas. |
| L11 | Hash de arquivos que não são mídia (ISO, ZIP enormes). | Todos os arquivos são catalogados (regra da spec). O hash é automático para foto, vídeo, RAW e sidecars; os demais têm hash sob demanda (configurável). |
| L12 | Sidecars (`.xmp`, `.aae`, `.thm`) nas cópias e reorganizações. | Viajam junto com a mídia principal (Fases 5 e 6). Detectados por nome-base na mesma pasta. |
| L13 | Copiar o backup do catálogo para os HDs é uma gravação fora do catálogo. | Opcional, desligado por padrão, numa pasta `FotoAtlas-catalogo\` e com o mesmo protocolo de cópia segura. |
| L14 | "Esquecer uma fonte". | Remove só as linhas do catálogo, com confirmação. Arquivos nunca são tocados (regra 8). |
| L15 | Privacidade dos logs locais. | Os logs ficam em `%LOCALAPPDATA%`, com rotação e nenhum envio. Exportar a auditoria é sempre uma ação explícita do usuário. |

## 4. Perguntas para o usuário (§19 + novas)

| | Pergunta | Recomendação |
|---|---|---|
| ❓Q1 | Modelo de organização padrão da biblioteca principal | `{ano}/{ano}-{mes}/` (ex.: `2019/2019-03/IMG_…jpg`): simples, estável e independente do aparelho. |
| ❓Q2 | Política padrão de conflito de nome | **Sufixo automático** (`_1`, `_2`…) quando o conteúdo é diferente; pular quando é idêntico (L2). Tudo aparece na prévia antes de confirmar. |
| ❓Q3 | Formato do instalador | **Inno Setup**: não virtualiza o `%APPDATA%` (C4), não exige certificado para instalar e preserva o catálogo nas atualizações. |
| ❓Q4 | Aceitar o ExifTool (Artistic/GPL, executável separado) | Aceitar. Não há alternativa com cobertura equivalente de HEIC/RAW/vídeo, e o uso como processo separado não afeta a licença MIT. |

Se a resposta for só "aprovado", as recomendações acima passam a valer.
