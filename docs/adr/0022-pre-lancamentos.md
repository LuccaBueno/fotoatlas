# ADR 0022 — Pré-lançamentos (1.3.0-beta.N) que o app nunca oferece

- **Status:** aceita
- **Data:** 2026-11-15

## Contexto
Na Fase 9 o usuário pediu que cada item terminado (com a CI verde 3 vezes seguidas) seja publicado como **pré-lançamento** no GitHub (`1.3.0-beta.1`, `1.3.0-beta.2`…), com instalador, `.sha256` e notas curtas, sem esperar aprovação, e que o aviso de versão nova (ADR 0020) e o "Atualizar agora" (ADR 0021) **ignorem pré-lançamentos**. Ele testa tudo em dezembro e só então sai a 1.3.0 estável.

Problema encontrado no código da 1.2.1: `AppVersion` descartava o sufixo (`2.0.0-beta` = `2.0.0`). Quem estivesse numa `1.3.0-beta.2` nunca receberia a `1.3.0` (versões "iguais"). O `build-installer.ps1` também só aceitava `1.2.3`.

## Decisão
- **Versões no Versionamento Semântico:** `AppVersion` guarda o pré-lançamento e compara como o SemVer: `1.2.1 < 1.3.0-beta.1 < 1.3.0-beta.2 < 1.3.0-beta.10 < 1.3.0`; partes numéricas como números; `+build` ignorado.
- **Só versões estáveis são oferecidas**, em três camadas:
  1. a consulta é a `releases/latest` da API do GitHub, que por definição nunca devolve rascunho nem pré-lançamento;
  2. `parseLatestRelease` descarta resposta com `draft`/`prerelease` verdadeiros **ou** tag com sufixo (`v1.3.0-beta.1` publicada sem a marca);
  3. `UpdateChecker` (aviso ao abrir e "Procurar atualização agora", que alimentam o "Atualizar agora") só aceita versão estável maior que a em uso.
- **Quem usa uma beta** recebe a estável da mesma versão ou mais nova (`1.3.0-beta.2` → `1.3.0`), nunca uma estável mais velha (`1.2.1`). O "Procurar agora" numa beta explica que só versões estáveis são oferecidas. O Sobre mostra "Versão 1.3.0-beta.1 (pré-lançamento)".
- **Instalador:** `FotoAtlas-1.3.0-beta.1-instalador.exe`, `AppVersion` do Inno com o sufixo. O `VersionInfoVersion` (número de quatro partes do Windows) recebe o número do fim do sufixo: `1.3.0-beta.2` → `1.3.0.2`; estável → `1.3.0.0`, como antes. O `--build-name` do Flutter aceita o sufixo (o executável mostra `1.3.0-beta.1` como versão do produto).
- **CI:** o teste de instalar/atualizar passa a instalar um pré-lançamento (`0.8.0-beta.1`) e atualizá-lo pela estável (`0.8.0`), o caminho de dezembro.
- **Publicação:** `gh release create v1.3.0-beta.N --prerelease` só depois de 3 rodadas verdes seguidas da CI no commit da tag; depois, conferir que `releases/latest` continua na estável e que o SHA-256 das notas, do `.sha256` e do instalador baixado de novo são iguais.

## Alternativas descartadas
- **Canal "beta" opcional no app:** o usuário pediu o contrário (nunca oferecer); fica para quando houver pedido.
- **Listar todas as releases (`/releases`) e filtrar no app:** mais dados e mais lógica; `releases/latest` já resolve.

## Consequências
- Testes: `packages\fotoatlas_core\test\update\update_check_test.dart` (ordem SemVer, tag com sufixo e marca de pré-lançamento descartadas, `releases/latest`, beta em uso recebe só estável mais nova); `app\test\notices_test.dart` (mensagem numa beta) e `app\test\distribution_test.dart` (rótulo do Sobre).
- Um catálogo aberto por uma beta com schema novo não abre mais na 1.2.1 (que recusa catálogo mais novo sem modificá-lo); a cópia `pre-migracao-v7-<data>.db` é feita antes de migrar. O roteiro de teste usa só o catálogo da demonstração.
