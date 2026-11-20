# MScript — Software 1

Sinopse, roteiro e revisões.

Especificação funcional: [docs/01-roteiro.md](../../docs/01-roteiro.md) · especificação de implementação: [docs/specs/02-mscript.md](../../docs/specs/02-mscript.md).

## Arquivos
- `mscript.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `mscript.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, o modo headless).
- `umscriptmain.pas` — formulário principal montado em código.
- `mscript_icon.rc` / `mscript_icon.res` / `mscript.ico` — ícone do executável.

## Como compilar
```
lazbuild src/mscript/mscript.lpi
```
Saída: `bin/mscript` (Linux) ou `bin/mscript.exe` (Windows); intermediários em `build/mscript/`. Depende de `src/common/` e dos pacotes CHATGPT `openai_core`, `openai_image`, `openai_voice` e `openai_video` (ver [install/README.md](../../install/README.md)).

## Execução
Só pode ser iniciado pelo MMenu, que passa `--launcher mmenu --mmenu-version <v> --production <pasta> --project-id <id> --revision <rNNNN>` (docs/specs/00-comum §4). Permite uma instância por vez.

## Situação
Primeira versão funcional (não cobre ainda toda a especificação):
- Sinopse, título, gênero e duração-alvo; geração do roteiro em cenas pela IA de texto configurada no MMenu (aceita a resposta em texto ou no contrato JSON de `docs/specs/02-mscript.md` §7.3; resposta inválida não substitui o roteiro). Sem provedor real, gera um esboço local de exemplo.
- Edição manual das cenas, inclusão de cena, reescrita de uma cena por prompt.
- Mapa de personagens (somente personagens; objetos ficam nas cenas) com `character_id` preservado entre extrações.
- Rascunho local em `work/roteiro.json` com salvamento automático; publicação de revisões (`scripts/roteiro.json`, `scripts/characters.json`, `scripts/roteiro.md`) e validação explícita (`approved`).
- Modo `--headless --event` (cascata): aplica `script.patch` com as operações `replace_text`, `replace_entity`, `set_duration` e `set_scene_field` sobre a revisão ativa; idempotente por `event_id`; recusa com código 7 (e marca o evento `failed`) fonte desatualizada, texto não encontrado, operação desconhecida ou evento sem operações.

Pendente: comparação de revisões, avisos de consistência, reordenação por arrastar, `set_dialogue`/`add_dialogue`/`remove_dialogue`.
