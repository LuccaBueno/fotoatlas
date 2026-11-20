# Roteiro de teste — Fase 9 (Avançados)

Roteiro único para testar, em dezembro, tudo o que entrou nos pré-lançamentos `1.3.0-beta.N`. Ele cresce a cada item publicado. Depois do seu teste (e dos ajustes que você pedir), publicamos a **1.3.0 estável**.

Comandos para o Windows PowerShell, com caminhos completos. Tudo usa **dados de demonstração** (fotos sintéticas); nenhuma foto sua é lida.

| Item | Pré-lançamento | Estado |
| --- | --- | --- |
| 0. Pré-lançamentos (aviso e "Atualizar agora" só com versões estáveis) | `1.3.0-beta.1` | pronto para testar |
| a. Fotos parecidas | `1.3.0-beta.1` | pronto para testar |
| b. RAW+JPEG e Live Photos agrupados | `1.3.0-beta.2` | pronto para testar |
| c. Importação do Google Fotos (Takeout) | `1.3.0-beta.3` | pronto para testar |
| d. Mapa | `1.3.0-beta.4` | pronto para testar |

## Antes de começar

**Sobre o catálogo de verdade.** O FotoAtlas instalado (1.2.1) usa o catálogo em `C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas`. As versões 1.3.0-beta acrescentam tabelas ao catálogo; um catálogo aberto por uma beta **não abre mais na 1.2.1** (ela recusa catálogo mais novo, sem modificá-lo). Antes de mudar, o FotoAtlas guarda uma cópia conferida em `C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas\backups\pre-migracao-v7-<data>.db` (ou `v8`, conforme a versão de onde vem). Por isso, este roteiro testa tudo com o catálogo da demonstração e **nunca** abre uma beta com o catálogo de verdade.

**Pasta da demonstração:** `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente`. Para começar do zero, com o FotoAtlas fechado:
```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\clean-temp.ps1
```

**Abrir a demonstração a partir do código** (na versão do pré-lançamento que você quer testar; troque `v1.3.0-beta.1` pela mais nova da tabela acima):
```powershell
cd C:\dev\fotoatlas
git fetch --tags
git checkout v1.3.0-beta.1
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\run-app.ps1 -DemoPersistente
```
No fim de todo o teste, volte para a versão em desenvolvimento:
```powershell
cd C:\dev\fotoatlas
git checkout main
```

## 0. Pré-lançamentos

**0.1. O FotoAtlas instalado não oferece pré-lançamento.** Abra o FotoAtlas 1.2.1 pelo menu Iniciar, vá em **Configurações › Atualizações** e clique em **Procurar atualização agora**. Mesmo com as betas publicadas, a resposta deve ser "Você já tem a versão mais nova (1.2.1)." e nenhuma faixa de versão nova aparece no topo. Feche o FotoAtlas.

**0.2. As betas estão marcadas como pré-lançamento no GitHub:**
```powershell
Start-Process 'https://github.com/LuccaBueno/fotoatlas/releases'
```
Cada `v1.3.0-beta.N` aparece com a etiqueta **Pre-release**, com o instalador `FotoAtlas-1.3.0-beta.N-instalador.exe` e o `.sha256`. A "Latest" continua sendo a `v1.2.1`.

**0.3. O instalador da beta, sem tocar no catálogo de verdade** (opcional; troca o FotoAtlas instalado pela beta — no fim deste passo você reinstala a 1.2.1). Baixe o instalador e o `.sha256` da beta mais nova para `C:\Users\Lucca-PC\Downloads` e confira:
```powershell
$beta = 'C:\Users\Lucca-PC\Downloads\FotoAtlas-1.3.0-beta.1-instalador.exe'
(Get-FileHash -LiteralPath $beta -Algorithm SHA256).Hash.ToLower()
Get-Content -LiteralPath "$beta.sha256"
```
Os dois códigos devem ser iguais. Instale **sem abrir o app no fim** (desmarque "Abrir o FotoAtlas" na última tela) e abra a beta com o catálogo da demonstração:
```powershell
& 'C:\Users\Lucca-PC\Downloads\FotoAtlas-1.3.0-beta.1-instalador.exe'
$env:FOTOATLAS_HOME = 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\catalogo'
$env:FOTOATLAS_DEMO = 'persistente'
& 'C:\Users\Lucca-PC\AppData\Local\Programs\FotoAtlas\fotoatlas.exe'
```
Em **Configurações › Sobre o FotoAtlas** deve aparecer "Versão 1.3.0-beta.1 (pré-lançamento)". Em **Atualizações › Procurar atualização agora**, a resposta explica que você está num pré-lançamento e que só versões estáveis são oferecidas (a mais nova publicada é a 1.2.1). Feche o FotoAtlas e **feche esta janela do PowerShell** (as variáveis valem só nela).

