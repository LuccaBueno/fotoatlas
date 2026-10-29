# FOTOATLAS — ESPECIFICAÇÃO TÉCNICA v4.1

**Plataforma:** Windows 10 e 11
**Stack:** Flutter + Dart + SQLite, com auxiliar nativo para APIs do Windows
**Repositório:** GitHub público — https://github.com/LuccaBueno/fotoatlas
**Ambiente:** Windows 11, Flutter 3.47.7 stable, .NET SDK 10, Git, GitHub CLI
**Prioridade máxima:** nenhum arquivo pode ser perdido, nem em caso de interrupção abrupta.

---

## 1. O PROBLEMA

O usuário tem fotos e vídeos espalhados por celulares, HDs, SSDs, pendrives, cartões e pastas de backup. Cada dispositivo tem uma organização diferente. Parte das fotos do celular já foi copiada para um HD, mas outra parte não. Ninguém sabe exatamente:

- o que já está no HD;
- o que ainda falta copiar;
- o que está duplicado;
- quais cópias são confiáveis.

Copiar tudo de novo "por garantia" gera mais duplicatas e mais bagunça.

**Exemplo central (caso de uso nº 1):**
> "Conectei meu celular e meu HD. Quero ver quais fotos do celular ainda NÃO estão no HD, escolher quais quero levar, copiá-las com segurança e deixar o HD organizado."

O FotoAtlas existe para responder a quatro perguntas:

1. **O que eu tenho e onde está?**
2. **O que já tem backup e o que ainda não tem?**
3. **O que eu quero levar para onde?**
4. **Como deixo tudo organizado sem perder nada?**

---

## 2. PRINCÍPIOS INEGOCIÁVEIS

1. **Segurança antes de desempenho.** Preservar os arquivos é mais importante que velocidade ou economia de espaço.
2. **Analisar nunca modifica.** Escanear, catalogar, comparar e encontrar duplicatas são operações somente leitura. Os arquivos de origem são abertos sempre em modo leitura.
3. **Importar = copiar.** Nada é movido entre dispositivos automaticamente.
4. **Nada é excluído automaticamente.** Duplicatas, filtros e regras produzem seleções, nunca exclusões.
5. **Nunca sobrescrever.** Conflitos de nome geram um novo nome ou pedem decisão do usuário.
6. **Prévia antes de agir.** Toda operação que grava em disco mostra antes o que vai acontecer e exige confirmação.
7. **Toda gravação passa por um diário persistente** e pode ser recuperada após queda de energia, travamento ou desconexão.
8. **Catálogo não é armazenamento.** Apagar ou reconstruir o banco nunca apaga arquivos.
9. **Fonte desconectada não é fonte vazia.**
10. **Falha de leitura não é exclusão.**
11. **Nunca chamar uma cópia de "segura" sem verificação por hash.**
12. **Tudo funciona offline.** Nenhum dado pessoal (fotos, GPS, metadados) sai do computador sem autorização explícita.

---

## 3. EXPERIÊNCIA DO USUÁRIO (REQUISITO DE PRIMEIRA CLASSE)

A interface precisa ser **fácil, útil, completa e, acima de tudo, intuitiva**. O usuário não precisa saber o que é hash, MTP ou WAL.

### 3.1. Princípios de interface

- **Responder perguntas, não mostrar tabelas.** A tela inicial diz, por exemplo: "1.243 fotos do *Celular atual* ainda não estão em nenhum HD" e oferece um botão "Ver e copiar".
- **Tarefas guiadas por assistentes** (passo a passo com "Voltar" e "Avançar") para tudo o que grava em disco.
- **Linguagem simples em PT-BR:**
  - "conteúdo idêntico" em vez de "hash igual";
  - "cópia conferida" em vez de "verificada por SHA-256";
  - "celular" em vez de "dispositivo MTP".
  Os detalhes técnicos ficam disponíveis num painel "Detalhes", para quem quiser.
- **Estados com cor + ícone + texto** (nunca só cor):
  - 🔴 Só 1 cópia
  - 🟡 Copiado, falta conferir
  - 🟢 Cópia conferida
  - 🔵 Backup em disco independente
  - ⚪ Situação desconhecida
