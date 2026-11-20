# MVisual — Software 2

Indexação e biblioteca visual.

Especificação funcional: [docs/02-biblioteca-visual.md](../../docs/02-biblioteca-visual.md) · especificação de implementação: [docs/specs/03-mvisual.md](../../docs/specs/03-mvisual.md).

## Arquivos
- `mvisual.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mvisual.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, MVisual e MBoard, o modo headless).
- `umvisualmain.pas` — formulário principal montado em código.
- `mvisual_icon.rc` / `mvisual_icon.res` / `mvisual.ico` — ícone do executável.

## Como compilar
```
lazbuild src/mvisual/mvisual.lpi
```
Saída: `bin/mvisual` (Linux) ou `bin/mvisual.exe` (Windows); intermediários em `build/mvisual/`. Depende de `src/common/` e dos pacotes CHATGPT `openai_core`, `openai_image`, `openai_voice` e `openai_video` (ver [install/README.md](../../install/README.md)).

## Execução
Só pode ser iniciado pelo MMenu, que passa `--launcher mmenu --mmenu-version <v> --production <pasta> --project-id <id> --revision <rNNNN>` (docs/specs/00-comum §4). Permite uma instância por vez.

## Situação
Primeira versão funcional:
- Etapa 1: indexa personagens, locais, objetos e figurinos a partir de uma revisão **aprovada** do MScript (revisões não aprovadas são recusadas); personagens reutilizam o `character_id` do MScript.
- Etapa 2: gera as 4 vistas (frontal, costas, direita, esquerda) pela IA de imagem configurada no MMenu, usando a frontal como referência; sem provedor, grava imagens provisórias (`.bmp`). Pode parar e retomar sem refazer o que já existe.
- Etapa 3: aprovar/rejeitar item (gravado no SQLite da produção), filtro de nitidez, publicação. A revisão só recebe `approved` quando todos os itens foram aprovados; caso contrário é publicada como `published`.
- Imagens e o índice em edição ficam no rascunho `work/draft/`; a revisão publicada nunca é reescrita.

Modo headless: `mvisual --headless --event <arquivo>` (evento `source.update` da cascata) reindexa a partir da revisão ativa do roteiro e publica com `change_event_id`; recusa (código 7) se houver rascunho aberto.

Pendente: ambiguidades/correferências, variantes, comparação de versões e geração automática das vistas de entidades novas.
