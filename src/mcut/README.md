# MCut — Software 6

Montagem do filme, avaliação de público e exportação.

Especificação funcional: [docs/08-montagem-final.md](../../docs/08-montagem-final.md) · especificação de implementação: [docs/specs/07-mcut.md](../../docs/specs/07-mcut.md).

## Arquivos
- `mcut.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mcut.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, MVisual e MBoard, o modo headless).
- `umcutmain.pas` — formulário principal montado em código.
- `mcut_icon.rc` / `mcut_icon.res` / `mcut.ico` — ícone do executável.

## Como compilar
```
lazbuild src/mcut/mcut.lpi
```
Saída: `bin/mcut` (Linux) ou `bin/mcut.exe` (Windows); intermediários em `build/mcut/`. Depende de `src/common/` e dos pacotes CHATGPT `openai_core`, `openai_image`, `openai_voice` e `openai_video` (ver [install/README.md](../../install/README.md)).

## Execução
Só pode ser iniciado pelo MMenu, que passa `--launcher mmenu --mmenu-version <v> --production <pasta> --project-id <id> --revision <rNNNN>` (docs/specs/00-comum §4). Permite uma instância por vez.

## Situação
Primeira versão funcional:
- Monta a timeline na ordem narrativa do roteiro, apontando cada cena para a revisão do projeto da cena no MScene; cena ausente aparece como pendência explícita.
- Cortes (in/out) e transições como dados da montagem, avaliações por cena e análise consolidada.
- "Salvar e Exportar" grava o filme com ffmpeg (`video/exports/filme_<rev>.mp4` ou `.mkv` sem perdas: trechos In/Out, corte, fusão ou fade para preto, resolução do formato) e publica a revisão com timeline, avaliações, análise, relatório (arquivo, duração, tamanho, SHA-256) e o artefato `video.film`. Com cenas pendentes, o estado é `pending_scenes_missing` e o filme não é gravado; falha do ffmpeg gera `export_failed`. As fontes do manifesto incluem o MScript e cada projeto de cena do MScene.
- "Assistir filme exportado" abre o filme da revisão atual.

Pendente: player embutido, vários trechos por cena, trilha musical/mixagem e sessões de público com participantes.
