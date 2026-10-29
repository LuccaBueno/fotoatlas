# 0012 — Celular pelo WPD, somente leitura

- Status: aceita
- Data: 2026-10-27 (Fase 3)

## Contexto
Android e iPhone aparecem no Windows como dispositivos portáteis (WPD/MTP), não como unidades: não há caminho Win32, os IDs de objeto do Android mudam entre sessões, a data pode faltar e a leitura pelo USB é lenta. Um travamento do driver não pode derrubar o app, e nada pode ser gravado no celular (regras 2 e 4).

## Alternativas consideradas
- **Biblioteca MediaDevices (MIT)**: madura, mas usa interop COM clássico (não compatível com AOT) e expõe também gravação, exclusão e movimentação — teríamos de confiar em não chamá-las.
- **Shell (`IShellFolder` sobre "Este Computador")**: dá caminhos "amigáveis", mas é mais lento, depende da UI do Explorer e também permite copiar/apagar.
- **Interop próprio mínimo** com `[GeneratedComInterface]` (escolhida).

## Decisão
- **Interop gerado em compilação** (`FotoAtlas.Helper/Devices/Wpd/WpdInterop.cs`), com GUIDs e ordem da vtable conferidos com `portabledeviceapi.idl`/`portabledevicetypes.idl` (mingw-w64). **Só os métodos de leitura são declarados**; quando a vtable obriga a ocupar um slot de escrita (`SendCommand`, `SetValues`, `Delete`, `CreateResource`…), ele vira `Reserved_*` sem parâmetros e nunca é chamado. Um teste (`InteropSoTemMetodosDeLeitura`) falha se aparecer qualquer método fora da lista de leitura.
- A sessão é aberta com `WPD_CLIENT_DESIRED_ACCESS = GENERIC_READ`: o próprio driver recusa gravações.
- Pendrives e cartões que o Windows também expõe pelo WPD (WpdFs, protocolo `MSC`) ficam fora da lista de celulares — eles já são tratados como unidades.
- **Protocolo** (`docs/protocolo-helper.md` §5.3): `devices.list`, `devices.listChildren` (uma pasta por pedido, em lotes) e `devices.hashObject` (SHA-256 calculado dentro do helper; nenhum byte de arquivo passa pelo pipe). Chamadas serializadas por aparelho; se o aparelho está ocupado (ex.: conferindo um vídeo), `devices.list` devolve a última situação conhecida em vez de esperar.
- **Situação do aparelho**: sem armazenamento visível (ou todos com capacidade 0) = `locked` (Android: desbloquear e escolher "Transferência de arquivos") ou `unauthorized` (iPhone: "Confiar"); `E_ACCESSDENIED` ao abrir = `unauthorized`.
- **Identidade** (ADR 0009): serial do aparelho (`WPD_DEVICE_SERIAL_NUMBER`) quando houver; senão o ID WPD (PnP). O ID WPD novo (outra porta USB) é aprendido quando o serial confirma. O celular vira um disco físico próprio (`bus_type = 'mtp'`; confiável só com serial), então cópia celular ↔ HD conta como backup independente quando o HD também tem identidade confiável (ver a atualização no fim).
- **Scan no core** (`PhoneScanLister`): a raiz da fonte lista os armazenamentos como pastas (L7). Checkpoint por pasta em `scan_dirs`, como no disco. O ID de cada pasta fica em cache; se um ID antigo não vale mais (outra sessão), o caminho é refeito a partir da raiz (`PhonePathResolver`). Exclusões: `Android/data`, `Android/obb`, `.thumbnails`. O scan e o hash do celular rodam no isolate principal: o trabalho pesado é do helper, e ao core só chegam lotes de JSON.
- **Desconexão, bloqueio ou helper fora do ar** → scan `interrupted` (retomável) e arquivos da conferência continuam `pending`; **nunca** `missing` nem `error` (regras 9 e 10). Erro de uma pasta → pasta `error`, e nada abaixo dela vira ausente.
- **Incremental**: tamanho + data do WPD. Se o aparelho não informa a data, tamanho + caminho decidem (refazer o hash de tudo pelo USB a cada scan seria inviável). Na cópia (Fase 5) o conteúdo é relido e conferido de qualquer forma.
- **Celulares simulados** (`--fake-devices PASTA`, ou `FOTOATLAS_FAKE_DEVICES`): backend do helper que lê um JSON por aparelho, com "desplugar" (apagar o arquivo), IDs que mudam a cada processo e falhas injetáveis. Usado nos testes da CI e no `run-app.ps1 -CelularSimulado`; só lê a pasta.

## Consequências
- Não há como testar o WPD real na CI (não existe celular virtual no Windows). A CI cobre: o interop real com objetos em memória do Windows (saco de propriedades, coleção de chaves, gerenciador, `PortableDeviceFTM`), a lista de métodos permitidos e todo o resto com celulares simulados pelo helper real. A navegação e a leitura num aparelho real ficam para o teste do usuário, somente leitura.
- Retomar após reconectar custa algumas listagens extras (refazer o caminho até a pasta pendente).
- Datas do WPD em hora local do aparelho são convertidas para FILETIME UTC pelo fuso do PC; só servem para o incremental. A data da foto vem do EXIF (Fase 4).

## Atualização (2026-10-28) — teste com celular real (Samsung SM-M546B, Android, somente leitura)
- **Stream liberado na hora.** No aparelho real, só o primeiro arquivo de cada vez era conferido; os seguintes falhavam em `GetStream` com `0x800700AA` (`ERROR_BUSY`): 6.575 de 6.596 na primeira conferência. Causa: o `IStream` vinha pelo wrapper gerado (`[GeneratedComInterface]`), e o `ComObject.FinalRelease()` não soltava a referência nativa — o stream só fechava quando o coletor de lixo rodava, e o MTP aceita uma transferência por vez (os 21 que passaram devem ter coincidido com coletas). Agora `GetStream` devolve o ponteiro cru, a leitura chama só `ISequentialStream::Read` (posição 3 da vtable, `NativeReadStream`) e o `Release` é explícito no `finally`; o helper registra no stderr se sobrar referência. Teste com um objeto COM falso confere que só o `Read` é chamado e que a referência é devolvida uma vez. Depois da correção: 0 erros em 6.575 arquivos (~106 GB).
- A leitura vai até `Read` devolver 0 bytes (como o exemplo do WPD), em vez de parar na primeira leitura curta (`S_FALSE`).
- O helper registra no stderr o passo que falhou numa conferência (`Transfer`, `GetStream`, `Read`, `SizeAndDate`) e o HRESULT, sem nomes de arquivo.
- **Celular × disco de identidade fraca**: o celular é um disco próprio, mas a cópia num SSD NVMe com serial zerado (comum) continua 🟢 "cópia conferida", não 🔵: disco fraco nunca conta como independente (R1, ADR 0009). O app explica isso ("não dá para confirmar que estão em discos diferentes") em vez de deixar parecer erro.
- **Scan de uma pasta só** (`scans.start(fonte, folder: …)`, CLI `scan start FONTE --folder P`): útil no celular, onde ler o aparelho inteiro pelo USB demora. O scan fica `partial`, só confirma ausências dentro da pasta, e a comparação marca "Resultado incompleto" para qualquer pasta do escopo fora do que já foi escaneado.
