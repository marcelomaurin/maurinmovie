# Modelo lógico e interoperabilidade (proposta)

## Princípios
Cada aplicativo mantém projeto próprio; o segundo guarda referência à identidade e revisão exata do primeiro. Formato físico (JSON, banco, pacote) será decidido na implementação. IDs estáveis não dependem de nomes visíveis.

## Projeto 1
- project_id, title, synopsis, revision_id, parent_revision_id, status, created_at, approved_at
- scenes[]: scene_id, sequence, heading, location_ref, time_of_day, action, dialogue[], estimated_duration, mood, mentions[]
- characters[]: character_id, name, aliases[], description, wardrobe_descriptions[], metadata
- revision_history[]: author, timestamp, change_summary, approval

## Projeto 2
- visual_project_id, visual_revision_id, parent_visual_revision_id, status
- source: script_project_id, script_revision_id, source_digest
- entities[]: entity_id, type (character|location|object|costume), canonical_name, aliases[], description, attributes, evidence[]
- appearances[]: entity_id, scene_id, role, costume_id?, state?, notes?, evidence_span?
- assets[]: asset_id, entity_id, view (front|back|right|left|other), variant_id?, file_ref, checksum, generation_metadata, approval_status, revision_id
- variants[]: variant_id, entity_id, variant_type, base_asset_ids[], applicable_scene_ids[], attributes
- approvals[]: target_id, decision, reviewer, timestamp, comments
- change_log[]: source_revision, affected_ids[], change_type, action, decision

## Integridade
- Todas as ocorrências apontam para entidades e cenas existentes na revisão importada.
- A identidade base é separada do figurino e de outras variações.
- Referências a arquivos são relativas ao pacote de projeto ou gerenciadas por manifesto; checksums detectam corrupção.
- Itens removidos do roteiro devem ser arquivados/assinalados, não apagados silenciosamente.
- O catálogo suporta busca por aliases e índice reverso de cenas.

## Exemplo conceitual
Cena 1 → PERSONAGEM_X, CASA_PROTAGONISTA, OBJETO_1; Cena 4 → PERSONAGEM_X, OBJETO_1; Cena 10 → PERSONAGEM_X, OBJETO_1. PERSONAGEM_X → [1,4,10].

## Projeto 3 — Storyboard
- storyboard_project_id, storyboard_revision_id, parent_revision_id, name_base, status
- sources: script_project_id/revision_id e visual_project_id/revision_id (exatos)
- scene_boards[]: scene_id, board_id, order, estimated_duration_seconds, opening_asset_id, closing_asset_id, dialogue_refs[], direction_notes[], visual_entity_refs[]
- segments[]: segment_id, parent_board_id, order, duration_seconds, opening_asset_id, closing_asset_id, dialogue_refs[], direction_notes[]
- revisions[]: revision_id, source_event_id, change_set, approval, generated_assets, status
- sync_transactions[]: transaction_id, initiating_storyboard_revision, script_revision_before/after, visual_revision_before/after, storyboard_revision_after, stage_status, errors, idempotency_key

## Regras entre projetos
- Projetos são independentes, nomeados `<NomeBase>_Roteiro_RNNN`, `<NomeBase>_Visual_RNNN`, `<NomeBase>_Storyboard_RNNN`. Contadores independentes, sem exigir números iguais.
- A última imagem de um segmento deve referenciar **o mesmo asset_id** que a primeira do próximo segmento (não apenas imagem semelhante).
- A soma das durações dos segmentos deve coincidir com a duração da cena; ao alterar duração, recalcular ou apontar divergência.
- A aprovação de mudança no Software 3 cria evento único; aplica revisão no 1, depois no 2, e regenera os quadros afetados no 3. Registrar estados intermediários e permitir retomada idempotente sem loop.
- A revisão anterior permanece imutável; o estado `sincronizado` exige integridade e conclusão de todas as etapas, e não implica aprovação artística automática de imagens novas.


## Projetos 4 e 5
- Sonoro: sound_project_id, revision_id, source_projects[1..3], voice_profiles[] (character_id, voice_id, timbre, synthesis_config, permissions), sound_assets[] (asset_id, entity_id, event_id, revision), timeline_events[] (scene_id, segment_id, start/end, asset_id), approvals[], previews[].
- Vídeo por cena: video_project_id, revision_id, scene_id, source_projects[1..4], segments[] (segment_id, video_asset_id, status, duration, dependencies), assembled_scene_asset_id, adjacent_scene_links[] (neighbor_scene_id, direction, status, review), approvals[], revision_history[].
- Todos guardam URI/caminho, project_id, revisão exata e hash das fontes; IDs estáveis suportam abertura cruzada e revisões em cascata. Ligações com cenas ainda inexistentes são pendentes, não aprovadas.
