# Escopo consolidado — MaurinMovie

## Estado e objetivo
**Escopo funcional fechado para planejamento da implementação**, com sete aplicativos desktop integrados para produzir filmes com assistência de IA, da sinopse à exportação final. Este documento fixa requisitos acordados; não declara funcionalidades implementadas. Decisões técnicas de detalhe e motores de IA serão tomadas na fase de arquitetura.

## Tecnologias obrigatórias
- **Linguagem:** Object Pascal com **Free Pascal**, utilizando a IDE **Lazarus** e componentes **LCL** para os sete aplicativos.
- **Padrão visual e organizacional:** MultiCNC/MultiSuite, conforme [especificação de layout](09-padrao-layout-multicnc.md). Adaptar controles ao trabalho audiovisual.
- **Biblioteca de ferramentaria comum:** projeto **CHATGPT** de Maurinsoft, repositório https://github.com/marcelomaurin/CHATGPT, para componentes compartilhados de IA, voz, arquivos, projetos e integrações, **após verificação das APIs e compatibilidade efetivamente disponíveis**. Não presumir que cada recurso já esteja implementado na biblioteca.
- Separar UI, regras de negócio, serviços de IA e armazenamento; interfaces entre aplicativos devem ser versionadas e documentadas.
- Motores de geração de imagem, áudio, clonagem/síntese e vídeo poderão ser integrados por adaptadores; implementação, requisitos de hardware, licenças e operação local/remota ainda a definir.

## Aplicativos e entregas funcionais
| Nº | Nome | Responsabilidade | Etapas principais |
|---|---|---|---|
| 0 | **MMenu** | Portal da suíte; abrir aplicativos, projetos e revisões, mostrar estado e pendências | Navegação, gestão de vínculos e monitoramento |
| 1 | **MScript** | Criar e aprovar roteiro a partir de sinopse | Sinopse, cenas, edição, validação, catálogo textual |
| 2 | **MVisual** | Indexar e gerar referências visuais de personagens, objetos, figurinos e cenários | Indexação sem imagens, geração automática em vistas padronizadas, validação |
| 3 | **MBoard** | Criar storyboard e subdivisões, editar e sincronizar revisões | Quadros inicial/final, revisão e segmentação, sincronização em cascata |
| 4 | **MSound** | Identidades vocais e efeitos sonoros, testes e ensaio sincronizado | IA de identidade/efeitos, validação isolada, prévia sonora por cena, salvar |
| 5 | **MScene** | Gerar vídeo de cada segmento e montar uma cena de cada vez | Gerar, validar/costurar, conferir continuidade com cenas vizinhas, salvar |
| 6 | **MCut** | Montar filme completo e exportar após avaliação do público | Timeline e cortes, transições, público, análise/correções, render final |

## Regras transversais obrigatórias
1. **Projetos independentes:** cada aplicativo mantém seu próprio arquivo/projeto, com nome-base, identificador estável, número de revisão independente e histórico imutável.
2. **Interoperabilidade:** todo projeto guarda ID, revisão exata, caminho/URI e integridade dos projetos de origem. MMenu e demais aplicativos devem poder abrir o arquivo correto no software correspondente.
3. **Identidade e indexação:** cenas, segmentos, personagens, objetos, cenários, vozes, efeitos e mídias têm IDs estáveis; vínculos não dependem somente de nomes visíveis.
4. **Cascata por impacto:** uma mudança aprovada gera revisões automáticas somente nos aplicativos afetados, em ordem de dependência, regenerando imagens, sons, storyboard ou vídeo conforme necessário. Evitar loops com ID de evento, histórico, estados e retomada de falhas.
5. **Aprovação humana:** geração por IA não equivale a aprovação. Preservar versões anteriores, decisões, comentários, prompts e parâmetros de geração.
6. **Continuidade:** segmentos compartilham quadro de fronteira; cenas são verificadas em relação à anterior e posterior quando existirem. MScene trabalha **uma cena por vez**.
7. **Som:** MSound tem duas IAs conceituais (criação de identidade/efeitos e síntese/clonagem para testes), e não produz inicialmente o áudio final do filme. Vozes reais clonadas exigem autorização.
8. **Avaliação pública:** MCut registra avaliações por cena e revisão, permite reavaliar fragmentos corrigidos e comparar resultados antes/depois.
9. **Exportação:** apenas MCut monta e renderiza o filme inteiro; MScene finaliza cenas individuais.
10. **Experiência comum:** interface desktop baseada no MultiCNC, logs, progresso, erros recuperáveis, configuração, revisão visível e navegação consistente.

## Organização do repositório — proposta
- `docs/`: requisitos, modelos de dados, critérios de aceite, layout, arquitetura e guias.
- `src/common/`: adaptadores e contratos compartilhados, integrando biblioteca CHATGPT.
- `src/mmenu/`, `src/mscript/`, `src/mvisual/`, `src/mboard/`, `src/msound/`, `src/mscene/`, `src/mcut/`: projetos Lazarus separados.
- `bin/`: executáveis e dependências distribuíveis.
- `tests/`: testes de integridade, revisões, vínculos e sincronização.
A estrutura é proposta, não indicação de diretórios já existentes.

## Entregas e critérios de fechamento da implementação
- Sete aplicativos compiláveis e operacionais em Lazarus/Free Pascal.
- MMenu inicia cada aplicativo e abre a revisão selecionada do projeto.
- Cada fluxo funcional descrito nos documentos individuais passa nos critérios de aceite.
- Persistência e reabertura de projetos/revisões sem perda de vínculos.
- Geração e regeneração por IA com logs, tratamento de falhas e retomada.
- Pipeline completo demonstrável: sinopse → roteiro → imagens → storyboard → identidade sonora → cenas → filme exportado.
- Testes automatizados de IDs, revisões, integridade, dependências e prevenção de ciclos.
- Documentação de instalação, configuração, operação e dependências.

## Fora do escopo definido / pendências técnicas
- Escolha e validação dos motores/modelos específicos de IA e suas licenças.
- Formatos físicos e extensões dos projetos, codecs e formatos finais de exportação.
- Sistemas operacionais e arquiteturas de CPU suportados, requisitos mínimos de GPU/RAM, processamento local ou remoto.
- Esquema definitivo de armazenamento, cache, filas de trabalho e mecanismos de integração entre executáveis.
- Detalhes finais de telas, protótipos, componentes e instalador.
- A plataforma não promete renderização de qualidade profissional sem validar capacidades dos modelos e hardware.

## Referências
- [MMenu](00-mmenu.md), [MScript](01-roteiro.md), [MVisual](02-biblioteca-visual.md), [MBoard](05-storyboard.md), [MSound](06-identidade-sonora.md), [MScene](07-geracao-e-montagem-de-cenas.md), [MCut](08-montagem-final.md).
- [Modelo de dados](03-modelo-de-dados.md), [Validação e revisões](04-validacao-e-revisoes.md), [Padrão MultiCNC](09-padrao-layout-multicnc.md).
