# Software 3 — Storyboard e sincronização em cascata

## Objetivo
Transformar cenas do roteiro e referências visuais aprovadas em storyboards de abertura e encerramento, com tempo estimado, falas e orientações. O Software 3 tem projeto próprio e versionado, vinculado às revisões exatas dos Softwares 1 e 2.

## Entradas
- Projeto de roteiro validado (Software 1): cenas, falas, ações, personagens, duração e metadados.
- Projeto visual (Software 2): índices, personagens, cenários, objetos, figurinos e imagens referenciais aprovadas.
- Registrar IDs, hashes e revisões das duas origens; nunca alterar os arquivos importados.

## Etapa 1 — Geração automática por IA
1. Percorrer **todas** as cenas do roteiro.
2. Para cada cena, produzir um storyboard com dois quadros: imagem inicial e imagem final.
3. Usar referências visuais e figurinos do Software 2, preservando identidade, cenário, objetos, enquadramento e continuidade.
4. Associar a cada storyboard ID da cena, texto/ações, falas e seus personagens, orientações de ambiente, duração estimada em segundos e minutos e IDs dos ativos visuais.
5. Mostrar duração individual e total; permitir falha isolada e retomada sem perder cenas prontas.
6. Marcar resultados como gerados, aguardando revisão; não aprovar automaticamente.

## Etapa 2 — Revisão e subdivisões
- Revisar storyboard por storyboard, mostrando lado a lado primeiro e último quadro, falas, referências e duração.
- Aprovar, rejeitar, substituir quadros, corrigir duração ou solicitar regeneração por prompt.
- Subdividir um storyboard em N segmentos filhos ordenados, mantendo vínculo com a cena original. Exemplo: 60 minutos em 60 segmentos de um minuto.
- Cada segmento tem quadro inicial, quadro final, duração, falas, orientações e referências; a soma dos tempos dos filhos deve coincidir com a duração da cena.
- **Continuidade exata:** o asset do quadro final do segmento i é o mesmo asset do quadro inicial do segmento i+1. A subdivisão não duplica nem redesenha o quadro de transição.
- Alterações na divisão não apagam versões anteriores.

## Etapa 3 — Ajustes editoriais e propagação automática
- Permitir editar falas, ações, objetos, personagens e orientações de ambiente diretamente no storyboard.
- Enquanto a edição estiver em rascunho, não alterar os projetos de origem.
- Ao **aprovar** a edição no Software 3, criar revisão do storyboard e iniciar uma transação de sincronização com ID único:
  1. **Software 1:** aplicar mudanças editoriais nas cenas afetadas e criar nova revisão do roteiro.
  2. **Software 2:** comparar a nova revisão, atualizar índices e gerar/regenerar automaticamente imagens referenciais afetadas, criando nova revisão visual.
  3. **Software 3:** importar as novas referências, regenerar somente quadros afetados e finalizar a nova revisão do storyboard, atualizando vínculos.
- Exemplo: trocar “pistola” por “bazuca” exige atualização textual no 1, geração das vistas da bazuca no 2 e atualização dos quadros com a nova interação do personagem no 3.
- Preservar referências e ativos não afetados. A mudança de um objeto não deve redesenhar personagens e cenários sem necessidade.
- Falha em qualquer estágio: manter status pendente/erro, registrar detalhes e permitir retomada idempotente; nunca declarar sincronização completa antes da integridade final.
- Impedir loops: mudanças carregam evento de origem e revisões já processadas não geram novo evento equivalente.
- A aprovação do ajuste no storyboard autoriza a cascata automática; imagens novas continuam com rastreabilidade de revisão visual e podem requerer inspeção artística posterior.

## Arquivos e versionamento
- Arquivo independente: `<NomeBase>_Storyboard_R001`, `R002` etc. Extensão a definir.
- Roteiro e visual têm seus próprios contadores de revisão: `<NomeBase>_Roteiro_RNNN`, `<NomeBase>_Visual_RNNN`.
- Números de revisão **não precisam coincidir** entre os três projetos.
- Cada revisão armazena referências exatas às revisões de origem, alterações, prompts, ativos, decisões, datas, estados e falhas. Revisões aprovadas anteriores são imutáveis.

## Critérios de aceite
1. Todas as cenas importadas têm quadro inicial/final, falas e tempo estimado ou falha individual registrada.
2. Segmentos mantêm continuidade por ID de imagem e soma correta das durações.
3. Revisão manual de cada quadro e subdivisões não altera automaticamente a origem até aprovação editorial.
4. Mudança aprovada no Software 3 gera automaticamente revisões encadeadas no 1 e 2 e atualiza os quadros do 3.
5. Troca de objeto reflete nas imagens de referência e nas cenas correspondentes, sem perder ativos antigos.
6. Reabertura do projeto restaura estado, histórico e dependências; falhas podem ser retomadas sem duplicação.

## Limites e decisões pendentes
A geração de vídeo animado final, motor de imagens, formato físico dos arquivos e implementação das interfaces ainda não foram especificados.
