# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado — Fase 7: Integridade periódica
- **Verificar integridade** (Dispositivos › Mais opções, no cartão de um disco, pasta ou celular; ou "Verificar…" com itens marcados na Biblioteca): o FotoAtlas lê cada arquivo de novo e compara com o conteúdo conferido antes. **Só lê**: nenhum arquivo é alterado, movido ou apagado. Antes de começar, diz quantos arquivos e quanto vai ler; dá para escolher "Tudo" ou "Só o que não é conferido há mais de N dias".
- Resultado de cada arquivo: **inalterado**; **alterado** (o conteúdo e a data de modificação mudaram — alguém editou); **possivelmente corrompido** (o conteúdo mudou, mas a data não — sinal de dano no disco); "não está mais no lugar" e "não deu para ler agora", que nunca fazem o arquivo ser considerado apagado. Em discos FAT, a diferença de exatamente 1 hora do horário de verão não disfarça um dano.
- **Possivelmente corrompidos** (Tarefas): cada arquivo com as **outras cópias conferidas** do conteúdo original (em que dispositivo e pasta, se está conectado, se é no mesmo disco, quando foi conferida) e **"Restaurar desta cópia…"**: abre a prévia da cópia segura (Fase 5) e só grava depois de você confirmar. A cópia boa é gravada **na mesma pasta, com outro nome** (`foto_1.jpg`); o arquivo danificado nunca é substituído nem apagado. Se a "cópia boa" também tiver se estragado, a cópia segura percebe e não grava. "A mudança é esperada…" aceita o conteúdo atual (só no catálogo).
- Arquivo possivelmente corrompido deixa de contar como cópia de segurança (na situação de backup, na Comparar e como origem de cópias) até ser restaurado ou regravado.
- **Verificação periódica** (Configurações): ligada por padrão, confere de novo o que não é conferido há mais de 90 dias (30, 90, 180 dias ou 1 ano). É **leve**: lê devagar, espera quando o FotoAtlas está escaneando, conferindo, copiando ou reorganizando, pode ser pausada e continua de onde parou. **Celulares nunca** são verificados sozinhos — só quando você pede.
- Tarefas: verificações em andamento e histórico (pausar, continuar, cancelar, "Ver arquivos"). Início: aviso de arquivos possivelmente corrompidos e de discos que não são verificados há tempo, com "Verificar agora".
- Fechar o app no meio de uma verificação é seguro: ela fica "interrompida" e continua de onde parou, sem repetir arquivos.
- CLI: `verify start|resume|status|problems|restore|accept|schedule|tick`.
- Demonstração: `run-app.ps1 -DemoPersistente` gera a pasta "Integridade" ("HD fotos" e "HD cópia"); `tools\scripts\demo-danificar.ps1` simula o dano no disco (ou, com `-Editar`, uma edição) só dentro da pasta da demonstração.
- Catálogo v6 (só acrescenta tabelas e colunas; backup automático antes da migração). ADR 0018.

### Adicionado — Fase 6: Reorganização
- **Reorganizar…** (Dispositivos, no cartão de um disco ou pasta): organiza as fotos e vídeos dentro do **mesmo disco**, movendo sem copiar (rápido, não ocupa espaço). Modelos: por ano e mês, por ano e dia, **por ano e momento** (`2024/2024-07-13 Aniversário da Ana`; momento sem nome usa a hora em que começou, `2024-07-13 14h03`), por tipo e ano, por ano e câmera, mesma estrutura ou tudo junto. Fotos sem hora confiável vão para "Sem data confirmada" (nome configurável); nomes que o Windows não aceita são ajustados.
- **Prévia em árvore "antes → depois"**: de onde cada arquivo sai, para onde vai, pastas novas, pastas que ficam vazias, nomes repetidos (ganham `_1`, `_2`… ou esperam a sua decisão) e o que fica onde está (o que não é foto nem vídeo, ou ainda não teve a data lida). Arquivos de edição `.xmp`/`.aae` com o mesmo nome vão junto com a foto.
- **Desfazer** (Tarefas): devolve cada arquivo ao lugar exato de antes, mesmo depois de fechar e abrir o app. Antes de confirmar, avisa quais arquivos mudaram desde a reorganização — esses só voltam se você confirmar —, quais sumiram e quais lugares antigos já têm outro arquivo (nada é sobrescrito).
- **Remover pastas vazias…** (Tarefas): as pastas que ficaram vazias nunca são apagadas sozinhas. Esta ação lista cada uma, você escolhe e confirma; só sai pasta sem nada dentro (nem arquivo oculto, como `Thumbs.db`), conferida de novo na hora.
- Para organizar em **outro disco**, o assistente oferece a cópia conferida ("Copiar para outro disco…"): a origem fica como está. **Celular nunca é reorganizado.**
- **Disco principal** (Dispositivos › Mais opções): destino sugerido nas cópias.
- Os modelos novos (`{hora}`, `{minuto}`, `{segundo}`, `{momento}`) também valem na cópia.
- Diário e recuperação: cada arquivo movido fica registrado antes de mover; se o app fechar no meio, ao abrir ele confere o disco e continua de onde parou. Testes de falha matam o processo em cada etapa (reorganização, Desfazer e a própria recuperação).
- CLI: `reorg plan|start|resume|undo|resolve|folders|status`; `recover` também cobre a reorganização.
- Demonstração: `run-app.ps1 -DemoPersistente` gera a pasta "HD bagunçado" para testar.
- Catálogo v5 (só acrescenta duas colunas no diário; backup automático antes da migração). ADR 0017.

