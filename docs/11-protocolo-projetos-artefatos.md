# Protocolo de projetos e artefatos MaurinMovie — MMP v1 (proposta)

## Objetivo
Padronizar diretórios, manifestos, IDs, revisões, dependências e ciclo de vida dos arquivos produzidos por MMenu, MScript, MVisual, MBoard, MSound, MScene e MCut. **Uma produção/filme = uma pasta-raiz**; cada aplicativo possui subpasta e projetos independentes dentro dela. O MMenu indexa os projetos, mas não precisa duplicar os dados. O protocolo MMP v1 é a convenção inicial a validar por protótipo.

## Layout físico recomendado
```text
MaurinMovie/
  productions/
    filme-exemplo__p_01J.../
      production.json               # ID, título, versão do protocolo, projetos ativos
      catalog.json                  # índice de artefatos e relações, reconstruível
      settings/
        production.json             # configurações gerais do filme
        ai-providers.json           # provedores/modelos, SEM segredos
      projects/
        00-mmenu/
          project.json
          revisions/r0001/manifest.json
        01-mscript/
          project.json
          revisions/r0001/
            manifest.json
            scripts/roteiro.json
            scripts/roteiro.md
        02-mvisual/
          project.json
          revisions/r0001/
            manifest.json
            indexes/entities.json
            images/personagens/...
            images/objetos/...
            images/cenarios/...
        03-mboard/
          project.json
          revisions/r0001/
            manifest.json
            storyboard/scenes.json
            images/quadros/...
        04-msound/
          project.json
          revisions/r0001/
            manifest.json
            voices/profiles.json
            audio/voices/...
            audio/effects/...
            audio/previews/...
        05-mscene/
          project.json
          scenes/<scene_id>/
            revisions/r0001/
              manifest.json
              video/segments/...
              video/assembled/...
              audio/guides/...
        06-mcut/
          project.json
          revisions/r0001/
            manifest.json
            timeline/timeline.json
            feedback/sessions.json
            feedback/ratings.json
            analysis/report.json
            video/exports/...
      shared/
        imports/                    # material externo, preservando origem
        cache/                      # descartável/regerável, nunca fonte da verdade
        temp/                       # arquivos parciais
        logs/                       # logs por app, data e execução
      backups/
```
- Cada diretório `revisions/rNNNN` publicado é **imutável**. Em produção, escrever primeiro em `shared/temp/<job_id>/`, validar e publicar atomicamente a revisão.
- O layout é lógico: mídias grandes podem ficar em armazenamento externo, desde que o manifesto registre URI e hash. Não duplicar vídeos/áudios pesados a cada revisão; referenciar blobs imutáveis por hash em um armazenamento de mídia gerenciado.
- `production.json` e `catalog.json` são índices atualizáveis com escrita atômica e cópia de segurança. Projetos e manifestos são a fonte de verdade; catálogo pode ser reconstruído.

## Contrato mínimo dos arquivos
`production.json`:
```json
{
  "schema": "mmp.production/1",
  "production_id": "p_01JEXEMPLO",
  "title": "Filme Exemplo",
  "created_at": "2026-11-16T09:00:00Z",
  "active_projects": {
    "MScript": {"project_id": "pr_script_01", "revision_id": "r0001"},
    "MVisual": {"project_id": "pr_visual_01", "revision_id": "r0002"}
  }
}
```

`project.json` (ponteiro editável do aplicativo):
```json
{
  "schema": "mmp.project/1",
  "production_id": "p_01JEXEMPLO",
  "project_id": "pr_script_01",
  "application": "MScript",
  "active_revision": "r0002",
  "revision_history": ["r0001", "r0002"]
}
```

`manifest.json` (imutável por revisão):
```json
{
  "schema": "mmp.manifest/1",
  "production_id": "p_01JEXEMPLO",
  "project_id": "pr_scene_01",
  "application": "MScene",
  "revision_id": "r0003",
  "parent_revision_id": "r0002",
  "state": "approved",
  "created_at": "2026-11-16T09:10:00Z",
  "sources": [
    {"project_id": "pr_board_01", "revision_id": "r0004", "manifest_sha256": "<sha256>"}
  ],
  "artifacts": [
    {
      "artifact_id": "a_01JEXEMPLO",
      "kind": "video.segment",
      "scene_id": "sc_0001",
      "segment_id": "sg_0001",
      "uri": "video/segments/sc_0001_sg_0001.mp4",
      "mime_type": "video/mp4",
      "sha256": "<sha256>",
      "bytes": 123456,
      "status": "approved"
    }
  ],
  "change_event_id": "evt_01JEXEMPLO"
}
```
Exemplos ilustrativos; hashes e IDs são marcadores, não valores reais. Em implementação, adotar identificadores únicos gerados pela aplicação e validação formal dos esquemas.

