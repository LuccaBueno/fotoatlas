# 0006 — Riverpod para o estado da interface

- Status: aceita
- Data: 2026-10-26

## Contexto
A UI consome muitos `Stream`s do core (progresso de scan, lista de fontes, conectividade) e precisa ser testável com widgets isolados.

## Alternativas consideradas
- **Provider**: mais simples, mas com menos garantias em tempo de compilação e escopo ligado à árvore de widgets.
- **Bloc**: verboso para este caso, já que os streams vêm prontos do core.
- **setState/ValueNotifier**: não escala para 6 telas com estado compartilhado.

## Decisão
- `flutter_riverpod` (MIT), na versão estável atual, **sem** geração de código (`riverpod_generator`) no início, para manter o build simples. Se a geração for adotada depois, entra por ADR.
- Um provider por serviço da fachada do core; `StreamProvider`/`Notifier` por tela; testes com `ProviderContainer` e *overrides* com fakes do core.

## Consequências
- Escolha recomendada pelo CLAUDE.md; licença MIT; mantido ativamente.
- Toda a lógica de negócio continua no core; os providers só fazem a adaptação para a UI.