Para voltar à 1.2.1, baixe `FotoAtlas-1.2.1-instalador.exe` da página da release `v1.2.1` para `C:\Users\Lucca-PC\Downloads` e instale por cima:
```powershell
& 'C:\Users\Lucca-PC\Downloads\FotoAtlas-1.2.1-instalador.exe'
```

## a. Fotos parecidas (1.3.0-beta.1)

A pasta de demonstração `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Fotos parecidas` é gerada sozinha na primeira abertura com `-DemoPersistente`. Ela tem 11 fotos sintéticas (desenhos de céu e formas coloridas, nada de fotos reais):

| Pasta | Fotos | O que são |
| --- | --- | --- |
| `Praia` e `WhatsApp` | `IMG_0101.jpg`, `IMG_0101_compartilhada.jpg`, `IMG_0101_editada.jpg`, `IMG-20240712-WA0003.jpg` | a mesma foto: original, recomprimida, mais clara e com metade do tamanho |
| `Festa` | `IMG_0201.jpg`, `IMG_0202.jpg` | rajada (as formas andaram um pouco) |
| `Viagem` | `IMG_0301.jpg`, `IMG_0301_recorte.jpg` | original e cortada nas bordas |
| `Viagem` | `IMG_0302.jpg`, `IMG_0303.jpg`, `tela_preta.jpg` | fotos sozinhas e uma tela preta (nunca devem aparecer) |

**a.1. Abrir e cadastrar.** Abra a demonstração (comando em "Antes de começar"). Em **Dispositivos › Adicionar dispositivo › Escolher uma pasta…**, escolha `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Fotos parecidas` e clique em **Escanear › Tudo**. Espere a conferência terminar (Início).

**a.2. A tela nova.** Clique em **Parecidas** no menu lateral. O cartão do topo mostra "Analisando as fotos…" e depois "11 de 11 fotos analisadas". Se aparecer "Esperando outras tarefas terminarem", é normal: a análise espera a conferência e a leitura das datas.

**a.3. Grupos e níveis.** Com **Mostrar: Até muito parecidas** (padrão), devem aparecer **3 grupos sugeridos**:
- **Quase idênticas**, 4 fotos (a praia);
- **Muito parecidas**, 2 fotos (a festa);
- **Muito parecidas**, 2 fotos (a viagem com o recorte).

As fotos sozinhas e a tela preta não aparecem. Passe o mouse sobre o selo de nível: aparece a explicação. Troque para **Só quase idênticas**: fica só a praia. Troque para **Todas, até "talvez"**: continuam os 3. Volte para **Até muito parecidas**.

> Na demonstração, as miniaturas vêm do Windows; o nível de algum grupo pode subir ou descer um degrau em relação à lista acima. Anote se isso acontecer.

**a.4. Comparar lado a lado.** No grupo da praia, clique em **Comparar lado a lado**. Confira, para cada foto: miniatura grande, nome, resolução (a do WhatsApp tem metade da largura e da altura), tamanho, data, câmera ("Google Pixel 7"), cópias, **Onde está** e a situação de backup. A primeira tem a etiqueta **Referência**; as outras, o nível em relação a ela.

**a.5. Copiar (cópia segura de sempre).** Marque duas fotos: o botão vira "Copiar 2 fotos marcadas para…". Clique e veja que abre o mesmo assistente "Copiar para…" de sempre, com prévia. Pode cancelar.

**a.6. Tirar do grupo e Desfazer.** Clique em **Tirar do grupo** na foto `IMG_0101_editada.jpg`. Ela some da comparação e aparece o aviso "A foto saiu do grupo. Nenhuma foto foi alterada." com **Desfazer**. Feche a comparação: o grupo da praia agora tem 3 fotos. Clique em **Desfazer** (se o aviso já tiver sumido, use **Mostrar de novo as descartadas**, no topo): o grupo volta a ter 4.

