<p align="center"><img src="docs/assets/logo-conceito.jpg" width="160" alt="FotoAtlas"></p>

# FotoAtlas

## ⬇️ Baixar

<p align="center">
  <a href="https://github.com/LuccaBueno/fotoatlas/releases/latest"><img src="https://img.shields.io/badge/Baixar_o_FotoAtlas-Windows_10_e_11-2ea44f?style=for-the-badge&logo=windows" alt="Baixar o FotoAtlas para Windows" height="48"></a>
</p>

1. Clique no botão acima e, em **Assets**, baixe o arquivo **`FotoAtlas-<versão>-instalador.exe`**.
2. Abra o arquivo baixado e clique em **Instalar**.
3. Se aparecer **"O Windows protegeu o computador"**, clique em **Mais informações › Executar assim mesmo** (o instalador ainda não tem assinatura digital).

> ⚠️ **Não baixe "Source code (zip)" nem "Source code (tar.gz)"**: isso é o código-fonte para programadores, não o programa. O que você quer é o arquivo terminado em **`-instalador.exe`**.

Funciona no Windows 10 (versão 1809 ou mais nova) e no Windows 11, 64 bits.

---

Organizador de fotos e vídeos para Windows: descobre o que você tem em cada celular, HD e pendrive, mostra **o que já tem backup e o que ainda falta**, e copia e reorganiza tudo **sem perder nenhum arquivo**, mesmo se a energia cair no meio.

## Instalar e atualizar

Não é preciso ser administrador nem instalar mais nada: o ExifTool e o FFmpeg já vêm junto. Na instalação, você pode escolher se quer um atalho na área de trabalho. Para atualizar, feche o FotoAtlas e instale a versão nova por cima: o catálogo e as configurações continuam como estavam. Mais detalhes em [Instalar, atualizar e desinstalar](docs/instalacao.md).

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
