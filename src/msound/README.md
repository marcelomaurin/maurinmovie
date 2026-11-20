# MSound — Software 4

Identidades vocais, efeitos e prévia sonora.

Especificação funcional: [docs/06-identidade-sonora.md](../../docs/06-identidade-sonora.md) · especificação de implementação: [docs/specs/05-msound.md](../../docs/specs/05-msound.md).

## Arquivos
- `msound.lpi` — projeto Lazarus do executável (não é o projeto do filme).
- `msound.lpr` — programa principal (valida o contexto do MMenu, instância única e, no MScript, o modo headless).
- `umsoundmain.pas` — formulário principal montado em código.
- `msound_icon.rc` / `msound_icon.res` / `msound.ico` — ícone do executável.

## Como compilar
```
lazbuild src/msound/msound.lpi
```
Saída: `bin/msound` (Linux) ou `bin/msound.exe` (Windows); intermediários em `build/msound/`. Depende de `src/common/` e dos pacotes CHATGPT `openai_core`, `openai_image`, `openai_voice` e `openai_video` (ver [install/README.md](../../install/README.md)).

## Execução
Só pode ser iniciado pelo MMenu, que passa `--launcher mmenu --mmenu-version <v> --production <pasta> --project-id <id> --revision <rNNNN>` (docs/specs/00-comum §4). Permite uma instância por vez.

## Situação
Primeira versão funcional:
- Etapa 1: cria um perfil de voz por personagem do MScript e um efeito de ambiente, com prévias WAV provisórias.
- Etapa 2: escuta isolada (síntese pela IA de voz configurada no MMenu ou pelo sintetizador do sistema), ajustes e aprovação por item.
- Etapa 3: eventos por cena na linha do tempo e ensaio apenas sonoro.
- Áudios novos ficam no rascunho `work/draft/`; a revisão só é `approved` com todos os itens aprovados.

Pendente: efeitos por objeto/ação a partir do roteiro, exportação da prévia em WAV, clonagem com autorização anexada.
