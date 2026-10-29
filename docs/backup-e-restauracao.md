# Cópias, backup do catálogo e o que fazer depois de uma queda

## O que o FotoAtlas garante numa cópia
- A origem nunca é alterada (só leitura).
- Cada arquivo é gravado em `<destino>\.fotoatlas-tmp\<uuid>.part`, enviado ao disco (`FlushFileBuffers`), **relido** e comparado pelo conteúdo (SHA-256) com o que foi lido da origem. Só então ele aparece no destino, com um renomear que nunca substitui outro arquivo.
- Nada é sobrescrito: nome ocupado vira `IMG_1.jpg`, `IMG_2.jpg`… (ou espera a sua decisão).
- Nada é apagado, exceto o arquivo temporário do próprio FotoAtlas que ainda não foi publicado (ADR 0016).
- Toda etapa fica no diário (catálogo). Depois de uma queda, ao abrir, o FotoAtlas confere o disco e termina o que ficou no meio; o resto espera "Continuar" na tela Tarefas.

## Limitação conhecida (R3)
Os testes automáticos matam o processo em cada etapa, mas isso **não** simula uma queda de energia que perde o cache de gravação do Windows nem um disco USB que diz "gravado" antes de gravar. Por isso:
- a cópia usa `FlushFileBuffers` e `MOVEFILE_WRITE_THROUGH`, e o catálogo usa `synchronous=FULL`;
- a recuperação nunca confia só no diário: relê o arquivo temporário ou o publicado e confere o conteúdo antes de considerá-lo copiado;
- se não for possível ter certeza, o arquivo fica como "Precisa da sua decisão" na tela Tarefas.

Recomendação: depois de uma queda de energia no meio de uma cópia para HD USB, abra o FotoAtlas com o HD conectado e deixe a recuperação conferir antes de desligar o disco.

## Arquivos na pasta temporária
`.fotoatlas-tmp` na raiz do destino guarda os arquivos em andamento. Arquivos que não pertencem a nenhuma cópia em andamento aparecem nos detalhes da cópia, na tela Tarefas, e **nunca são apagados automaticamente**. Os de conferência que não bateu ficam para diagnóstico (o disco pode ter problemas). Você pode apagá-los à mão depois de conferir.

## Backup do catálogo
Automático a cada 24 h (`VACUUM INTO`, últimos 10) em `%APPDATA%\FotoAtlas\backups`. O catálogo não é armazenamento: apagar ou restaurar o catálogo nunca apaga fotos.