## [0.5.0] — 2026-10-30 — Fase 5: Cópia segura

### Ajustes de usabilidade (depois do teste da Fase 5)
- **Comparar**: abas com "contém/contido" — **"Em A, não contido em B — faltam"**, **"Em B, não contido em A"** e **"Contido em A e em B"** — e dica em cada aba citando os nomes reais dos lados (ex.: "Arquivos de "Pixel de Teste" que "HD" ainda não contém").
- "Copiar para B…" desabilitado explica o porquê: "Marque arquivos ou clique em "Selecionar todos os resultados"". Dicas também em "Selecionar todos os resultados", "Adicionar pasta ou dispositivo", "Adicionar momento", "Filtrar por data ou câmera", nos tipos, em "Comparar", "Trocar A e B" e "Conferir agora".
- **Assistente de cópia**: o caminho completo do destino aparece abaixo de "Para onde" (quebrando linha, com dica); na lista, nome e caminho em duas linhas. Quando tudo já está no destino, sugere o próximo passo: escolher outro destino ou **"Adicionar dispositivo…"** direto do assistente (um disco novo vira o destino).
- **Tarefas › Detalhes**: lista os arquivos copiados e conferidos (origem → onde ficou), destaca os **salvos com outro nome** com o porquê ("IMG_20240502_120000.jpg → salvo como IMG_20240502_120000_1.jpg porque o nome já existia na pasta") e os **não copiados com o motivo** (já estava lá idêntico, você escolheu não copiar, erro). A lista completa continua no relatório exportado.

### Adicionado — Fase 5: Cópia segura
- **Copiar o que falta**, com conferência: "Copiar para B…" na Comparar (todos os resultados ou os marcados) e "Copiar para…" com itens marcados na Biblioteca abrem um assistente com **prévia** antes de gravar qualquer coisa: quantos arquivos e quanto espaço, o que o destino já tem (mesmo conteúdo, outro nome), espaço livre e quanto sobra, nomes que já existem, arquivos acima de 4 GB num disco FAT32, nomes ajustados para o Windows, itens sem data ou com hora incerta e as pastas que vão ser criadas. Organização por ano e mês (padrão), por dia, por tipo e ano, mantendo a estrutura da origem ou tudo numa pasta.
- **Cada arquivo é conferido**: gravado numa pasta temporária do destino, enviado ao disco, relido e comparado pelo conteúdo com a origem; só então aparece no destino. Nada é sobrescrito (nome ocupado vira `_1`, `_2`… ou espera a sua decisão) e a origem nunca muda. A data de modificação da origem é mantida.
- **Celular como origem**: o arquivo é lido pelo cabo USB e gravado direto na pasta temporária do destino; se o celular sair no meio, a cópia pausa sem deixar nada pela metade e continua quando ele voltar.
- **Diário e recuperação**: toda etapa de cada arquivo fica registrada. Se o FotoAtlas fechar, travar ou o computador desligar no meio, ao abrir ele confere o disco, termina o que já estava copiado e conferido e deixa o resto esperando "Continuar". Rodar a recuperação de novo não muda nada.
- **Tela Tarefas**: cópias em andamento com progresso (o arquivo do momento e se está copiando ou conferindo), pausar, continuar, cancelar o que falta (o que já foi copiado fica), decidir nomes repetidos ("Copiar com outro nome" ou "Não copiar"), tentar de novo os que não foram copiados, arquivos desconhecidos na pasta temporária (listados, nunca apagados) e **exportar o relatório** (CSV).
- Falta de espaço, disco de destino ou origem desconectados pausam a cópia com o motivo na tela; uma pasta da origem que sumiu no meio aparece como "não copiado", sem marcar o arquivo como apagado.
- CLI: `copy plan`, `copy start … --yes`, `copy resume`, `copy retry`, `copy status`, `copy export` e `recover`.
- Helper: `devices.pullToFile` (grava só arquivos novos `.part` dentro de `.fotoatlas-tmp`).
- Testes de falha: o processo é morto em cada etapa da cópia (11 pontos) e no meio da própria recuperação; a recuperação roda 3 vezes sem efeito colateral e a cópia termina sem perda nem sobrescrita. Falta de espaço e FAT32 com arquivo de mais de 4 GB em discos virtuais (VHD) na CI.
- Demonstração: o HD do celular simulado tem um arquivo com o mesmo nome de uma foto que falta (para ver o `_1`); com `-DemoPersistente -CelularSimulado` o Pixel lê devagar e dá para "desplugá-lo" no meio da cópia.
- Documentos: ADR 0016 (cópia segura) e `docs/backup-e-restauracao.md` (o que é garantido e a limitação de queda de energia).

