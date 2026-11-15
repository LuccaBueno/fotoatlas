# Roteiro de teste — Fase 9 (Avançados)

Roteiro único para testar, em dezembro, tudo o que entrou nos pré-lançamentos `1.3.0-beta.N`. Ele cresce a cada item publicado. Depois do seu teste (e dos ajustes que você pedir), publicamos a **1.3.0 estável**.

Comandos para o Windows PowerShell, com caminhos completos. Tudo usa **dados de demonstração** (fotos sintéticas); nenhuma foto sua é lida.

| Item | Pré-lançamento | Estado |
| --- | --- | --- |
| 0. Pré-lançamentos (aviso e "Atualizar agora" só com versões estáveis) | entra junto com a `1.3.0-beta.1` | pronto para testar |
| a. Fotos parecidas | `1.3.0-beta.1` | em desenvolvimento |
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

## a. Fotos parecidas

_Em desenvolvimento: os passos entram aqui quando a `1.3.0-beta.1` for publicada._

## b. RAW+JPEG e Live Photos agrupados

_Não iniciado._

## c. Importação do Google Fotos (Takeout)

_Não iniciado._

## d. Mapa

_Não iniciado._

## Resultado

Anote o que não funcionou ou ficou confuso (número do passo + o que aconteceu) e mande na conversa. Quando tudo estiver aprovado, publicamos a 1.3.0 estável.
