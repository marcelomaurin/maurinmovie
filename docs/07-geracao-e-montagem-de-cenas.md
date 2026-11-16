# Software 5 — Geração de vídeo e montagem de cenas

## Objetivo e limite
Gerar **uma cena por vez**, usando os artefatos versionados dos Softwares 1–4. Se o storyboard subdividir uma cena, gerar primeiro **cada sub-bloco individualmente**, validar os trechos e montá-los numa única cena. O Software 5 monta e valida cenas completas; **não** monta automaticamente o filme inteiro.

## Entradas obrigatórias
- Software 1: roteiro, falas, ações, ordem, duração e IDs de cenas/personagens/objetos.
- Software 2: banco de imagens aprovado, identidades de personagens, cenários, objetos, figurinos e variantes com IDs estáveis.
- Software 3: storyboard da cena, quadros inicial/final, segmentos, ordem, continuidade entre quadros e durações.
- Software 4: perfis vocais, áudio-guia/ensaios, efeitos, eventos temporais e vínculos por IDs.
- Cada fonte possui project_id, revisão exata, localização/URI, hash e manifesto. O projeto do Software 5 deve poder abrir a revisão relacionada no aplicativo original.

## Etapa 1 — Geração sequencial da cena atual
1. Selecionar a **próxima cena** da sequência; não gerar em lote as dez cenas do exemplo.
2. Verificar que os artefatos necessários estão disponíveis e coerentes nas revisões selecionadas.
3. Para cena subdividida, gerar vídeo do primeiro segmento, depois do seguinte, respeitando duração e o quadro de transição compartilhado. Para cena sem subdivisão, gerar a cena como um segmento único.
4. Fornecer à IA imagens e identidades aprovadas, ambiente, objetos, figurinos, quadros-chave, áudio-guia e marcações de tempo. A IA deve respeitar o banco de referências, sem reinventar a identidade.
5. Sincronizar movimento de boca com falas e vozes, gestos de mãos, interação com objetos, ações, efeitos e duração.
6. Registrar vídeo gerado, modelo, prompt, parâmetros, dependências, erros e estado por segmento. Falhas devem permitir retomar apenas o segmento afetado.

## Etapa 2 — Revisão e integração interna da cena
- Reproduzir cada sub-bloco, validar enquadramento, identidade, movimento, sincronia labial, gestos, som, duração e coerência com roteiro/storyboard.
- Permitir corrigir/regenerar somente o trecho reprovado, sem refazer trechos já aprovados.
- Após aprovação dos segmentos, **costurar** em ordem num vídeo único da cena, com continuidade entre quadro final e inicial compartilhados, transições e áudio sincronizado.
- Exibir a cena integrada para validação humana; registrar decisões e revisões. Não iniciar automaticamente todas as cenas seguintes.

## Etapa 3 — Validação da ligação entre cenas
- Reproduzir em sequência **cena anterior → cena atual → próxima cena, quando já existir**.
- Permitir aprovação explícita das transições anterior/atual e atual/próxima, observando imagem, posição, cenário, objetos, figurino, som, ritmo, iluminação, ação e cronologia.
- Se a cena seguinte ainda não existir, marcar a transição como **pendente**, não aprovada por suposição; revisitar a ligação quando a próxima cena for criada.
- Se houver problema, revisar os trechos/cenas afetados, preservando o restante e o histórico.
- Avançar à geração da próxima cena após validação da cena atual e das ligações disponíveis; ligações futuras permanecem pendentes até haver material.

## Etapa 4 — Salvar e finalizar o projeto da cena
- Salvar projeto independente e versionado: `<NomeBase>_Cena_<SceneID>_Video_RNNN` (extensão a definir).
- Guardar sub-blocos e seus vídeos, montagem final da cena, prévias, decisões, status de ligação com cenas adjacentes, metadados, revisões e referências exatas aos quatro projetos de origem.
- Permitir abrir/reabrir cena e projetos de origem, comparar versões e retomar trabalho sem perder aprovações.
- Uma cena salva pode ter ligação futura pendente; diferenciar `cena_aprovada`, `ligacao_anterior_aprovada`, `ligacao_posterior_pendente` e `finalizada`.

## Regras de revisão e integridade
- Revisões anteriores nunca são sobrescritas. IDs persistentes de cena, segmento, personagem, objeto, ativo e evento sonoro sustentam rastreabilidade.
- Se uma alteração aprovada na cena afetar roteiro, visual, storyboard ou som, registrar impacto e iniciar revisão em cascata nos aplicativos afetados; não propagar mera alteração de renderização sem impacto editorial.
- Não considerar ligação com cena inexistente validada. Ao criar a cena posterior, reabrir a verificação da ligação pendente.
- Preservar o mesmo quadro/asset de fronteira entre segmentos sempre que o storyboard exigir; validar coerência temporal e audiovisual na montagem.

## Critérios de aceite
1. Dez cenas no roteiro não provocam geração automática de dez cenas: a geração é sequencial e controlada.
2. Cena subdividida é gerada e validada por sub-bloco, depois montada em uma cena única.
3. A IA usa bancos visuais, roteiro, storyboard e banco sonoro com revisões exatas.
4. Boca, voz, gestos, objetos e efeitos são sincronizados por eventos temporais.
5. A revisão da etapa 3 reproduz anterior, atual e próxima se existir, permitindo validação das ligações.
6. Próxima cena inexistente gera pendência de continuidade, posteriormente revisitada.
7. Etapa 4 salva um projeto versionado por cena com arquivos, histórico e vínculos aos Softwares 1–4.

## Decisões técnicas pendentes
Motor de vídeo, formatos e codecs, duração máxima de segmento, recursos de processamento, armazenamento e política de aprovação de transições ainda serão definidos na implementação.
