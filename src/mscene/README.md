# MScene — Software 5

Geração, revisão e montagem de cenas.

Especificação funcional: [docs/07-geracao-e-montagem-de-cenas.md](../../docs/07-geracao-e-montagem-de-cenas.md) · especificação de implementação: [docs/specs/06-mscene.md](../../docs/specs/06-mscene.md).

## Arquivos
- `mscene.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mscene.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, o modo headless).
- `umscenemain.pas` — formulário principal montado em código.
- `mscene_icon.rc` / `mscene_icon.res` / `mscene.ico` — ícone do executável.

## Como compilar
```
lazbuild src/mscene/mscene.lpi
```
Saída: `bin/mscene` (Linux) ou `bin/mscene.exe` (Windows); intermediários em `build/mscene/`. Depende de `src/common/` e dos pacotes CHATGPT `openai_core`, `openai_image`, `openai_voice` e `openai_video` (ver [install/README.md](../../install/README.md)).

## Execução
Só pode ser iniciado pelo MMenu, que passa `--launcher mmenu --mmenu-version <v> --production <pasta> --project-id <id> --revision <rNNNN>` (docs/specs/00-comum §4). Permite uma instância por vez.

## Situação
Primeira versão funcional:
- Uma cena por vez: cria o projeto da cena em `projects/05-mscene/scenes/<scene_id>/` e lista os segmentos do storyboard.
- Gera as descrições dos sub-blocos e uma prévia (vídeo pela IA de vídeo/FFmpeg quando disponível), aprovação por sub-bloco, costura (registro da ordem) e marcação das ligações anterior/próxima (próxima inexistente fica pendente).
- Arquivos novos ficam no rascunho do projeto da cena (`work/draft/`).

Pendente: geração real de vídeo por segmento, costura com ffmpeg, reprodução anterior/atual/próxima e retomada por segmento.