**a.7. Não são parecidas.** No grupo da festa, clique em **Não são parecidas**: o grupo some e aparece o aviso com **Desfazer**. Feche e abra o FotoAtlas: o grupo continua fora (está guardado no catálogo). Clique em **Mostrar de novo as descartadas**: o grupo volta.

**a.8. Nada foi alterado.** Com o FotoAtlas aberto ou fechado, confira que a pasta continua com as mesmas 11 fotos, com as datas de modificação de julho de 2024:
```powershell
Get-ChildItem -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Fotos parecidas' -Recurse -File | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
```
(`tela_preta.jpg` tem a data do dia em que a pasta foi gerada.)

**a.9. Pausar e continuar.** Ainda em **Parecidas**, se a análise estiver rodando, clique em **Pausar** e depois em **Continuar**. Se já terminou, o botão diz **Analisar agora** e não faz nada de novo (tudo já foi analisado).

**a.10. Ajuda.** Clique no **?** (canto inferior esquerdo) com a tela Parecidas aberta: aparecem "Fotos parecidas", o que dá para fazer e o significado dos três selos.

**Limitações conhecidas:** recortes grandes, fotos giradas ou espelhadas não são reconhecidas como parecidas. Fotos que estão só no celular entram na análise depois que a miniatura delas aparece na Biblioteca (a análise nunca lê do celular sozinha).

## b. RAW+JPEG e Live Photos agrupados (1.3.0-beta.2)

Agrupar é **só visual, no catálogo**: nenhum arquivo muda. Copiar e reorganizar um item agrupado levam todos os arquivos dele juntos (a prévia mostra); a conferência, a comparação, o backup e a verificação continuam arquivo por arquivo.

A pasta de demonstração `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Fotos agrupadas` é gerada sozinha na primeira abertura com `-DemoPersistente` (se você já abriu a demonstração antes desta versão, ela é criada na próxima abertura). As fotos são sintéticas, e o "RAW" é simulado (um arquivo `.DNG` com o conteúdo de um JPEG):

| Pasta | Arquivos | O que deve acontecer |
| --- | --- | --- |
| `Câmera` | `IMG_1001.JPG` + `IMG_1001.DNG` | um item **RAW+JPEG** |
| `Câmera` | `IMG_1002.JPG` + `IMG_1002.DNG` | um item **RAW+JPEG** |
| `iPhone` | `IMG_2001.JPG` + `IMG_2001.MOV` (vídeo de 2,5 s) | um item **Live** |
| `iPhone` | `IMG_2002.JPG` + `IMG_2002.MOV` (vídeo de 1 min) | dois itens separados (vídeo longo não é Live Photo) |
| `iPhone` | `IMG_3001.JPG` | sozinha |

**b.1. Cadastrar.** Abra a demonstração (comando em "Antes de começar", com `v1.3.0-beta.2`). Em **Dispositivos › Adicionar dispositivo › Escolher uma pasta…**, escolha `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Fotos agrupadas` e clique em **Escanear › Tudo**. Espere a conferência e a leitura das datas terminarem (Início).

**b.2. Um item só.** Abra a **Biblioteca** e filtre pelo dispositivo "Fotos agrupadas". Devem aparecer **6 itens** (não 9): os dois JPEG da câmera com o selo **RAW+JPEG**, o `IMG_2001.JPG` com o selo **Live**, e sozinhos o `IMG_2002.JPG`, o vídeo `IMG_2002.MOV` e o `IMG_3001.JPG`. Passe o mouse sobre um selo: aparece "Foto e RAW tirados juntos (2 arquivos). Copiar ou reorganizar leva todos juntos."

**b.3. Detalhes.** Clique no `IMG_1001.JPG`. No painel à direita, o cartão **RAW+JPEG: 2 arquivos** lista `IMG_1001.JPG (foto)` e `IMG_1001.DNG (RAW)`.

**b.4. Filtro por tipo mostra cada arquivo.** Em **Tipo**, escolha **RAW**: aparecem os dois `.DNG` sozinhos. Tire o filtro.

