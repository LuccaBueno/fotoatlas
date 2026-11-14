# 0008 — Acesso Win32 no core via FFI, com bindings próprios mínimos

- Status: aceita
- Data: 2026-10-26

## Contexto
O core precisa de:
- listagem com atributos (placeholders do OneDrive, reparse points) e sem `stat` extra;
- publicação sem sobrescrever (`MoveFileExW`);
- flush garantido;
- criação exclusiva (`CREATE_NEW`);
- espaço livre;
- resolver um volume pelo GUID.

O `dart:io` não expõe atributos nem `MoveFileExW`, e `Directory.list` + `stat` por arquivo é lento em 50 mil arquivos.

## Alternativas consideradas
- **`package:win32`** (BSD-3): cobertura enorme, mas é uma dependência grande para cerca de 14 funções.
- **Delegar ao helper**: cada arquivo passaria pelo pipe, e o protocolo crítico de cópia ficaria acoplado ao helper.
- **Só `dart:io`**: sem atributos e sem garantia de não sobrescrever num rename (no Windows, `File.rename` substitui o destino).

## Decisão
- `package:ffi` (BSD-3) + bindings escritos à mão em `lib/src/platform/win32/`, cobrindo: `FindFirstFileExW`, `FindNextFileW`, `FindClose`, `GetFileAttributesExW`, `CreateFileW`, `ReadFile`, `WriteFile`, `FlushFileBuffers`, `CloseHandle`, `MoveFileExW`, `GetDiskFreeSpaceExW`, `GetVolumePathNamesForVolumeNameW`, `GetVolumeNameForVolumeMountPointW`, `GetLastError`.
- **Nunca usar `File.rename`/`File.copy` do `dart:io`** em arquivos de usuário. O teste de arquitetura verifica isso.
- Fsync: o `RandomAccessFile.flush()` do Dart no Windows deve chamar `FlushFileBuffers`. Na Fase 5 isso será confirmado no código-fonte do SDK em uso. De qualquer forma, o caminho crítico da cópia usa `CreateFileW` + `WriteFile` + `FlushFileBuffers` direto via FFI, para não depender desse detalhe.
- Prefixo `\\?\` sempre que o caminho for absoluto.

## Atualização (2026-10-26, Fase 1)
- Também entraram `GetVolumePathNameW`, `FindFirstVolumeW`/`FindNextVolumeW`/`FindVolumeClose`, `GetVolumeInformationW` e `GetDriveTypeW` (listagem de volumes de reserva, sem o helper).
- **`GetLastError` via FFI não é 100% confiável**: medimos cerca de 1 em 2.000 enumerações devolvendo 0 em vez de `ERROR_NO_MORE_FILES` (18), mesmo com `isLeaf: true`. Regra adotada: só o código 18 encerra a listagem; qualquer outro valor (inclusive 0) refaz a listagem da pasta inteira (até 3 vezes) e, se persistir, vira erro daquela pasta. Assim, uma leitura duvidosa nunca vira "lista mais curta" (regra 10). Qualquer uso futuro de `GetLastError` no core segue o mesmo princípio: código inesperado = falha, nunca sucesso.
- Também medimos que o `Directory.listSync` do `dart:io` falha em caminhos acima de 260 caracteres, o que confirma o uso de `FindFirstFileExW` com `\\?\`.

## Atualização (2026-11-14, v1.2.1): nada de `isLeaf` em chamadas que esperam o disco
- **Problema:** o teste de desempenho do scan (atraso máximo do event loop principal < 100 ms) normalmente mede 15–23 ms, mas em runner lento da CI chegou a 90 ms e 118 ms (runs 43633788956 e 43638933920; nesta o scan levou 26,6 s em vez de ~4 s, ou seja, disco lento).
- **Causa:** todas as funções do kernel32 estavam declaradas com `isLeaf: true`. Durante uma chamada leaf a VM não consegue levar aquela thread a um ponto seguro, e a coleta de lixo é **do grupo de isolates inteiro** (o `Isolate.spawn` cria isolates no mesmo grupo, com heap compartilhado). Quando o isolate do catálogo ou o do scan precisava coletar lixo enquanto o scan estava preso num `FindNextFileW` esperando o disco, todos os isolates — inclusive o da interface — ficavam parados até a chamada voltar. A suspeita inicial (commits do SQLite com `synchronous=FULL`) não se confirmou: no pacote `sqlite3` só funções triviais são leaf; `sqlite3_step`, que faz o commit, não é, então a espera do disco no SQLite não segura a coleta.
- **Evidência:** experimento isolado (um isolate chamando `Sleep(150)` do kernel32, outro gerando lixo, o principal medindo um timer de 10 ms): com `isLeaf: true`, atraso máximo de 160 ms e até 6,4 s; sem `isLeaf`, 15–19 ms. A taxa de `GetLastError` zerado não muda (~1 em 1.000 nos dois casos, sempre 0, já tratado por `retryOnZeroError` e pela regra acima).
- **Decisão:** só `GetLastError` continua leaf (não espera nada). Todas as outras funções — listagem, volumes, abrir, ler, gravar, `FlushFileBuffers`, mover, criar/remover pasta — são chamadas normais. O custo extra de uma chamada normal (~dezenas de ns) é irrelevante perto de uma operação de disco. Um teste de arquitetura impede que `isLeaf` volte em outra função. O limite de 100 ms do teste de desempenho não foi alterado.
- O mesmo problema afetava a conferência e a cópia (um `ReadFile` lento num HD externo travava a interface); a correção vale para tudo.

## Consequências
- Licença BSD-3 (`ffi`).
- O código FFI fica concentrado e revisável, e cada função tem teste de integração no Windows.
- O core passa a ser **somente Windows**, o que é aceitável porque o produto é só para Windows. Os testes puramente lógicos continuam portáveis.
