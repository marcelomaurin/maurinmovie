# Estado da implementação e próximos critérios de aceite

Os requisitos continuam em [docs/specs](specs/README.md). Esta leitura compara as especificações com o código e separa o que já está disponível dos fluxos que ainda precisam ser completados.

| Área | Código disponível | Pendências verificáveis |
|---|---|---|
| Protocolo MMP | Projetos por programa, revisões, fontes, manifesto SHA-256, catálogo e SQLite. MScript tem rascunho e a plataforma oferece argumentos padronizados. | Padronizar rascunho, bloqueio por projeto, abertura histórica somente leitura e processamento sem janela nos demais apps. Consolidar a fila de eventos, a retomada de transações e os esquemas JSON. |
| MMenu | Abre produções, inicia apps, mantém configurações e mostra artefatos, integridade, registros e histórico. O MCut fica disponível quando a produção tem um vídeo de cena aprovado. O MMenu retoma ou cancela a correção editorial iniciada no MBoard. | Expor em conjunto os estados por cena e por transação. |
| MScript | Gera e edita roteiro, extrai personagens, mantém rascunho e publica revisões. Aplica alterações estruturadas por cena sem janela, com validação da revisão de origem e proteção contra duplicação. | Ampliar o registro de impacto, a comparação e o histórico do roteiro. |
| MVisual | Indexa entidades, conserva as vistas existentes ao retomar o lote, registra aprovações e publica o índice com hash. As edições ficam em rascunho. | Completar detecção de mudanças por entidade, comparação por vista e variante e resolução manual de ambiguidades. |
| MBoard | Gera abertura, encerramento e quadros intermediários com a referência aprovada disponível. Preserva quadros aprovados de cenas equivalentes e valida a soma dos tempos e as fronteiras compartilhadas antes de publicar. | Ampliar seleção e edição das referências, oferecer outros critérios de subdivisão e retomar automaticamente a geração de quadros com falha. |
| MSound | Indexa falas por personagem e segmento, permite ajustar tempos e adicionar efeitos WAV com licença. Exporta prévias da cena e de seus segmentos com tempos, faixas e volumes. | Completar cadastro de autorização e fluxo de clonagem real, sugestões de efeitos e reordenação visual da timeline. |
| MScene | Gera e valida MP4 por segmento a partir do quadro inicial do MBoard. Costura segmentos aprovados, publica o vídeo e registra os vínculos da cena. Envia o WAV do MSound quando a revisão do storyboard e a política de aprovação permitem. | Enviar quadro final e referências visuais suplementares a provedores de vídeo compatíveis. Completar a inspeção das junções com trecho contínuo, checklist e comentários. O modo local do provedor é uma demonstração com imagem estática. |
| MCut | Usa vídeos aprovados por revisão, verifica SHA-256, aplica cortes, fade de saída e dissolve e exporta MP4 ou MKV. O relatório registra duração e checksum. A média do público usa somente a revisão selecionada. | Completar o player e edição avançada na timeline, comparações de transições, sessões de exibição, reavaliação por trecho e histórico de decisões editoriais. |

## Exportação

Configure FFmpeg e FFprobe em **MMenu → Configurações → Executáveis e ferramentas**, ou deixe ambos no `PATH`. No MScene, gere os segmentos, revise cada vídeo, costure a cena e aprove a revisão. Use os arquivos do novo projeto de cena no MCut. Revisões antigas que só têm o JSON de montagem precisam ser renderizadas no MScene para fornecer o vídeo.

No MCut, monte a timeline e configure cortes e transições. Uma saída de corte igual a `0` usa o fim do clipe. **Salvar e Exportar Filme** grava o vídeo e o relatório na pasta `video/exports` da nova revisão. Uma timeline com cena ausente, sem aprovação ou com mídia divergente do manifesto é registrada como pendente.


## Prévia sonora

Publique o storyboard e abra o MSound. Crie o banco, selecione uma linha na aba **Ensaio Sincronizado** e use **Gerar Prévia WAV da Cena**. Os tempos são relativos ao começo da cena, em milissegundos. Os efeitos WAV importados podem sobrepor falas. Cada evento editado deve permanecer dentro do seu segmento. Publique a revisão do MSound para disponibilizar os WAVs ao MScene. O MScene usa o WAV apenas se o storyboard vinculado for o mesmo e o artefato passar na verificação de integridade. O provedor de vídeo local FFmpeg aceita esse arquivo como guia.

## Retomar uma correção editorial

No MBoard, aplique a edição de ação ou diálogo à cena, aprove-a e envie pela ação de cascata. Na aba de sincronização do MMenu, selecione a transação e clique em **Retomar sincronização**. O MScript publica a correção na cena escolhida se a revisão do roteiro ainda corresponder à solicitação. Revise e publique o MVisual usando esse roteiro. Retome a transação para abrir o MBoard, gere a partir das fontes atualizadas e publique os quadros. Retome novamente para conferir os vínculos e encerrar. A geração e a aprovação visual continuam sob controle do operador. Se o roteiro tiver mudado em paralelo, revise a alteração antes de emitir outra solicitação.
