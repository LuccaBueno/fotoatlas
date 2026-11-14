# 0020 — Aviso de versão nova (consulta ao GitHub)

- Status: aceita
- Data: 2026-11-14

## Contexto
Até a 1.0.0, o usuário só sabia de uma versão nova se fosse olhar o GitHub (ADR 0019: "sem atualização automática"). Pedido do usuário (2026-11-14): ao abrir, no máximo uma vez por dia e desligável em Configurações, o app consulta a última versão publicada em `github.com/LuccaBueno/fotoatlas` e, se houver versão nova, mostra um aviso discreto com "Baixar", que abre a página da versão. Nunca baixa nem instala sozinho, não envia nenhum dado pessoal e, sem internet, falha em silêncio.

É o primeiro acesso à rede do FotoAtlas. A regra 12 da spec ("tudo funciona offline; nenhum dado pessoal sai do computador sem autorização explícita") continua valendo: o app funciona igual sem internet, e a consulta não leva nada do usuário.

## Decisão
- **Onde:** `packages\fotoatlas_core\lib\src\update\update_check.dart` (Dart puro, `dart:io` `HttpClient`; nenhuma dependência nova). O app só chama `AppBackend.checkForUpdate` uma vez ao abrir (`availableUpdateProvider`) e mostra a faixa `UpdateBanner` acima do conteúdo.
- **O que vai:** um `GET https://api.github.com/repos/LuccaBueno/fotoatlas/releases/latest`, sem corpo, sem cookies e sem parâmetros, com `User-Agent: FotoAtlas` (o GitHub exige um) e `Accept: application/vnd.github+json`. Nem a versão instalada é enviada: a comparação é feita no computador. O GitHub vê o endereço IP de quem pergunta, como em qualquer acesso à internet; o texto de Configurações diz que nenhuma informação do usuário é enviada.
- **Frequência:** no máximo uma consulta por dia (`update.lastCheckMs` na tabela `settings`). A tentativa conta mesmo sem internet, para não insistir a cada abertura. Relógio que voltou para trás conta como "já passou um dia".
- **Desligar:** Configurações › Atualizações › "Procurar versão nova ao abrir" (`update.checkEnabled`, ligado por padrão). Desligado, não há nenhum acesso à rede.
- **Versão de desenvolvimento** (sem `FOTOATLAS_VERSION`, como no `run-app.ps1` e nos testes): nunca consulta.
- **Falhas:** sem internet, DNS, demora (limite de 10 s), resposta diferente de 200, JSON estranho, rascunho ou pré-lançamento → nenhum aviso, nada registrado na tela.
- **"Baixar":** abre a página da versão no navegador padrão (`explorer.exe <endereço>`). Só abre páginas que começam com `https://github.com/LuccaBueno/fotoatlas/releases/`: se o `html_url` da resposta for outro, usa o endereço montado a partir da versão. O FotoAtlas nunca baixa nem executa o instalador.
- **"Agora não"** esconde o aviso até a próxima abertura do app (e a próxima consulta só acontece no dia seguinte).
- Versões comparadas número a número (`1.10.0 > 1.9.0`); `v` na frente e sufixos (`-beta`, `+build`) são ignorados.

## Alternativas descartadas
- **Atualizar sozinho** (baixar e instalar): contraria o pedido e a regra de prévia + confirmação; o instalador também não deve fechar o app no meio de uma cópia (ADR 0019).
- **Pacote `url_launcher`** para abrir o navegador: traria um plugin nativo só para isso; `explorer.exe` com o endereço conferido resolve.
- **Consultar a cada abertura:** desnecessário; uma vez por dia basta para saber de versões novas.

## Consequências
- Testes: `packages\fotoatlas_core\test\update\update_check_test.dart` (comparação de versões, leitura da resposta, endereço fora do repositório oficial, servidor local que confere que o pedido não leva corpo nem cookies, erro, demora e conexão recusada → `null`, uma vez por dia, desligado e versão de desenvolvimento nunca consultam); `app\test\notices_test.dart` (faixa com "Baixar" e "Agora não", sem versão nova nenhum aviso, Configurações).
- Se o repositório mudar de lugar, versões antigas param de avisar (falham em silêncio); a página de versões continua sendo o caminho manual.
