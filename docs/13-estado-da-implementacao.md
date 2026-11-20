# Estado da implementação e próximos critérios de aceite

Os requisitos continuam em [docs/specs](specs/README.md). Esta leitura compara as especificações com o código e separa o que já está disponível dos fluxos que ainda precisam ser completados.

| Área | Código disponível | Pendências verificáveis |
|---|---|---|
| Protocolo MMP | Projetos por programa, revisões, fontes, manifesto SHA-256, catálogo e SQLite. MScript tem rascunho e a plataforma oferece argumentos padronizados. | Padronizar rascunho, bloqueio por projeto, abertura histórica somente leitura e processamento sem janela nos demais apps. Consolidar a fila de eventos, a retomada de transações e os esquemas JSON. |
| MMenu | Abre produções, inicia apps, mantém configurações e mostra artefatos, integridade, registros e histórico. O MCut fica disponível quando a produção tem um vídeo de cena aprovado. | Expor em conjunto os estados por cena e por transação. Permitir retomar ou cancelar a cascata do início ao fim pela interface. |
| MScript | Gera e edita roteiro, extrai personagens, mantém rascunho e publica revisões. Há entrada sem janela para evento. | Validar o patch em cascata com destino e alterações estruturadas, registro de impacto e reexecução idempotente. Verificar critérios de comparação, evidência e histórico do roteiro. |
| MVisual | Indexa entidades, gera imagens, registra aprovações e publica a etapa para o MBoard. | Completar regeneração incremental por cena, comparação por vista e variante, resolução manual de ambiguidades e retomada independente da geração em lote. |
| MBoard | Carrega roteiro, gera quadro inicial, subdivide cenas e reutiliza o ID do quadro compartilhado na fronteira. | Gerar quadros finais e intermediários usando as referências visuais aprovadas. Completar validação das durações, correções localizadas e a cascata incremental MScript → MVisual → MBoard. |
| MSound | Mantém banco sonoro, sintetiza frases de teste e reproduz efeitos. | Implementar a prévia WAV com falas e efeitos distribuídos por tempo e segmento. Vincular cada fala ao personagem certo e registrar autorização na clonagem real. |
| MScene | Gera e valida MP4 por segmento a partir do quadro inicial do MBoard. Costura segmentos aprovados, publica o vídeo e registra os vínculos da cena. | Enviar quadro final, referências visuais e áudio-guia ao provedor quando suportados. Completar a inspeção das junções com trecho contínuo, checklist e comentários. O modo local do provedor é uma demonstração com imagem estática. |
| MCut | Usa vídeos aprovados por revisão, verifica SHA-256, aplica cortes, fade de saída e dissolve e exporta MP4 ou MKV. O relatório registra duração e checksum. A média do público usa somente a revisão selecionada. | Completar o player e edição avançada na timeline, comparações de transições, sessões de exibição, reavaliação por trecho e histórico de decisões editoriais. |

## Exportação

Configure FFmpeg e FFprobe em **MMenu → Configurações → Executáveis e ferramentas**, ou deixe ambos no `PATH`. No MScene, gere os segmentos, revise cada vídeo, costure a cena e aprove a revisão. Use os arquivos do novo projeto de cena no MCut. Revisões antigas que só têm o JSON de montagem precisam ser renderizadas no MScene para fornecer o vídeo.

No MCut, monte a timeline e configure cortes e transições. Uma saída de corte igual a `0` usa o fim do clipe. **Salvar e Exportar Filme** grava o vídeo e o relatório na pasta `video/exports` da nova revisão. Uma timeline com cena ausente, sem aprovação ou com mídia divergente do manifesto é registrada como pendente.
