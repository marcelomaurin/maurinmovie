# MSound — Software 4

Identidades vocais, efeitos e previa sonora.

Especificação funcional: [docs/06-identidade-sonora.md](../../docs/06-identidade-sonora.md).

## Arquivos
- `msound.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `msound.lpr` — programa principal.
- `umsoundmain.pas` / `umsoundmain.lfm` — formulário principal (esqueleto: cabeçalho, área de trabalho e barra de status).
- `msound.res` — gerado automaticamente pelo Lazarus/lazbuild na primeira compilação; não precisa ser versionado.

## Como compilar
```
lazbuild src/msound/msound.lpi
```
Saída: `bin/msound` (ou `bin/msound.exe`); intermediários em `build/msound/`.
Código compartilhado em `src/common/` (já está no caminho de busca do `.lpi`).

## Situação
Esqueleto inicial. Compila com `lazbuild` (Lazarus 3.0, Linux) e abre a janela vazia; nenhuma funcionalidade implementada. Ainda não lê `--production`, `--project-id` ou `--revision`, e não cria nem abre `project.json` (ver [docs/12-arquivos-de-projeto.md](../../docs/12-arquivos-de-projeto.md)).
