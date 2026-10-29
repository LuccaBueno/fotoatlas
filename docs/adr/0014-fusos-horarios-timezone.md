# 0014 — Fusos horários com o pacote `timezone` (base IANA embutida)

- Status: aceita
- Data: 2026-10-29

## Contexto
A spec (§8, §8.1) pede o instante real (UTC) **e** a hora local vivida de cada foto, com fuso padrão configurável (America/Sao_Paulo). Fotos sem fuso no EXIF precisam ser convertidas pelo fuso *naquela data*: São Paulo teve horário de verão até 2019 (−02:00 no verão), então "−3 h fixo" erraria uma hora em anos de fotos. O Dart só conhece o fuso da própria máquina e o UTC.

## Alternativas consideradas
- **Deslocamento fixo por configuração** (ex.: −03:00): simples, mas erra todas as fotos de verão até 2019.
- **Fuso da máquina** (`DateTime.toLocal`): depende do Windows do usuário e não deixa escolher outro fuso.
- **Consultar o Windows via FFI** (`SystemTimeToTzSpecificLocalTimeEx`): a base do Windows não tem todo o histórico e mudaria a resposta conforme a atualização do sistema.
- **`package:timezone`** (BSD-2-Clause, mantido pela equipe do Dart/Flutter): base IANA completa embutida no código.

## Decisão
`timezone` 0.11.x no core, com `data/latest.dart` (todas as zonas, histórico completo), carregado na primeira conversão. Usado só para converter (nenhum acesso à rede: a dependência transitiva `http` não é usada pelo core).

## Consequências
- Licença BSD-2-Clause (permitida).
- Uma data local inexistente (começo do horário de verão) é avançada pelo pacote; uma ambígua (fim) fica com o primeiro deslocamento.
- A base fica congelada na versão do pacote: mudanças futuras de fuso exigem atualizar a dependência.
- Teste: 01/12/2018 10:00 em São Paulo → −02:00; 01/12/2024 → −03:00.
