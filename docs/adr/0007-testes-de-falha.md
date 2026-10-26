# 0007 — Estratégia de testes, incluindo testes de falha (kill)

- Status: aceita
- Data: 2026-10-26

## Contexto
A prioridade máxima é não perder arquivos, inclusive com interrupção abrupta (spec §2, §16 Fase 5, §17).

## Decisão

### Camadas
1. **Unitários** (`dart test`): identificação de fontes, regras de ausência, máquina de estados, templates, sanitização de nomes, estratégia de datas. Quando a lógica não depende do SO, a plataforma Win32 fica atrás de interfaces.
2. **Integração com o SO** (Windows, temp real): enumerador FFI, caminho longo, junctions (`mklink /J` não exige admin), permissão negada (`icacls /deny` numa pasta temp), conflito de nome, `MoveFileExW`.
3. **Integração via CLI**: o teste inicia `dart run bin/fotoatlas_cli.dart` com `FOTOATLAS_HOME` em temp e confere o banco e o disco.
4. **Falha (kill)**: a CLI tem pontos instrumentados (`crashpoint('copy.after_flush')`). Com `FOTOATLAS_CRASHPOINT=<nome>[:<n-ésima ocorrência>]`, ela imprime `CRASHPOINT <nome>` e **fica bloqueada**. O teste vê o marcador e chama `Process.kill()`, que no Windows vira `TerminateProcess`: sem `finally` e sem flush do Dart. Depois roda a recuperação **3 vezes seguidas** e confere que nenhum arquivo foi perdido nem sobrescrito, que a 2ª e a 3ª execução não mudam nada e que a origem ficou intacta (hash antes = depois).
   - Pontos mínimos (Fase 5): antes e depois de cada transição de estado, no meio da escrita do `.part`, entre o commit de `publishing` e o `MoveFileExW`, e entre o `MoveFileExW` e o commit de `published`.
   - Fase 1: o mesmo mecanismo no scan (kill no meio de um lote → retomar → contagem exata, sem duplicatas).
5. **Helper** (`dotnet test`): parsing do protocolo, regras de recusa de escrita e `volumes.list` contendo o volume do sistema.
6. **App** (`flutter test`): widgets com fakes do core. Na Fase 1, um `integration_test` cobre "a UI não trava": scan de 50 mil arquivos num worker, medindo a latência do event loop principal.

### Simulações (spec §17)
- Falta de espaço: VHD pequeno (CI, admin) e, localmente, um *fake* de `GetDiskFreeSpaceEx` na checagem prévia.
- Origem que some: renomear a pasta de fixture durante o teste.
- FAT32 e troca de letra: VHD criado com `diskpart` em temp. Roda só na CI (os runners são admin) ou com `FOTOATLAS_VHD_TESTS=1`; desligado por padrão na máquina local.

### Regras
- Fixtures sempre sintéticos (`tools/fixtures/`), gerados em `Directory.systemTemp.createTemp`.
- Um helper de teste aborta se algum caminho de trabalho não estiver dentro do temp do sistema.

## Consequências
- **Limitação declarada (R3)**: matar o processo não simula a perda do cache do SO nem um disco que mente sobre o flush. A mitigação é `FlushFileBuffers`, `MOVEFILE_WRITE_THROUGH`, `synchronous=FULL` e uma recuperação que sempre confere os hashes no disco.
- Os testes de integração e de falha rodam só no Windows (CI `windows-latest`).
