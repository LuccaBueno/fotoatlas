# 0019 — Instalador para Windows, atualização e desinstalação

- Status: aceita
- Data: 2026-10-31

## Contexto
A Fase 8 (spec §16) distribui o FotoAtlas para quem não tem Flutter, .NET nem as ferramentas de desenvolvimento. Pedidos do usuário (2026-10-31): instalador com ExifTool e FFmpeg incluídos; atalhos no menu Iniciar e na área de trabalho; ícone do app feito da logo do menu lateral (globo com lupa) na janela, na barra de tarefas, no executável e no instalador; **atualizar nunca pode apagar o catálogo nem as configurações**; **desinstalar não apaga o catálogo sem perguntar**. O formato (Inno Setup) foi escolhido no planejamento (Q3).

## Decisão

### Inno Setup 6, por usuário (`installer\fotoatlas.iss`)
- `PrivilegesRequired=lowest`: instala em `C:\Users\<usuário>\AppData\Local\Programs\FotoAtlas`, sem pedir permissão de administrador. O catálogo também é por usuário, então quem instala é quem usa.
- `AppId` fixo: uma versão nova reconhece a instalada e instala por cima, na mesma pasta.
- O instalador só grava na pasta do programa, nos atalhos e no registro de desinstalação do usuário. **O catálogo e as configurações** (`C:\Users\<usuário>\AppData\Roaming\FotoAtlas`, com os backups) e o cache de miniaturas (`C:\Users\<usuário>\AppData\Local\FotoAtlas`) ficam fora da pasta do programa, e o script não tem nenhuma instrução que grave ou apague neles. Na atualização, `[InstallDelete]` limpa só `{app}\data` e `{app}\tools`, para não sobrarem arquivos de versões velhas (ex.: uma ExifTool antiga).
- Schema novo numa atualização: o próprio app já faz backup antes de migrar (`pre-migracao-vN-….db`) e recusa catálogo de versão mais nova (ex.: depois de voltar para um instalador antigo), sem modificá-lo.
- **App aberto:** `AppMutex=FotoAtlas.App.Aberto` (o executável cria o mutex em `app\windows\runner\main.cpp`). Com o app aberto, o instalador e o desinstalador pedem para fechá-lo; no modo silencioso, desistem sem mudar nada. `CloseApplications=no`: o FotoAtlas nunca é fechado à força no meio de uma cópia.
- **Desinstalar:** remove o programa e os atalhos. No fim, se a pasta do catálogo ou do cache existir, pergunta se quer apagá-las, explicando que as fotos não estão lá e que reinstalar continua de onde parou. O botão padrão é **Não**, e no modo silencioso a resposta é sempre Não. Com **Sim**, as pastas vão para a **Lixeira** (`Microsoft.VisualBasic.FileIO.FileSystem.DeleteDirectory` com `SendToRecycleBin`), nunca são apagadas de vez; se algo não puder ir para a Lixeira, fica onde está e o desinstalador avisa.
- Textos em PT-BR (`BrazilianPortuguese.isl`, com as mensagens de app aberto e de confirmação reescritas em linguagem simples).

### Conteúdo do pacote (`tools\scripts\build-installer.ps1`)
- App Flutter em release, com `--dart-define=FOTOATLAS_VERSION=<versão>` (Configurações › Sobre o FotoAtlas mostra a versão e a pasta do catálogo).
- Helper publicado como **executável único autocontido** (`--self-contained -p:PublishSingleFile=true -p:PublishTrimmed=true`, ~14 MB): não precisa do .NET instalado. Native AOT foi descartado: exige o linker do Visual Studio no PATH na hora do build e não traz ganho relevante aqui. O projeto já é `IsAotCompatible` com avisos tratados como erro, então o trimming não remove nada usado; os testes do core com o helper real passam com o executável publicado.
- ExifTool 13.60 e FFmpeg LGPL (versões e SHA-256 fixados no `get-tools.ps1`, ADR 0004 e 0005) em `{app}\tools\exiftool` e `{app}\tools\ffmpeg`, onde o core já procura (`ExternalTools.locate`). O helper fica ao lado do executável (`HelperClient.locate`).
- `LICENSE.txt` e `AVISOS-DE-TERCEIROS.txt` (ExifTool, FFmpeg LGPL com o link do código-fonte exato, Flutter, SQLite, .NET, Inno Setup).
- O script confere o pacote antes de gerar o instalador (faltando uma peça, para) e recusa arquivos `.db`, `.log` e `.pdb`.

### Runtime do Visual C++ estático
O executável e o plugin `file_selector_windows` dependiam de `MSVCP140.dll`/`VCRUNTIME140.dll`, que uma máquina limpa pode não ter. Empacotar essas DLLs (licença de redistribuição da Microsoft, fora da lista MIT/BSD/Apache/LGPL) exigiria aprovação. Em vez disso, `app\windows\CMakeLists.txt` compila o executável e os plugins com o runtime estático (`/MT`): `dumpbin /dependents` não mostra mais nenhuma DLL do runtime. O `flutter_windows.dll` e o `sqlite3.dll` já não dependiam dele. Os plugins conversam com o motor pela API C do Flutter, então cada módulo ter o seu runtime não causa problema.

### Ícone (`app\tool\gen_app_icon.dart`)
- Gerado a partir da mesma logo do menu lateral: `Icons.travel_explore` (Material Icons, Apache 2.0) na cor primária do tema, sobre um quadrado arredondado na cor da superfície, legível em barra de tarefas clara ou escura. Tamanhos de 16 a 256 px (BMP 32 bits até 128 px, PNG em 256 px), renderizados um a um.
- Um só arquivo (`app\windows\runner\resources\app_icon.ico`) serve à janela, à barra de tarefas e ao executável (recurso `IDI_APP_ICON`), ao instalador (`SetupIconFile`) e à entrada em Aplicativos instalados (`UninstallDisplayIcon`). Versionado; para gerar de novo: `flutter test tool\gen_app_icon.dart` na pasta `app`.

### Testes
- `app\test\distribution_test.dart`: ícone com todos os tamanhos; o gerador usa a logo do menu; versão nas Configurações; regras do `.iss` (mutex igual ao do executável, sem fechar à força, `AppId` fixo, por usuário, atalhos, nenhuma exclusão fora de `{app}`, pergunta com padrão Não e Lixeira).
- `tools\scripts\test-installer.ps1` (job "Instalador" da CI, num runner limpo e descartável): instala, confere arquivos, atalhos, ícone do executável, ExifTool/ffprobe/helper funcionando da pasta instalada e o app abrindo com o helper instalado; tenta atualizar com o app aberto (tem de recusar); atualiza 0.8.0 → 0.8.1 e confere o catálogo **byte a byte**; abre a versão nova com o catálogo antigo; desinstala e confere que o programa e os atalhos saíram e o catálogo ficou idêntico. O script recusa rodar fora da CI (ou sem `-MaquinaDeTeste`) e recusa se já houver um FotoAtlas instalado ou um catálogo na conta.

## Consequências
- O instalador tem ~100 MB, a maior parte do FFmpeg (ffmpeg.exe e ffprobe.exe estáticos).
- Sem assinatura de código: o Windows SmartScreen avisa na primeira execução ("O Windows protegeu o computador" → "Mais informações" → "Executar assim mesmo"). Assinar exige um certificado pago; fica para depois.
- Sem atualização automática: o usuário baixa a versão nova do GitHub e instala por cima.
- O caminho "Sim, apagar" da desinstalação não tem teste automático (o modo silencioso sempre responde Não); fica no roteiro de teste manual.