## Identificadores e nomes
- **ID imutável e global por produção:** `production_id`, `project_id`, `scene_id`, `segment_id`, `character_id`, `object_id`, `voice_id`, `artifact_id`, `event_id`. Nomes de exibição podem mudar sem trocar IDs.
- **Revisão sequencial por projeto:** `r0001`, `r0002`, ...; revisões de aplicativos diferentes não precisam coincidir.
- Arquivo físico com nome legível: `<scene_id>_<segment_id>_<tipo>_<variante>.<ext>`. O **manifesto é a autoridade**, não o nome do arquivo.
- Caminhos relativos à raiz do manifesto para arquivos locais; URIs externas explícitas para mídia fora da pasta. Normalizar separadores e proibir `../` que escape da raiz.
- Referências de mídia incluem SHA-256, tamanho, tipo MIME, origem, modelo/parâmetros quando gerada por IA, licença/permissões, estado e revisão de criação.

## Protocolo de comunicação entre aplicativos
1. MMenu mantém o registro de executáveis e o catálogo de produções; abre o aplicativo escolhido com argumentos padronizados:
   `MScript --production "<pasta-raiz>" --project-id "pr_script_01" --revision "r0002"`.
2. Cada aplicativo lê `production.json`, resolve o projeto por ID e valida `schema`, revisão, hashes e fontes; nunca adivinha revisão por nome do arquivo.
3. Cada aplicativo escreve exclusivamente seu espaço de projeto; alterações editoriais em outro aplicativo são **solicitações de revisão**, não gravação direta no arquivo alheio.
4. Para comunicação inicial, usar arquivos de eventos JSON em fila local persistente ou IPC, a escolher na arquitetura. Envelope obrigatório: `event_id`, `production_id`, `origin_app`, `target_app`, `project_id`, `source_revision`, `requested_change`, `affected_ids`, `created_at`, `status`.
5. Estados de tarefa: `queued → running → awaiting_review → approved → published`, ou `failed/cancelled`; estados de sincronização independentes (`pending/in_progress/complete/failed`). Reprocessar pelo mesmo `event_id` não deve duplicar revisões.
6. Alterações aprovadas disparam grafo de dependências: roteiro → visual → storyboard → som → vídeo de cena → montagem. Calcular impacto por IDs, reprocessar apenas dependentes afetados, detectar ciclos, preservar revisão anterior e registrar falhas recuperáveis.
7. Publicação transacional: gerar em temp, verificar integridade, registrar manifesto, mover para revisão imutável, atualizar `project.json` e `catalog.json` atomicamente quando possível; nunca apontar revisão ativa para artefato incompleto.
8. Lock por projeto/revisão durante gravação; permitir leitura concorrente de revisões publicadas. Falhas de energia ou processo não devem corromper revisão aprovada.

## Tipos de artefato mínimos
- MScript: `script.scene`, `script.dialogue`, `script.character`.
- MVisual: `visual.character.reference`, `visual.object.reference`, `visual.location.reference`.
- MBoard: `storyboard.frame`, `storyboard.segment`.
- MSound: `audio.voice.profile`, `audio.effect`, `audio.preview`.
- MScene: `video.segment`, `video.scene`, `audio.guide`.
- MCut: `film.timeline`, `feedback.rating`, `analysis.report`, `video.film.export`.
- MMenu: `workspace.registry`, `sync.status`.

## Administração e recuperação
- **Painel de artefatos no MMenu:** filtrar por produção, aplicativo, cena, personagem, tipo, revisão, status, tamanho e origem; localizar dependências e abrir arquivo/projeto no aplicativo correto.
- **Integridade:** auditoria de hashes, mídia ausente, referências quebradas, versões de esquema e fontes incompatíveis.
- **Armazenamento:** cache descartável; importações originais preservadas; política de retenção e limpeza de renders obsoletos mediante confirmação; backups externos recomendados.
- **Segurança:** tokens de provedores fora dos projetos exportáveis, em armazenamento seguro do sistema; não gravar segredos em JSON, logs ou Git.
- **Migrações:** `schema` com versão; migrar criando nova revisão/backup, sem reescrever histórico imutável.
- **Portabilidade:** exportar/importar a pasta da produção com manifesto, ou pacote com mídias externas incluídas e URIs remapeadas; validar hashes ao importar.

## Testes de aceite do protocolo
1. Criar uma produção e os sete projetos sem colisão de IDs.
2. Reabrir MScene a partir do MMenu com revisão exata do storyboard, visual e som.
3. Renomear personagem e recuperar todas as referências por ID.
4. Mover pasta da produção e resolver todos os caminhos relativos.
5. Simular queda durante geração: revisão aprovada continua íntegra e trabalho temporário pode ser retomado.
6. Alterar um objeto numa cena e atualizar somente artefatos afetados, sem loops ou duplicações.
7. Detectar áudio/vídeo corrompido por hash e impedir publicação/exportação incorreta.
8. Exportar e reimportar produção preservando revisões e dependências.
9. Mudar uma cena e manter o filme antigo reproduzível até a nova revisão ser aprovada.

## Pendências para arquitetura
Definir formato físico de armazenamento de blobs, IPC versus fila em arquivos, schemas JSON formais, migrações, locking multiplataforma, codecs, limite de tamanho e política de limpeza. Essas escolhas não alteram a semântica dos IDs, manifestos e revisões.
