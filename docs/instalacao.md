# Instalar, atualizar e desinstalar o FotoAtlas

Para quem vai usar o FotoAtlas (não precisa de Flutter, .NET nem nada de desenvolvimento). Requisito: Windows 10 (versão 1809 ou mais nova) ou Windows 11, 64 bits.

## Instalar

1. Baixe `FotoAtlas-<versão>-instalador.exe` na página de versões do projeto: https://github.com/LuccaBueno/fotoatlas/releases
2. Abra o arquivo. Como o instalador ainda não tem assinatura digital, o Windows pode mostrar **"O Windows protegeu o computador"**: clique em **Mais informações › Executar assim mesmo**.
3. Escolha se quer um atalho na área de trabalho (vem marcado) e clique em **Instalar**. Não é preciso ser administrador.

O FotoAtlas fica em `C:\Users\<seu usuário>\AppData\Local\Programs\FotoAtlas`, com atalho no menu Iniciar (e na área de trabalho, se você escolheu). O ExifTool e o FFmpeg, usados para ler as datas e os detalhes de fotos e vídeos, já vêm junto.

## Onde ficam os seus dados

| O quê | Onde | Instalar ou atualizar mexe? |
|---|---|---|
| Suas fotos e vídeos | Onde sempre estiveram (celular, HDs, pendrives) | Nunca |
| Catálogo e configurações (o que o FotoAtlas sabe sobre seus arquivos) e os backups automáticos do catálogo | `C:\Users\<seu usuário>\AppData\Roaming\FotoAtlas` | Nunca |
| Miniaturas (cache, pode ser refeito) | `C:\Users\<seu usuário>\AppData\Local\FotoAtlas` | Nunca |
| O programa | `C:\Users\<seu usuário>\AppData\Local\Programs\FotoAtlas` | Sim (só esta pasta) |

O caminho exato do catálogo aparece em **Configurações › Sobre o FotoAtlas**, junto com a versão instalada.

## Atualizar

Baixe o instalador da versão nova e abra, com o FotoAtlas **fechado**. Ele instala por cima, na mesma pasta, e mantém os atalhos. O catálogo e as configurações continuam exatamente como estavam: na próxima vez que o FotoAtlas abrir, ele continua de onde parou.

- Se o FotoAtlas estiver aberto, o instalador pede para fechá-lo antes. Ele nunca fecha o FotoAtlas sozinho (uma cópia em andamento não é interrompida pelo instalador). Se você fechar no meio de uma tarefa, ela continua de onde parou depois.
- Se a versão nova precisar mudar o formato do catálogo, o FotoAtlas guarda antes uma cópia do catálogo em `C:\Users\<seu usuário>\AppData\Roaming\FotoAtlas\backups` (arquivo `pre-migracao-…`).
- Voltar para uma versão mais velha não estraga nada: se o catálogo for de uma versão mais nova, a versão velha avisa e não o modifica.

## Desinstalar

**Configurações do Windows › Aplicativos › Aplicativos instalados › FotoAtlas › Desinstalar** (com o FotoAtlas fechado).

1. Confirme em **Desinstalar** (ou **Cancelar** para desistir). O desinstalador remove o programa e os atalhos. Suas fotos e vídeos nunca são tocados.
2. No fim, ele pergunta o que fazer com o catálogo, as configurações e as miniaturas:
   - **Manter catálogo** (o padrão): ficam guardados. Se você instalar o FotoAtlas de novo, ele continua de onde parou.
   - **Apagar catálogo (vai para a Lixeira)**: as pastas vão para a **Lixeira** (dá para recuperar de lá até você esvaziá-la).

## Problemas comuns

- **"O FotoAtlas está aberto" ao instalar ou desinstalar:** feche o FotoAtlas (se houver uma tarefa em andamento, ele avisa e guarda onde parou) e clique em OK.
- **O antivírus ou o SmartScreen bloqueou:** o instalador não tem assinatura digital paga. Baixe sempre da página oficial do projeto (endereço acima).
