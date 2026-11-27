# 0028 — Backup do celular em um assistente e "Pergunte ao FotoAtlas"

- Status: aceita
- Data: 2026-11-27

## Contexto
Pedido do usuário (Fase 9, itens f e g, pré-lançamento `1.3.0-beta.6`):
- (f) um botão de destaque no Início, "Fazer backup do celular", com um assistente que faz tudo em sequência e explica cada passo: escolher o celular e o HD (os conectados); garantir que o HD foi escaneado por inteiro ("senão posso copiar fotos que você já tem"); escanear e conferir o celular, com tempo estimado; comparar celular × HD inteiro pelo conteúdo, com exemplos em miniatura e a lista completa; perguntar a pasta ("Backup do celular") e a organização ("Manter as pastas do celular" como padrão), com um desenho da estrutura; prévia, confirmação, cópia segura, relatório e "Comparar de novo" até "Sim, 100%". Pausar e continuar a qualquer momento; nada é apagado do celular.
- (g) no "?" de cada tela, um campo que responde dúvidas a partir de uma base de perguntas e respostas embutida (offline), cada resposta com um botão para a tela ou ação certa, e uma página "O que o FotoAtlas faz (e o que nunca faz)".

## Decisão

### Assistente (só app: `features/backup/`)
- **Não há motor novo.** Cada passo usa o que já existe e já é seguro: cadastro (`addPhone`/`addPath`), escaneamento (retomável), fila de conferência, comparação por escopo (`Scope` do celular só com foto/RAW/vídeo × HD inteiro), lista do que falta e a cópia segura (`previewCopy`/`startCopy`, diário, `.part`, SHA-256). Nenhuma regra de segurança muda: o celular só é lido; nada é sobrescrito nem apagado.
- Passo 1 lista os dispositivos **conectados agora** (`listDevices`/`listDrives`) e os já cadastrados; um celular ou HD novo é cadastrado ao continuar (só grava no catálogo).
- Passo 2 só libera "Continuar" com o HD escaneado por inteiro (`wholeScannedAt`) e o conteúdo dele conferido; se faltar, explica o porquê e escaneia.
- Passo 3 escaneia o celular de novo a cada backup (fotos novas) e mostra a conferência com o tempo estimado da fila.
- Passo 4: "X fotos do celular já estão no HD (não serão copiadas) · Y ainda não estão (Z GB)", 8 miniaturas de exemplo e a lista completa (paginada). Resultado incompleto (arquivos sem conferência) é dito e nunca vira "100%".
- Passo 5: pasta (padrão "Backup do celular") e organização (padrão `{original}` = "Manter as pastas do celular"); o desenho vem das pastas da prévia da cópia (só leitura).
- Passo 6: prévia (quantos, tamanho, espaço livre, bloqueios) e "Copiar N arquivos"; progresso com pausar/continuar; no fim, relatório (CSV) e "Comparar de novo".
- **Pausar e continuar:** "Pausar e continuar depois" pausa o escaneamento, a conferência ou a cópia em andamento e guarda a sessão (celular, HD, passo, pasta, organização, operação de cópia) em `settings` (`phoneBackup.session`). O Início passa a mostrar "Continuar o backup do celular". Ao continuar sem cópia começada, o assistente volta ao passo do celular (pode haver fotos novas). Terminar apaga a sessão.

### "Pergunte ao FotoAtlas" (`app/ask.dart`)
- Base embutida de ~20 perguntas e respostas em PT-BR, cada uma com palavras-chave e uma ação (abrir uma tela, o assistente de backup ou a página de promessas). Busca local simples: sem acentos e maiúsculas, sem palavras vazias, prefixos das palavras na pergunta (peso 3), nas palavras-chave (peso 3) e na resposta (peso 1), e frases inteiras das palavras-chave (peso 4); mostra as 3 melhores. **Nada sai do computador**: não há modelo nem rede (o teste de arquitetura da rede continua valendo).
- "O que o FotoAtlas faz (e o que nunca faz)": as regras da spec §2 em palavras simples, pelo botão do "?" e pela resposta "O app apaga alguma coisa?".

## Consequências
- Sem mudança de schema (continua v11) e sem código novo de gravação no core.
- A base de respostas precisa acompanhar o app: o teste confere que as perguntas de exemplo do pedido trazem a resposta certa em primeiro lugar.
- A busca é por palavras, não entende frases livres; quando não acha, diz isso e sugere palavras.
