# 0009 — Identificação de fontes por pontuação

- Status: aceita
- Data: 2026-10-26

## Contexto
A spec §6 lista os identificadores por ordem de confiança: marcador, GUID do volume, serial do volume e serial do disco físico. Na prática:
- o GUID é estável no mesmo PC, mas muda em outro PC;
- o serial do volume muda ao formatar e pode se repetir em discos clonados;
- o serial do disco físico em gavetas USB costuma faltar ou ser falso (R1).

## Decisão
- Pontuação combinada (tabela em `arquitetura.md` §3.5):
  - ≥ 60 pontos e um só candidato → reconhece sozinho;
  - vários candidatos ≥ 60 → o melhor vence só com folga de 40+ pontos (ex.: GUID já confirmado); senão, pergunta;
  - empate, ou pontuação entre 30 e 59 → **pergunta ao usuário**;
  - abaixo disso → trata como dispositivo novo.
- A letra da unidade nunca entra na identidade; os caminhos ficam relativos à raiz da fonte.
- O marcador `.fotoatlas-id` vem desligado por padrão e só é gravado com autorização explícita, porque é uma escrita no dispositivo.
- A cobertura "discos diferentes" exige identidades de disco `reliable` e diferentes, ou confirmação manual (`physical_disks.user_confirmed`).
- Celular: ID do dispositivo WPD + nome amigável.

## Consequências
- A troca de letra é transparente (critério da Fase 1). Isso é testado com dados de volume simulados e, na CI, com VHD.
- Em casos ambíguos o app pergunta, em vez de adivinhar.
- Os pesos podem ser calibrados com testes, sem mudar o schema.
