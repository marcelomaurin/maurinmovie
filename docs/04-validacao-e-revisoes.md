# Critérios de aceite e revisão

## Software 1
1. Sinopse gera roteiro organizado em cenas com IDs estáveis e metadados.
2. Roteiro pode ser editado manualmente e reescrito por prompt, sem perda da versão anterior.
3. Projeto só é marcado validado após aprovação explícita.
4. Mapa textual de personagens e descrições de figurino deriva do roteiro validado.
5. Projeto pode ser salvo, fechado e reaberto com suas revisões.

## Software 2 — Etapa 1
1. Importa uma revisão validada do Software 1 sem modificar a origem.
2. Identifica e relaciona pessoas, locais, objetos e figurinos por cena.
3. Consultas entidade → cenas e cena → entidades funcionam, inclusive por aliases.
4. Cada referência possui evidência no roteiro e ID persistente.
5. Etapa 1 não gera imagens.

## Software 2 — Etapa 2
1. Geração automática percorre entidades indexadas e registra resultado ou erro por item.
2. Personagens e objetos recebem vistas frontal, traseira, direita e esquerda; cenários têm conjunto documentado de vistas.
3. Figurinos são separados da identidade base e vinculados ao roteiro.
4. Imagens e variantes possuem ID, metadados e relações com entidades e cenas.
5. Falhas podem ser retomadas sem perder resultados anteriores.

## Software 2 — Etapa 3
1. Aprovação, rejeição, edição manual e correção por prompt estão disponíveis individualmente.
2. Alterações preservam versões e aprovações anteriores.
3. Projeto visual é salvo e reaberto independentemente, preservando vínculo com revisão do roteiro.
4. Mudanças no roteiro são detectadas e geram proposta de atualização incremental, não sobrescrita automática.

## Pendências para próxima rodada
Definir plataforma/linguagem, formatos de projeto, motores de IA e geração de imagens, armazenamento de mídia, políticas de custos/execução local, e interfaces dos dois aplicativos.