- **Prévia visual** de toda operação: quantidade, tamanho, espaço livre no destino, conflitos e a estrutura de pastas resultante.
- **Tudo pode ser interrompido** (pausar, cancelar) e **retomado**.
- **Desfazer** para reorganizações dentro do mesmo disco.
- **Filtros como "chips"** clicáveis (Ano, Dispositivo, Câmera, Tipo, Situação de backup), com construtor avançado (E/OU/NÃO) escondido em "Filtro avançado".
- **Seleção em massa** óbvia: clicar, Shift+clique, Ctrl+clique, "Selecionar todos os resultados" e uma barra fixa mostrando "523 itens · 4,2 GB · 498 conteúdos únicos".
- **Interface sempre responsiva.** Trabalho pesado roda em segundo plano, com progresso visível.
- Tema claro e escuro, atalhos de teclado e boa legibilidade.

### 3.2. Telas principais (navegação lateral)

1. **Início.** Painel com as respostas às 4 perguntas, alertas ("HD antigo não é verificado há 6 meses") e atalhos para as tarefas mais comuns.
2. **Biblioteca.** Galeria em grade e em lista, filtros, seleção e painel de detalhes com todas as localizações conhecidas do item.
   - **Linha do tempo única** pela **data e hora real da captura (até os segundos)**, intercalando fotos e vídeos de todos os dispositivos (celular, câmera, HD) numa só sequência — ex.: a foto da câmera às 14:03:12 aparece entre as do celular de 14:02:50 e 14:05:01. Navegação por ano → mês → dia → **momento**. Conteúdo idêntico em vários lugares aparece uma vez.
   - **Momentos**: grupos automáticos de fotos próximas no tempo (§8), com nome editável; o usuário pode **nomear, juntar e separar** momentos. Isso só muda o catálogo, nunca os arquivos.
   - Hora de **baixa confiança** (ex.: tirada da data do sistema de arquivos) aparece sinalizada (ícone + texto "hora incerta"), com atalho para confirmar ou corrigir.
   - **Corrigir relógio de um dispositivo** (§8): assistente com prévia "antes → depois" antes de aplicar.
3. **Dispositivos.** Fontes cadastradas, conectadas e desconectadas, com último escaneamento, espaço e cobertura de backup de cada uma.
   - **Um botão só, "Adicionar dispositivo"** (aqui e no seletor da Comparar), que abre uma janela listando automaticamente o que está conectado: **celulares** com a situação ("Pronto", "Bloqueado", "Falta permitir o acesso"), **unidades** (HD, SSD, pendrive, cartão de memória; as já cadastradas aparecem marcadas) e a opção **"Escolher uma pasta…"**. Cadastrar só grava no catálogo.
   - **"Escanear" pergunta o quê:** "Tudo" ou "Só algumas pastas" (ex.: só DCIM › Camera e WhatsApp do celular). As pastas são lidas do dispositivo na hora, em árvore, com o **tamanho estimado** quando a pasta já foi escaneada antes (senão, "tamanho desconhecido"). O cartão mostra **quais pastas já foram escaneadas** (e quando) e avisa que o resto ainda não foi; ao escanear de novo, as mesmas pastas vêm sugeridas.
4. **Comparar.** Dois **escopos livres**, A e B (ex.: "pasta 1 + pasta 2 do HD antigo" × "pasta Backup do HD novo", ou celular × HD inteiro), montados com uma ou mais pastas/subpastas, dispositivos inteiros e/ou **momentos** (§8.3, a partir da Fase 4), com filtros opcionais. A pergunta principal fica no topo: **"B contém todo o conteúdo de A?"**, com resposta direta — "Sim, 100%" ou "Faltam N arquivos (X GB)" — e a lista do que falta pronta para seleção e cópia. Abaixo, "Só em B" e "Nos dois". Se algum arquivo dos escopos ainda não teve o conteúdo conferido, a resposta é "Resultado incompleto", nunca "100%". Escopos podem ser salvos com nome (ex.: "Fotos do celular antigo") para reutilizar. Regras na seção 9.
5. **Tarefas.** Fila de operações em andamento e histórico completo (auditoria) com exportação.
6. **Configurações.** Biblioteca principal, modelos de organização, verificação periódica e backup do catálogo.

### 3.3. Assistentes

- **Copiar o que falta:** origem → destino → comparação → filtros/seleção → modelo de organização → prévia → confirmar → progresso → relatório.
- **Reorganizar disco** (ver seção 12).
- **Verificar integridade.**
- **Primeira execução:** cadastrar dispositivos, escolher a biblioteca principal e fazer o primeiro escaneamento.

---

## 4. ARQUITETURA

