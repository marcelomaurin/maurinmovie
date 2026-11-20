# 3 — MBoard (storyboard e sincronização)

Executável: `mboard` / `mboard.exe` · código: [src/mboard](../../src/mboard) · requisitos: [docs/05-storyboard.md](../05-storyboard.md) · especificação: [docs/specs/04-mboard.md](../specs/04-mboard.md)

Transforma as cenas do roteiro e as referências visuais em storyboards com quadro inicial e final, duração e falas; subdivide cenas em segmentos com continuidade exata e propaga ajustes editoriais aprovados para o roteiro.

## Aba Quadros & Edição

![Quadros](imagens/mboard-quadros.png)

| Elemento | Uso |
|---|---|
| **Etapa 1: Gerar Storyboard** | Percorre todas as cenas do roteiro ativo e gera quadro inicial e final de cada uma (imagem pela IA quando configurada, senão quadro provisório). Tudo fica `generated` |
| Grade de storyboards | Board, cena, cabeçalho, duração, número de segmentos e estado (`generated`, `edited`, `approved`) |
| Quadro Inicial / Quadro Final | Imagens da cena selecionada, lado a lado |
| Duração, Falas/Ação, Orientações de câmera | Campos editáveis; **Salvar Ajuste (Rascunho)** marca o storyboard como `edited` sem mexer no roteiro |
| **Aprovar Cena Selecionada** | Aprova o storyboard |

## Aba Segmentos & Continuidade

![Segmentos](imagens/mboard-segmentos.png)

**Etapa 2: Subdividir Cena...** divide a cena em N segmentos (até 60). A soma das durações é igual à da cena e o quadro final do segmento *i* é **o mesmo `asset_id`** do quadro inicial do segmento *i+1* (no exemplo, `a_mid_1` fecha o segmento 1 e abre o 2); o primeiro começa no quadro inicial da cena e o último termina no final.

## Cabeçalho

- **Publicar Revisão:** `approved` se todas as cenas estiverem aprovadas, senão `published`.
- **Aprovar e Cascata:** compara os storyboards `edited` com o roteiro de origem e monta as operações (`replace_text` de ação e falas, `set_duration`). Depois registra o evento e a transação e executa o MScript sem janela, que publica a nova revisão do roteiro. Os estágios MVisual e MBoard ficam pendentes na transação, acompanhada no MMenu (aba Sincronizações). Se o MScript estiver aberto, a alteração for ambígua ou a fonte estiver desatualizada, a transação fica `failed` com o motivo.

## Arquivos

Rascunho em `projects/03-mboard/work/draft/images/quadros/`; revisão em `revisions/rNNNN/storyboard/scenes.json` (`storyboard.segment`) e `images/quadros/*` (`storyboard.frame`), com as revisões do MScript e do MVisual como fontes.

## Ainda não implementado

Atualização automática dos estágios MVisual e MBoard da cascata, retomada de transação, "Atualizar fontes" ao abrir, substituição de quadro por arquivo e critérios de subdivisão por falas.