**b.5. Copiar leva o grupo.** Crie uma pasta vazia para ser o destino:
```powershell
New-Item -ItemType Directory -Path 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Destino agrupadas'
```
Cadastre-a como pasta (**Dispositivos › Adicionar dispositivo › Escolher uma pasta…**) e escaneie. Na Biblioteca, marque **só** o `IMG_1001.JPG` e o `IMG_2001.JPG` e clique em **Copiar para…**, com destino "Destino agrupadas". A prévia diz "Vai copiar 4 arquivos" e "2 arquivos vão junto com a foto de que fazem parte (RAW ou vídeo da Live Photo), para a mesma pasta. Nenhum deles estava marcado." Confirme e espere terminar em **Tarefas**. Confira que os 4 arquivos estão lado a lado:
```powershell
Get-ChildItem -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Destino agrupadas' -Recurse -File | Select-Object FullName, Length | Format-Table -AutoSize
```

**b.6. Reorganizar leva o grupo.** Em **Dispositivos**, no cartão "Fotos agrupadas", abra **Reorganizar…** com qualquer modelo por data. A prévia mostra "3 arquivos RAW ou vídeos de Live Photo vão junto com a foto de que fazem parte, para a mesma pasta e com o mesmo nome", e na árvore "depois" cada `.DNG`/`.MOV` está na mesma pasta do seu `.JPG`. Pode **Cancelar** (ou reorganizar e depois usar **Desfazer** em **Tarefas**).

**b.7. Desagrupar.** Nos detalhes do `IMG_1002.JPG`, clique em **Desagrupar**. Aparece "Desagrupado: 2 arquivos aparecem sozinhos (só no catálogo)", e a Biblioteca passa a mostrar o `IMG_1002.DNG` separado. Feche e abra o FotoAtlas: continua separado (o grupo não volta sozinho).

**b.8. Agrupar à mão.** Clique no `IMG_1002.JPG` (isso já o marca) e marque também a caixinha do `IMG_1002.DNG`. Na barra da seleção, clique em **Agrupar**: os dois voltam a ser um item, com o selo **Agrupado**.

**b.9. Nada foi alterado.** A pasta "Fotos agrupadas" continua com os mesmos 9 arquivos, com as datas de junho de 2024 (se você não reorganizou no b.6):
```powershell
Get-ChildItem -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Fotos agrupadas' -Recurse -File | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
```

**Limitações conhecidas:** só agrupa arquivos da mesma pasta. A Live Photo é reconhecida pelo identificador da Apple (fotos e vídeos de iPhone de verdade) ou pelo mesmo nome com um vídeo de até 5 s. Verificar um item agrupado pela Biblioteca verifica só a foto principal; a verificação do disco inteiro lê todos os arquivos.

## c. Importação do Google Fotos (Takeout) (1.3.0-beta.3)

Os `.json` do Takeout dão a data e o local de cada foto. O FotoAtlas lê esses `.json` **só para o catálogo**: nenhuma foto é alterada e nada é gravado dentro dos arquivos. Foto ou vídeo numa pasta do Takeout **sem o seu `.json`** aparece como **hora a confirmar**. Os zips do Takeout **só são lidos**: o FotoAtlas extrai o conteúdo para uma pasta pela cópia segura (prévia, conferência, nada sobrescrito) e nunca apaga os zips.

A pasta de demonstração `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Google Takeout` é gerada sozinha com `-DemoPersistente`. As fotos são sintéticas e **não têm data no EXIF**: a data vem só do `.json`.

| Onde | Arquivos | O que deve acontecer |
| --- | --- | --- |
| `Pasta\Takeout\Google Fotos\Viagem 2023` | `IMG_0001.jpg` + `IMG_0001.jpg.supplemental-metadata.json` | 22/07/2023 10:05 (horário de Brasília), com local |
| | `IMG_0002(1).jpg` + `IMG_0002.jpg(1).json` | 22/07/2023 11:30 |
| | `IMG_0003.jpg`, `IMG_0003-editado.jpg` + `IMG_0003.jpg.json` | as duas em 23/07/2023 06:00 |
| | `sem_json.jpg` | **hora a confirmar** |
| | `metadados.json` | do álbum: ignorado |
| `Zips` | `takeout-20240101T000000Z-001.zip` e `-002.zip` | álbum "Aniversário": 2 fotos, com os `.json` divididos entre os dois zips |

