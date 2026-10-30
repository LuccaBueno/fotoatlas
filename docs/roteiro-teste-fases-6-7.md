# Roteiro de teste — Fases 6 (Reorganização) e 7 (Integridade)

Teste único das duas fases, só com dados sintéticos da demonstração (nada é lido de celular real nem de pastas pessoais). Comandos para o PowerShell, com caminhos completos.

Pasta da demonstração: `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente`

## Preparação

**0. Começar do zero** (com o app fechado):
```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\clean-temp.ps1
```

**1. Abrir a demonstração** (gera "HD bagunçado", "Integridade" e o Pixel simulado na primeira vez):
```powershell
cd C:\dev\fotoatlas
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\run-app.ps1 -DemoPersistente -CelularSimulado
```

## Fase 6 — Reorganizar

**2.** Dispositivos › **Adicionar dispositivo › Escolher uma pasta…** › `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\HD bagunçado`. Depois **Escanear › Tudo** e espere a conferência e a leitura das datas terminarem (acompanhe no Início).

**3.** No cartão do HD bagunçado: **Reorganizar…** › modelo **Por ano e momento**. A prévia deve mostrar:
- `2024\2024-07-13 14h03\`: `IMG_20240713_140300.jpg` (+ `.xmp`), `IMG_20240713_151000.jpg`, `IMG_20240713_162000.jpg`
- `2024\2024-08-20 09h30\`: `IMG_20240820_093000_1.jpg` (o nome já existia), `VID_20240820_094500.mp4`, `IMG_20240820_100000.jpg`
- `2024\2024-12-31 23h30\`: `IMG_20241231_233000.jpg` e `IMG_20250101_001500.jpg` (o momento passa da meia-noite e fica numa pasta só)
- `Sem data confirmada\foto_escaneada.jpg`
- 1 arquivo já está no lugar; 2 ficam onde estão (`lista de compras.txt` e `Thumbs.db`)

No Explorer, confira que nada mudou antes de confirmar.

**4.** Confirme. As pastas `Downloads antigos`, `Pendrive da tia` e `Velhas` continuam existindo, mesmo vazias.

**5.** Simule uma edição num arquivo movido:
```powershell
(Get-Item -LiteralPath 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\HD bagunçado\2024\2024-08-20 09h30\VID_20240820_094500.mp4').LastWriteTime = Get-Date
```

**6.** Feche o app e abra de novo com o comando do passo 1. Em Tarefas, clique em **Desfazer**. A prévia deve avisar que **1 arquivo mudou**. Confirme: os outros voltam ao lugar exato, e o vídeo fica esperando você escolher **Devolver mesmo assim** ou **Deixar onde está**.

**7.** Tarefas › **Remover pastas vazias…**: cada pasta aparece separada. Marque uma e confirme; só ela deve sair.

## Fase 7 — Integridade

**8.** Cadastre como pasta e escaneie (**Tudo**) as duas pastas abaixo. Espere a conferência terminar:
- `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Integridade\HD fotos`
- `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Integridade\HD cópia`

**9.** No cartão do HD fotos: **Mais opções (⋮) › Verificar integridade…**. A janela deve dizer "Vai ler 6 arquivos". Clique em **Verificar**. Em Tarefas deve aparecer **Concluída · 6 inalterados**.

**10.** Simule o dano no disco (troca 16 bytes de `HD fotos\2024\IMG_0003.jpg` e mantém a data; o script só mexe na pasta da demonstração):
```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\demo-danificar.ps1
```

**11.** Guarde uma "foto" dos arquivos para provar depois que a verificação só lê:
```powershell
$pasta = 'C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Integridade'
$antes = Get-ChildItem -LiteralPath $pasta -Recurse -File | ForEach-Object { "$((Get-FileHash -LiteralPath $_.FullName).Hash) $($_.LastWriteTimeUtc.Ticks) $($_.FullName)" }
```

**12.** Verifique o HD fotos de novo. Deve aparecer:
- em Tarefas, "5 inalterados · 1 possivelmente corrompido";
- em **Possivelmente corrompidos (1)**, o arquivo `IMG_0003.jpg`, com a outra cópia `HD cópia › Backup 2024 › foto_3.jpg` ("no mesmo disco");
- no Início, o aviso com **Ver e restaurar**.

Depois, na mesma janela do PowerShell, confira que nada mudou. O resultado deve ser `True`:
```powershell
$depois = Get-ChildItem -LiteralPath $pasta -Recurse -File | ForEach-Object { "$((Get-FileHash -LiteralPath $_.FullName).Hash) $($_.LastWriteTimeUtc.Ticks) $($_.FullName)" }
$null -eq (Compare-Object $antes $depois)
```

**13.** Clique em **Restaurar desta cópia…**. A prévia deve dizer "Vai gravar: HD fotos › 2024 › IMG_0003_1.jpg", e o arquivo ainda não deve existir no Explorer. Clique em **Restaurar (cópia conferida)**. Depois disso, `IMG_0003.jpg` (danificado e intacto) e `IMG_0003_1.jpg` (a cópia boa) ficam lado a lado em `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\Integridade\HD fotos\2024`.

**14.** Simule uma edição de verdade (conteúdo e data mudam):
```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\fotoatlas\tools\scripts\demo-danificar.ps1 -Arquivo 'HD fotos\2024\IMG_0005.jpg' -Editar
```
Verifique o HD fotos de novo. Deve dar "5 inalterados · 1 editado", e nada novo em Possivelmente corrompidos.

**15. Celular, só a pedido:**
- adicione o **Pixel de Teste** (Adicionar dispositivo), escaneie (**Tudo**) e espere a conferência (leva uns 3 s por arquivo);
- no cartão dele, use **⋮ › Verificar integridade… (lê o celular de novo, devagar)**. Deve aparecer o aviso de leitura lenta;
- comece a verificação e, em Tarefas, clique em **Pausar** e depois em **Continuar**;
- feche o app no meio da verificação e abra de novo (comando do passo 1): ela aparece "Esperando · Interrompida…";
- clique em **Continuar** e espere concluir sem repetir arquivos.

**16. Verificação periódica:** em Configurações › Verificação periódica, ela deve estar ligada, com 90 dias. Para ver a periódica rodar agora:
- feche o app e rode:
  ```powershell
  cd C:\dev\fotoatlas\packages\fotoatlas_core
  dart run bin/fotoatlas_cli.dart --home "C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente\catalogo" --no-helper verify schedule --every 0
  ```
- abra o app de novo (comando do passo 1) e espere uns 2 minutos;
- em Tarefas deve aparecer "Verificação periódica: …" só com as pastas e discos, **sem o Pixel**;
- no fim, volte o intervalo para **90 dias** em Configurações.

## Nota sobre "Encerramento: etapas que estouraram o prazo: hash"

Essa linha aparece nos testes automáticos do core, mas **não é uma falha**: o teste "tarefas em andamento" (`test/shutdown_test.dart`) passa e simula de propósito uma leitura do celular travada para sempre (`stallHash = true`).
O encerramento abandona essa etapa depois do prazo, como define o ADR 0013 (fechar o app sempre funciona). Nada foi corrigido porque o comportamento é o esperado; a linha é só um aviso de diagnóstico do `TestEnv.close`.
