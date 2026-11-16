# Software 2 — Indexação, referências visuais e continuidade

## Objetivo
Construir catálogo visual consistente de personagens, cenários e objetos a partir de uma revisão validada do projeto de roteiro. Seu projeto é independente do Software 1, mas guarda vínculo explícito com a revisão de origem.

## Etapa 1 — Leitura, identificação e indexação (sem geração de imagens)
- Importar projeto e revisão do Software 1; verificar integridade e disponibilidade das cenas.
- IA analisa cada cena e identifica personagens, locais/cenários, objetos relevantes, figurinos e menções indiretas. Resolve correferências (ex.: João, protagonista, ele) e nomes alternativos sem perder evidência textual.
- Atribuir ID permanente a cada entidade, classificar tipo, descrição canônica, aliases, atributos, fonte (cena/trecho) e relacionamentos.
- Construir índice bidirecional: entidade → cenas e cena → entidades, com papel, estado, figurino e contexto em cada ocorrência. Exemplos: personagem X nas cenas 1, 4 e 10; objeto 1 nas cenas 1, 4 e 10.
- Identificar ambiguidades, duplicidades e divergências para revisão; não fundir entidades incertas automaticamente.
- Permitir consulta por nome/alias, ID, cena, categoria e atributos; inicialmente exibir fichas e ocorrências, e após a etapa 2 também todas as imagens associadas.

## Etapa 2 — Geração automática de referências visuais
- Para cada entidade indexada, gerar ou associar imagens referenciais e registrar prompt, modelo, parâmetros, semente quando disponível, origem, versão e vínculo com o ID.
- **Personagens:** ficha de identidade visual base independente do figurino; vistas padronizadas frontal, costas, perfil direito e perfil esquerdo, com enquadramento, escala, proporções e fundo consistentes. Figurinos são entidades/camadas separadas derivadas das descrições do Software 1, associadas a personagem e cenas.
- **Objetos:** vistas padronizadas frontal, traseira, direita e esquerda, com possibilidade de superior/inferior e estados controlados (aberto, fechado, danificado) conforme roteiro.
- **Cenários:** referências gerais e vistas/ângulos padronizados documentados, planta ou relações espaciais quando disponíveis; preservar arquitetura, mobiliário e elementos fixos entre cenas.
- Gerar variações controladas de roupa, pose, expressão, iluminação, estado e ângulo sem redefinir a identidade base. Registrar dependências e diferenças.
- Processamento em lote automático, com progresso, falhas individualizadas e possibilidade de retomar sem regenerar itens válidos.
- A geração de imagem é tentativa sujeita à validação: não pressupor consistência perfeita entre imagens; usar referências e verificações de continuidade.

## Etapa 3 — Validação e edição
- Painel de revisão item a item com todas as vistas, variantes, origem textual, cenas associadas e histórico.
- Ações: aprovar, rejeitar, editar manualmente, solicitar alteração por prompt, regenerar seletivamente e comparar versões.
- Aprovação da identidade base separada da aprovação dos figurinos e variantes; uma alteração não deve sobrescrever ativos aprovados.
- Registrar autor, data, comentário, prompt e versão. Impedir que item pendente seja marcado como aprovado por mera geração automática.
- Salvar projeto visual próprio com índice, arquivos/imagens, metadados, vínculos e histórico de validação.

## Revisões e sincronização
- O projeto visual referencia ID e revisão exata do projeto de roteiro de origem.
- Ao receber revisão nova do roteiro, comparar cenas, entidades e descrições; classificar inclusões, exclusões e alterações.
- Propor revisão incremental do projeto visual, atualizando somente referências afetadas; manter imagens e aprovações não afetadas, com opção de revisão humana das mudanças.
- Nunca alterar automaticamente uma revisão visual já aprovada; registrar origem e dependências.

## Consultas esperadas
- “Ator X”: listar todas as imagens, figurinos, variantes e cenas vinculadas ao personagem.
- “Casa do protagonista”: mostrar imagens do cenário, vistas e todas as cenas de uso.
- “Cena 10”: listar personagens, cenários, objetos e figurinos correspondentes, com referências aprovadas.

## Fora do escopo confirmado
Geração de vídeo final, animação 3D, modelagem 3D, montagem e áudio ainda não foram definidos como requisitos destes dois aplicativos.
