# Software 0 — MMenu (portal MaurinMovie)

## Objetivo
Ser a porta de entrada para os seis aplicativos independentes do MaurinMovie, mantendo um ponto central de navegação e acesso a projetos, revisões e pendências. MMenu não substitui os arquivos de projeto nem altera silenciosamente o conteúdo editorial.

## Aplicativos oficiais
- 0 — **MMenu**: portal e lançador de projetos.
- 1 — **MScript**: sinopse, roteiro e revisões.
- 2 — **MVisual**: indexação e biblioteca visual.
- 3 — **MBoard**: storyboard e sincronização editorial.
- 4 — **MSound**: identidades vocais, efeitos e prévia sonora.
- 5 — **MScene**: geração, revisão e montagem de cenas individuais.
- 6 — **MCut**: montagem do filme, avaliações de público e exportação final.

Os nomes são escritos **sem espaço** após o M. O nome da suíte permanece MaurinMovie.

## Funções do portal
1. Exibir menu com os seis aplicativos e permitir iniciá-los diretamente.
2. Listar os projetos disponíveis, identificando ID, nome, caminho/URI, software de origem, revisão, status e última atualização.
3. Permitir escolher um projeto e abrir o aplicativo responsável já com **o arquivo e a revisão exata**.
4. Exibir o estado geral da produção: revisões em uso, cenas pendentes, geração de imagens/áudio/vídeo, avaliações e sincronizações em cascata.
5. Exibir em qual etapa uma sincronização falhou e permitir navegar até o aplicativo responsável; não declarar conclusão antes da confirmação de cada etapa.
6. Resolver arquivos movidos por ID/manifesto quando possível; caso não encontrados, solicitar revinculação, sem presumir caminhos.
7. Manter projetos separados: MMenu agrega referências, não consolida os dados internos em um arquivo único.
8. Preservar histórico e permitir visualizar vínculos entre projetos e suas revisões sem confundir revisão de aplicativo com versão do executável.

## Modelo conceitual
- workspace_id, workspace_name, project_refs[] (software_id, project_id, revision_id, uri, checksum, status)
- application_registry[] (software_id, display_name, executable_location, supported_project_types)
- sync_jobs[] (event_id, source_revision, affected_projects[], stage, status, error)
- recent_projects[], missing_links[], user_preferences

## Critérios de aceite
1. O menu apresenta MScript, MVisual, MBoard, MSound, MScene e MCut com grafia correta.
2. Cada aplicativo abre o projeto/revisão selecionado sem perder rastreabilidade.
3. MMenu mostra pendências e falhas de sincronização sem afirmar que foram concluídas.
4. Arquivos movidos são localizados por ID ou sinalizados para revinculação.
5. O portal não sobrescreve revisões dos seis aplicativos.

## Decisões técnicas pendentes
Linguagem, sistema operacional alvo, mecanismo de execução, extensão do workspace, gerenciamento de caminhos e instalação dos executáveis.