### Mudado
- Fechar o app com uma cópia em andamento pergunta antes e, ao fechar, pausa a cópia com segurança (o arquivo do momento volta para a fila).

## [0.4.0] — 2026-10-29 — Fase 4: Metadados e Biblioteca

### Ajustes de usabilidade (depois do teste da Fase 4)
- Situações de backup com nomes claros: **"Sem backup (só em 1 lugar)"**, "Parece ter cópia (falta conferir)", "Tem cópia conferida", **"Backup em outro disco"**, "Ainda não dá para saber".
- Filtros **"Horário do dia"** e **"Hora confiável?"** (antes "Horário" e "Hora"); "Mostrar tudo, menos os marcados" no lugar de "Excluir os marcados (NÃO)"; contagens com unidade.
- Momentos: nome descritivo quando não têm nome ("Sábado de manhã"); um instante só mostra "09:00"; botão "Opções" maior e menu pelo clique direito no cabeçalho.
- **Ajuda**: dica em ícones, selos, chips e botões (o selo de backup diz onde o arquivo está); botão **"?"** na navegação com a ajuda e a legenda da tela aberta; **guia de primeiros passos** na primeira abertura (pode pular e rever pelo "?").
- **Corrigir o relógio**: novo modo padrão "Sei a hora certa de uma foto", com a frase do que vai mudar antes da prévia.
- Data de **1º de janeiro às 00:00:00** em ponto (relógio zerado) passa a ser hora incerta e vai para "Hora a confirmar"; catálogos existentes são recalculados ao abrir, sem reler os arquivos.

### Adicionado — Fase 4: Metadados e Biblioteca
- **Biblioteca** com três visões: **linha do tempo única** pela hora real da captura (até os segundos), intercalando fotos e vídeos de todos os dispositivos, com cabeçalhos de mês, dia e **momento**; **grade**; e **lista**. Navegação ano → mês → dia → momento ao lado. Conteúdo idêntico em vários lugares aparece uma vez.
- **Data e hora da captura**: lidas do EXIF (com subsegundos e fuso), do vídeo (UTC), do nome do arquivo (celular, câmera, WhatsApp, Pixel, prints, Dropbox) ou da data do arquivo, nessa ordem (configurável). Cada item guarda a origem e a confiança (confiável, provável, incerta); **hora incerta** aparece sinalizada, com "A hora está certa" e "Corrigir a hora…". Fuso padrão America/Sao_Paulo, com o antigo horário de verão.
- **Momentos automáticos** por intervalo sem fotos (padrão 2 h, configurável), considerando todos os dispositivos. **Nomear, juntar, separar** e voltar ao automático pelo cabeçalho; as edições ficam fixas nos recálculos. Hora incerta fica em **"Hora a confirmar"** até ser confirmada.
- **Corrigir o relógio de um dispositivo** (ex.: câmera 1 h adiantada, ano errado), com prévia "antes → depois", o item de outro dispositivo que fica ao lado e o efeito nos momentos; também calcula o deslocamento por duas fotos tiradas no mesmo instante. Só no catálogo; **Desfazer** na hora ou em Configurações.
- **Filtros em chips**: ano, dispositivo, câmera, tipo, situação de backup, **horário** (faixa, inclusive atravessando a meia-noite; período do dia; dia da semana), **momento**, hora (confiança, a confirmar, corrigidas, conflitantes) e mais (período de datas, sem data, tamanho, resolução, duração, GPS, erro de leitura); busca por nome, pasta ou momento; **filtro avançado E/OU/NÃO**; **filtros salvos**.
- **Seleção em massa**: clique, Ctrl+clique, Shift+clique, Ctrl+A ("todos os resultados", não só os visíveis), inverter, tirar da seleção por critério; barra fixa com itens, tamanho, arquivos e situação de backup.
- **Painel de detalhes** com todas as localizações (conectado/desconectado), câmera, dimensões, exposição, GPS, duração e todas as datas encontradas.
- **Miniaturas em cache** (Shell do Windows pelo helper; FFmpeg para vídeos; miniatura embutida no EXIF, inclusive do celular lendo só o começo do arquivo).
- **Comparar**: momento como parte do escopo (em todos os dispositivos ou só num) e filtro por período/câmera; escopos salvos guardam os dois.
- **Configurações › Datas e momentos**: intervalo dos momentos, fuso, ordem das datas, histórico de correções de relógio com desfazer, situação do leitor de metadados.
- Leitura de metadados automática depois da conferência (ExifTool e ffprobe, só leitura), com progresso, pausa e "ler de novo os que deram erro"; sem o ExifTool, as datas vêm do nome e da data do arquivo e se completam quando ele existir.
- `tools/scripts/get-tools.ps1`: baixa ExifTool 13.60 e FFmpeg 8.1 LGPL com SHA-256 conferido (não versionados).
- Celular simulado com fotos com EXIF de verdade e uma pasta **"Câmera"** com o relógio 1 h adiantado (para testar a linha do tempo, os momentos e a correção).
- Helper: `thumbnails.get` e `devices.readHead` (grava só arquivos novos dentro da pasta de cache).
- Catálogo v4 (aditivo): data efetiva, momentos, edições de momentos e correções de relógio (ADR 0014 e 0015).
- Desempenho medido: 100 mil itens — filtros de 100 a 370 ms (exigido < 1 s), recálculo dos momentos em ~1,4 s.