**c.1. Takeout em pasta.** Abra a demonstração (comando em "Antes de começar", com `v1.3.0-beta.3`). Cadastre a pasta `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Google Takeout\Pasta` (**Dispositivos › Adicionar dispositivo › Escolher uma pasta…**) e escaneie. Espere a conferência e a leitura das datas terminarem.

**c.2. Datas e locais.** Na **Biblioteca**, filtre pelo dispositivo "Pasta". Confira as datas da tabela. Clique no `IMG_0001.jpg`: nos detalhes, "Hora provável · do Google Fotos (.json do Takeout)" e a **Localização** preenchida. Em **Detalhes** aparece a data do Google Fotos entre as candidatas.

**c.3. Sem `.json`.** O `sem_json.jpg` aparece com **hora incerta** (e no filtro **Hora a confirmar**). Nos detalhes, em **Detalhes**, a linha "Google Fotos: Está numa pasta do Takeout sem o .json dela: a hora fica a confirmar."

**c.4. Zips: prévia.** Crie uma pasta vazia para o destino e cadastre as duas (a dos zips e a do destino), escaneando cada uma:
```powershell
New-Item -ItemType Directory -Path 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Destino Takeout'
```
`C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Google Takeout\Zips` e `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Destino Takeout`. No cartão "Zips", em **Mais opções › Extrair zip do Google Takeout…**, aparecem os dois zips marcados. Escolha **Para onde: Destino Takeout** e clique em **Ver prévia**: "Vai extrair 4 arquivos (…): 2 fotos e vídeos, 2 .json com datas e locais." e "Os zips só são lidos…". Clique em **Voltar** e em **Cancelar** uma vez para ver que nada acontece; depois repita e clique em **Extrair**.

