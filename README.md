<p align="center"><img src="docs/assets/logo-conceito.jpg" width="160" alt="FotoAtlas"></p>

# FotoAtlas

Organizador de fotos e vídeos para Windows: descobre o que você tem em cada celular, HD e pendrive, mostra **o que já tem backup e o que ainda falta**, e copia e reorganiza tudo **sem perder nenhum arquivo**, mesmo se a energia cair no meio.

## Baixar e instalar

**[Baixar a versão mais recente](https://github.com/LuccaBueno/fotoatlas/releases/latest)** (Windows 10 versão 1809 ou mais nova, ou Windows 11, 64 bits).

1. Na página da versão, baixe `FotoAtlas-<versão>-instalador.exe`, em **Assets**.
2. Abra o arquivo. Se aparecer **"O Windows protegeu o computador"**, clique em **Mais informações › Executar assim mesmo** (o instalador não tem assinatura digital).
3. Escolha se quer um atalho na área de trabalho e clique em **Instalar**.

Não é preciso ser administrador nem instalar mais nada: o ExifTool e o FFmpeg já vêm junto. Para atualizar, feche o FotoAtlas e instale a versão nova por cima: o catálogo e as configurações continuam como estavam. Mais detalhes em [Instalar, atualizar e desinstalar](docs/instalacao.md).

## Por que existe

Backups espalhados, pastas organizadas de jeitos diferentes, fotos do celular copiadas só em parte. Copiar tudo de novo "por garantia" só cria mais duplicatas. O FotoAtlas responde:

1. O que eu tenho e onde está?
2. O que já tem backup e o que ainda não tem?
3. O que eu quero levar para onde?
4. Como deixo tudo organizado sem perder nada?

## Princípios

- Analisar nunca modifica seus arquivos.
- Nada é apagado ou sobrescrito automaticamente.
- Toda cópia é conferida byte a byte (SHA-256) e recuperável após interrupções.
- Funciona offline; nenhuma foto ou localização sai do seu computador.

## Tecnologias

Flutter · Dart · SQLite · C# .NET 10 (APIs do Windows) · ExifTool · FFmpeg

## Documentação

- [Instalar, atualizar e desinstalar](docs/instalacao.md)
- [Especificação](docs/FOTOATLAS_SPEC.md)
- [Roteiro](docs/ROADMAP.md)
- [Desenvolvimento: build, testes e execução](docs/desenvolvimento.md)
- [Arquitetura](docs/arquitetura.md)
- [Schema do catálogo (v1 + mudanças da v2)](docs/schema-v1.md)
- [Protocolo do helper nativo](docs/protocolo-helper.md)
- [Análise da especificação](docs/analise-spec.md)
- [Decisões técnicas (ADRs)](docs/adr/)

## Licença

MIT