### Mudado
- **Modo demonstração avisado na tela**: com `run-app.ps1 -Demo` ou `-CelularSimulado`, uma faixa fixa no topo diz "Modo demonstração — tudo será descartado ao fechar", e a pergunta ao fechar e a tela "Encerrando com segurança…" avisam que nada será mantido (antes prometiam "continua de onde parou", o que não vale nesse modo).
- **Fechar com tarefas em andamento pergunta antes**: "Há tarefas em andamento: …" com o progresso de cada uma (escaneamento, conferência, backup do catálogo) e "Continuar trabalhando" (padrão) ou "Fechar mesmo assim". Sem nada em andamento, fecha direto.
- **Se a leitura de dispositivos cair** (fora do fechamento), o app avisa: o que estava em andamento foi interrompido sem perder nada; a conferência continua sozinha quando o celular volta e o escaneamento continua em "Retomar".
- **Um botão só, "Adicionar dispositivo"**, em Dispositivos e no seletor da Comparar, no lugar de "Adicionar pasta", "Adicionar celular" e "Adicionar unidade". A janela lista sozinha o que está conectado: celulares com a situação ("Pronto", "Bloqueado", "Falta permitir o acesso"), unidades (HD, SSD, pendrive, cartão — as já cadastradas aparecem como "Já cadastrada") e "Escolher uma pasta…", com "Procurar de novo".
- **"Escanear" pergunta o quê**: "Tudo" ou "Só algumas pastas". As pastas aparecem em árvore, lidas do dispositivo na hora (só leitura; abrir a janela não cataloga nada), cada uma com "escaneada em …" ou "ainda não escaneada" e o tamanho pelo último escaneamento ("tamanho desconhecido" se nunca foi escaneada). No celular com um armazenamento só, ele já aparece aberto. Marcar uma pasta inclui as de dentro.
- Na Comparar, depois de adicionar um dispositivo novo, a mesma pergunta aparece antes de escanear.

### Adicionado
- **`run-app.ps1 -DemoPersistente`**: demonstração mantida entre aberturas, sempre em `%TEMP%\fotoatlas_demo_persistente` (apagável pelo `clean-temp.ps1`), para testar a retomada de verdade. Com `-CelularSimulado`, os celulares simulados são gerados uma vez na mesma pasta e o Pixel lê devagar (3 s por arquivo), para dar tempo de fechar no meio da conferência. O gerador ganhou `--leitura-lenta MS`.
- **Várias pastas num escaneamento só** (core `scans.start(fonte, folders: [...])`; CLI `scan start FONTE --folder A --folder B`). Continua parcial e honesto: só confirma ausências dentro das pastas lidas; a comparação de partes não escaneadas dá "Resultado incompleto".
- O cartão do dispositivo mostra **quais pastas já foram escaneadas** (e quando) e avisa que o resto ainda não foi; o próximo "Escanear" já sugere as mesmas pastas. Depois de um scan do dispositivo inteiro, pastas escaneadas sozinhas mais tarde aparecem como "atualizadas depois".
- Core: `scans.listFolders`, `sources.folderStats`, `sources.listDrives`, `SourceView.scannedFolders`/`wholeScannedAt`/`scannedAt()`.

