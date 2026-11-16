# Software 6 — Montagem final, avaliação do público e exportação do filme

## Objetivo
Montar o filme completo na **ordem das cenas estabelecida pelo roteiro**, usando cenas aprovadas e versionadas do Software 5. A ordem é narrativa, não necessariamente cronológica dentro da história. Permitir assistir, ajustar montagem e transições, coletar avaliações do público, analisar os resultados, revisar trechos e exportar o filme completo.

## Entradas e rastreabilidade
- Software 1: projeto e revisão exata do roteiro, ordem narrativa, IDs e metadados de cenas.
- Software 5: vídeo de cada cena e sua revisão, duração, status de aprovação, dependências dos projetos 1–4 e vínculos de continuidade.
- A montagem guarda também os IDs, caminhos/URIs, hashes e revisões exatas dos projetos 1–5, direta ou transitivamente. É possível abrir o projeto original no aplicativo correspondente.
- Se uma cena estiver ausente, reprovada ou com mídia quebrada, mostrar pendência explícita; não substituí-la silenciosamente.

## Etapa 1 — Montagem inicial assistível e edição
1. IA lê o roteiro aprovado e organiza as cenas do Software 5 **uma a uma, na ordem do roteiro**.
2. Constrói linha do tempo com player do filme completo, navegação por cena, timecode e identificação da revisão de origem.
3. Permite assistir, pausar, marcar pontos, aparar início/fim e realizar cortes de montagem não destrutivos, preservando a cena original.
4. Quando o ajuste exigir modificar o conteúdo interno da cena (ações, diálogos, imagens, sincronismo), abrir o projeto correto no Software 5, na revisão vinculada; se necessário, a revisão segue em cascata aos Softwares 1–4. Ao retornar, atualizar o vínculo para a nova revisão e recompor somente a parte afetada.
5. Registrar edições de timeline, decisões, origem e duração resultante.

## Etapa 2 — Transições e acabamento entre cenas
- Aplicar e ajustar corte seco, fade in, fade out e outros efeitos de transição entre cenas.
- Permitir pré-visualização, comparação, duração e parametrização das transições.
- Transições não modificam silenciosamente o conteúdo aprovado dentro da cena; alterações internas retornam ao Software 5.
- Salvar as configurações como dados editáveis da montagem, sem sobrescrever os vídeos-fonte.

## Etapa 3 — Sessões de avaliação com público
- Criar sessão de exibição de uma revisão identificada do filme; cadastrar/convidar participantes (ex.: dez pessoas), com controle de acesso e consentimento.
- Participantes assistem ao filme ou às cenas disponibilizadas e registram **nota e comentário por cena**, vinculados a scene_id, revision_id, participante/sessão e instante/trecho opcional.
- Preservar avaliações individuais e data; permitir respostas anônimas ou identificadas conforme configuração e proteger os dados dos avaliadores.
- Permitir **reavaliação dirigida** de uma cena ou fragmento alterado, opcionalmente com segundos de contexto anterior e posterior, sem obrigar o público a rever o filme todo.
- Vincular cada nova avaliação à revisão exata e ao trecho exibido; não misturar avaliações de revisões diferentes.

## Etapa 4 — Análise dos dados e ciclo de correções
- Consolidar notas, quantidade de respostas, distribuição, comentários e tendências **por cena e por revisão**, distinguindo ausência de resposta de avaliação negativa.
- Comparar avaliações antes/depois de uma alteração, inclusive para fragmentos, e apontar problemas recorrentes: duração, ritmo, compreensão, continuidade, som, transições.
- Produzir relatório com evidências e recomendações de ação; IA pode sugerir melhorias, mas não alterar criativamente o filme sem decisão do responsável.
- Uma correção aprovada identifica o software responsável, abre a revisão de origem e cria **nova revisão** nos projetos afetados. Refaz apenas artefatos dependentes, retorna ao Software 6 e atualiza a montagem.
- Após a correção, repetir as etapas pertinentes do Software 6: assistir à montagem alterada, conferir transições, solicitar reavaliação do público do trecho quando desejado e comparar resultados.
- Rastrear ciclo completo: feedback → decisão → revisão no software de origem → nova mídia → nova montagem → reavaliação. Não sobrescrever versões aprovadas nem criar loops de sincronização.

## Etapa 5 — Salvamento e renderização final
- Verificar ordem, integridade das mídias, revisões, aprovações necessárias, áudio, transições e pendências de montagem.
- Salvar projeto próprio `<NomeBase>_Filme_RNNN` (extensão a definir), incluindo timeline, transições, cortes, sessões de público, relatórios, decisões, histórico e referências aos projetos 1–5.
- Renderizar **o filme inteiro** na ordem aprovada, com as cenas, transições, som e configurações de vídeo corretos. Permitir escolher formato, resolução, codec e demais parâmetros de exportação (implementação a definir).
- Registrar versão do render, parâmetros, checksums, arquivo de saída, duração e relatório de exportação. Uma falha não deve ser anunciada como exportação concluída.
- Preservar projetos e renders anteriores; nova alteração gera nova revisão.

## Modelo conceitual adicional
- film_project: film_project_id, base_name, revision_id, parent_revision_id, status
- sources[]: software_id, project_id, revision_id, URI, checksum
- timeline_items[]: item_id, scene_id, scene_video_revision_id, order, in_point, out_point, duration, transition_in/out
- screenings[]: session_id, film_revision_id, invited_participants[], access_policy, created_at
- feedback[]: feedback_id, session_id, participant_id_or_anonymous, scene_id, fragment_range?, revision_id, rating, comment, timestamp
- analyses[]: analysis_id, compared_revision_ids[], per_scene_metrics, findings, proposed_actions
- correction_cycles[]: cycle_id, feedback_ids[], decision, affected_project_ids[], before_after_revisions[], status
- exports[]: export_id, film_revision_id, file_uri, format, resolution, codec, duration, checksum, status

## Critérios de aceite
1. Dez cenas são exibidas na ordem do roteiro, mesmo que os fatos narrados não sejam cronológicos.
2. Etapa 1 permite assistir ao filme e editar cortes; alteração de conteúdo interno retorna ao Software 5 na revisão correta.
3. Etapa 2 permite prévia e configuração de fade in/out e transições entre cenas.
4. Etapa 3 registra comentários e notas por cena, por participante e por revisão; permite reexibir apenas fragmento corrigido.
5. Etapa 4 analisa resultados por cena, compara versões e rastreia revisões e retornos aos softwares anteriores.
6. Correções retornam ao Software 6 para completar novamente as etapas impactadas, sem perder histórico.
7. Etapa 5 salva projeto versionado e gera o filme completo; mídias ausentes e falhas de renderização são reportadas.
8. Cada cena do filme aponta à revisão exata do Software 5 e permite rastrear as fontes 1–4.

## Decisões técnicas pendentes
Formatos de projeto e exportação, mecanismo de timeline/renderização, sistema de convite ao público, política de privacidade/retenção e parâmetros de qualidade serão definidos no projeto técnico.
