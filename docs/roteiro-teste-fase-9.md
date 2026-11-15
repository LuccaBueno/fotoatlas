# Roteiro de teste — Fase 9 (Avançados)

Roteiro único para testar, em dezembro, tudo o que entrou nos pré-lançamentos `1.3.0-beta.N`. Ele cresce a cada item publicado. Depois do seu teste (e dos ajustes que você pedir), publicamos a **1.3.0 estável**.

Comandos para o Windows PowerShell, com caminhos completos. Tudo usa **dados de demonstração** (fotos sintéticas); nenhuma foto sua é lida.

| Item | Pré-lançamento | Estado |
| --- | --- | --- |
| 0. Pré-lançamentos (aviso e "Atualizar agora" só com versões estáveis) | `1.3.0-beta.1` | pronto para testar |
| a. Fotos parecidas | `1.3.0-beta.1` | pronto para testar |
| b. RAW+JPEG e Live Photos agrupados | `1.3.0-beta.2` | não iniciado |
| c. Importação do Google Fotos (Takeout) | `1.3.0-beta.3` | não iniciado |
| d. Mapa | `1.3.0-beta.4` | não iniciado |

## Antes de começar

**Sobre o catálogo de verdade.** O FotoAtlas instalado (1.2.1) usa o catálogo em `C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas`. As versões 1.3.0-beta acrescentam tabelas ao catálogo; um catálogo aberto por uma beta **não abre mais na 1.2.1** (ela recusa catálogo mais novo, sem modificá-lo). Antes de mudar, o FotoAtlas guarda uma cópia conferida em `C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas\backups\pre-migracao-v7-<data>.db`. Por isso, este roteiro testa tudo com o catálogo da demonstração e **nunca** abre uma beta com o catálogo de verdade.

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

## b. RAW+JPEG e Live Photos agrupados

_Não iniciado._

## c. Importação do Google Fotos (Takeout)

_Não iniciado._

## d. Mapa

_Não iniciado._

## Resultado

Anote o que não funcionou ou ficou confuso (número do passo + o que aconteceu) e mande na conversa. Quando tudo estiver aprovado, publicamos a 1.3.0 estável.