### Corrigido
- **O app não fechava pelo X** (o botão ficava vermelho e a janela continuava aberta). O encerramento esperava, sem prazo, o fim de streams cujos ouvintes estavam pausados (telas fora de vista) — o que nunca acontece no Dart — e ainda até 10 s por worker de scan/conferência, o backup do catálogo e o helper. Agora fechar **sempre funciona**: aparece "Encerrando com segurança…" com o que falta (pausar o escaneamento, pausar a conferência, terminar o backup, encerrar a leitura de dispositivos, fechar o catálogo); cada etapa tem prazo, o helper é finalizado se não responder (ex.: preso numa leitura do celular) e o app sai em no máximo 12 s. O que ficou pela metade continua de onde parou ao abrir de novo (ADR 0013).
- Fechar o catálogo podia voltar antes de o arquivo do banco ser fechado de verdade (reabrir logo em seguida dava "database is locked") e esperava, sem fim, consultas reativas de telas fora de vista; agora só volta com o arquivo fechado e não depende dessas consultas.
- Teste de desempenho da cobertura (100 mil arquivos) falhava às vezes na suíte completa por rodar em paralelo com o de 50 mil arquivos (1,5 s sozinho; até 5,4 s competindo, limite de 5 s). Os dois agora rodam em sequência, num arquivo só (`test/perf/perf_test.dart`).
- Na tela Dispositivos vazia, "Adicionar dispositivo" aparecia no topo e no centro; agora só no centro.
- Ao fechar durante a conferência do celular, o terminal mostrava `Unhandled Exception: HelperException(helper_crashed)`: um pedido ao helper feito com o encerramento em andamento ficava pendente sem ninguém esperando e falhava quando o helper era finalizado. Agora nenhum pedido fica órfão e nada novo vai para o helper durante o encerramento (ADR 0013).
- CI: os testes de desempenho (geram 50 mil arquivos e saturam o disco) passam a rodar sozinhos, depois dos outros; rodando juntos, atrasavam testes de encerramento até o limite de 30 s.
- A conferência do celular gravava os resultados em lotes de 32: fechar no meio refazia pelo USB o que já tinha sido lido. Agora cada arquivo é gravado na hora e, ao reabrir, a conferência continua exatamente de onde parou.
- O cartão dizia "mas 0 pastas não puderam ser lidas" depois de um scan de uma pasta só; agora diz "Só algumas pastas foram escaneadas".
- "Retomar" de um scan pausado de uma pasta só falhava pelo app (pedia a fonte inteira); agora retoma o mesmo scan.

## [0.3.0] — 2026-10-28 — Fase 3: Celular (leitura)

### Adicionado
- **Celulares (Android e iPhone) pelo cabo USB, só leitura** (ADR 0012). O helper lê o aparelho pelo Windows Portable Devices com um interop próprio que **não declara nenhum método de gravação, movimentação ou exclusão**, e abre a sessão pedindo só leitura. Pendrives e cartões que o Windows também mostra como "dispositivo portátil" ficam fora da lista de celulares.
- **Adicionar celular** (Dispositivos e no seletor da Comparar): lista os aparelhos conectados com a situação — "Pronto", "Bloqueado" (desbloqueie e escolha "Transferência de arquivos") ou "Falta permitir o acesso" ("Permitir" no Android, "Confiar" no iPhone). No iPhone, aviso para usar **"Manter originais"** em Ajustes › Fotos.
- **Escanear o celular** pasta por pasta, com os armazenamentos (interno, cartão SD) como primeiras pastas, pausável e retomável. Pastas privadas de apps (`Android/data`, `Android/obb`) e caches de miniaturas ficam de fora.
- **Conferência de conteúdo do celular**: o SHA-256 é calculado no helper, lendo o arquivo pelo USB, com detecção de arquivo que mudou depois do scan ou durante a leitura.
- **Comparar celular × HD**: o celular é uma fonte como as outras (aparelho inteiro, um armazenamento ou uma pasta como DCIM). O celular conta como disco próprio: foto no celular e num HD de identidade confiável = backup em disco independente.
- **Escanear só uma pasta** (CLI `scan start FONTE --folder P`; no core, `scans.start(fonte, folder: …)`), útil no celular: o scan fica parcial, só confirma ausências dentro da pasta, e a comparação dá "Resultado incompleto" para pastas do escopo que ainda não foram escaneadas.
- **"Não dá para confirmar que estão em discos diferentes"**: quando uma cópia conferida (🟢) está num disco que o Windows não identifica com certeza (ex.: SSD NVMe com número de série zerado), o Início e o cartão do dispositivo explicam por que ela não aparece como 🔵 disco independente (R1).
- `tools/scripts/clean-temp.ps1 [-Simular]`: apaga só as pastas de `%TEMP%` que começam com `fotoatlas_`, deixando intactas as que estão em uso.
- O mesmo celular é reconhecido pelo número de série, mesmo em outra porta USB.
- **Celulares simulados** para testes e demonstração sem aparelho: `--fake-devices` no helper / `FOTOATLAS_FAKE_DEVICES`, gerador `tools/fixtures/bin/gen_phone_demo.dart` e `run-app.ps1 -CelularSimulado`.
- **CLI**: `devices` e `sources add-phone CELULAR [--name N]`.
- **Schema v3** (aditivo): `sources.device_serial`, `sources.device_platform`, `file_instances.device_object_id`, com teste de migração a partir da v1 e da v2.
- Protocolo do helper: `devices.list`, `devices.listChildren`, `devices.hashObject`; o cliente aceita eventos por pedido e cancelamento (`system.cancel`).

