# MScript — Software 1

Sinopse, roteiro e revisoes.

Especificação funcional: [docs/01-roteiro.md](../../docs/01-roteiro.md).

## Arquivos
- `mscript.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mscript.lpr` — programa principal.
- `umscriptmain.pas` / `umscriptmain.lfm` — formulário principal (esqueleto: cabeçalho, área de trabalho e barra de status).
- `mscript.res` — gerado automaticamente pelo Lazarus/lazbuild na primeira compilação; não precisa ser versionado.

## Como compilar
```
lazbuild src/mscript/mscript.lpi
```
Saída: `bin/mscript` (ou `bin/mscript.exe`); intermediários em `build/mscript/`.
Código compartilhado em `src/common/` (já está no caminho de busca do `.lpi`).

## Situação
Esqueleto inicial. Compila com `lazbuild` (Lazarus 3.0, Linux) e abre a janela vazia; nenhuma funcionalidade implementada. Ainda não lê `--production`, `--project-id` ou `--revision`, e não cria nem abre `project.json` (ver [docs/12-arquivos-de-projeto.md](../../docs/12-arquivos-de-projeto.md)).
