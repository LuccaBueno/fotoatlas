# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

## [1.2.2] — 2026-11-28

Ramo `release/1.2.x`, a partir da `v1.2.1`: só esta correção, sem as funções da Fase 9.

### Corrigido
- O componente de dispositivos (helper) volta sozinho depois de cair. Antes, cada reinício recebia o número do processo errado e encerrava na hora, e uma queda deixava os celulares sem leitura até fechar o FotoAtlas. O helper também volta a se encerrar quando o FotoAtlas é finalizado à força, em vez de ficar aberto sozinho. Causa: o `--parent-pid` usava o getter `pid` do `HelperClient` (o PID do helper anterior) no lugar do `pid` do `dart:io`, desde a 0.4.0. Só esta correção; nenhuma função nova.

## [1.3.0-beta.7] — 2026-11-28 (pré-lançamento)

Traz tudo da `1.3.0-beta.6` e a correção abaixo, que também sai sozinha na `1.2.2` estável (ramo `release/1.2.x`). Sem mudança no catálogo (continua na versão 11). Roteiro de teste: item h de `docs\roteiro-teste-fase-9.md`.

### Corrigido
- O componente de dispositivos (helper) volta sozinho depois de cair. Antes, cada reinício recebia o número do processo errado e encerrava na hora. Por isso, uma queda deixava os celulares e as miniaturas sem leitura até fechar o app. O helper também volta a se encerrar quando o FotoAtlas é finalizado à força, em vez de ficar aberto sozinho.
- Teste de desempenho do scan: um processo de referência mede, ao mesmo tempo, as paradas da própria máquina, e só o atraso que é do app conta no limite de 100 ms, que não mudou.

## [1.3.0-beta.6] — 2026-11-27 (pré-lançamento)

### Adicionado
- **Fazer backup do celular** (destaque no Início, também na tela de boas-vindas): um assistente que faz tudo em sequência e explica cada passo. 1) escolher o celular e o HD entre os conectados (um novo é cadastrado na hora); 2) se o HD não foi escaneado por inteiro, explica por quê ("senão posso copiar fotos que você já tem") e escaneia; 3) lê e confere o celular, com o tempo estimado; 4) compara celular × HD inteiro pelo conteúdo: "X fotos do celular já estão no HD (não serão copiadas) · Y ainda não estão (Z GB)", com miniaturas de exemplo e a lista completa; 5) pasta de destino (sugere "Backup do celular") e organização ("Manter as pastas do celular" como padrão), com o desenho de como vai ficar; 6) prévia, confirmação e cópia segura, relatório e **Comparar de novo** até "Sim, 100%". **Pausar e continuar depois** a qualquer momento (o Início mostra "Continuar o backup do celular", mesmo depois de fechar o app). Nada é apagado do celular. ADR 0028.
- **Pergunte ao FotoAtlas** no "?" de cada tela: digite uma dúvida ("como faço backup do celular?", "o app apaga alguma coisa?", "o que é cópia conferida?", "por que meu resultado está incompleto?", "como desfazer uma reorganização?"…) e a resposta, em linguagem simples, vem de uma base embutida no app — **sem internet**, nada é enviado. Cada resposta tem um botão que leva direto à tela ou ação certa.
- **O que o FotoAtlas faz (e o que nunca faz)**: página com as regras do app em palavras simples, pelo "?".
- Sem mudança no catálogo (continua na versão 11).

### Corrigido
- Listar celulares logo depois de o componente de dispositivos (helper) cair espera ele voltar sozinho, em vez de dizer na hora que não há leitura de celulares. Quando ele cai, o motivo (código de saída e as últimas mensagens) fica guardado e a CLI mostra.

## [1.3.0-beta.5] — 2026-11-27 (pré-lançamento)

### Adicionado
- **Limpar repetidos** (nova tela **Repetidos**): arquivos com exatamente o mesmo conteúdo guardados mais de uma vez no **mesmo** dispositivo. Cada grupo mostra todas as cópias lado a lado — miniatura grande, nome, caminho completo, pasta, data, tamanho e resolução —, com **Abrir a foto** (visualizador do Windows) e **Mostrar na pasta** (Explorador com o arquivo selecionado). ADR 0027.
- O FotoAtlas **sugere qual cópia fica** — **a da pasta mais organizada** (pasta de data, sem "(1)" ou "cópia" no nome, caminho mais curto) ou **a mais antiga**, você escolhe a regra — e você troca qual fica ou deixa o grupo de fora. Dá para revisar **um grupo por vez** ou **aceitar as sugestões de todos**; **nenhum grupo vem marcado**.
- Antes de remover: **prévia** com a lista do que sai, quantos e o espaço liberado, e confirmação explícita ("Entendi"). Na hora, o **SHA-256** da cópia que fica e de cada uma que sai é conferido de novo; se algo mudou (ou é o mesmo arquivo com outro nome), **aquele grupo é pulado e avisado**.
- O que sai vai **sempre para a Lixeira do Windows** (dá para restaurar por lá), nunca é apagado de vez: se o Windows fosse apagar de vez (disco sem Lixeira), nada sai. Celular, pendrive e cartão de memória nunca entram; nada é feito entre dispositivos diferentes; uma cópia de cada conteúdo sempre fica.
- Cada limpeza fica no diário e em **Tarefas** (pausar, continuar, cancelar o resto, tentar de novo os que ficaram, arquivo por arquivo com o motivo) e tem **relatório CSV** com o que saiu e qual cópia ficou. Fechar o app no meio não perde nada: ao abrir de novo, o FotoAtlas confere no disco o que já foi para a Lixeira e continua de onde parou.
- Catálogo na versão 11 (cópia `pre-migracao-v10-<data>.db` antes de migrar): a tabela de operações é refeita uma vez com os mesmos dados para aceitar o tipo novo (segunda exceção às migrações só aditivas, aprovada; ADR 0027). Um catálogo aberto pela 1.3.0-beta.5 não abre mais nas betas anteriores.
- **Números clicáveis** nos cartões dos dispositivos e no Início: "N arquivos sem backup", "N com cópia conferida" e as outras situações abrem a **Biblioteca já filtrada** por aquele dispositivo e situação (filtro novo **Situação**, que conta exatamente como os cartões, inclusive arquivos ainda não conferidos); "N arquivos repetidos" abre **Limpar repetidos** naquele dispositivo; "possivelmente corrompido" abre Tarefas. Cursor de mão e a dica **Ver estes arquivos**.
- Demonstração: pasta "Repetidos" (a mesma foto sintética em vários lugares) no `run-app.ps1 -DemoPersistente`. CLI: `dedupe sources | groups | plan | start | resume | retry | export`.
- Testes: Lixeira real do Windows com arquivos sintéticos (e unidade `subst` sem Lixeira, onde nada sai), arquivo alterado entre a prévia e a remoção, link físico, e a CLI morta em cada ponto da limpeza e no meio da recuperação.

## [1.3.0-beta.4] — 2026-11-20 (pré-lançamento)