### Corrigido (teste com celular real)
- **Conferência no celular real falhava em quase todos os arquivos** com "Erro de leitura no dispositivo (0x800700AA)" (aparelho ocupado): o helper não fechava de verdade o stream de leitura de cada arquivo (o wrapper COM do .NET só o liberava quando o coletor de lixo rodava), e o celular aceita uma transferência por vez. Agora o stream é liberado na hora, depois de ler até o fim (ADR 0012, atualização).
- Testes deixavam pastas em `%TEMP%` (`fotoatlas_app_test_*`, `fotoatlas_test_*`, `fotoatlas_cli_phone_build_*`): a remoção falhava em silêncio quando um arquivo ainda estava preso por instantes, e nos testes do app só era registrada depois da preparação. Agora toda pasta de teste é apagada com novas tentativas (até ~10 s) e o teste **falha** se sobrar algo; o `run-app.ps1` apaga o catálogo de demonstração e os celulares simulados quando o app fecha.
- Mensagens com acento dos scripts PowerShell saíam trocadas no Windows PowerShell 5.1 (arquivos sem BOM).

### Segurança
- Teste de integração com VHD abria o helper sem celulares simulados e listaria um celular real plugado; agora usa uma pasta vazia de simulados, e o teste de arquitetura falha se algum teste abrir o core com acesso a celulares reais.
- Desconectar, bloquear o celular ou o helper cair no meio do scan ou da conferência **nunca** marca arquivo como ausente nem como erro: o scan fica "interrompido" e retoma das pastas pendentes; o que faltava conferir continua pendente (regras 9 e 10).
- Uma falha ao ler um item de uma pasta do celular marca a pasta inteira como não lida (nada abaixo dela vira ausente), em vez de pular o item.
- Teste no helper falha se o interop WPD ganhar qualquer método fora da lista de leitura.

### Evidências (critérios da Fase 3)
- Celular simulado × HD pela CLI compilada com o **helper real**: lista, cadastra, escaneia (6 arquivos), confere e compara — faltam 3, nos dois 3, só em B 1; com o celular "desplugado", continua listado e a comparação usa o último scan.
- Desconexão no meio do scan (helper real, após N listagens): `interrupted`, `PRAGMA integrity_check = ok`, nenhum arquivo ausente; reconectado com IDs de objeto novos, retoma e termina com a contagem exata. O mesmo no core com IDs que mudam entre sessões, e foto apagada no celular só vira ausente num scan completo.
- Kill do processo no meio do scan do celular → retomar termina com 6 arquivos, sem duplicar.
- Interop WPD real testado sem aparelho (objetos do próprio Windows: propriedades, chaves, gerenciador).
- Teste do usuário com celular simulado no app: Pixel × HD → faltam 3, só em B 1, nos dois 3.
- **Celular real, somente leitura** (Samsung Galaxy M54, Android por MTP, catálogo de demonstração em `%TEMP%`): `devices` → pronto, 1 armazenamento ("Armazenamento interno", 241,6 GB, 49,4 GB livres); scan só de `DCIM/Camera` → **6.596 arquivos** (6.255 JPG, 286 MP4, 55 HEIC; 106,8 GB = 99,5 GiB), 1 pasta, 0 erros; conferência → 6.596 conferidos, 0 erros, 0 alterados, em 47 min (~37 MB/s), nenhum conteúdo repetido. Nada foi gravado no aparelho: a sessão WPD é aberta só para leitura e o interop não tem métodos de gravação. A primeira conferência falhou em 6.575 arquivos (0x800700AA) e levou à correção acima.

## [0.2.0] — 2026-10-27 — Fase 2: Conteúdo e cobertura

### Requisitos ajustados (sem implementação ainda)
- **Data e hora da captura (até segundos) como cidadã de primeira classe** — spec §3.2, §8.1–8.3, §10, §12 e §16; ROADMAP das Fases 4 e 6: linha do tempo única intercalando todos os dispositivos pela hora real; **momentos** automáticos (intervalo sem fotos, padrão 2 h) que o usuário pode nomear, juntar e separar, usados como filtro, escopo na Comparar e no modelo de organização `{ano}/{ano}-{mes}-{dia} {momento}/`; filtros por faixa de horário, período do dia e dia da semana; correção de relógio por dispositivo de captura com prévia, só no catálogo; hora de baixa confiança sinalizada e fora dos momentos automáticos até ser confirmada.

