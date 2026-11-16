# MaurinMovie — Especificação funcional

## Visão geral
Suíte modular de produção audiovisual com IA. Os projetos dos aplicativos são independentes, versionados e interligados por IDs e referências exatas às revisões. Aprovações editoriais pertencem ao usuário.

## Aplicativos — nomes oficiais
0. **MMenu** — portal de entrada, navegação, abertura de projetos e acompanhamento das revisões.
1. **MScript** — sinopse, roteiro, cenas e personagens.
2. **MVisual** — biblioteca visual, indexação e continuidade.
3. **MBoard** — storyboard, quadros, segmentos e sincronização em cascata.
4. **MSound** — identidade vocal, efeitos e ensaios sonoros.
5. **MScene** — geração e montagem de cada cena em vídeo.
6. **MCut** — montagem final do filme, avaliação de público e exportação.

Todos os nomes começam com **M**, sem espaço. **MaurinMovie** é o nome da suíte.

## Documentação detalhada
- [Software 0 — MMenu](00-mmenu.md)
- [Software 1 — MScript](01-roteiro.md)
- [Software 2 — MVisual](02-biblioteca-visual.md)
- [Software 3 — MBoard](05-storyboard.md)
- [Software 4 — MSound](06-identidade-sonora.md)
- [Software 5 — MScene](07-geracao-e-montagem-de-cenas.md)
- [Software 6 — MCut](08-montagem-final.md)
- [Modelo de dados e interoperabilidade](03-modelo-de-dados.md)
- [Critérios de aceite e revisões](04-validacao-e-revisoes.md)

## Fluxo e rastreabilidade
MScript → MVisual → MBoard → MSound → MScene → MCut. MMenu permite acessar qualquer um deles e acompanhar o andamento. Uma alteração aprovada em um aplicativo pode exigir revisões nos aplicativos afetados, mantendo histórico, IDs estáveis e evitando ciclos de sincronização. Cada projeto guarda localização, ID e revisão exata de suas fontes.

**Status:** requisitos funcionais documentados; arquitetura técnica, formatos finais, motores de IA e implementação ainda pendentes.

## Padrão visual obrigatório
Todos os sete aplicativos adotam **MultiCNC / MultiSuite como referência de layout e experiência de uso**, com adaptações para roteiro, imagens, storyboard, som, vídeo e montagem. Ver [padrão de interface MultiCNC](09-padrao-layout-multicnc.md).

## Escopo e tecnologias definidos
O desenvolvimento dos sete aplicativos será em **Lazarus / Free Pascal (Object Pascal, LCL)**, seguindo o **layout do MultiCNC/MultiSuite** e reutilizando o repositório [CHATGPT](https://github.com/marcelomaurin/CHATGPT) como biblioteca de ferramentaria compartilhada, mediante verificação de APIs e compatibilidade.

**[Escopo consolidado do projeto](10-escopo-consolidado.md)** — responsabilidades, regras transversais, arquitetura inicial proposta, entregas, critérios de aceite e pendências técnicas.

## Protocolo de organização de projetos e mídias
Cada produção terá pasta-raiz própria; cada aplicativo terá subpasta, projeto, revisões e manifestos, com artefatos de roteiro, imagem, áudio e vídeo indexados por IDs e hashes. MMenu coordena a abertura, o catálogo e as pendências, sem sobrescrever projetos de outros aplicativos. [Protocolo MMP v1 — pastas, manifestos, comunicação e gerenciamento](11-protocolo-projetos-artefatos.md).

## Especificações de implementação
Especificação detalhada de cada programa (requisitos numerados, telas, fluxos, dados JSON, linha de comando, integração MMP e critérios de aceite), lacunas e decisões propostas: **[docs/specs](specs/README.md)**.
