# MaurinMovie — Especificação funcional (v0.1)

## Visão geral
Plataforma modular de produção de filmes curtos e longos com inteligência artificial. Os aplicativos possuem projetos independentes, versionados e interoperáveis. A IA auxilia a criação; decisões criativas e aprovações pertencem ao usuário.

## Aplicativos
1. **Roteiro**: sinopse → roteiro por cenas → edição/revisão → validação → catálogo textual de personagens e metadados → projeto de roteiro versionado.
2. **Biblioteca visual e continuidade**: importa revisão específica do projeto 1 → indexa entidades e ocorrências por cena → gera imagens de referência padronizadas automaticamente → revisão/aprovação humana → projeto visual independente e versionado.

## Documentos
- [Software 1 — Roteiro](01-roteiro.md)
- [Software 2 — Biblioteca visual](02-biblioteca-visual.md)
- [Modelo de dados e interoperabilidade](03-modelo-de-dados.md)
- [Critérios de aceite e fluxo de revisões](04-validacao-e-revisoes.md)


3. **Storyboard**: importa revisões dos projetos 1 e 2 → gera quadros inicial/final e duração por cena → permite revisão e subdivisões contínuas → propaga alterações aprovadas em cascata para roteiro, biblioteca visual e storyboard, com novas revisões independentes.

## Revisões e sincronização
Arquivos: `<NomeBase>_Roteiro_RNNN`, `<NomeBase>_Visual_RNNN`, `<NomeBase>_Storyboard_RNNN`. Aprovação no Software 3 aciona automaticamente revisões no 1, depois no 2, com regeneração dos quadros afetados no 3. Versões anteriores são imutáveis; falhas ficam pendentes para retomada.

- [Software 3 — Storyboard](05-storyboard.md)

Status: escopo funcional inicial; decisões técnicas e formatos finais ainda sujeitos a validação.


## Novos aplicativos
4. **Identidade sonora**: duas IAs (criação de voz/efeitos e síntese/clonagem para testes); validação isolada, vínculo aos IDs e prévia sonora sincronizada; salvamento de projeto próprio.
5. **Vídeo e montagem de cenas**: geração **uma cena por vez**, segmentada conforme storyboard; revisão e costura de sub-blocos; validação das ligações anterior/atual/próxima; salvamento versionado por cena.

- [Software 4 — Identidade sonora](06-identidade-sonora.md)
- [Software 5 — Geração e montagem de cenas](07-geracao-e-montagem-de-cenas.md)


6. **Montagem final e público**: organiza as cenas do Software 5 na ordem do roteiro; permite assistir e cortar; aplica transições; recolhe avaliações cena a cena; analisa e revisa com retorno aos aplicativos anteriores; salva projeto e renderiza o filme completo.

- [Software 6 — Montagem final, avaliação do público e exportação](08-montagem-final.md)
