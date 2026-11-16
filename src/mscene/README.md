# MScene — Software 5

Geracao, revisao e montagem de cenas.

Especificação funcional: [docs/07-geracao-e-montagem-de-cenas.md](../../docs/07-geracao-e-montagem-de-cenas.md).

## Arquivos
- `mscene.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mscene.lpr` — programa principal.
- `umscenemain.pas` / `umscenemain.lfm` — formulário principal (esqueleto: cabeçalho, área de trabalho e barra de status).
- `mscene.res` — gerado automaticamente pelo Lazarus/lazbuild na primeira compilação; não precisa ser versionado.

## Como compilar
```
lazbuild src/mscene/mscene.lpi
```
Saída: `bin/mscene` (ou `bin/mscene.exe`); intermediários em `build/mscene/`.
Código compartilhado em `src/common/` (já está no caminho de busca do `.lpi`).

## Situação
Esqueleto inicial. Compila com `lazbuild` (Lazarus 3.0, Linux) e abre a janela vazia; nenhuma funcionalidade implementada. Ainda não lê `--production`, `--project-id` ou `--revision`, e não cria nem abre `project.json` (ver [docs/12-arquivos-de-projeto.md](../../docs/12-arquivos-de-projeto.md)).
