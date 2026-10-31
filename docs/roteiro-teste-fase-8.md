# Roteiro de teste — Fase 8 (instalador)

Teste do instalador no seu computador: instalar, conferir os ícones e as ferramentas, atualizar e desinstalar. Comandos para o Windows PowerShell, com caminhos completos.

**Sobre os dados:** abrir o FotoAtlas instalado pelo atalho usa o catálogo de verdade, em `C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas`. Hoje essa pasta não existe; o teste a cria vazia. **Não cadastre dispositivos nela**: para ver fotos, o passo 6 abre o app instalado com o catálogo da demonstração (`C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\catalogo`). No passo 12 essa pasta de teste vai para a Lixeira.

A mesma sequência roda sozinha na CI, numa máquina limpa (job "Instalador", com `tools\scripts\test-installer.ps1`).

## Preparação

**0.** Feche o FotoAtlas, se estiver aberto.

**1. Gerar os dois instaladores** (a versão 0.8.1 serve só para testar a atualização; cada um leva alguns minutos):
```powershell
cd C:\dev\fotoatlas
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\build-installer.ps1 -Versao 0.8.0
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\build-installer.ps1 -Versao 0.8.1
```
Resultado: `C:\dev\fotoatlas\dist\FotoAtlas-0.8.0-instalador.exe` e `C:\dev\fotoatlas\dist\FotoAtlas-0.8.1-instalador.exe` (cerca de 100 MB cada).

**2.** Veja o ícone dos instaladores no Explorer (globo com lupa, não o ícone padrão):
```powershell
explorer.exe C:\dev\fotoatlas\dist
```

## Instalar

**3.** Abra o instalador 0.8.0:
```powershell
& 'C:\dev\fotoatlas\dist\FotoAtlas-0.8.0-instalador.exe'
```
Confira: textos em português; **nenhum pedido de permissão de administrador**; a opção "Criar um atalho na área de trabalho" vem marcada. Se aparecer "O Windows protegeu o computador", use **Mais informações › Executar assim mesmo**. Na última tela, deixe "Abrir o FotoAtlas" marcado e clique em **Concluir**.

**4.** Confira o ícone do FotoAtlas (globo com lupa) em: atalho na área de trabalho, menu Iniciar (procure "FotoAtlas"), canto da janela e barra de tarefas.

**5.** No FotoAtlas: **Configurações**, role até o fim:
- **Sobre o FotoAtlas:** "Versão 0.8.0" e "Catálogo e configurações: C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas".
- **Leitura dos dados das fotos:** "ExifTool: encontrado" e "FFmpeg: encontrado" (vêm no instalador).

Feche o FotoAtlas.

**6. O app instalado com a demonstração** (fotos sintéticas; não usa o catálogo de verdade):
```powershell
$env:FOTOATLAS_HOME = 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\catalogo'
$env:FOTOATLAS_DEMO = 'persistente'
& 'C:\Users\Lucca-PC\AppData\Local\Programs\FotoAtlas\fotoatlas.exe'
```
A faixa "Modo demonstração" aparece. Na **Biblioteca**, as fotos e os vídeos da demonstração aparecem com miniaturas; os vídeos mostram a duração (FFmpeg). Feche o FotoAtlas e **feche esta janela do PowerShell** (as duas variáveis valem só nela). Abra uma janela nova do PowerShell para continuar.

## Atualizar

**7. Com o app aberto, a atualização tem de esperar.** Abra o FotoAtlas pelo menu Iniciar e rode:
```powershell
& 'C:\dev\fotoatlas\dist\FotoAtlas-0.8.1-instalador.exe'
```
Ao clicar em Instalar, deve aparecer "O FotoAtlas está aberto. Feche o FotoAtlas…". Clique em **Cancelar** e confirme a saída do instalador. O FotoAtlas continua aberto, sem ter sido fechado à força. Feche-o.

**8. Guarde uma "foto" da pasta do catálogo** (com o FotoAtlas fechado):
```powershell
$cat = 'C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas'
$antes = Get-ChildItem -LiteralPath $cat -Recurse -File | ForEach-Object { "$((Get-FileHash -LiteralPath $_.FullName).Hash) $($_.FullName)" }
$antes
```

**9. Atualize:** rode de novo o instalador 0.8.1 (comando do passo 7). Ele vai direto para a pasta já instalada. Na última tela, **desmarque "Abrir o FotoAtlas"** antes de clicar em Concluir (abrir o app atualiza o catálogo e atrapalharia a comparação). Depois, na **mesma janela** do PowerShell:
```powershell
$depois = Get-ChildItem -LiteralPath $cat -Recurse -File | ForEach-Object { "$((Get-FileHash -LiteralPath $_.FullName).Hash) $($_.FullName)" }
@(Compare-Object $antes $depois).Count -eq 0
```
Deve mostrar `True`: a atualização não mudou nenhum byte do catálogo nem das configurações.

**10.** Abra o FotoAtlas pelo menu Iniciar: **Configurações › Sobre o FotoAtlas** deve mostrar "Versão 0.8.1". Os atalhos e os ícones continuam os mesmos.

## Desinstalar

**11. Desinstalar mantendo o catálogo.** Com o FotoAtlas ainda aberto, vá em **Configurações do Windows › Aplicativos › Aplicativos instalados › FotoAtlas › Desinstalar**:
- Deve aparecer "O FotoAtlas está aberto". Feche o FotoAtlas e clique em **OK**.
- A confirmação diz que as fotos não são tocadas e que o catálogo não é apagado agora. Confirme.
- No fim, a pergunta "Quer apagar também o catálogo, as configurações e as miniaturas?" vem com **Não** selecionado. Clique em **Não**.

Confira (deve mostrar `False`, `False`, `False`, `True`):
```powershell
Test-Path -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Programs\FotoAtlas\fotoatlas.exe'
Test-Path -LiteralPath 'C:\Users\Lucca-PC\Desktop\FotoAtlas.lnk'
Test-Path -LiteralPath 'C:\Users\Lucca-PC\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\FotoAtlas.lnk'
Test-Path -LiteralPath 'C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas\catalog.db'
```
Se a sua área de trabalho estiver no OneDrive, o atalho fica em `C:\Users\Lucca-PC\OneDrive\Desktop` (ou `Área de Trabalho`); confira lá.

**12. Reinstalar e desinstalar mandando o catálogo de teste para a Lixeira.** Instale o 0.8.1 de novo (comando do passo 7), abra pelo menu Iniciar e veja que é o mesmo catálogo (Configurações › Sobre). Feche e desinstale de novo, agora respondendo **Sim** na pergunta final. Deve aparecer "O catálogo, as configurações e as miniaturas foram para a Lixeira." Confira:
```powershell
Test-Path -LiteralPath 'C:\Users\Lucca-PC\AppData\Roaming\FotoAtlas'
```
Deve mostrar `False`, e a pasta "FotoAtlas" deve estar na Lixeira (pode esvaziá-la: era só o catálogo vazio deste teste).

## Opcional: máquina limpa de verdade

Se o Windows Sandbox estiver ativado (Windows 11 Pro: "Ativar ou desativar recursos do Windows" › Windows Sandbox), copie `C:\dev\fotoatlas\dist\FotoAtlas-0.8.1-instalador.exe` para dentro dele, instale e abra: o FotoAtlas deve abrir sem pedir nenhum outro programa (nem .NET, nem Visual C++).
