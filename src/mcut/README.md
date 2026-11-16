# MCut — Software 6

Montagem do filme, avaliacao de publico e exportacao.

Especificação funcional: [docs/08-montagem-final.md](../../docs/08-montagem-final.md).

## Arquivos
- `mcut.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mcut.lpr` — programa principal.
- `umcutmain.pas` / `umcutmain.lfm` — formulário principal (esqueleto: cabeçalho, área de trabalho e barra de status).
- `mcut.res` — gerado automaticamente pelo Lazarus/lazbuild na primeira compilação; não precisa ser versionado.

## Como compilar
```
lazbuild src/mcut/mcut.lpi
```
Saída: `bin/mcut` (ou `bin/mcut.exe`); intermediários em `build/mcut/`.
Código compartilhado em `src/common/` (já está no caminho de busca do `.lpi`).

## Situação
Esqueleto inicial. Compila com `lazbuild` (Lazarus 3.0, Linux) e abre a janela vazia; nenhuma funcionalidade implementada. Ainda não lê `--production`, `--project-id` ou `--revision`, e não cria nem abre `project.json` (ver [docs/12-arquivos-de-projeto.md](../../docs/12-arquivos-de-projeto.md)).