### Adicionado
- **Mapa** na Biblioteca (ao lado de Lista): as fotos e os vídeos com local do filtro atual, agrupados pela proximidade, com o número de cada grupo. Roda do mouse, **+**/**−** e arrastar para navegar; clicar num grupo aproxima; clicar numa foto abre os detalhes; **Ver todos os locais** enquadra tudo. Diz quantos itens ficaram de fora por não ter local. ADR 0026.
- **Ver as fotos desta área:** a área visível do mapa vira o filtro **Área do mapa** (também atravessando a linha de data, no Pacífico) e a Biblioteca volta para a linha do tempo. O filtro entra nos filtros salvos.
- O mapa **funciona sem internet**, com contornos de países e estados embutidos (Natural Earth, domínio público). **Nenhum local sai do computador.**
- **Configurações › Mapa:** mapa online (OpenStreetMap), **desligado por padrão**. Ligar pede confirmação com o que é enviado (só a região do mapa que você olha e o endereço de internet do computador; nunca os locais das fotos, nomes de arquivos ou o catálogo). As imagens do mapa ficam só na memória.
- Demonstração: pasta "Viagens (mapa)" (fotos sintéticas com local) no `run-app.ps1 -DemoPersistente`.
- Teste de arquitetura: só a atualização e o mapa online acessam a internet.
- CI: o teste que grava cerca de 4 GB num VHD FAT32 roda sozinho, depois dos de desempenho (em paralelo, travava a E/S dos outros testes).

## [1.3.0-beta.3] — 2026-11-18 (pré-lançamento)

### Adicionado
- **Google Takeout em pasta:** os `.json` que acompanham as fotos do Google Fotos dão a data e o local de cada foto, **só no catálogo** (nenhuma foto é alterada). Reconhece os nomes do Takeout: `.supplemental-metadata.json`, nomes cortados, duplicatas `(1)` e fotos editadas (`-editado`), além do título de dentro do `.json`. A hora aparece como **do Google Fotos** (provável), e o local entra só quando a foto não tem o próprio. Foto ou vídeo numa pasta do Takeout **sem o seu `.json`** fica com **hora a confirmar**. `.json` que chegam depois (outra parte do Takeout) atualizam as datas sem ler as fotos de novo. ADR 0025.
- **Extrair zip do Google Takeout…** (em **Mais opções** do dispositivo com os `takeout-….zip`): prévia com quantas fotos, vídeos e `.json` vão sair, e extração para uma pasta escolhida pela cópia segura (diário, CRC do zip e SHA-256 conferidos, nada sobrescrito). Os zips **só são lidos** e nunca são apagados; a mesma entrada repetida em duas partes sai uma vez só.
- Catálogo na versão 10 (cópia `pre-migracao-v9-<data>.db` antes de migrar): tabela nova dos `.json` lidos e a origem de data "Google Fotos". A tabela de metadados é refeita uma vez com os mesmos dados (única exceção às migrações só aditivas; ADR 0025).
- Demonstração: pasta "Google Takeout" (pasta extraída e dois zips) no `run-app.ps1 -DemoPersistente`.

## [1.3.0-beta.2] — 2026-11-18 (pré-lançamento)

### Adicionado
- **RAW+JPEG e Live Photos como um item só** na Biblioteca, com o selo **RAW+JPEG**, **Live** ou **Agrupado**. O FotoAtlas reconhece, na mesma pasta, a foto e o RAW com o mesmo nome, e a Live Photo pelo identificador da Apple (mesmo com nomes diferentes) ou pelo mesmo nome com um vídeo de até 5 s. É **só visual, no catálogo**: nenhum arquivo muda, e a conferência, a comparação, o backup e a verificação continuam arquivo por arquivo. ADR 0024.
- **Copiar** um item agrupado leva todos os arquivos dele para a mesma pasta, com o mesmo sufixo se o nome já existir no destino. A prévia diz quantos vão junto e quantos não estavam marcados. **Reorganizar** leva o RAW e o vídeo junto com a foto, para a mesma pasta e com o mesmo nome final. A restauração de um arquivo danificado continua levando só ele.
- Detalhes do item com a lista de arquivos e **Desagrupar** (o grupo não volta sozinho). **Agrupar** os itens marcados, pela barra da seleção.
- A situação de backup de um item agrupado é a pior entre os arquivos dele: um RAW sem backup não fica escondido atrás de um JPEG com backup. Filtros por tipo, extensão e situação de backup mostram cada arquivo sozinho.
- Catálogo na versão 9 (só acréscimos; cópia `pre-migracao-v8-<data>.db` antes de migrar). O ExifTool passa a ler também o `ContentIdentifier` (só leitura).
- Demonstração: pasta "Fotos agrupadas" no `run-app.ps1 -DemoPersistente`. CLI: `items detect | list | split | group`.

## [1.3.0-beta.1] — 2026-11-15 (pré-lançamento)

### Adicionado
- **Fotos parecidas** (nova tela **Parecidas**): o FotoAtlas sugere grupos de fotos diferentes que parecem a mesma — a mesma foto em outro tamanho ou qualidade (como as enviadas por mensagem), mais clara, com um pequeno corte, ou tiradas em sequência —, cada grupo com o nível de confiança (**Quase idênticas**, **Muito parecidas**, **Talvez parecidas**) e um filtro por nível. **Comparar lado a lado** mostra cada foto grande, com resolução, tamanho, data, câmera, onde está e se tem backup. Dá para dizer **Não são parecidas** (o grupo não volta), **Tirar do grupo** uma foto (as duas com **Desfazer**), marcar fotos e **Copiar para…** pela cópia segura, e **Mostrar de novo as descartadas**. São só sugestões: nada é apagado, movido ou alterado, e a qualidade de nenhuma foto muda. A análise usa as miniaturas, roda devagar em segundo plano, espera as outras tarefas e nunca lê do celular para isso. ADR 0023.
- Catálogo na versão 8 (só acréscimos; cópia `pre-migracao-v7-<data>.db` antes de migrar). Um catálogo aberto pela 1.3.0-beta.1 não abre mais na 1.2.1.
- Demonstração: pasta "Fotos parecidas" no `run-app.ps1 -DemoPersistente`. CLI: `similar run | groups | dismiss | restore`.
- Teste de arquitetura: codificar imagem só é permitido no cache de miniaturas — o app nunca recodifica uma foto do usuário.
- Miniatura de último recurso para JPEG/PNG sem o Shell do Windows (lida em modo leitura, gravada só no cache).
- **Pré-lançamentos** (`1.3.0-beta.N`): cada item da Fase 9 é publicado no GitHub como pré-lançamento, com instalador e `.sha256`, para teste. O Sobre mostra "Versão 1.3.0-beta.1 (pré-lançamento)". ADR 0022.

### Alterado
- O aviso de versão nova e o "Atualizar agora" oferecem **só versões estáveis**: pré-lançamentos nunca aparecem, nem marcados como tal no GitHub nem com sufixo na versão. Quem estiver numa beta recebe a estável da mesma versão (ou mais nova), nunca uma mais velha; o "Procurar atualização agora" explica isso.
- O instalador aceita versões com sufixo (`FotoAtlas-1.3.0-beta.1-instalador.exe`); a CI passa a testar um pré-lançamento atualizado pela estável.

### Corrigido
- Versões com sufixo eram lidas como se não tivessem sufixo: quem estivesse numa `1.3.0-beta.2` nunca seria avisado da `1.3.0`.

## [1.2.1] — 2026-11-14

### Corrigido
- A interface podia travar por instantes durante o escaneamento, a conferência ou a cópia num disco lento (HD externo, pendrive): enquanto o Windows demorava para responder a uma leitura do disco, o FotoAtlas inteiro esperava junto. Agora só a tarefa espera e a interface continua respondendo. Causa: as chamadas ao Windows estavam marcadas como "leaf" no FFI, o que impede a coleta de lixo do Dart de parar aquela thread; como a coleta é de todos os isolates juntos, os outros ficavam parados até a chamada voltar. Só `GetLastError` continua leaf. Evidências e decisão no ADR 0008 (atualização de 2026-11-14).
- O teste de desempenho do escaneamento de 50 mil arquivos, que em runner lento da CI chegava a 90–118 ms de atraso (limite de 100 ms, mantido), volta a ter folga. Um teste de arquitetura novo impede `isLeaf` em funções que esperam o disco.

## [1.2.0] — 2026-11-14

### Adicionado
- **Atualizar agora:** o aviso de versão nova ganhou o botão **Atualizar agora**, ao lado de **Baixar**. Ele baixa o instalador da release oficial (github.com/LuccaBueno/fotoatlas) para uma pasta temporária, com progresso e **Cancelar**; confere se o SHA-256 do arquivo (relido do disco) é igual ao do `.sha256` da mesma release, e se não for apaga o download e avisa; pergunta antes de fechar, listando as tarefas em andamento, que são pausadas com segurança; e então inicia o instalador, fecha o FotoAtlas com segurança e, no fim da instalação, o abre de novo na versão nova. Nada acontece sem o clique e a confirmação do usuário. Sem internet, download interrompido ou arquivo diferente: avisa e não mexe em nada. A atualização nunca toca no catálogo nem nas configurações. ADR 0021.
- **Configurações › Atualizações › Procurar atualização agora:** consulta na hora (mesmo com a consulta ao abrir desligada) e diz se há versão nova (mostrando o aviso), se já está na mais nova ou se não deu para consultar.
- Instalador: com `/ATUALIZARDOAPP=1`, espera o FotoAtlas fechar sozinho (até 2 min, nunca fecha à força) e o abre de novo no fim. Sem o parâmetro, continua recusando atualizar com o app aberto.
- `tools/scripts/build-installer.ps1` grava o `.sha256` ao lado do instalador.
- Testes: download conferido, SHA-256 errado, arquivo trocado, conexão que cai, servidor mudo, cancelar, sem internet, `.sha256` ausente ou de outro arquivo; fluxo completo na interface; encerramento seguro antes de sair; e, na CI, o instalador com os argumentos do app esperando o app fechar e reabrindo-o com o catálogo intacto.

## [1.1.0] — 2026-11-14

### Adicionado
- **Aviso de versão nova:** ao abrir, no máximo uma vez por dia, o FotoAtlas pergunta ao GitHub qual é a versão mais nova (sem enviar nenhuma informação do usuário). Se houver, aparece uma faixa discreta no topo com **Baixar** (abre a página da versão no navegador) e **Agora não**. Nunca baixa nem instala nada sozinho; sem internet, nada acontece. Desligável em Configurações › **Atualizações**. ADR 0020.

### Corrigido
- O aviso "Cópia iniciada. Acompanhe em Tarefas." não sumia (no Flutter atual, um aviso com botão fica fixo por padrão). Agora ele e os de verificação e reorganização somem sozinhos depois de alguns segundos e ao clicar em **Ver em Tarefas**. O aviso "Desfazer" da correção de relógio também some sozinho.

### Removido
- `docs/assets/logo-conceito.jpg`, que não era mais usada.

### Documentação
- README começa com a seção **⬇️ Baixar**: botão para a versão mais recente, três passos e o aviso de que "Source code" não é o programa. A descrição e o site do repositório no GitHub apontam para o download.
- README de portfólio: logo atual (globo com lupa, gerada por `app/tool/gen_app_icon.dart` em `docs/assets/logo.png`), capturas do modo demonstração com dados sintéticos (Início, Biblioteca, Comparar, Reorganizar, Tarefas), GIF da comparação e seções "Destaques técnicos" e "Arquitetura" (diagrama Mermaid).

## [1.0.0] — 2026-11-06 — Primeira versão estável

Mesmas funções da 0.8.0, agora como versão estável, com o instalador publicado na página de versões do GitHub.

## [0.8.0] — 2026-11-06 — Fase 8: Distribuição

### Ajustes de usabilidade (depois do teste da Fase 8)
- **Desinstalar:** as duas perguntas Yes/No seguidas, com sentidos opostos, viraram botões com o texto da ação, em português: **Desinstalar** / **Cancelar** no começo e **Manter catálogo** (padrão) / **Apagar catálogo (vai para a Lixeira)** no fim. "Manter catálogo" fica no lugar de "Desinstalar": um clique repetido não apaga nada. A CI agora clica nesses botões, inclusive em "Apagar catálogo", e confere a pasta na Lixeira.
- **Biblioteca com filtro:** o cabeçalho do momento mostra "1 de 4 itens" quando o filtro deixa só parte dele visível.

### Adicionado — Fase 8: Distribuição
- **Instalador para Windows** (`FotoAtlas-<versão>-instalador.exe`, Inno Setup), em português e sem pedir permissão de administrador. Instala em `C:\Users\<usuário>\AppData\Local\Programs\FotoAtlas`, com atalho no menu Iniciar e (opcional, vem marcado) na área de trabalho. Já inclui o ExifTool e o FFmpeg; não precisa do .NET nem do "Visual C++ Redistributable".
- **Atualizar** é instalar a versão nova por cima: o catálogo, os backups e as configurações (`C:\Users\<usuário>\AppData\Roaming\FotoAtlas`) e as miniaturas ficam intactos. Com o FotoAtlas aberto, o instalador pede para fechá-lo e nunca o fecha à força.
- **Desinstalar** remove o programa e os atalhos e, no fim, pergunta o que fazer com o catálogo, as configurações e as miniaturas. O padrão é manter (reinstalar continua de onde parou); apagando, as pastas vão para a Lixeira.
- **Ícone do FotoAtlas** (o globo com lupa do menu lateral) no lugar do ícone padrão do Flutter: janela, barra de tarefas, executável, instalador e Aplicativos instalados.
- Configurações › **Sobre o FotoAtlas**: versão instalada e a pasta do catálogo e das configurações.
- `tools\scripts\build-installer.ps1` gera o instalador; `tools\scripts\test-installer.ps1` instala, atualiza e desinstala de verdade numa máquina limpa (job "Instalador" da CI). Guia para usuários em `docs\instalacao.md`. ADR 0019.

## [0.7.0] — 2026-10-31 — Fase 7: Integridade periódica

### Ajustes de usabilidade (depois do teste das Fases 6 e 7)
- **Arquivo danificado no cartão do dispositivo:** em vez de "1 arquivo que ainda não dá para saber" (cinza), aparece em vermelho **"1 arquivo possivelmente corrompido — Ver e restaurar"**, que abre Tarefas. A cópia boa no outro dispositivo, cuja única outra cópia se danificou, passa a contar como **"sem backup"**.
- **Início:** o painel de backup explica esses arquivos com texto próprio ("o conteúdo mudou sem a data mudar — sinal de dano no disco"), e não mais como "o conteúdo ainda não foi conferido".
- **Depois de restaurar:** o arquivo sai de "Possivelmente corrompidos" e vai para **"Restaurados e resolvidos"**, com "Restaurado — a cópia boa está em IMG_0003_1.jpg" e o botão **"Marcar como resolvido"** (só no catálogo). O arquivo danificado continua onde está, sem ser apagado. Ele também sai do aviso do Início e da situação de backup. Se o mesmo arquivo for regravado e se danificar de novo, volta a pedir atenção.
- **Biblioteca logo depois do escaneamento:** as fotos e vídeos aparecem sem esperar a conferência (antes, um celular de 106 GB deixava a Biblioteca quase vazia por quase 1 hora), com a data do nome ou do arquivo e o selo **"conferindo…"**. Conforme a conferência avança, viram itens normais (sem duplicar). Enquanto conferem, não dá para marcá-los, e só aparecem sem filtro ou com filtros de dispositivo, tipo e extensão.
- **Documentos:** todos os `.md` são salvos em UTF-8 com BOM (o `Get-Content` do Windows PowerShell 5.1 trocava os acentos), e as instruções usam caminhos completos do Windows (ex.: `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente`), nunca variáveis no formato do cmd nem caminhos estilo Linux. `tools\scripts\check-docs.ps1` confere isso (também na CI).
- CLI: `verify problems` mostra se cada arquivo está pendente, restaurado ou resolvido; `verify resolve ITEM`.
- Catálogo v7 (só acrescenta uma coluna; backup automático antes da migração).

### Adicionado — Fase 7: Integridade periódica
- **Verificar integridade** (Dispositivos › Mais opções, no cartão de um disco, pasta ou celular; ou "Verificar…" com itens marcados na Biblioteca): o FotoAtlas lê cada arquivo de novo e compara com o conteúdo conferido antes. **Só lê**: nenhum arquivo é alterado, movido ou apagado. Antes de começar, diz quantos arquivos e quanto vai ler; dá para escolher "Tudo" ou "Só o que não é conferido há mais de N dias".
- Resultado de cada arquivo: **inalterado**; **alterado** (o conteúdo e a data de modificação mudaram — alguém editou); **possivelmente corrompido** (o conteúdo mudou, mas a data não — sinal de dano no disco); "não está mais no lugar" e "não deu para ler agora", que nunca fazem o arquivo ser considerado apagado. Em discos FAT, a diferença de exatamente 1 hora do horário de verão não disfarça um dano.
- **Possivelmente corrompidos** (Tarefas): cada arquivo com as **outras cópias conferidas** do conteúdo original (em que dispositivo e pasta, se está conectado, se é no mesmo disco, quando foi conferida) e **"Restaurar desta cópia…"**: abre a prévia da cópia segura (Fase 5) e só grava depois de você confirmar. A cópia boa é gravada **na mesma pasta, com outro nome** (`foto_1.jpg`); o arquivo danificado nunca é substituído nem apagado. Se a "cópia boa" também tiver se estragado, a cópia segura percebe e não grava. "A mudança é esperada…" aceita o conteúdo atual (só no catálogo).
- Arquivo possivelmente corrompido deixa de contar como cópia de segurança (na situação de backup, na Comparar e como origem de cópias) até ser restaurado ou regravado.
- **Verificação periódica** (Configurações): ligada por padrão, confere de novo o que não é conferido há mais de 90 dias (30, 90, 180 dias ou 1 ano). É **leve**: lê devagar, espera quando o FotoAtlas está escaneando, conferindo, copiando ou reorganizando, pode ser pausada e continua de onde parou. **Celulares nunca** são verificados sozinhos — só quando você pede.
- Tarefas: verificações em andamento e histórico (pausar, continuar, cancelar, "Ver arquivos"). Início: aviso de arquivos possivelmente corrompidos e de discos que não são verificados há tempo, com "Verificar agora".
- Fechar o app no meio de uma verificação é seguro: ela fica "interrompida" e continua de onde parou, sem repetir arquivos.
- CLI: `verify start|resume|status|problems|restore|accept|schedule|tick`.
- Demonstração: `run-app.ps1 -DemoPersistente` gera a pasta "Integridade" ("HD fotos" e "HD cópia"); `tools\scripts\demo-danificar.ps1` simula o dano no disco (ou, com `-Editar`, uma edição) só dentro da pasta da demonstração.
- Catálogo v6 (só acrescenta tabelas e colunas; backup automático antes da migração). ADR 0018.

## [0.6.0] — 2026-10-31 — Fase 6: Reorganização

### Ajustes de usabilidade (depois do teste das Fases 6 e 7)
- **Prévia da reorganização:** o caminho aparece com a letra da unidade (`C:\Users\…`), nunca o caminho técnico do volume (`\\?\Volume{…}`). Mensagens de erro de leitura/gravação também deixaram de mostrá-lo.
- **Árvore da prévia:** nomes cortados ("IMG_20240713_…") mostram o nome completo ao passar o mouse, nas pastas e nos arquivos.
- **Desfazer com arquivo editado:** a decisão aparece direto no cartão da tarefa — "1 arquivo mudou depois da reorganização", com **"Devolver mesmo assim"** e **"Deixar onde está"** —, sem precisar abrir Detalhes.
- **Remover pastas vazias:** as pastas vêm **desmarcadas** (é uma remoção), com o botão **"Marcar todas"**.
- **Biblioteca:** um momento que atravessa a meia-noite (ex.: 23:30–00:15) aparece **uma vez só, no dia em que começa**.

### Adicionado — Fase 6: Reorganização
- **Reorganizar…** (Dispositivos, no cartão de um disco ou pasta): organiza as fotos e vídeos dentro do **mesmo disco**, movendo sem copiar (rápido, não ocupa espaço). Modelos: por ano e mês, por ano e dia, **por ano e momento** (`2024/2024-07-13 Aniversário da Ana`; momento sem nome usa a hora em que começou, `2024-07-13 14h03`), por tipo e ano, por ano e câmera, mesma estrutura ou tudo junto. Fotos sem hora confiável vão para "Sem data confirmada" (nome configurável); nomes que o Windows não aceita são ajustados.
- **Prévia em árvore "antes → depois"**: de onde cada arquivo sai, para onde vai, pastas novas, pastas que ficam vazias, nomes repetidos (ganham `_1`, `_2`… ou esperam a sua decisão) e o que fica onde está (o que não é foto nem vídeo, ou ainda não teve a data lida). Arquivos de edição `.xmp`/`.aae` com o mesmo nome vão junto com a foto.
- **Desfazer** (Tarefas): devolve cada arquivo ao lugar exato de antes, mesmo depois de fechar e abrir o app. Antes de confirmar, avisa quais arquivos mudaram desde a reorganização — esses só voltam se você confirmar —, quais sumiram e quais lugares antigos já têm outro arquivo (nada é sobrescrito).
- **Remover pastas vazias…** (Tarefas): as pastas que ficaram vazias nunca são apagadas sozinhas. Esta ação lista cada uma, você escolhe e confirma; só sai pasta sem nada dentro (nem arquivo oculto, como `Thumbs.db`), conferida de novo na hora.
- Para organizar em **outro disco**, o assistente oferece a cópia conferida ("Copiar para outro disco…"): a origem fica como está. **Celular nunca é reorganizado.**
- **Disco principal** (Dispositivos › Mais opções): destino sugerido nas cópias.
- Os modelos novos (`{hora}`, `{minuto}`, `{segundo}`, `{momento}`) também valem na cópia.
- Diário e recuperação: cada arquivo movido fica registrado antes de mover; se o app fechar no meio, ao abrir ele confere o disco e continua de onde parou. Testes de falha matam o processo em cada etapa (reorganização, Desfazer e a própria recuperação).
- CLI: `reorg plan|start|resume|undo|resolve|folders|status`; `recover` também cobre a reorganização.
- Demonstração: `run-app.ps1 -DemoPersistente` gera a pasta "HD bagunçado" para testar.
- Catálogo v5 (só acrescenta duas colunas no diário; backup automático antes da migração). ADR 0017.

## [0.5.0] — 2026-10-30 — Fase 5: Cópia segura

### Ajustes de usabilidade (depois do teste da Fase 5)
- **Comparar**: abas com "contém/contido" — **"Em A, não contido em B — faltam"**, **"Em B, não contido em A"** e **"Contido em A e em B"** — e dica em cada aba citando os nomes reais dos lados (ex.: "Arquivos de "Pixel de Teste" que "HD" ainda não contém").
- "Copiar para B…" desabilitado explica o porquê: "Marque arquivos ou clique em "Selecionar todos os resultados"". Dicas também em "Selecionar todos os resultados", "Adicionar pasta ou dispositivo", "Adicionar momento", "Filtrar por data ou câmera", nos tipos, em "Comparar", "Trocar A e B" e "Conferir agora".
- **Assistente de cópia**: o caminho completo do destino aparece abaixo de "Para onde" (quebrando linha, com dica); na lista, nome e caminho em duas linhas. Quando tudo já está no destino, sugere o próximo passo: escolher outro destino ou **"Adicionar dispositivo…"** direto do assistente (um disco novo vira o destino).
- **Tarefas › Detalhes**: lista os arquivos copiados e conferidos (origem → onde ficou), destaca os **salvos com outro nome** com o porquê ("IMG_20240502_120000.jpg → salvo como IMG_20240502_120000_1.jpg porque o nome já existia na pasta") e os **não copiados com o motivo** (já estava lá idêntico, você escolheu não copiar, erro). A lista completa continua no relatório exportado.

### Adicionado — Fase 5: Cópia segura
- **Copiar o que falta**, com conferência: "Copiar para B…" na Comparar (todos os resultados ou os marcados) e "Copiar para…" com itens marcados na Biblioteca abrem um assistente com **prévia** antes de gravar qualquer coisa: quantos arquivos e quanto espaço, o que o destino já tem (mesmo conteúdo, outro nome), espaço livre e quanto sobra, nomes que já existem, arquivos acima de 4 GB num disco FAT32, nomes ajustados para o Windows, itens sem data ou com hora incerta e as pastas que vão ser criadas. Organização por ano e mês (padrão), por dia, por tipo e ano, mantendo a estrutura da origem ou tudo numa pasta.
- **Cada arquivo é conferido**: gravado numa pasta temporária do destino, enviado ao disco, relido e comparado pelo conteúdo com a origem; só então aparece no destino. Nada é sobrescrito (nome ocupado vira `_1`, `_2`… ou espera a sua decisão) e a origem nunca muda. A data de modificação da origem é mantida.
- **Celular como origem**: o arquivo é lido pelo cabo USB e gravado direto na pasta temporária do destino; se o celular sair no meio, a cópia pausa sem deixar nada pela metade e continua quando ele voltar.
- **Diário e recuperação**: toda etapa de cada arquivo fica registrada. Se o FotoAtlas fechar, travar ou o computador desligar no meio, ao abrir ele confere o disco, termina o que já estava copiado e conferido e deixa o resto esperando "Continuar". Rodar a recuperação de novo não muda nada.
- **Tela Tarefas**: cópias em andamento com progresso (o arquivo do momento e se está copiando ou conferindo), pausar, continuar, cancelar o que falta (o que já foi copiado fica), decidir nomes repetidos ("Copiar com outro nome" ou "Não copiar"), tentar de novo os que não foram copiados, arquivos desconhecidos na pasta temporária (listados, nunca apagados) e **exportar o relatório** (CSV).
- Falta de espaço, disco de destino ou origem desconectados pausam a cópia com o motivo na tela; uma pasta da origem que sumiu no meio aparece como "não copiado", sem marcar o arquivo como apagado.
- CLI: `copy plan`, `copy start … --yes`, `copy resume`, `copy retry`, `copy status`, `copy export` e `recover`.
- Helper: `devices.pullToFile` (grava só arquivos novos `.part` dentro de `.fotoatlas-tmp`).
- Testes de falha: o processo é morto em cada etapa da cópia (11 pontos) e no meio da própria recuperação; a recuperação roda 3 vezes sem efeito colateral e a cópia termina sem perda nem sobrescrita. Falta de espaço e FAT32 com arquivo de mais de 4 GB em discos virtuais (VHD) na CI.
- Demonstração: o HD do celular simulado tem um arquivo com o mesmo nome de uma foto que falta (para ver o `_1`); com `-DemoPersistente -CelularSimulado` o Pixel lê devagar e dá para "desplugá-lo" no meio da cópia.
- Documentos: ADR 0016 (cópia segura) e `docs/backup-e-restauracao.md` (o que é garantido e a limitação de queda de energia).

### Mudado
- Fechar o app com uma cópia em andamento pergunta antes e, ao fechar, pausa a cópia com segurança (o arquivo do momento volta para a fila).

## [0.4.0] — 2026-10-29 — Fase 4: Metadados e Biblioteca

### Ajustes de usabilidade (depois do teste da Fase 4)
- Situações de backup com nomes claros: **"Sem backup (só em 1 lugar)"**, "Parece ter cópia (falta conferir)", "Tem cópia conferida", **"Backup em outro disco"**, "Ainda não dá para saber".
- Filtros **"Horário do dia"** e **"Hora confiável?"** (antes "Horário" e "Hora"); "Mostrar tudo, menos os marcados" no lugar de "Excluir os marcados (NÃO)"; contagens com unidade.
- Momentos: nome descritivo quando não têm nome ("Sábado de manhã"); um instante só mostra "09:00"; botão "Opções" maior e menu pelo clique direito no cabeçalho.
- **Ajuda**: dica em ícones, selos, chips e botões (o selo de backup diz onde o arquivo está); botão **"?"** na navegação com a ajuda e a legenda da tela aberta; **guia de primeiros passos** na primeira abertura (pode pular e rever pelo "?").
- **Corrigir o relógio**: novo modo padrão "Sei a hora certa de uma foto", com a frase do que vai mudar antes da prévia.
- Data de **1º de janeiro às 00:00:00** em ponto (relógio zerado) passa a ser hora incerta e vai para "Hora a confirmar"; catálogos existentes são recalculados ao abrir, sem reler os arquivos.

### Adicionado — Fase 4: Metadados e Biblioteca
- **Biblioteca** com três visões: **linha do tempo única** pela hora real da captura (até os segundos), intercalando fotos e vídeos de todos os dispositivos, com cabeçalhos de mês, dia e **momento**; **grade**; e **lista**. Navegação ano → mês → dia → momento ao lado. Conteúdo idêntico em vários lugares aparece uma vez.
- **Data e hora da captura**: lidas do EXIF (com subsegundos e fuso), do vídeo (UTC), do nome do arquivo (celular, câmera, WhatsApp, Pixel, prints, Dropbox) ou da data do arquivo, nessa ordem (configurável). Cada item guarda a origem e a confiança (confiável, provável, incerta); **hora incerta** aparece sinalizada, com "A hora está certa" e "Corrigir a hora…". Fuso padrão America/Sao_Paulo, com o antigo horário de verão.
- **Momentos automáticos** por intervalo sem fotos (padrão 2 h, configurável), considerando todos os dispositivos. **Nomear, juntar, separar** e voltar ao automático pelo cabeçalho; as edições ficam fixas nos recálculos. Hora incerta fica em **"Hora a confirmar"** até ser confirmada.
- **Corrigir o relógio de um dispositivo** (ex.: câmera 1 h adiantada, ano errado), com prévia "antes → depois", o item de outro dispositivo que fica ao lado e o efeito nos momentos; também calcula o deslocamento por duas fotos tiradas no mesmo instante. Só no catálogo; **Desfazer** na hora ou em Configurações.
- **Filtros em chips**: ano, dispositivo, câmera, tipo, situação de backup, **horário** (faixa, inclusive atravessando a meia-noite; período do dia; dia da semana), **momento**, hora (confiança, a confirmar, corrigidas, conflitantes) e mais (período de datas, sem data, tamanho, resolução, duração, GPS, erro de leitura); busca por nome, pasta ou momento; **filtro avançado E/OU/NÃO**; **filtros salvos**.
- **Seleção em massa**: clique, Ctrl+clique, Shift+clique, Ctrl+A ("todos os resultados", não só os visíveis), inverter, tirar da seleção por critério; barra fixa com itens, tamanho, arquivos e situação de backup.
- **Painel de detalhes** com todas as localizações (conectado/desconectado), câmera, dimensões, exposição, GPS, duração e todas as datas encontradas.
- **Miniaturas em cache** (Shell do Windows pelo helper; FFmpeg para vídeos; miniatura embutida no EXIF, inclusive do celular lendo só o começo do arquivo).
- **Comparar**: momento como parte do escopo (em todos os dispositivos ou só num) e filtro por período/câmera; escopos salvos guardam os dois.
- **Configurações › Datas e momentos**: intervalo dos momentos, fuso, ordem das datas, histórico de correções de relógio com desfazer, situação do leitor de metadados.
- Leitura de metadados automática depois da conferência (ExifTool e ffprobe, só leitura), com progresso, pausa e "ler de novo os que deram erro"; sem o ExifTool, as datas vêm do nome e da data do arquivo e se completam quando ele existir.
- `tools/scripts/get-tools.ps1`: baixa ExifTool 13.60 e FFmpeg 8.1 LGPL com SHA-256 conferido (não versionados).
- Celular simulado com fotos com EXIF de verdade e uma pasta **"Câmera"** com o relógio 1 h adiantado (para testar a linha do tempo, os momentos e a correção).
- Helper: `thumbnails.get` e `devices.readHead` (grava só arquivos novos dentro da pasta de cache).
- Catálogo v4 (aditivo): data efetiva, momentos, edições de momentos e correções de relógio (ADR 0014 e 0015).
- Desempenho medido: 100 mil itens — filtros de 100 a 370 ms (exigido < 1 s), recálculo dos momentos em ~1,4 s.

### Mudado
- **Modo demonstração avisado na tela**: com `run-app.ps1 -Demo` ou `-CelularSimulado`, uma faixa fixa no topo diz "Modo demonstração — tudo será descartado ao fechar", e a pergunta ao fechar e a tela "Encerrando com segurança…" avisam que nada será mantido (antes prometiam "continua de onde parou", o que não vale nesse modo).
- **Fechar com tarefas em andamento pergunta antes**: "Há tarefas em andamento: …" com o progresso de cada uma (escaneamento, conferência, backup do catálogo) e "Continuar trabalhando" (padrão) ou "Fechar mesmo assim". Sem nada em andamento, fecha direto.
- **Se a leitura de dispositivos cair** (fora do fechamento), o app avisa: o que estava em andamento foi interrompido sem perder nada; a conferência continua sozinha quando o celular volta e o escaneamento continua em "Retomar".
- **Um botão só, "Adicionar dispositivo"**, em Dispositivos e no seletor da Comparar, no lugar de "Adicionar pasta", "Adicionar celular" e "Adicionar unidade". A janela lista sozinha o que está conectado: celulares com a situação ("Pronto", "Bloqueado", "Falta permitir o acesso"), unidades (HD, SSD, pendrive, cartão — as já cadastradas aparecem como "Já cadastrada") e "Escolher uma pasta…", com "Procurar de novo".
- **"Escanear" pergunta o quê**: "Tudo" ou "Só algumas pastas". As pastas aparecem em árvore, lidas do dispositivo na hora (só leitura; abrir a janela não cataloga nada), cada uma com "escaneada em …" ou "ainda não escaneada" e o tamanho pelo último escaneamento ("tamanho desconhecido" se nunca foi escaneada). No celular com um armazenamento só, ele já aparece aberto. Marcar uma pasta inclui as de dentro.
- Na Comparar, depois de adicionar um dispositivo novo, a mesma pergunta aparece antes de escanear.

### Adicionado
- **`run-app.ps1 -DemoPersistente`**: demonstração mantida entre aberturas, sempre em `C:\Users\Lucca-PC\AppData\Local\Temp\fotoatlas_demo_persistente` (apagável pelo `clean-temp.ps1`), para testar a retomada de verdade. Com `-CelularSimulado`, os celulares simulados são gerados uma vez na mesma pasta e o Pixel lê devagar (3 s por arquivo), para dar tempo de fechar no meio da conferência. O gerador ganhou `--leitura-lenta MS`.
- **Várias pastas num escaneamento só** (core `scans.start(fonte, folders: [...])`; CLI `scan start FONTE --folder A --folder B`). Continua parcial e honesto: só confirma ausências dentro das pastas lidas; a comparação de partes não escaneadas dá "Resultado incompleto".
- O cartão do dispositivo mostra **quais pastas já foram escaneadas** (e quando) e avisa que o resto ainda não foi; o próximo "Escanear" já sugere as mesmas pastas. Depois de um scan do dispositivo inteiro, pastas escaneadas sozinhas mais tarde aparecem como "atualizadas depois".
- Core: `scans.listFolders`, `sources.folderStats`, `sources.listDrives`, `SourceView.scannedFolders`/`wholeScannedAt`/`scannedAt()`.

### Corrigido
- **O app não fechava pelo X** (o botão ficava vermelho e a janela continuava aberta). O encerramento esperava, sem prazo, o fim de streams cujos ouvintes estavam pausados (telas fora de vista) — o que nunca acontece no Dart — e ainda até 10 s por worker de scan/conferência, o backup do catálogo e o helper. Agora fechar **sempre funciona**: aparece "Encerrando com segurança…" com o que falta (pausar o escaneamento, pausar a conferência, terminar o backup, encerrar a leitura de dispositivos, fechar o catálogo); cada etapa tem prazo, o helper é finalizado se não responder (ex.: preso numa leitura do celular) e o app sai em no máximo 12 s. O que ficou pela metade continua de onde parou ao abrir de novo (ADR 0013).
- Fechar o catálogo podia voltar antes de o arquivo do banco ser fechado de verdade (reabrir logo em seguida dava "database is locked") e esperava, sem fim, consultas reativas de telas fora de vista; agora só volta com o arquivo fechado e não depende dessas consultas.
- Teste de desempenho da cobertura (100 mil arquivos) falhava às vezes na suíte completa por rodar em paralelo com o de 50 mil arquivos (1,5 s sozinho; até 5,4 s competindo, limite de 5 s). Os dois agora rodam em sequência, num arquivo só (`test/perf/perf_test.dart`).
- Na tela Dispositivos vazia, "Adicionar dispositivo" aparecia no topo e no centro; agora só no centro.
- Ao fechar durante a conferência do celular, o terminal mostrava `Unhandled Exception: HelperException(helper_crashed)`: um pedido ao helper feito com o encerramento em andamento ficava pendente sem ninguém esperando e falhava quando o helper era finalizado. Agora nenhum pedido fica órfão e nada novo vai para o helper durante o encerramento (ADR 0013).
- CI: os testes de desempenho (geram 50 mil arquivos e saturam o disco) passam a rodar sozinhos, depois dos outros; rodando juntos, atrasavam testes de encerramento até o limite de 30 s.
- A conferência do celular gravava os resultados em lotes de 32: fechar no meio refazia pelo USB o que já tinha sido lido. Agora cada arquivo é gravado na hora e, ao reabrir, a conferência continua exatamente de onde parou.
- O cartão dizia "mas 0 pastas não puderam ser lidas" depois de um scan de uma pasta só; agora diz "Só algumas pastas foram escaneadas".
- "Retomar" de um scan pausado de uma pasta só falhava pelo app (pedia a fonte inteira); agora retoma o mesmo scan.

## [0.3.0] — 2026-10-28 — Fase 3: Celular (leitura)

### Adicionado
- **Celulares (Android e iPhone) pelo cabo USB, só leitura** (ADR 0012). O helper lê o aparelho pelo Windows Portable Devices com um interop próprio que **não declara nenhum método de gravação, movimentação ou exclusão**, e abre a sessão pedindo só leitura. Pendrives e cartões que o Windows também mostra como "dispositivo portátil" ficam fora da lista de celulares.
- **Adicionar celular** (Dispositivos e no seletor da Comparar): lista os aparelhos conectados com a situação — "Pronto", "Bloqueado" (desbloqueie e escolha "Transferência de arquivos") ou "Falta permitir o acesso" ("Permitir" no Android, "Confiar" no iPhone). No iPhone, aviso para usar **"Manter originais"** em Ajustes › Fotos.
- **Escanear o celular** pasta por pasta, com os armazenamentos (interno, cartão SD) como primeiras pastas, pausável e retomável. Pastas privadas de apps (`Android/data`, `Android/obb`) e caches de miniaturas ficam de fora.
- **Conferência de conteúdo do celular**: o SHA-256 é calculado no helper, lendo o arquivo pelo USB, com detecção de arquivo que mudou depois do scan ou durante a leitura.
- **Comparar celular × HD**: o celular é uma fonte como as outras (aparelho inteiro, um armazenamento ou uma pasta como DCIM). O celular conta como disco próprio: foto no celular e num HD de identidade confiável = backup em disco independente.
- **Escanear só uma pasta** (CLI `scan start FONTE --folder P`; no core, `scans.start(fonte, folder: …)`), útil no celular: o scan fica parcial, só confirma ausências dentro da pasta, e a comparação dá "Resultado incompleto" para pastas do escopo que ainda não foram escaneadas.
- **"Não dá para confirmar que estão em discos diferentes"**: quando uma cópia conferida (🟢) está num disco que o Windows não identifica com certeza (ex.: SSD NVMe com número de série zerado), o Início e o cartão do dispositivo explicam por que ela não aparece como 🔵 disco independente (R1).
- `tools/scripts/clean-temp.ps1 [-Simular]`: apaga só as pastas de `C:\Users\Lucca-PC\AppData\Local\Temp` que começam com `fotoatlas_`, deixando intactas as que estão em uso.
- O mesmo celular é reconhecido pelo número de série, mesmo em outra porta USB.
- **Celulares simulados** para testes e demonstração sem aparelho: `--fake-devices` no helper / `FOTOATLAS_FAKE_DEVICES`, gerador `tools/fixtures/bin/gen_phone_demo.dart` e `run-app.ps1 -CelularSimulado`.
- **CLI**: `devices` e `sources add-phone CELULAR [--name N]`.
- **Schema v3** (aditivo): `sources.device_serial`, `sources.device_platform`, `file_instances.device_object_id`, com teste de migração a partir da v1 e da v2.
- Protocolo do helper: `devices.list`, `devices.listChildren`, `devices.hashObject`; o cliente aceita eventos por pedido e cancelamento (`system.cancel`).

### Corrigido (teste com celular real)
- **Conferência no celular real falhava em quase todos os arquivos** com "Erro de leitura no dispositivo (0x800700AA)" (aparelho ocupado): o helper não fechava de verdade o stream de leitura de cada arquivo (o wrapper COM do .NET só o liberava quando o coletor de lixo rodava), e o celular aceita uma transferência por vez. Agora o stream é liberado na hora, depois de ler até o fim (ADR 0012, atualização).
- Testes deixavam pastas em `C:\Users\Lucca-PC\AppData\Local\Temp` (`fotoatlas_app_test_*`, `fotoatlas_test_*`, `fotoatlas_cli_phone_build_*`): a remoção falhava em silêncio quando um arquivo ainda estava preso por instantes, e nos testes do app só era registrada depois da preparação. Agora toda pasta de teste é apagada com novas tentativas (até ~10 s) e o teste **falha** se sobrar algo; o `run-app.ps1` apaga o catálogo de demonstração e os celulares simulados quando o app fecha.
- Mensagens com acento dos scripts PowerShell saíam trocadas no Windows PowerShell 5.1 (arquivos sem BOM).

### Segurança
- Teste de integração com VHD abria o helper sem celulares simulados e listaria um celular real plugado; agora usa uma pasta vazia de simulados, e o teste de arquitetura falha se algum teste abrir o core com acesso a celulares reais.
- Desconectar, bloquear o celular ou o helper cair no meio do scan ou da conferência **nunca** marca arquivo como ausente nem como erro: o scan fica "interrompido" e retoma das pastas pendentes; o que faltava conferir continua pendente (regras 9 e 10).
- Uma falha ao ler um item de uma pasta do celular marca a pasta inteira como não lida (nada abaixo dela vira ausente), em vez de pular o item.
- Teste no helper falha se o interop WPD ganhar qualquer método fora da lista de leitura.

### Evidências (critérios da Fase 3)
- Celular simulado × HD pela CLI compilada com o **helper real**: lista, cadastra, escaneia (6 arquivos), confere e compara — faltam 3, nos dois 3, só em B 1; com o celular "desplugado", continua listado e a comparação usa o último scan.
- Desconexão no meio do scan (helper real, após N listagens): `interrupted`, `PRAGMA integrity_check = ok`, nenhum arquivo ausente; reconectado com IDs de objeto novos, retoma e termina com a contagem exata. O mesmo no core com IDs que mudam entre sessões, e foto apagada no celular só vira ausente num scan completo.
- Kill do processo no meio do scan do celular → retomar termina com 6 arquivos, sem duplicar.
- Interop WPD real testado sem aparelho (objetos do próprio Windows: propriedades, chaves, gerenciador).
- Teste do usuário com celular simulado no app: Pixel × HD → faltam 3, só em B 1, nos dois 3.
- **Celular real, somente leitura** (Samsung Galaxy M54, Android por MTP, catálogo de demonstração em `C:\Users\Lucca-PC\AppData\Local\Temp`): `devices` → pronto, 1 armazenamento ("Armazenamento interno", 241,6 GB, 49,4 GB livres); scan só de `DCIM/Camera` → **6.596 arquivos** (6.255 JPG, 286 MP4, 55 HEIC; 106,8 GB = 99,5 GiB), 1 pasta, 0 erros; conferência → 6.596 conferidos, 0 erros, 0 alterados, em 47 min (~37 MB/s), nenhum conteúdo repetido. Nada foi gravado no aparelho: a sessão WPD é aberta só para leitura e o interop não tem métodos de gravação. A primeira conferência falhou em 6.575 arquivos (0x800700AA) e levou à correção acima.

## [0.2.0] — 2026-10-27 — Fase 2: Conteúdo e cobertura

### Requisitos ajustados (sem implementação ainda)
- **Data e hora da captura (até segundos) como cidadã de primeira classe** — spec §3.2, §8.1–8.3, §10, §12 e §16; ROADMAP das Fases 4 e 6: linha do tempo única intercalando todos os dispositivos pela hora real; **momentos** automáticos (intervalo sem fotos, padrão 2 h) que o usuário pode nomear, juntar e separar, usados como filtro, escopo na Comparar e no modelo de organização `{ano}/{ano}-{mes}-{dia} {momento}/`; filtros por faixa de horário, período do dia e dia da semana; correção de relógio por dispositivo de captura com prévia, só no catálogo; hora de baixa confiança sinalizada e fora dos momentos automáticos até ser confirmada.

### Adicionado
- **Conferência de conteúdo (SHA-256)** em segundo plano, um leitor por disco físico, em isolates (ADR 0010). Lê os arquivos só para leitura, sem baixar placeholders do OneDrive, e detecta arquivo que mudou depois do escaneamento ou durante a leitura (tamanho e data antes e depois). Erro de leitura fica registrado com o motivo e nunca vira "ausente". Pausar/continuar; "tentar de novo" para os que falharam; começa sozinha depois de cada escaneamento e quando um dispositivo conecta. Retomada exata depois de o processo ser morto.
- **Duplicatas exatas e cobertura de backup**: 🔴 só 1 cópia, 🟡 provável cópia (falta conferir), 🟢 cópia conferida no mesmo disco, 🔵 backup em disco independente, ⚪ desconhecido. O mesmo arquivo visto por duas fontes sobrepostas conta uma vez; disco de identidade incerta nunca conta como independente; dispositivo desconectado continua contando. Espaço ocupado por arquivos repetidos, por dispositivo.
- **Comparar com escopo livre** (ADR 0011): A e B com uma ou mais pastas e/ou dispositivos inteiros, filtro por tipo e **escopos salvos com nome**. Resposta direta a "B contém todo o conteúdo de A?" — "Sim, 100%", "Faltam N arquivos (X GB)" com a lista pronta para seleção, ou "Resultado incompleto" quando há arquivo sem conteúdo conferido, pasta não lida ou dispositivo nunca escaneado. Também "Só em B" e "Nos dois". Sempre por conteúdo; nomes e pastas não importam. "Conferir agora" prioriza os arquivos dos dois escopos.
- **Backup automático do catálogo** (`VACUUM INTO`): conferido antes de publicar, nunca sobrescreve, guarda os 10 mais novos e preserva os backups de migração. Automático uma vez por dia ao abrir o app e manual em Configurações.
- **App**: Início com o painel "O que já tem backup e o que ainda não tem" e o progresso da conferência; Dispositivos com a situação de backup e os repetidos de cada fonte; tela **Comparar** completa; **Configurações** com o backup do catálogo.
- **CLI**: `hash run|retry`, `coverage`, `compare A B [--list] [--type]`, `scopes list|save|remove`, `backup now|list`.
- **Schema v2** (aditivo): `file_instances.hash_error` e tabela `saved_scopes`, com teste de migração a partir do snapshot da v1.

### Alterado (ajustes pedidos no teste do usuário)
- **Comparar**: o seletor "Adicionar pasta ou dispositivo" ganhou o botão **"Adicionar nova pasta/dispositivo…"**, que cadastra uma pasta ou unidade, já começa a escanear e deixa a nova fonte selecionada, sem sair da tela; e a dica "Não encontrou? Ela precisa ser adicionada e escaneada primeiro".
- **Comparar**: o resumo separa arquivos de conteúdos ("A: 5 arquivos (4 conteúdos diferentes, 1 repetido)"), e explica que as abas contam conteúdos — "Faltam em B" + "Nos dois" = conteúdos de A. O core passou a devolver `aContents`/`aRepeated`/`bContents`/`bRepeated` (também na saída da CLI `compare`).
- Contadores com plural e concordância em todas as telas: "1 arquivo com só 1 cópia", "4 cópias conferidas", "2 arquivos só na nuvem", "1 mudou durante a leitura".
- Caminhos nas listas com um só separador: "HD_antigo › pasta2 › notas.txt" (antes misturava › e /).

### Corrigido
- O `ProviderScope` do app ficava dentro do `MaterialApp`, e diálogos não enxergavam os providers (o seletor de pastas da comparação quebraria). Achado pelo teste do app com o core real.

### Segurança
- Leitura de arquivos de usuário só por `safe_io/source_reader.dart` (`GENERIC_READ`, `OPEN_EXISTING`, `FILE_FLAG_OPEN_NO_RECALL`); o teste de arquitetura confere as flags e agora também pega os nomes Dart dos bindings (`createFile`, `moveFileEx`).
- Publicação sem sobrescrever (`MoveFileExW` sem `REPLACE_EXISTING`) já usada no backup do catálogo.

### Evidências (critérios da Fase 2)
- Conteúdo idêntico com nomes diferentes é agrupado; mesmo nome com conteúdo diferente não é (testes do core).
- "Só 1 cópia" correto num cenário de 3 fontes (2 no mesmo disco, 1 em outro), inclusive com disco de identidade fraca e fontes sobrepostas.
- Arquivo que cresce ou é reescrito com o mesmo tamanho durante a leitura é detectado.
- Comparação A = pasta1 + pasta2 × B = pasta3, com nomes diferentes e conteúdo parcial: faltam 2 (2.400 bytes), só em B 1, nos dois 2; "incompleto" com hash pendente em qualquer lado (core, CLI, app com core real).
- 100 mil arquivos no catálogo: cobertura ~1,5 s, comparação ~0,2 s, página da lista ~0,2 s (fora da thread da interface).
- Kill no meio da conferência → retomar termina sem duplicar conteúdo; nova execução não faz nada.

### Alterado
- **Requisito da comparação ajustado** (spec §3.2, §9 e §16): A e B passam a ser escopos livres (várias pastas e/ou dispositivos, com filtros), a pergunta principal é "B contém todo o conteúdo de A?" (sempre por conteúdo), com resultado "incompleto" quando há arquivos sem conteúdo conferido, e escopos podem ser salvos com nome.
- CI: `actions/checkout@v7` e `actions/setup-dotnet@v6` (Node 24); `subosito/flutter-action@v2` já usa `actions/cache@v5` (Node 24). Disparo manual (`workflow_dispatch`) para repetir a CI.

### Testes
- VHD: a conferência pelo Windows (`Get-DiskImage`) mostrou que, depois do `detach vdisk` do diskpart, o disco continuava anexado — a tolerância a "already detached" escondia isso. Agora o teste desanexa com `Dismount-DiskImage` e confere o estado, sem tolerância (3 execuções seguidas verdes na CI).

## [0.1.0] — 2026-10-26 — Fase 1: Fundação

### Adicionado
- **Catálogo SQLite v1** (drift): todas as tabelas de `docs/schema-v1.md`, com WAL, `synchronous=FULL` e `foreign_keys`. Recusa abrir um catálogo de versão mais nova, faz backup antes de migrar, usa um único escritor em isolate e permite só um processo por vez (`catalog.lock`).
- **Helper nativo** (C# .NET 10): protocolo JSON-lines v1 (`hello`, `system.*`, cancelamento, vigia do processo pai) e `volumes.list`, que traz GUID, serial, sistema de arquivos, espaço e disco físico, com uma classificação de identidade conservadora para seriais falsos de gavetas USB e de NVMe. Regras de escrita prontas para as próximas fases.
- **Cliente do helper** com reinício automático (espera crescente), ping de vigilância e reserva Win32 quando o helper não está disponível.
- **Cadastro de fontes** (pastas e unidades inteiras), reconhecido por pontuação (ADR 0009) e independente da letra da unidade. Casos ambíguos pedem confirmação, a conectividade é verificada a cada 3 s e há aviso de pastas sobrepostas. Fonte desconectada continua visível com os dados do último scan.
- **Escaneamento de listagem** (sem hash) com `FindFirstFileExW` e caminhos `\\?\`, em isolate próprio, com checkpoint transacional por lote: pausar, retomar e cancelar, scan incremental e retomada após o processo morrer. Uma ausência só é confirmada em scan completo; pasta com erro de leitura nunca vira exclusão. Junctions e symlinks não são seguidos. Placeholders do OneDrive são catalogados sem serem abertos. Lixeira, `System Volume Information`, `.fotoatlas-tmp` e pastas do sistema ficam de fora.
- **CLI** `fotoatlas_cli`: `volumes`, `sources add|list`, `scan start|resume|status`, e crashpoints para testes de falha.
- **Gerador de fixtures sintéticos** determinístico (`tools/fixtures`): nomes de celular/câmera/WhatsApp, Unicode, nomes repetidos, cópias idênticas e caminho com mais de 260 caracteres.
- **App Windows**: navegação lateral com as 6 telas, tema claro/escuro e textos em PT-BR. Telas **Início** (visão geral, alertas, atalhos) e **Dispositivos** (adicionar pasta/unidade, escanear, pausar, retomar, cancelar, renomear, esquecer, confirmar unidade). As demais telas explicam o que virá.
- **CI** no GitHub Actions (windows-latest): helper, core + fixtures e app (análise, formatação, código gerado, testes e build).
- Documentação: `docs/desenvolvimento.md`, atualizações dos ADRs 0007, 0008 e 0009; snapshot do schema (`drift_schemas/drift_schema_v1.json`).

### Segurança
- Teste de arquitetura impede que módulos não autorizados gravem, movam ou apaguem arquivos.
- `GetLastError` via FFI às vezes vem zerado (medido: ~1 em 2.000). A listagem só termina com `ERROR_NO_MORE_FILES` e, em qualquer outro caso, refaz a pasta ou registra erro, nunca uma "lista mais curta".

### Evidências (critérios da Fase 1)
- 50 mil arquivos em 294 pastas escaneados em ~1,6 s; atraso máximo do event loop principal de 10–15 ms durante o scan.
- Troca de letra reconhecida (volumes simulados e VHD real NTFS e FAT32 na CI).
- Fonte desconectada visível com os dados do último scan (testes do core e do app).
- Processo morto no meio do scan (TerminateProcess) → retomada com contagem exata, sem duplicatas.

## Etapa 0 — Planejamento
- Especificação técnica v4.1, roteiro, CLAUDE.md e conceito de logo.
- Análise da especificação, arquitetura, schema SQLite v1, protocolo do helper nativo, ADRs 0001–0009 e plano da Fase 1.