O repositório é um monorepo com três partes:

```
fotoatlas/
├── packages/
│   └── fotoatlas_core/      # Dart puro (sem Flutter): catálogo, scanner, hash,
│                            # metadados, cópia segura, diário, recuperação
├── native/
│   └── fotoatlas_helper/    # C# .NET: MTP/WPD, miniaturas do Shell,
│                            # identificação de volumes e discos físicos
├── app/                     # Flutter Windows: interface
├── tools/
│   └── fixtures/            # geradores de dados de teste sintéticos
└── docs/                    # ADRs, arquitetura, procedimentos
```

- O **core** pode ser executado por CLI (`fotoatlas_cli`). Isso permite testes automatizados que **matam o processo no meio de uma cópia** para validar a recuperação.
- O **helper nativo** é um executável separado que conversa por JSON-lines via stdin/stdout. Se ele travar, o app continua funcionando e o helper é reiniciado.
- **Trabalho pesado** roda em isolates, numa fila de tarefas com limite de concorrência. A UI nunca bloqueia.

### 4.1. Tecnologias

| Função | Tecnologia |
|---|---|
| Interface | Flutter (Windows desktop) |
| Banco | SQLite via `sqlite3` + `drift` (WAL, `synchronous=FULL`, `foreign_keys=ON`) |
| Hash | SHA-256 em streaming (`package:crypto`) |
| Metadados | **ExifTool** empacotado, em modo `-stay_open` (lotes) |
| Vídeo | **FFprobe/FFmpeg**, build LGPL empacotado |
| Miniaturas | API de miniaturas do Shell do Windows (helper), com fallback para FFmpeg |
| Celular | Windows Portable Devices (helper), para Android e iPhone |
| Volumes/discos | Win32: GUID do volume, número de série, número do disco físico (helper) |
| Publicação de arquivo | `MoveFileExW` **sem** `MOVEFILE_REPLACE_EXISTING` (via FFI) |
| Fsync | `FlushFileBuffers` (verificar se `RandomAccessFile.flush()` usa isso; se não, chamar via FFI) |
| Caminhos longos | Prefixo `\\?\` onde necessário |
| Hash perceptual | dHash/pHash sobre as miniaturas (fora do MVP) |
| Mapa | `flutter_map`; tiles online só com consentimento, ou pacote offline (fora do MVP) |

Antes de adotar cada dependência, registrar um ADR em `docs/adr/` com alternativas, licença, manutenção e motivo da escolha.

---

## 5. MODELO DE DADOS

Três conceitos distintos:

- **Conteúdo (`contents`):** bytes únicos, identificados por SHA-256 + tamanho.
- **Instância (`file_instances`):** um arquivo físico em uma fonte e caminho.
- **Item lógico (`media_items`):** agrupa RAW+JPEG, Live Photos e versões editadas. **Fora do MVP**, mas o schema deve permitir sua adição.

Tabelas principais (esboço — refinar no planejamento):

- `sources`: id (UUID), nome, tipo (hd_externo, interno, pendrive, cartao, celular, pasta), volume_guid, volume_serial, disco_fisico_id, marcador_id (opcional), raiz, conectada, ultima_conexao.
- `scans`: id, source_id, inicio, fim, tipo (completo/incremental), status, cobertura (completa/parcial), erros.
- `contents`: id, sha256, tamanho, tipo_midia, criado_em.
- `file_instances`: id, source_id, **caminho_relativo à raiz da fonte**, nome, extensao, tamanho, mtime, ctime, content_id (nulo até calcular o hash), hash_status, ultima_verificacao, disponibilidade, integridade (ok/alterado/corrompido/desconhecido), visto_no_scan_id, ausente_confirmado_em.
- `media_metadata`: content_id, data_captura, origem_da_data, confianca_da_data, fuso, fabricante, modelo, lente, iso, abertura, exposicao, focal, largura, altura, orientacao, lat, lon, duracao, fps, codec_video, codec_audio, bitrate, software.
- `date_corrections`: correções manuais, sem tocar no arquivo original.
- `operations` e `operation_items`: o **diário** (seção 11).
- `saved_filters`, `selection_sets`, `tags`, `content_tags`.
- `integrity_checks`: histórico de verificações.

Os caminhos são guardados **relativos à raiz da fonte**, para que a troca da letra da unidade não importe.

---

## 6. IDENTIFICAÇÃO DE FONTES

- **Identificadores, por ordem de confiança:**
  1. arquivo marcador `.fotoatlas-id` (opcional, **desligado por padrão**, gravado só com autorização);
  2. GUID do volume;
  3. número de série do volume;
  4. número de série do disco físico.
- Ao reconectar uma fonte, reconhecê-la automaticamente. Em caso de ambiguidade, perguntar ao usuário.
- Saber o **disco físico** de cada volume, para distinguir backup independente de outra partição do mesmo disco.
- No celular, usar o ID do dispositivo WPD com o nome amigável.

---

## 7. ESCANEAMENTO

- Recursivo, em segundo plano, pausável, cancelável e retomável (com checkpoint no banco).
- **Incremental:** se tamanho e mtime não mudaram, não recalcular o hash.
- Calcular o hash após a listagem, numa fila separada, com progresso e estimativa de tempo.
- **Detectar mudança durante a leitura:** comparar tamanho e mtime antes e depois do hash.
- **Ignorar sem ler os placeholders do OneDrive/arquivos sob demanda** (atributos `RECALL_ON_DATA_ACCESS`/`OFFLINE`), marcando-os como "somente na nuvem".
- Evitar ciclos (junctions e symlinks); tratar permissão negada e caminhos longos.
- Uma ausência só é **confirmada** se o scan foi completo e sem erro naquela pasta.
- **Escanear só algumas pastas** (escolhidas pelo usuário) é permitido: o scan fica parcial, só confirma ausências dentro das pastas lidas, e a comparação de qualquer parte não escaneada dá "Resultado incompleto".
- Arquivos desconhecidos são catalogados (sem metadados), nunca descartados.

---

## 8. METADADOS E DATAS

- Extração via ExifTool (fotos, HEIC, RAW, XMP) e FFprobe (vídeos).
- **Estratégia de data, por prioridade (configurável):**
  1. correção manual;
  2. `DateTimeOriginal` (+ `OffsetTimeOriginal`);
  3. datas internas do vídeo (QuickTime `CreateDate`, **normalmente em UTC**);
  4. data no nome do arquivo (padrões `IMG_20190312_…`, `IMG-20190312-WA0001`, `VID_…`, `Screenshot_…`, `PXL_…`);
  5. datas do sistema de arquivos.
- Guardar a origem e o nível de confiança de cada data.
- **Normalizar os fusos:** fotos sem fuso = horário local; vídeos em UTC são convertidos. O fuso padrão é configurável (America/Sao_Paulo).
- Filtros para encontrar: "sem data confiável", "datas conflitantes" e "corrigidas manualmente".
- **Nunca regravar os metadados originais.**

### 8.1. Data e hora da captura (primeira classe)
- Cada conteúdo tem **data e hora da captura com precisão de segundos** (e subsegundos quando o arquivo tiver, ex.: `SubSecTimeOriginal`), guardadas como instante normalizado (UTC) **e** como hora local vivida, com a origem e a confiança (§8).
- A ordenação da linha do tempo e dos momentos usa o **instante real** (UTC); a tela mostra a hora local. Fotos de dispositivos diferentes ficam intercaladas corretamente mesmo com fusos diferentes.
- **Níveis de confiança:** alta (EXIF com fuso ou vídeo em UTC conhecido), média (EXIF sem fuso, assumindo o fuso padrão; data no nome do arquivo), **baixa** (só data do sistema de arquivos, que muda com cópias e restaurações). Hora de baixa confiança é sinalizada em toda a interface.

### 8.2. Correção de relógio por dispositivo de captura
- Para câmeras com relógio errado: o usuário escolhe um **dispositivo de captura** (fabricante + modelo + número de série do corpo quando o EXIF tiver; ex.: "Canon X") e informa um deslocamento ("+1 h", "−3 min 20 s") ou um ajuste de ano/data ("ano errado: 2015 → 2025"), opcionalmente limitado a um período ou a fontes específicas.
- **Prévia obrigatória** antes de aplicar: quantos itens mudam, exemplos "antes → depois" e como a linha do tempo/os momentos ficam. Uma técnica de apoio: alinhar uma foto da câmera com uma do celular tirada no mesmo instante para calcular o deslocamento.
- Aplicada **só no catálogo** (correção registrada com histórico, sobre a data extraída; correções manuais por item continuam valendo acima dela), **nunca no arquivo**. Pode ser desfeita a qualquer momento.

### 8.3. Momentos
- **Agrupamento automático** pela hora real: um novo momento começa quando há um intervalo sem fotos/vídeos maior que o limite (**padrão 2 h, configurável**). Considera todos os dispositivos juntos.
- Itens com hora de **baixa confiança não entram em momentos automáticos** até o usuário confirmar a hora (ou corrigi-la); ficam numa lista "Hora a confirmar".
- O usuário pode **nomear** ("Aniversário da Ana"), **juntar** e **separar** momentos. As edições ficam guardadas no catálogo e **nunca se perdem** quando o agrupamento é recalculado (ex.: novas fotos, novo limite, correção de relógio): momentos editados ficam fixos, e itens novos dentro do intervalo deles são incluídos; o recálculo só mexe nos automáticos e mostra o que mudou.
- Momentos não alteram arquivos. Podem ser usados como **filtro** (§10), como **escopo na Comparar** (§9; ex.: "este momento já está todo no HD?") e no **modelo de organização** (§12).

---

## 9. COBERTURA DE BACKUP E DUPLICATAS

- **Duplicata exata** = mesmo SHA-256 + mesmo tamanho.
- **Níveis de cobertura de cada conteúdo:**
  - só 1 cópia conhecida;
  - várias cópias no mesmo disco físico;
  - cópias em discos físicos diferentes;
  - pelo menos 1 cópia conferida recentemente.
- **Comparação A × B com escopo livre:**
  - **Escopo** = conjunto de uma ou mais entradas, cada uma sendo um dispositivo/fonte inteiro, uma pasta/subpasta dentro de uma fonte ou **um momento** (§8.3, Fase 4: os arquivos daquele momento, em qualquer dispositivo; combinável com uma fonte para restringir, ex.: "momento X no celular"), mais **filtros opcionais** (tipo de mídia agora; data, câmera etc. quando os metadados existirem — Fase 4). A e B são escopos independentes; entradas de fontes diferentes podem ser misturadas no mesmo lado.
  - **Sempre por conteúdo** (SHA-256 + tamanho). Nomes, extensões e estrutura de pastas são ignorados: a mesma foto com outro nome, em outra pasta, conta como "está em B".
  - **Pergunta principal:** "B contém todo o conteúdo de A?" Respostas possíveis:
    - **"Sim, 100%"** — todo conteúdo de A existe em B, e não há pendências (abaixo);
    - **"Faltam N arquivos (X GB)"** — N é o número de conteúdos distintos de A ausentes em B e X a soma dos seus tamanhos (cópias repetidas dentro de A contam uma vez; o total de arquivos de A envolvidos aparece nos detalhes). A lista do que falta vem pronta para seleção, mostrando onde cada conteúdo está em A;
    - **"Resultado incompleto"** — há arquivos, em A ou em B, cujo conteúdo ainda não foi conferido (hash pendente, com erro, alterado durante a leitura ou somente na nuvem), ou pastas do escopo que não puderam ser lidas / fontes nunca escaneadas por completo. Nesse caso o app **nunca** mostra "100%": informa quantos arquivos faltam conferir, de que lado, e oferece "Conferir agora" (prioriza esses arquivos na fila de hash). O número de "faltam" já conhecido continua visível, com a ressalva.
  - **Também mostrar:** "Só em B" (conteúdos de B que não existem em A) e "Nos dois" (conteúdos presentes em ambos), com contagem e tamanho.
  - Instâncias ausentes (`missing`) não contam; instâncias de fonte **desconectada contam** pelo último scan (regra 9), com aviso "resultado baseado no escaneamento de <data>".
  - Se A e B se sobrepõem fisicamente (ex.: A = pasta dentro do HD, B = HD inteiro), avisar: um arquivo nessa área "está em B" por ser o mesmo arquivo, não uma cópia de segurança.
  - **Escopos salvos:** o usuário pode salvar um escopo com nome (ex.: "Fotos do celular antigo") e reutilizá-lo em qualquer lado da comparação. Escopos salvos ficam no catálogo; apagar um escopo nunca toca em arquivos.
  - A comparação é somente leitura (regra 2).
- Espaço ocupado por duplicatas, por fonte.
- **Duplicatas visuais** (perceptuais) ficam fora do MVP. Quando entrarem, serão só sugestões com comparação lado a lado.

---

## 10. PESQUISA, FILTROS E SELEÇÃO

- **Filtros:**
  - data (ano/mês/intervalo/sem data);
  - **horário** da captura: faixa de horário (ex.: 18:00–23:59), **período do dia** (madrugada 0–6 h, manhã 6–12 h, tarde 12–18 h, noite 18–24 h, pela hora local) e **dia da semana**;
  - **momento** (um ou mais);
  - confiança da hora (alta/média/baixa, "hora a confirmar") e "com correção de relógio";
  - fonte;
  - câmera/celular;
  - tipo e extensão;
  - tamanho;
  - resolução;
  - duração;
  - GPS sim/não;
  - situação de backup;
  - erros;
  - hash pendente;
  - texto (nome, caminho, tags).
- Combinações E/OU/NÃO; filtros salvos.
- **Seleção:**
  - individual, intervalo e todos os resultados (não só os visíveis);
  - inverter;
  - remover da seleção por critério;
  - conjuntos salvos.
- Barra de seleção com quantidade, tamanho, conteúdos únicos e situação de backup.
- **Revalidar a seleção** imediatamente antes de executar qualquer operação.
- Consultas paginadas e índices adequados. A galeria nunca carrega a biblioteca inteira na memória.

---

## 11. CÓPIA SEGURA E RECUPERAÇÃO

### 11.1. Protocolo por arquivo

1. Registrar o item no diário como `pendente` (transação SQLite commitada).
2. Verificar se origem e destino estão acessíveis, se há espaço livre e se o **limite de 4 GB em FAT32** é respeitado.
3. Copiar para `destino/.fotoatlas-tmp/<uuid>.part` **no mesmo volume do destino**, calculando o hash da origem durante a leitura.
4. Fazer `FlushFileBuffers` e fechar.
5. **Reler o arquivo temporário** e calcular o hash do destino.
6. Se os hashes forem diferentes: marcar `falhou`, manter o `.part` para diagnóstico e **não publicar**.
7. Publicar com `MoveFileExW` sem substituição. Se o nome já existir, aplicar a política de conflito (sufixo `_1`, `_2`… ou perguntar).
8. Registrar `verificado` e atualizar o catálogo.

Os estados de um item são: `pendente → copiando → copiado → conferindo → conferido → publicado` ou `falhou` / `precisa_atencao`.

### 11.2. Recuperação na inicialização (idempotente)

- Ler os itens do diário que não estão em estado final.
- **`.part` existente:** se o hash conferir com a origem, publicar; senão, refazer a cópia.
- **Destino publicado mas sem registro:** conferir o hash e registrar.
- **Arquivo desconhecido na pasta temporária:** nunca apagar automaticamente; listar para o usuário.
- Se não for possível determinar o estado com segurança, marcar `precisa_atencao` e mostrar na tela Tarefas.

### 11.3. SQLite

- WAL, `synchronous=FULL`, `foreign_keys=ON`, migrações versionadas e transacionais.
- Banco em `%APPDATA%\FotoAtlas\`, nunca no diretório de instalação.
- `PRAGMA integrity_check` periódico.
- **Backup automático do catálogo** via `VACUUM INTO`, com rotação (ex.: últimos 10), e opção de copiá-lo também para os HDs de backup.

---

## 12. REORGANIZAÇÃO

O objetivo é deixar o HD organizado sem risco.

- **Modelos de estrutura** configuráveis, por exemplo:
  - `{ano}/{ano}-{mes}/`
  - `{ano}/{dispositivo}/`
  - `{tipo}/{ano}/`
  - `{ano}/{ano}-{mes}-{dia} {momento}/` (ex.: `2024/2024-07-13 Aniversário da Ana/`)
  - estrutura original preservada
- **Variáveis de data e hora** usam a hora da captura já com as correções do catálogo (§8.2): `{ano}`, `{mes}`, `{dia}`, `{hora}`, `{minuto}`, `{segundo}`; `{momento}` é o nome do momento (§8.3).
- **Momento sem nome** usa o início do momento (ex.: `2024-07-13 14h03`); itens fora de momentos (hora a confirmar) vão para uma pasta configurável (padrão `Sem data confirmada/`). Nomes são sanitizados para o Windows (caracteres proibidos, nomes reservados, espaços/pontos no fim, comprimento).
- A prévia mostra quantos itens dependem de hora de baixa confiança antes de confirmar.
- **Prévia em árvore** de "antes → depois", com conflitos destacados.
- **Dentro do mesmo volume:** mover por renomeação (operação de metadados, sem copiar dados), registrada no diário, sem substituição e com **Desfazer**.
- **Entre volumes:** sempre copiar e conferir (seção 11). A origem permanece intacta.
- **Remover originais após a cópia conferida:** fora do MVP. Quando existir, será uma operação separada, com confirmação explícita e exigência de pelo menos uma outra cópia conferida.
- **Sincronização destrutiva** (apagar no destino o que sumiu da origem): **nunca**.

---

## 13. CELULAR

- Android e iPhone via Windows Portable Devices (helper nativo).
- Não tratar o celular como um disco comum: sem caminhos Win32 e sem renomeação atômica.
- Avisar quando o celular estiver bloqueado ou sem autorização ("Permitir acesso" / "Confiar neste computador").
- Escanear DCIM, Pictures, Movies, WhatsApp e outras pastas, com o hash calculado em streaming (lendo o arquivo inteiro pelo USB, em segundo plano).
- **iPhone:** alertar que a opção *Ajustes → Fotos → Transferir para Mac ou PC* deve estar em **"Manter originais"**, senão o HEIC é convertido em JPG.
- A cópia segue o protocolo da seção 11, com a origem lida pelo helper.
- Tratar a desconexão no meio da operação e retomar a cópia de forma segura.

---

## 14. INTEGRIDADE PERIÓDICA

- Recalcular os hashes por fonte, por lote ou de arquivos individuais, com agendamento configurável e sem pesar no uso do computador.
- Classificar o resultado em:
  - **inalterado**;
  - **alterado legitimamente** (mtime mudou);
  - **possivelmente corrompido** (conteúdo mudou e mtime não).
- Nunca substituir nem apagar. Mostrar outras cópias conferidas daquele conteúdo e oferecer a restauração a partir delas, via cópia segura.

---

## 15. FORA DO MVP

- Item lógico (RAW+JPEG, Live Photos, versões editadas)
- Duplicatas visuais
- Mapa
- Pesquisa por conteúdo com IA (modelo local, opcional)
- Remoção de originais
- Construtor visual de regras complexas (os filtros salvos cobrem o MVP)
- Importação do Google Takeout (sidecars `.json`)

---

## 16. FASES E CRITÉRIOS DE CONCLUSÃO

Cada fase termina com **testes passando + demonstração funcionando + CHANGELOG atualizado**. O app precisa estar executável ao fim de cada fase.

### Fase 1 — Fundação
- Monorepo, CI (GitHub Actions: análise + testes), schema SQLite v1 e migrações.
- Cadastro de fontes (pastas e unidades Windows) e identificação de volumes (helper mínimo).
- Escaneamento de listagem (sem hash), pausável e retomável.
- Telas Dispositivos e Início básicas.
- **Critérios:**
  - escanear uma árvore sintética de 50 mil arquivos sem travar a UI;
  - reconhecer a mesma fonte após troca da letra da unidade;
  - fonte desconectada continua visível com os dados do último scan.

### Fase 2 — Conteúdo e cobertura
- Fila de hash; duplicatas exatas; backup automático do catálogo.
- Tela Comparar (A × B, com escopo livre e escopos salvos — §9) e painel de cobertura.
- **Critérios:**
  - comparação com A = pasta1 + pasta2 e B = pasta3, com nomes diferentes e conteúdo parcial, responde corretamente "faltam N", "só em B" e "nos dois"; com hash pendente em qualquer lado, responde "incompleto";
  - conteúdo idêntico com nomes diferentes é agrupado;
  - mesmo nome com conteúdo diferente **não** é agrupado;
  - "só 1 cópia" está correto em cenário de teste com 3 fontes;
  - arquivo modificado durante o hash é detectado.

### Fase 3 — Celular (leitura)
- Helper com WPD; listar e escanear Android e iPhone; comparar o celular com o HD.
- **Critérios:**
  - com um celular real, listar fotos que não estão no HD (somente leitura);
  - desconexão durante o scan não corrompe o catálogo.

### Fase 4 — Metadados e Biblioteca
- ExifTool, FFprobe, estratégia de datas, miniaturas em cache, galeria, linha do tempo, filtros, seleção em massa e filtros salvos.
- **Critérios:**
  - filtros por data, câmera, fonte e situação de backup funcionando em 100 mil itens com resposta abaixo de 1 s;
  - fusos de vídeo × foto coerentes;
  - datas de WhatsApp reconhecidas;
  - linha do tempo intercala 2+ dispositivos pela hora real (segundos), inclusive com fusos diferentes;
  - momentos automáticos com limite configurável; nomear/juntar/separar sobrevive a um recálculo; hora de baixa confiança fica fora até confirmar;
  - correção de relógio por dispositivo com prévia, aplicada só no catálogo (arquivo com hash igual antes e depois) e reversível;
  - filtros por faixa de horário, período do dia, dia da semana e momento em 100 mil itens abaixo de 1 s.

### Fase 5 — Cópia segura
- Diário, protocolo completo, recuperação e assistente "Copiar o que falta" (unidades e celular).
- **Critérios:** testes automatizados matando o processo em cada estado do protocolo, sem perda, sem sobrescrita e com recuperação idempotente (executada 3 vezes seguidas sem efeito colateral).

### Fase 6 — Reorganização
- Modelos de estrutura, prévia em árvore, movimentação no mesmo volume com diário e Desfazer.
- **Critérios:** interrupção no meio da reorganização é recuperável; Desfazer restaura exatamente a estrutura anterior; modelo `{ano}/{ano}-{mes}-{dia} {momento}/` gera a árvore esperada (com momento sem nome, hora a confirmar e nomes inválidos no Windows).

### Fase 7 — Integridade periódica
- **Critérios:** corrupção simulada (bytes alterados com mtime preservado) é detectada e outras cópias conferidas são apontadas.

### Fase 8 — Distribuição
- Instalador (MSIX ou Inno Setup) com ExifTool e FFmpeg empacotados.
- Atualização preserva o catálogo; teste em máquina limpa; documentação de usuário.

### Fase 9+ — Recursos avançados (seção 15)

---

## 17. TESTES

- **Unitários** no core; **integração** via CLI; **testes de falha** que matam o processo (`Process.kill`) em pontos instrumentados do protocolo.
- **Dados de teste sempre sintéticos**, gerados em `tools/fixtures/` (imagens com EXIF variado, vídeos curtos, nomes repetidos, datas erradas, árvores profundas).
- **Nunca** rodar testes em backups ou fotos reais do usuário.
- Simular:
  - falta de espaço;
  - origem que some (pasta renomeada ou removida durante o teste);
  - conflito de nome;
  - FAT32 (se possível, com VHD montado);
  - caminho longo;
  - permissão negada.

---

## 18. GIT E GITHUB

- Repositório **público** (sem dados pessoais, nunca); Conventional Commits; versionamento semântico; CHANGELOG.
- `.gitignore`:
  - banco de dados;
  - miniaturas;
  - fixtures gerados;
  - builds;
  - binários do ExifTool/FFmpeg (baixados por script, não versionados);
  - qualquer arquivo pessoal.
- Documentação:
  - README;
  - `docs/arquitetura.md`;
  - `docs/adr/`;
  - `docs/backup-e-restauracao.md`;
  - instruções de build.
- Releases no GitHub com o instalador.

---

## 19. DECISÕES

**Tomadas:**
- Flutter + Dart + SQLite, com core em Dart puro testável por CLI.
- Helper nativo em **C# .NET 10** (se houver motivo técnico forte para C++, justificar em ADR).
- ExifTool + FFmpeg (LGPL) empacotados.
- Marcador `.fotoatlas-id` opcional, desligado por padrão.
- Repositório público.
- Ordem das fases conforme a seção 16.

**A confirmar com o usuário durante o planejamento:**
- Modelo de organização padrão da biblioteca principal.
- Política padrão para conflito de nome (sufixo automático × perguntar).
- Formato do instalador.

---

## 20. INSTRUÇÕES PARA O CLAUDE CODE

1. Leia toda esta especificação e aponte contradições, riscos e lacunas.
2. Antes de escrever código, apresente:
   - arquitetura detalhada;
   - schema SQLite v1;
   - protocolo do helper nativo;
   - ADRs iniciais;
   - plano da Fase 1 com tarefas.
3. **Aguarde aprovação.** Depois implemente **só a Fase 1**.
4. Uma funcionalidade só está concluída com testes passando e evidência de funcionamento.
5. Nunca execute operações de escrita, movimentação ou exclusão em pastas do usuário fora do diretório de fixtures.
6. Se algo não puder ser feito de forma confiável (ex.: limitação do WPD), explique e proponha uma alternativa segura.
7. Ao fim de cada fase:
   - atualize o CHANGELOG e a documentação;
   - faça commit e push;
   - apresente um resumo do que foi testado e do que ficou pendente.
