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
