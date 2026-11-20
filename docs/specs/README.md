# Especificações de implementação — MaurinMovie

Esta pasta transforma os requisitos funcionais de `docs/` em especificações prontas para implementação, uma por programa, no nível de detalhe necessário para uma IA (ou pessoa) construir cada aplicativo em Lazarus/Free Pascal sem ter de adivinhar.

**Configuração centralizada:** todos os parâmetros de configuração (IA de texto, imagem/foto, som e vídeo, ferramentas, perfis, políticas) ficam no MMenu; os outros programas só os leem.

Os documentos originais (`docs/00` a `docs/12`) continuam sendo a fonte dos requisitos. Quando uma especificação aqui decide algo que eles deixavam em aberto, a decisão vem marcada como **[PROPOSTA]** e está listada em [99-lacunas.md](99-lacunas.md).

## Documentos

| Arquivo | Programa | Conteúdo |
|---|---|---|
| [00-comum.md](00-comum.md) | todos | plataforma, camadas, layout comum, linha de comando, pasta da produção, IDs, estados, eventos e cascata, provedores de IA, log, testes |
| [01-mmenu.md](01-mmenu.md) | MMenu (0) | portal, produções, lançamento por revisão, pendências, artefatos, integridade |
| [02-mscript.md](02-mscript.md) | MScript (1) | sinopse, roteiro por cenas, edição, comparação, validação, personagens, `script.patch` |
| [03-mvisual.md](03-mvisual.md) | MVisual (2) | indexação, geração de vistas, validação, atualização incremental/cascata |
| [04-mboard.md](04-mboard.md) | MBoard (3) | storyboard, segmentos com quadro compartilhado, ajustes editoriais, orquestração da cascata |
| [05-msound.md](05-msound.md) | MSound (4) | perfis vocais (IA A), síntese (IA B), efeitos, prévia sonora sincronizada |
| [06-mscene.md](06-mscene.md) | MScene (5) | geração de vídeo por segmento, costura, ligação entre cenas, projeto por cena |
| [07-mcut.md](07-mcut.md) | MCut (6) | timeline, cortes, transições, público, análise, correções, render |
| [08-recursos-e-configuracao.md](08-recursos-e-configuracao.md) | todos (configurado no MMenu) | catálogo de recursos externos e de **todas** as configurações: IAs, ferramentas, credenciais, pastas, perfis de mídia, idiomas, prompts, políticas, rede, interface |
| [99-lacunas.md](99-lacunas.md) | — | lacunas, decisões propostas e inconsistências |
| [telas/](telas/) | — | 24 wireframes SVG e o gerador `gerar_telas.py` |

## Estrutura de cada especificação

1. Objetivo e limites · 2. Etapas e pré-requisitos · 3. Requisitos funcionais numerados (`RF-<app>-NN`, com a origem em `docs/`) · 4. Telas (imagem + tabela por marca numerada) · 5. Linha de comando · 6. Fluxo (diagramas Mermaid) · 7. Dados (arquivos da revisão e exemplos JSON completos) · 8. Regras de negócio · 9. Integração com os outros apps · 10. Critérios de aceite testáveis · 11. Estrutura de código sugerida.

## Telas

Os wireframes são gerados por script, para manter todos coerentes com o mesmo esqueleto:

```
python3 docs/specs/telas/gerar_telas.py
```

As letras A–G e os números em círculos laranja nas imagens correspondem às tabelas das especificações. São referências de disposição e conteúdo, não o design final (cores e ícones do MultiCNC ainda devem ser extraídos, ver L-18).

| Programa | Telas |
|---|---|
| Comum | `00-esqueleto-comum` |
| MMenu | `01-mmenu-principal`, `01-mmenu-artefatos`, `01-mmenu-nova-producao`, `01-mmenu-configuracoes` |
| MScript | `02-mscript-sinopse`, `02-mscript-roteiro`, `02-mscript-comparar`, `02-mscript-personagens` |
| MVisual | `03-mvisual-indexacao`, `03-mvisual-geracao`, `03-mvisual-validacao` |
| MBoard | `04-mboard-grade`, `04-mboard-segmentos`, `04-mboard-sincronizacao` |
| MSound | `05-msound-vozes`, `05-msound-previa` |
| MScene | `06-mscene-geracao`, `06-mscene-ligacao` |
| MCut | `07-mcut-timeline`, `07-mcut-transicoes`, `07-mcut-publico`, `07-mcut-analise`, `07-mcut-exportacao` |

## Ordem de implementação recomendada

Cada marco termina com testes passando (`tests/<app>/`) usando o provedor de IA simulado.

| Marco | Entrega | Depende de |
|---|---|---|
| M0 | `src/common`: IDs, JSON atômico, SHA-256, produção/projeto/manifesto, publicação de revisão, lock, log, eventos, `mmpai` com provedor simulado, frames de UI comuns | — |
| M1 | MMenu: nova produção, abrir produção, cartões com revisões, lançar com `--project-id`/`--revision`, **tela Configurações completa** (`mmpsettings`) | M0 |
| M2 | MScript completo, incluindo `--headless --event` (`script.patch`) | M0 |
| M3 | MVisual: indexação → geração → validação → atualização incremental | M2 |
| M4 | MBoard: geração, segmentos, ajustes e cascata 1→2→3; MMenu passa a mostrar transações | M3 |
| M5 | MSound | M4 |
| M6 | MScene (exige `mmpmedia`: ffmpeg + mpv) | M5 |
| M7 | MCut | M6 |
| M8 | Pipeline completo demonstrável com o provedor simulado; depois, troca por provedores reais | M7 |

## Como usar estas especificações com uma IA

Para implementar um programa, entregue à IA: `00-comum.md`, a especificação do programa, as imagens das telas dele, o documento-fonte em `docs/` e o código atual de `src/common/` e `src/<app>/`. Peça que implemente por etapas (barra de etapas da tela) e que escreva os testes dos critérios de aceite da seção 10 antes de declarar uma etapa pronta.

Para conferir o que já está no código e as pendências por programa, veja o [estado da implementação](../13-estado-da-implementacao.md).