### Adicionado
- **Conferência de conteúdo (SHA-256)** em segundo plano, um leitor por disco físico, em isolates (ADR 0010). Lê os arquivos só para leitura, sem baixar placeholders do OneDrive, e detecta arquivo que mudou depois do escaneamento ou durante a leitura (tamanho e data antes e depois). Erro de leitura fica registrado com o motivo e nunca vira "ausente". Pausar/continuar; "tentar de novo" para os que falharam; começa sozinha depois de cada escaneamento e quando um dispositivo conecta. Retomada exata depois de o processo ser morto.
- **Duplicatas exatas e cobertura de backup**: 🔴 só 1 cópia, 🟡 provável cópia (falta conferir), 🟢 cópia conferida no mesmo disco, 🔵 backup em disco independente, ⚪ desconhecido. O mesmo arquivo visto por duas fontes sobrepostas conta uma vez; disco de identidade incerta nunca conta como independente; dispositivo desconectado continua contando. Espaço ocupado por arquivos repetidos, por dispositivo.
- **Comparar com escopo livre** (ADR 0011): A e B com uma ou mais pastas e/ou dispositivos inteiros, filtro por tipo e **escopos salvos com nome**. Resposta direta a "B contém todo o conteúdo de A?" — "Sim, 100%", "Faltam N arquivos (X GB)" com a lista pronta para seleção, ou "Resultado incompleto" quando há arquivo sem conteúdo conferido, pasta não lida ou dispositivo nunca escaneado. Também "Só em B" e "Nos dois". Sempre por conteúdo; nomes e pastas não importam. "Conferir agora" prioriza os arquivos dos dois escopos.
- **Backup automático do catálogo** (`VACUUM INTO`): conferido antes de publicar, nunca sobrescreve, guarda os 10 mais novos e preserva os backups de migração. Automático uma vez por dia ao abrir o app e manual em Configurações.
- **App**: Início com o painel "O que já tem backup e o que ainda não tem" e o progresso da conferência; Dispositivos com a situação de backup e os repetidos de cada fonte; tela **Comparar** completa; **Configurações** com o backup do catálogo.
- **CLI**: `hash run|retry`, `coverage`, `compare A B [--list] [--type]`, `scopes list|save|remove`, `backup now|list`.
- **Schema v2** (aditivo): `file_instances.hash_error` e tabela `saved_scopes`, com teste de migração a partir do snapshot da v1.

### Alterado (ajustes pedidos no teste do usuário)
- **Comparar**: o seletor "Adicionar pasta ou dispositivo" ganhou o botão **"Adicionar nova pasta/dispositivo…"**, que cadastra uma pasta ou unidade, já começa a escanear e deixa a nova fonte selecionada, sem sair da tela; e a dica "Não encontrou? Ela precisa ser adicionada e escaneada primeiro".
- **Comparar**: o resumo separa arquivos de conteúdos ("A: 5 arquivos (4 conteúdos diferentes, 1 repetido)"), e explica que as abas contam conteúdos — "Faltam em B" + "Nos dois" = conteúdos de A. O core passou a devolver `aContents`/`aRepeated`/`bContents`/`bRepeated` (também na saída da CLI `compare`).
- Contadores com plural e concordância em todas as telas: "1 arquivo com só 1 cópia", "4 cópias conferidas", "2 arquivos só na nuvem", "1 mudou durante a leitura".
- Caminhos nas listas com um só separador: "HD_antigo › pasta2 › notas.txt" (antes misturava › e /).

### Corrigido
- O `ProviderScope` do app ficava dentro do `MaterialApp`, e diálogos não enxergavam os providers (o seletor de pastas da comparação quebraria). Achado pelo teste do app com o core real.

### Segurança
- Leitura de arquivos de usuário só por `safe_io/source_reader.dart` (`GENERIC_READ`, `OPEN_EXISTING`, `FILE_FLAG_OPEN_NO_RECALL`); o teste de arquitetura confere as flags e agora também pega os nomes Dart dos bindings (`createFile`, `moveFileEx`).
- Publicação sem sobrescrever (`MoveFileExW` sem `REPLACE_EXISTING`) já usada no backup do catálogo.

### Evidências (critérios da Fase 2)
- Conteúdo idêntico com nomes diferentes é agrupado; mesmo nome com conteúdo diferente não é (testes do core).
- "Só 1 cópia" correto num cenário de 3 fontes (2 no mesmo disco, 1 em outro), inclusive com disco de identidade fraca e fontes sobrepostas.
- Arquivo que cresce ou é reescrito com o mesmo tamanho durante a leitura é detectado.
- Comparação A = pasta1 + pasta2 × B = pasta3, com nomes diferentes e conteúdo parcial: faltam 2 (2.400 bytes), só em B 1, nos dois 2; "incompleto" com hash pendente em qualquer lado (core, CLI, app com core real).
- 100 mil arquivos no catálogo: cobertura ~1,5 s, comparação ~0,2 s, página da lista ~0,2 s (fora da thread da interface).
- Kill no meio da conferência → retomar termina sem duplicar conteúdo; nova execução não faz nada.

