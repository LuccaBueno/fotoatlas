# 0003 — Helper nativo em C# .NET 10, processo separado com JSON-lines

- Status: aceita
- Data: 2026-10-26

## Contexto
WPD (celulares), miniaturas do Shell e identificação de discos físicos são APIs COM/Win32 trabalhosas em Dart FFI. Uma falha nessas APIs (por exemplo, um driver MTP travado) não pode derrubar o app.

## Alternativas consideradas
- **Dart FFI + COM direto**: um só processo, mas um travamento do WPD congela o isolate ou o processo, e o COM em Dart é verboso.
- **C++**: binário menor e sem runtime, mas desenvolvimento mais lento e mais risco de bugs de memória. Não há motivo técnico forte para ele (spec §19).
- **Plugin Flutter nativo**: roda dentro do processo do app e não serve para a CLI.

## Decisão
- `native/fotoatlas_helper`: console app .NET 10 com `nullable enable` e `TreatWarningsAsErrors`. No MVP, sem dependências NuGet de runtime: só P/Invoke e COM com source generators (`[LibraryImport]`, `[GeneratedComInterface]`), mantendo o código compatível com Native AOT.
- Comunicação por JSON-lines em stdin/stdout (`docs/protocolo-helper.md`), com `System.Text.Json` em *source generation*.
- Nenhum byte de arquivo passa pelo pipe: hash e gravação em `.part` acontecem no helper, e o core confere tudo de forma independente.
- Testes com xUnit (Apache-2.0).

## Consequências
- O core funciona sem o helper: fontes de pasta e unidades já cadastradas continuam escaneáveis. Só a detecção de volumes, o celular e as miniaturas dependem dele.
- A forma de distribuição (self-contained × AOT) fica para a Fase 8 (R10).
- Na Fase 3, comparar num ADR próprio a biblioteca MediaDevices (MIT) com um interop COM nosso.
