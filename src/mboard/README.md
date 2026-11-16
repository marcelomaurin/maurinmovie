# MBoard — Software 3

Storyboard e sincronizacao editorial.

Especificação funcional: [docs/05-storyboard.md](../../docs/05-storyboard.md).

## Arquivos
- `mboard.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mboard.lpr` — programa principal.
- `umboardmain.pas` / `umboardmain.lfm` — formulário principal (esqueleto: cabeçalho, área de trabalho e barra de status).
- `mboard.res` — gerado automaticamente pelo Lazarus/lazbuild na primeira compilação; não precisa ser versionado.

## Como compilar
```
lazbuild src/mboard/mboard.lpi
```
Saída: `bin/mboard` (ou `bin/mboard.exe`); intermediários em `build/mboard/`.
Código compartilhado em `src/common/` (já está no caminho de busca do `.lpi`).

## Situação
Esqueleto inicial. Compila com `lazbuild` (Lazarus 3.0, Linux) e abre a janela vazia; nenhuma funcionalidade implementada. Ainda não lê `--production`, `--project-id` ou `--revision`, e não cria nem abre `project.json` (ver [docs/12-arquivos-de-projeto.md](../../docs/12-arquivos-de-projeto.md)).
