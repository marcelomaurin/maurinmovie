# Software 1 — Sinopse e roteiro

## Objetivo
Produzir um projeto de filme a partir de uma sinopse com auxílio de IA, para curta ou longa-metragem, mantendo controle editorial e histórico de revisões.

## Fluxo obrigatório
1. Criar/editar sinopse, definir título provisório, gênero, duração-alvo opcional e premissas.
2. Solicitar à IA um roteiro organizado em cenas sequenciais. Cada cena contém ID permanente, ordem, título, descrição da ação, local, período/tempo, personagens presentes, diálogos quando aplicável, duração estimada e clima emocional. A IA pode sugerir objetos e figurinos descritos no texto.
3. Exibir roteiro para edição manual, reescrita parcial/total por prompt e comparação de versões. Nenhuma geração é considerada aprovada automaticamente.
4. Validar explicitamente uma revisão do roteiro; permitir voltar ao rascunho, criar novas revisões e manter revisões anteriores acessíveis.
5. Após validação, extrair mapa textual de personagens e metadados por personagem e por cena, incluindo descrições físicas e de figurino presentes no roteiro; permitir conferência e validação.
6. Salvar projeto próprio, com identificadores estáveis, revisões, roteiro, cenas, mapa de personagens e metadados para consumo pelo Software 2.

## Regras
- O roteiro validado e seus metadados são a fonte editorial de verdade. O Software 2 não altera esse conteúdo silenciosamente.
- Revisão publicada é imutável; mudanças produzem nova revisão. IDs das cenas devem sobreviver a alterações de ordem e texto sempre que representam a mesma cena.
- Preservar autoria humana, prompts, data, alterações e estado de validação.
- A IA pode sugerir correções de inconsistências; alterações requerem confirmação.

## Saídas
Projeto de roteiro independente e versionado, exportável/importável, com sinopse, roteiro por cenas, personagens, figurinos descritos, metadados e revisão aprovada.
