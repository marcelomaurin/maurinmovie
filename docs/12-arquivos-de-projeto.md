# Contrato de arquivo de projeto de cada aplicativo — MMP v1

## Dois níveis diferentes
1. **Projeto-fonte Lazarus:** cada programa possui seu próprio `.lpi`, `.lpr`, unidade `.pas` e formulário `.lfm` dentro de `src/<app>/` no repositório de desenvolvimento. O `.lpi` é o projeto do **executável**, não do filme.
2. **Projeto de produção (artefato do filme):** cada aplicativo salva, **dentro da pasta da produção**, seu próprio `project.json` e diretórios `revisions/rNNNN/manifest.json`. O `project.json` é o arquivo de projeto que o usuário abre no aplicativo, e deve ser tratado como artefato de primeira classe, indexado pelo MMenu.

## Nomes e caminhos
| App | Projeto Lazarus (código) | Projeto de produção (dados) |
|---|---|---|
| MMenu | `src/mmenu/mmenu.lpi` | `projects/00-mmenu/project.json` |
| MScript | `src/mscript/mscript.lpi` | `projects/01-mscript/project.json` |
| MVisual | `src/mvisual/mvisual.lpi` | `projects/02-mvisual/project.json` |
| MBoard | `src/mboard/mboard.lpi` | `projects/03-mboard/project.json` |
| MSound | `src/msound/msound.lpi` | `projects/04-msound/project.json` |
| MScene | `src/mscene/mscene.lpi` | `projects/05-mscene/project.json`, e projetos versionados por cena em `scenes/<scene_id>/` |
| MCut | `src/mcut/mcut.lpi` | `projects/06-mcut/project.json` |

Todos os caminhos de produção são relativos a `productions/<slug>__<production_id>/`.

## Obrigatoriedade do artefato project.json
Cada aplicativo cria ou abre o arquivo `project.json` em sua pasta própria. Ele contém `schema`, `production_id`, `project_id`, `application`, `active_revision`, `revision_history`, `created_at`, `updated_at` e `settings`. O manifesto de cada revisão enumera seus artefatos (scripts, imagens, áudio, vídeo) e referências exatas de origem. **Nenhum aplicativo grava diretamente o projeto de outro.**

## Regras
- MMenu identifica e abre o arquivo de projeto correto, não apenas o executável.
- Não armazenar conteúdo binário grande dentro do JSON: registrar URIs, hash SHA-256 e tamanho.
- Atualizar `project.json` atomicamente, com backup; revisões publicadas são imutáveis.
- MScene admite projetos por cena, preservando o índice principal do aplicativo.
- Projetos podem ser copiados/movidos junto com a produção sem quebrar referências relativas.
- Ao criar uma nova produção, inicializar os projetos necessários; não confundir modelos vazios com projetos de produção efetivamente criados.

## Situação da implementação
A criação da produção (MMenu), a leitura de `project.json`/`manifest.json`, a publicação de revisões (`PublishProjectRevision` em `src/common/ummpappbase.pas`) e a auditoria de integridade estão implementadas e cobertas por `tests/test_mmp_protocol.pas`. Cada aplicativo cria/abre seu `project.json` e publica revisões imutáveis; o trabalho em edição fica em `projects/NN-app/work/` (MScript: `work/roteiro.json`; demais: `work/draft/`). A situação funcional de cada aplicativo está no `README.md` da respectiva pasta em `src/`.