### Alterado
- **Requisito da comparação ajustado** (spec §3.2, §9 e §16): A e B passam a ser escopos livres (várias pastas e/ou dispositivos, com filtros), a pergunta principal é "B contém todo o conteúdo de A?" (sempre por conteúdo), com resultado "incompleto" quando há arquivos sem conteúdo conferido, e escopos podem ser salvos com nome.
- CI: `actions/checkout@v7` e `actions/setup-dotnet@v6` (Node 24); `subosito/flutter-action@v2` já usa `actions/cache@v5` (Node 24). Disparo manual (`workflow_dispatch`) para repetir a CI.

### Testes
- VHD: a conferência pelo Windows (`Get-DiskImage`) mostrou que, depois do `detach vdisk` do diskpart, o disco continuava anexado — a tolerância a "already detached" escondia isso. Agora o teste desanexa com `Dismount-DiskImage` e confere o estado, sem tolerância (3 execuções seguidas verdes na CI).

## [0.1.0] — 2026-10-26 — Fase 1: Fundação

### Adicionado
- **Catálogo SQLite v1** (drift): todas as tabelas de `docs/schema-v1.md`, com WAL, `synchronous=FULL` e `foreign_keys`. Recusa abrir um catálogo de versão mais nova, faz backup antes de migrar, usa um único escritor em isolate e permite só um processo por vez (`catalog.lock`).
- **Helper nativo** (C# .NET 10): protocolo JSON-lines v1 (`hello`, `system.*`, cancelamento, vigia do processo pai) e `volumes.list`, que traz GUID, serial, sistema de arquivos, espaço e disco físico, com uma classificação de identidade conservadora para seriais falsos de gavetas USB e de NVMe. Regras de escrita prontas para as próximas fases.
- **Cliente do helper** com reinício automático (espera crescente), ping de vigilância e reserva Win32 quando o helper não está disponível.
- **Cadastro de fontes** (pastas e unidades inteiras), reconhecido por pontuação (ADR 0009) e independente da letra da unidade. Casos ambíguos pedem confirmação, a conectividade é verificada a cada 3 s e há aviso de pastas sobrepostas. Fonte desconectada continua visível com os dados do último scan.
- **Escaneamento de listagem** (sem hash) com `FindFirstFileExW` e caminhos `\\?\`, em isolate próprio, com checkpoint transacional por lote: pausar, retomar e cancelar, scan incremental e retomada após o processo morrer. Uma ausência só é confirmada em scan completo; pasta com erro de leitura nunca vira exclusão. Junctions e symlinks não são seguidos. Placeholders do OneDrive são catalogados sem serem abertos. Lixeira, `System Volume Information`, `.fotoatlas-tmp` e pastas do sistema ficam de fora.
- **CLI** `fotoatlas_cli`: `volumes`, `sources add|list`, `scan start|resume|status`, e crashpoints para testes de falha.
- **Gerador de fixtures sintéticos** determinístico (`tools/fixtures`): nomes de celular/câmera/WhatsApp, Unicode, nomes repetidos, cópias idênticas e caminho com mais de 260 caracteres.
- **App Windows**: navegação lateral com as 6 telas, tema claro/escuro e textos em PT-BR. Telas **Início** (visão geral, alertas, atalhos) e **Dispositivos** (adicionar pasta/unidade, escanear, pausar, retomar, cancelar, renomear, esquecer, confirmar unidade). As demais telas explicam o que virá.
- **CI** no GitHub Actions (windows-latest): helper, core + fixtures e app (análise, formatação, código gerado, testes e build).
- Documentação: `docs/desenvolvimento.md`, atualizações dos ADRs 0007, 0008 e 0009; snapshot do schema (`drift_schemas/drift_schema_v1.json`).

### Segurança
- Teste de arquitetura impede que módulos não autorizados gravem, movam ou apaguem arquivos.
- `GetLastError` via FFI às vezes vem zerado (medido: ~1 em 2.000). A listagem só termina com `ERROR_NO_MORE_FILES` e, em qualquer outro caso, refaz a pasta ou registra erro, nunca uma "lista mais curta".

### Evidências (critérios da Fase 1)
- 50 mil arquivos em 294 pastas escaneados em ~1,6 s; atraso máximo do event loop principal de 10–15 ms durante o scan.
- Troca de letra reconhecida (volumes simulados e VHD real NTFS e FAT32 na CI).
- Fonte desconectada visível com os dados do último scan (testes do core e do app).
- Processo morto no meio do scan (TerminateProcess) → retomada com contagem exata, sem duplicatas.

## Etapa 0 — Planejamento
- Especificação técnica v4.1, roteiro, CLAUDE.md e conceito de logo.
- Análise da especificação, arquitetura, schema SQLite v1, protocolo do helper nativo, ADRs 0001–0009 e plano da Fase 1.
