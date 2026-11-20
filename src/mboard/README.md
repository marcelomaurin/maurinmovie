# MBoard — Software 3

Storyboard e sincronização editorial.

Especificação funcional: [docs/05-storyboard.md](../../docs/05-storyboard.md) · especificação de implementação: [docs/specs/04-mboard.md](../../docs/specs/04-mboard.md).

## Arquivos
- `mboard.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mboard.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, o modo headless).
- `umboardmain.pas` — formulário principal montado em código.
- `mboard_icon.rc` / `mboard_icon.res` / `mboard.ico` — ícone do executável.

## Como compilar
```
lazbuild src/mboard/mboard.lpi
```
Saída: `bin/mboard` (Linux) ou `bin/mboard.exe` (Windows); intermediários em `build/mboard/`. Depende de `src/common/` e dos pacotes CHATGPT `openai_core`, `openai_image`, `openai_voice` e `openai_video` (ver [install/README.md](../../install/README.md)).

## Execução
Só pode ser iniciado pelo MMenu, que passa `--launcher mmenu --mmenu-version <v> --production <pasta> --project-id <id> --revision <rNNNN>` (docs/specs/00-comum §4). Permite uma instância por vez.

## Situação
Primeira versão funcional:
- Etapa 1: gera quadro inicial e final por cena a partir das revisões ativas do MScript e do MVisual (imagem pela IA quando configurada, senão quadro provisório).
- Etapa 2: subdivide uma cena em N segmentos com continuidade exata (o quadro final do segmento *i* é o mesmo `asset_id` do inicial do segmento *i+1*) e soma de durações igual à da cena.
- Ajustes editoriais em rascunho e aprovação por cena; a revisão só é `approved` com todas as cenas aprovadas.
- "Aprovar e Cascata": monta operações `script.patch` comparando os quadros editados com o roteiro, registra evento e transação e executa o MScript em modo headless (estágio 1). Os estágios MVisual e MBoard ficam registrados como pendentes e a transação só fica `complete` quando todos publicarem.
- Quadros novos ficam no rascunho `work/draft/` até a publicação.

Pendente: atualização automática dos estágios MVisual/MBoard da cascata, retomada (`--resume-transaction`) e "Atualizar fontes".