**c.5. Zips: extração.** Em **Tarefas**, a extração termina com 4 arquivos. Confira a pasta criada:
```powershell
Get-ChildItem -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Destino Takeout' -Recurse -File | Select-Object FullName, Length | Format-Table -AutoSize
```
Ela tem `Google Fotos (Takeout)\Google Fotos\Aniversário\` com `IMG_0101.jpg`, `IMG_0102.jpg` e os dois `.json`. Na **Biblioteca**, as duas fotos aparecem em 09/03/2024, às 18:15 e 18:40 (o `.json` da segunda estava no outro zip).

**c.6. Os zips não mudaram.** Rode antes do c.5 e de novo depois; os dois resultados devem ser iguais:
```powershell
Get-ChildItem -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Google Takeout\Zips' -File | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.LastWriteTime, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
```

**c.7. Extrair de novo não sobrescreve.** Repita **Extrair zip do Google Takeout…** para o mesmo destino: a prévia avisa que os 4 nomes já existem e que eles ganham `_1`. Pode cancelar.

**c.8. Nenhuma foto mudou.** As fotos de "Pasta" continuam sem data no EXIF (o FotoAtlas não grava nada nelas). Com o ExifTool baixado pelo projeto:
```powershell
& 'C:\dev\fotoatlas\third_party\bin\exiftool\exiftool.exe' -DateTimeOriginal -GPSPosition 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Google Takeout\Pasta\Takeout\Google Fotos\Viagem 2023\IMG_0001.jpg'
```
Não aparece nenhuma das duas informações.

**Limitações conhecidas:** só os `takeout-….zip` aparecem para extrair. Pausar no meio de um vídeo grande do zip só pausa no fim daquele arquivo. A data do Google Fotos é "provável", não "confiável": às vezes o Google usa a data do envio.

## d. Mapa (1.3.0-beta.4)

Na **Biblioteca › Mapa**, as fotos e os vídeos com local aparecem no mapa, agrupados pela proximidade. O mapa **funciona sem internet**, com os contornos de países e estados que vêm com o FotoAtlas (Natural Earth). **Nenhum local sai do computador** a menos que você ligue o mapa online (OpenStreetMap) em **Configurações › Mapa**, e ligar pede confirmação mostrando exatamente o que é enviado.

A pasta de demonstração `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Viagens (mapa)` é gerada sozinha com `-DemoPersistente`. As fotos são sintéticas, com local gravado no EXIF:

| Pasta | Fotos | Onde |
| --- | --- | --- |
| `Rio` | 3 | Cristo Redentor (2) e Copacabana |
| `São Paulo` | 2 | Avenida Paulista |
| `Lisboa` | 2 | Belém e centro |
| `Tóquio` | 1 | Torre de Tóquio |
| `Fiji` | 2 | uma de cada lado da linha de data (179° L e 179° O) |
| `Sem local` | 2 | sem GPS: não aparecem no mapa |

**d.1. Cadastrar.** Abra a demonstração (comando em "Antes de começar", com `v1.3.0-beta.4`). Cadastre a pasta `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Viagens (mapa)` (**Dispositivos › Adicionar dispositivo › Escolher uma pasta…**) e escaneie. Espere a conferência e a leitura das datas terminarem.

**d.2. O mapa sem internet.** Na **Biblioteca**, filtre pelo dispositivo "Viagens (mapa)" e clique em **Mapa** (ao lado de Lista). Em cima: "10 fotos e vídeos com local · 2 sem local (não aparecem)". Embaixo, à direita: "Mapa sem internet: contornos de países e estados (Natural Earth)…". Aparecem os contornos dos países, com bolinhas: uma com **5** no Brasil (ou, conforme o tamanho da janela, **3** no Rio e **2** em São Paulo), uma com **2** em Lisboa, uma em Tóquio e as duas de Fiji, uma em cada ponta do mapa. Como o mapa dá a volta no mundo, com a janela larga os continentes se repetem nas laterais.

**d.3. Aproximar e mover.** Use a roda do mouse (aproxima onde está o ponteiro), os botões **+** e **−** à direita, e arraste para mover. Ao aproximar o Brasil, os contornos dos estados aparecem e a bolinha de 5 se separa em Rio (3) e São Paulo (2). Clique numa bolinha com número: o mapa aproxima até ela. Aproximando o Rio, o Cristo (2) e Copacabana (1) se separam. **Ver todos os locais** (o terceiro botão) volta a mostrar tudo. Arrastar para os lados dá a volta no mundo.

**d.4. Detalhes.** Clique numa bolinha sem número (uma foto só): abre o painel de detalhes daquela foto, com a **Localização**.

**d.5. Filtrar pela área.** Enquadre só o Brasil e clique em **Ver as fotos desta área**: a Biblioteca volta para a **Linha do tempo** com "5 itens" e o chip **Área do mapa**. Clicar no chip volta ao mapa; o **x** do chip tira o filtro. Com a área, dá para salvar o filtro (**Filtros salvos › Salvar este filtro…**) e ele volta igual.

**d.6. Linha de data.** Enquadre Fiji de modo que as duas fotos fiquem na tela (uma de cada lado da linha de data, no meio do Pacífico) e clique em **Ver as fotos desta área**: "2 itens".

**d.7. Mapa online só com confirmação.** Em **Configurações › Mapa**, ligue **Usar o mapa online (OpenStreetMap)**. Aparece "Ligar o mapa online?" explicando o que vai e o que não vai (os locais das fotos, os nomes dos arquivos e o catálogo nunca são enviados). Clique em **Cancelar**: continua desligado. Ligue de novo e confirme com **Ligar o mapa online**. Volte ao **Mapa**: com internet, aparecem as ruas e cidades do OpenStreetMap e, embaixo, "© colaboradores do OpenStreetMap". Sem internet (por exemplo, com o Wi-Fi desligado), continuam aparecendo os contornos.

**d.8. Desligar.** Volte em **Configurações › Mapa** e desligue: o **Mapa** volta a ser só os contornos, sem nenhum pedido à internet.

**d.9. Nenhuma foto mudou.** O FotoAtlas só lê o local das fotos. Com o ExifTool baixado pelo projeto, a posição continua igual à que foi gerada:
```powershell
& 'C:\dev\fotoatlas\third_party\bin\exiftool\exiftool.exe' -GPSPosition -n 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Viagens (mapa)\Rio\IMG_4001.JPG'
```
Deve mostrar `-22.9519 -43.2105`.

**Limitações conhecidas:** os contornos são simplificados (para achar onde as fotos foram tiradas, não para navegar); ruas e nomes de cidades só com o mapa online. As imagens do mapa online ficam só na memória e são baixadas de novo a cada abertura. Fotos sem local (muitas das recebidas por mensagem) não aparecem no mapa.

## Resultado

Anote o que não funcionou ou ficou confuso (número do passo + o que aconteceu) e mande na conversa. Quando tudo estiver aprovado, publicamos a 1.3.0 estável.
