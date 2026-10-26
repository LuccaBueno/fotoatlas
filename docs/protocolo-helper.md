# Protocolo do helper nativo — v1

- Data: 2026-10-26 (Etapa 0)
- Processo: `fotoatlas_helper.exe` (C# .NET 10), iniciado pelo core (app ou CLI)
- Transporte: **JSON-lines** em stdin (pedidos) e stdout (respostas e eventos); stderr só para log de diagnóstico.

## 1. Regras de transporte

- UTF-8 **sem BOM**, uma mensagem JSON por linha terminada em `\n`, no máximo 1 MiB por linha.
- **Nenhum byte de arquivo passa pelo pipe.** Conteúdo de celular e miniaturas é gravado pelo helper em caminhos indicados pelo core (seção 6) e o hash é calculado no próprio helper.
- Inteiros até 2^53 vão como número JSON (tamanhos, seriais de 32 bits). Valores de 64 bits que podem passar disso (FILETIME) vão como **string decimal**.
- Caminhos de volume no formato Win32 (`E:\`, `\\?\Volume{…}\`). Caminhos no celular são sempre referenciados por `objectId` (opaco) e `name`.
- Campos desconhecidos são ignorados pelos dois lados (compatibilidade adiante).

## 2. Envelope

**Pedido** (core → helper)
```json
{"v":1,"id":"17","method":"volumes.list","params":{}}
```

**Resposta** (helper → core), exatamente uma por pedido
```json
{"v":1,"id":"17","ok":true,"result":{ }}
{"v":1,"id":"17","ok":false,"error":{"code":"device_locked","message":"…","retryable":true}}
```

**Evento de pedido** (zero ou mais antes da resposta: progresso, lotes)
```json
{"v":1,"id":"17","event":"progress","data":{"done":120,"total":900}}
```

**Evento espontâneo** (sem `id`)
```json
{"v":1,"event":"hello","data":{"protocol":1,"helperVersion":"0.1.0","pid":4242}}
{"v":1,"event":"device.arrived","data":{"deviceId":"…"}}
```

- O `id` é uma string única por sessão, escolhida pelo core.
- Cancelamento: `{"v":1,"id":"18","method":"system.cancel","params":{"target":"17"}}`. O pedido 17 responde com `ok:false`, `code:"cancelled"`.

## 3. Ciclo de vida

1. O core inicia: `fotoatlas_helper.exe --protocol 1 --parent-pid <pid> --cache-dir <dir>`.
2. O helper emite `hello`. O core confere `protocol == 1`; se for diferente, encerra o helper e mostra um erro de versão.
3. O helper encerra sozinho quando: o stdin fecha (EOF), chega `system.shutdown` ou o processo pai morre (vigiado por handle).
4. Se o processo cai ou fica 10 s sem responder a `system.ping`, o core mata e reinicia com espera crescente (1, 2, 4… até 30 s). Os pedidos em voo falham com `helper_crashed`, que o core trata como **falha de leitura, nunca como ausência** (regra 10).
5. Concorrência: pedidos podem rodar em paralelo, mas as chamadas WPD são serializadas por dispositivo.

## 4. Códigos de erro

| Código | Significado | `retryable` |
|---|---|---|
| `bad_request` | JSON inválido, método ou parâmetro desconhecido | não |
| `cancelled` | Cancelado a pedido | não |
| `not_found` | Volume, dispositivo ou objeto não existe (agora) | não |
| `access_denied` | Permissão negada | não |
| `device_locked` | Celular bloqueado | sim |
| `device_unauthorized` | Falta "Permitir acesso" / "Confiar neste computador" | sim |
| `device_disconnected` | Desconectado no meio da operação | sim |
| `io_error` | Erro de E/S (traz `win32Code`/`hresult` em `details`) | sim |
| `write_refused` | Caminho de escrita fora das regras da seção 6 | não |
| `already_exists` | Destino já existe (`CreateNew`) | não |
| `internal` | Exceção inesperada (detalhes no stderr) | sim |

## 5. Métodos

### 5.1. Sistema (Fase 1)

| Método | Params | Resultado |
|---|---|---|
| `system.ping` | — | `{"uptimeMs":1234}` |
| `system.info` | — | `{"helperVersion":"0.1.0","protocol":1,"os":"10.0.26200"}` |
| `system.cancel` | `{"target":"<id>"}` | `{}` |
| `system.shutdown` | — | `{}` e encerra |

### 5.2. Volumes e discos (Fase 1)

`volumes.list` → `{"volumes":[Volume]}`

```json
{
  "guidPath": "\\\\?\\Volume{3f2a…}\\",
  "mountPoints": ["E:\\"],
  "label": "Backup1",
  "fileSystem": "NTFS",
  "serial": 2882400001,
  "totalBytes": 2000398934016,
  "freeBytes": 812345678848,
  "driveType": "fixed",
  "isSystem": false,
  "isBoot": false,
  "physicalDisks": [
    {
      "diskNumber": 2,
      "serial": "WD-WX12A3456789",
      "model": "WDC WD20SPZX-22UA7T0",
      "sizeBytes": 2000398934016,
      "busType": "usb",
      "removableMedia": false,
      "identityConfidence": "reliable"
    }
  ]
}
```

- Implementação: `FindFirstVolumeW`/`FindNextVolumeW`, `GetVolumePathNamesForVolumeNameW`, `GetVolumeInformationW`, `GetDiskFreeSpaceExW`, `GetDriveTypeW`, `IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS` (volume → discos; pode haver mais de um) e `IOCTL_STORAGE_QUERY_PROPERTY` (`StorageDeviceProperty`: serial, modelo, barramento).
- `driveType`: `fixed`, `removable`, `network`, `cdrom`, `ram`, `unknown`. Volumes de rede e CD aparecem na lista, mas o core não oferece cadastrá-los no MVP (L5).
- `identityConfidence`: `reliable` = serial presente, sem cara de *placeholder* (não vazio, não só zeros/espaços, não igual ao de outro disco conectado); `weak` = falta serial, mas há modelo+tamanho; `unknown` = nada útil.
- Volumes sem letra (só GUID) também aparecem; volumes do sistema (EFI, Recuperação) vêm marcados e o core os esconde.
- A detecção de conexão/desconexão na Fase 1 é feita pelo core chamando `volumes.list` a cada 3 s. Um evento `volume.changed` pode substituir isso depois, sem quebrar o protocolo.

### 5.3. Celular — WPD (Fase 3)

| Método | Params | Resultado / eventos |
|---|---|---|
| `devices.list` | — | `{"devices":[{"deviceId","friendlyName","manufacturer","model","kind":"android\|iphone\|camera\|other","status":"ok\|locked\|unauthorized","storages":[{"storageId","name","totalBytes","freeBytes"}]}]}` |
| `devices.enumerate` | `{"deviceId","storageId","rootObjectId?"}` | eventos `entries` com `{"items":[{"objectId","parentObjectId","name","isFolder","size","modified":"<FILETIME str>\|null","persistentId?"}]}` em lotes de até 500; resultado `{"folders":N,"files":N,"errors":[…]}` |
| `devices.hashObject` | `{"deviceId","objectId","expectedSize?"}` | eventos `progress`; resultado `{"sha256":"<hex>","size":N}` |
| `devices.pullToFile` | `{"deviceId","objectId","destPath","expectedSize"}` | grava em `destPath` (regras da seção 6), calcula o SHA-256 durante a leitura, faz `FlushFileBuffers`; resultado `{"sha256":"<hex>","bytesWritten":N}` |

- Uma desconexão no meio devolve `device_disconnected`; o `.part` parcial fica como está e o core decide (recuperação).
- iPhone: `devices.list` inclui `"kind":"iphone"` para o app mostrar o aviso "Manter originais".

### 5.4. Miniaturas (Fase 4)

| Método | Params | Resultado |
|---|---|---|
| `thumbnails.get` | `{"path"` **ou** `"deviceId"+"objectId", "size":256, "outPath"}` | grava JPEG em `outPath` (dentro de `--cache-dir`, `CreateNew`); `{"width","height"}`. Usa `IShellItemImageFactory::GetImage`; se falhar, `not_found`/`io_error` e o core tenta o FFmpeg. |

## 6. Regras de escrita do helper (defesa em profundidade)

O helper **recusa** (`write_refused`) qualquer escrita que não cumpra todas as regras:

1. `devices.pullToFile`: `destPath` absoluto, com componente de pasta `.fotoatlas-tmp`, terminando em `.part` e sem `..` após a normalização.
2. `thumbnails.get`: `outPath` dentro do `--cache-dir` recebido na inicialização.
3. Sempre `FileMode.CreateNew` (nunca sobrescreve) e `FileShare.None` durante a escrita.
4. Nenhum método abre arquivo de origem com acesso de escrita; nenhum método apaga, move ou renomeia.

Testes do helper (`dotnet test`) cobrem cada regra de recusa.

## 7. Versionamento

- `protocol` sobe só em mudança incompatível. Campos e métodos novos não mudam a versão.
- O core e o helper são distribuídos juntos; a checagem do `hello` evita misturar versões em ambiente de desenvolvimento.
