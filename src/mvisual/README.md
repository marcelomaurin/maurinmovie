# MVisual — Software 2

Indexacao e biblioteca visual.

Especificação funcional: [docs/02-biblioteca-visual.md](../../docs/02-biblioteca-visual.md).

## Arquivos
- `mvisual.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mvisual.lpr` — programa principal.
- `umvisualmain.pas` / `umvisualmain.lfm` — formulário principal (esqueleto: cabeçalho, área de trabalho e barra de status).
- `mvisual.res` — gerado automaticamente pelo Lazarus/lazbuild na primeira compilação; não precisa ser versionado.

## Como compilar
```
lazbuild src/mvisual/mvisual.lpi
```
Saída: `bin/mvisual` (ou `bin/mvisual.exe`); intermediários em `build/mvisual/`.
Código compartilhado em `src/common/` (já está no caminho de busca do `.lpi`).

## Situação
Esqueleto inicial. Compila com `lazbuild` (Lazarus 3.0, Linux) e abre a janela vazia; nenhuma funcionalidade implementada. Ainda não lê `--production`, `--project-id` ou `--revision`, e não cria nem abre `project.json` (ver [docs/12-arquivos-de-projeto.md](../../docs/12-arquivos-de-projeto.md)).
