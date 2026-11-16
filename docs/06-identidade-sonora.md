# Software 4 — Identidade vocal, efeitos e ensaio sonoro

## Objetivo
Criar, indexar, testar e aprovar identidades vocais e efeitos sonoros associados aos IDs persistentes de personagens, objetos, ações, ambientes e cenas dos Softwares 1 (roteiro), 2 (biblioteca visual) e 3 (storyboard). **Não** produz a trilha definitiva do filme; prepara um banco sonoro reutilizável e prévias.

## Entradas e rastreabilidade
- Importar os três projetos com ID, nome, caminho/URI, revisão exata, hash/manifesto e IDs das entidades e cenas.
- Abrir o projeto relacionado diretamente no respectivo aplicativo e na revisão referenciada; caso o arquivo tenha mudado de lugar, resolver pelo ID e, se necessário, solicitar novo vínculo.
- Manter independência dos arquivos e histórico de revisões.

## Etapa 1 — Criação automática do banco sonoro
- IA A define identidade vocal de cada personagem: timbre, tonalidade, ritmo, sotaque, dicção, forma de falar, expressividade e perfil vocal reutilizável, vinculado ao character_id.
- IA A indexa efeitos de ambiente, objeto, mecanismo, movimento e ação, vinculando IDs e eventos de cena. Exemplo: bazuca → clique/preparação, disparo, trajetória e explosão, apenas onde o roteiro indicar.
- IA B sintetiza/clona a identidade vocal para testes de frases, com configuração reproduzível e identidade estável. Amostras de pessoas reais exigem autorização.
- Cada som possui asset_id, tipo, entity_id, source_revision, origem, parâmetros, licença/permissões, versão e estado.

## Etapa 2 — Validação isolada
- Escutar e comparar vozes isoladamente; testar frases curtas por síntese/clonagem.
- Ajustar timbre, tonalidade, ritmo, sotaque, emoção, velocidade e estilo; aprovar/rejeitar/refazer cada perfil.
- Escutar, alterar, aprovar ou rejeitar cada efeito isolado.
- **Não** confundir essa etapa com ensaio sincronizado da cena, reservado à etapa 3.

## Etapa 3 — Vinculação e prévia sonora sincronizada
- Vincular vozes e efeitos a personagem/objeto/ação e a eventos temporais de cenas e segmentos do storyboard, com diálogo, início, fim, volume e camadas.
- Permitir reproduzir **apenas áudio** de uma cena ou trecho, com vozes e efeitos no tempo correto, sem imagem, para avaliar ritmo, interação e sincronização.
- Revisar marcações e vínculos; registrar prévias de ensaio, não áudio final.
- Alteração editorial aprovada que afete os projetos 1, 2 ou 3 dispara revisões automáticas em cascata somente nos projetos impactados; mudança puramente vocal pode ficar restrita ao Software 4.
- Propagação rastreada por evento único, sem loop, sem sobrescrever revisões antigas, com retomada em caso de erro.

## Etapa 4 — Salvar e finalizar
- Salvar projeto próprio e versionado: `<NomeBase>_Sonoro_RNNN` (extensão a definir).
- Persistir banco de vozes e efeitos, perfis de síntese/clonagem, aprovações, linha do tempo sonora, prévias, IDs, referências exatas aos projetos 1–3 e histórico de mudanças.
- Verificar vínculos e arquivos faltantes; distinguir projeto salvo de sincronização pendente.

## Critérios de aceite
1. Uma voz permanece ligada ao mesmo personagem pelo ID mesmo após renomeação.
2. Objetos/ações recuperam seus efeitos por ID e ocorrência na cena.
3. Duas IAs têm funções distintas: identidade/efeitos e síntese/clonagem para testes.
4. Etapa 2 permite ouvir e validar cada item isolado; etapa 3 permite tocar cena apenas sonora sincronizada.
5. Cada revisão é imutável e permite reabrir os projetos 1–3 em suas revisões exatas.
6. Alterações com impacto propagam revisões apenas onde necessário, sem loop.
