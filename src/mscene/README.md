# MScene — Software 5

Geração, revisão e montagem de cenas.

Especificação funcional: [docs/07-geracao-e-montagem-de-cenas.md](../../docs/07-geracao-e-montagem-de-cenas.md) · especificação de implementação: [docs/specs/06-mscene.md](../../docs/specs/06-mscene.md).

## Arquivos
- `mscene.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mscene.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, MVisual e MBoard, o modo headless).
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
- Gera o vídeo de cada sub-bloco (`video/segments/*.mp4`): IA de vídeo real quando configurada; senão animática com os quadros do MBoard, falas (voz sintetizada ou amostra do MSound) e ambiência do local (`ummpmedia`).
- Aprovação por sub-bloco, costura com ffmpeg em `video/assembled/<cena>.mp4`, prévia da ligação com a cena anterior/próxima e botões Assistir (mpv ou programa padrão).
- Lista os pedidos de correção do MCut (`shared/events/inbox/MScene`); salvar a cena atende o pedido (evento arquivado, transação concluída).
- Arquivos novos ficam no rascunho do projeto da cena (`work/draft/`).

Pendente: reprodução embutida, regeneração de um único segmento e regras de sequência entre cenas.
