# MMenu — Software 0 · Portal da suíte

> Especificação para implementação. Requisitos-fonte: [00-mmenu](../00-mmenu.md), [11-protocolo](../11-protocolo-projetos-artefatos.md), [12-arquivos-de-projeto](../12-arquivos-de-projeto.md). Regras gerais: [00-comum](00-comum.md).
> Código: `src/mmenu/` (já existe uma primeira versão em `ummenumain.pas`, ver §12).

## 1. Objetivo e limites

O MMenu é a porta de entrada: cria e abre produções, mostra os seis aplicativos e o estado de cada projeto, lança o aplicativo certo **no projeto e na revisão exatos**, e acompanha pendências, eventos e transações de cascata.

O MMenu **não** edita conteúdo editorial, **não** grava `project.json` nem revisões de outros aplicativos, e **não** consolida os dados dos apps num arquivo único. A única escrita fora do próprio projeto que ele faz é criar a estrutura de uma produção nova e atualizar `catalog.json` (índice reconstruível).

## 2. Usuário e cenários

| # | Cenário |
|---|---|
| C1 | Criar uma produção nova e já abrir o MScript nela |
| C2 | Abrir uma produção existente e ver em que etapa está cada app |
| C3 | Abrir o MVisual numa revisão antiga para consulta (somente leitura) |
| C4 | Ver que uma cascata falhou no MScript, abrir o detalhe e retomar |
| C5 | Encontrar todos os arquivos de uma cena, achar um vídeo ausente e revinculá-lo |
| C6 | Configurar onde estão os executáveis dos apps |

## 3. Requisitos funcionais

| ID | Requisito | Origem |
|---|---|---|
| RF-MM-01 | Exibir os seis apps (MScript, MVisual, MBoard, MSound, MScene, MCut) com grafia exata, número, descrição curta, revisão ativa e selo de estado | docs/00 §1, aceite 1 |
| RF-MM-02 | Abrir produção selecionando `production.json`; validar `schema = mmp.production/1`; recusar arquivo com outro nome ou schema | código atual + docs/11 |
| RF-MM-03 | Criar produção nova (tela §6.3): pasta `<slug>__<production_id>`, `production.json`, `catalog.json`, `settings/`, `projects/NN-app/project.json` de cada app selecionado (sem revisões), `shared/*`, `backups/` | docs/11, docs/12 |
| RF-MM-04 | Lista de produções recentes (máx. 10) persistida em `mmenu.ini`; item inexistente aparece riscado com opção "Localizar…" | docs/00 §2 |
| RF-MM-05 | Para cada app: ler `project.json` e o `manifest.json` da revisão ativa; mostrar revisão, rótulo (`revision_labels`), `state`, `updated_at`, fontes e hash ✔/✘ | docs/00 §2 |
| RF-MM-06 | Abrir app com `--production`, `--project-id`, `--revision` (e `--scene-id` no MScene). Para revisão não ativa, o app abre em somente leitura | docs/00 §3, docs/11 |
| RF-MM-07 | Listar revisões de cada projeto e permitir abrir qualquer uma | docs/00 §8 |
| RF-MM-08 | Painel "Pendências e sincronizações": transações (`shared/transactions`) e eventos (`shared/events`) não concluídos, com etapa onde falharam; ligações de cena pendentes do MScene; cenas sem vídeo; itens `pending_review` por app | docs/00 §4–5 |
| RF-MM-09 | Nunca exibir "concluído" para transação cujo `status` ≠ `complete` | docs/00 aceite 3 |
| RF-MM-10 | Retomar transação: lançar o app de origem com `--headless --resume-transaction`; cancelar transação (com confirmação) marca `cancelled`, sem apagar revisões publicadas | docs/11 §5 |
| RF-MM-11 | Painel de artefatos (tela §6.2): filtrar por app, tipo, cena, entidade/ID, estado, revisão, tamanho, integridade; mostrar cadeia de dependências; abrir no app correto | docs/11 "Administração" |
| RF-MM-12 | Verificar integridade: percorrer todos os manifestos, conferir existência, tamanho e SHA-256; relatório exportável (.md e .json) | docs/11 |
| RF-MM-13 | Revincular: quando um arquivo ou projeto não é encontrado, pedir o novo local, conferir SHA-256 e registrar o mapeamento em `catalog.json` (`relinks[]`); nunca alterar manifesto publicado | docs/00 §6, aceite 4 |
| RF-MM-14 | Reconstruir `catalog.json` a partir dos manifestos | docs/11 |
| RF-MM-15 | Configurar executáveis (tela dedicada com os seis caminhos, botão "Detectar"), mantendo a descoberta automática atual (`<dir do MMenu>/<app>` e `../bin/<app>`) | código atual |
| RF-MM-16 | Distinguir **versão do executável** (Sobre, `--version` de cada app) de **revisão do projeto** | docs/00 §8 |
| RF-MM-17 | Atualizar a tela automaticamente quando arquivos da produção mudarem (varredura a cada 5 s de `updated_at` de `project.json`, `shared/events`, `shared/transactions`) | [PROPOSTA] |
| RF-MM-18 | Detectar se um app já está aberto na mesma produção (lock `.lock` ativo) e avisar antes de abrir outra instância | [PROPOSTA] |

## 4. Requisitos não funcionais

- Abrir uma produção com 7 projetos e 5.000 artefatos em menos de 2 s (lê só `project.json` e manifestos ativos; verificação completa de hash é sob demanda, em thread).
- Funciona sem rede e sem provedores de IA.
- Nunca bloqueia projetos de outros apps (só lê).

## 5. Linha de comando

`mmenu [--production <pasta>] [--log-level …] [--version] [--help]`. Com `--production`, abre a produção diretamente. O MMenu não tem modo headless de evento; mas aceita `--check-integrity --production <pasta>` [PROPOSTA] para rodar a verificação e sair (código 0 se íntegra, 4 se houver problema), útil em scripts.

## 6. Telas

### 6.1 Principal

![MMenu principal](telas/01-mmenu-principal.svg)

| Marca | Elemento | Comportamento |
|---|---|---|
| A | Cabeçalho comum | Projeto = `pr_menu_…` (projeto do próprio MMenu). Botão Salvar publica um instantâneo do estado (§7.2) |
| 1 | Produção ativa + ações | "Abrir produção…" (`TOpenDialog` filtrando `production.json`), "Nova produção…" (§6.3), "Configurações…" (executáveis e preferências); lista Recentes (duplo clique abre) e botões de integridade |
| 2 | Grade de apps (2 colunas × 3 linhas, cartões `TPanel`) | cada cartão: nº · nome, descrição, revisão ativa (ou "4/10 cenas" no MScene, "—" se não há revisão), selo de estado; botão "Abrir ▸" abre a revisão ativa; clique no cartão seleciona e preenche o painel 4. Cartão desabilitado (cinza) se o executável não for encontrado, com dica "Configure o caminho" |
| 3 | Pendências e sincronizações (`TListView` em modo relatório) | colunas Evento/Transação, Origem (app + revisão), Etapa atual, Estado; duplo clique abre detalhe (painel de artefatos, aba de eventos); menu de contexto: Retomar, Cancelar, Abrir app da etapa |
| 4 | Detalhes do projeto selecionado | tabela de campos, lista de revisões (selo por `state`), botões "Abrir esta revisão no <App>", "Ver dependências", "Revincular arquivo ausente…" |
| C | Rodapé | "Produção carregada: N projetos · M pendências" |

Sem produção carregada: grade visível mas botões "Abrir ▸" lançam o app sem argumentos (comportamento atual), e o painel 3 mostra "Nenhuma produção aberta".

### 6.2 Painel de artefatos e eventos

![MMenu artefatos](telas/01-mmenu-artefatos.svg)

| Marca | Elemento | Comportamento |
|---|---|---|
| 1 | Filtros | combos preenchidos a partir do `catalog.json`; "Aplicar" filtra; filtro de integridade "Somente com problema" executa a verificação dos itens visíveis |
| 2 | Tabela de artefatos | colunas `artifact_id`, tipo (`kind`), app/revisão, cena, tamanho, estado, hash (✔, ✘ ausente, ✘ divergente). Ordenável por coluna. Paginação de 500 linhas |
| 3 | Dependências | cadeia de projetos/revisões de que o artefato depende (lidas de `sources` dos manifestos), nó com problema destacado; ações Abrir no aplicativo, Revincular, Exportar relatório |
| 4 | Fila de eventos MMP | todos os eventos (inbox + archive) com origem → destino, resumo de `requested_change`, status, tentativas; ações Retomar evento e Cancelar evento |

Abre como janela não modal a partir de "Painel de artefatos…".

### 6.3 Nova produção (diálogo modal)

![MMenu nova produção](telas/01-mmenu-nova-producao.svg)

Campos: Título (obrigatório, 1–120 caracteres), Pasta-raiz (padrão `~/MaurinMovie/productions` ou último usado), pasta gerada (somente leitura: `slug` = título minúsculo sem acentos, espaços → `-`, máx. 40 caracteres, `__` + `production_id`), apps a inicializar (todos marcados), idioma do roteiro, perfil de provedores (Padrão = simulado). "Criar" falha se a pasta já existir. Ao criar, pergunta "Abrir o MScript agora?".

## 7. Dados

### 7.1 Configuração local (`GetAppConfigDir(False)/MaurinMovie/mmenu.ini`)

```ini
[Production]
Root=/home/u/MaurinMovie/productions/filme-exemplo__p_01JD…
[Recent]
0=/…/filme-exemplo__p_01JD…
1=/…/curta-noturno__p_01JC…
[Applications]
MScript=/opt/maurinmovie/bin/mscript
MVisual=
…
[Window]
Left=…
```

Formato atual do código preservado (`[Production] Root`, `[Applications] <App>`); seção `[Recent]` é nova.

### 7.2 Projeto do MMenu (`projects/00-mmenu/`)

`project.json` padrão (`application: "MMenu"`). Cada revisão publicada (`Salvar`) contém `workspace/registry.json` (`kind: workspace.registry`) e `workspace/sync-status.json` (`kind: sync.status`), um instantâneo de:

```json
{
  "workspace_id": "pr_menu_…",
  "workspace_name": "Filme Exemplo",
  "project_refs": [
    {"software_id": 1, "application": "MScript", "project_id": "pr_script_…", "revision_id": "r0003",
     "uri": "projects/01-mscript/project.json", "checksum": "sha256…", "status": "approved"}
  ],
  "sync_jobs": [
    {"event_id": "evt_…", "transaction_id": "tx_…", "source_revision": "MBoard r0004",
     "affected_projects": ["pr_script_…", "pr_visual_…"], "stage": "MVisual", "status": "failed",
     "error": "…"}
  ],
  "missing_links": [{"artifact_id": "a_…", "expected_uri": "…", "detected_at": "…"}]
}
```

Serve de registro histórico ("como estava a produção no dia X"). O registro de executáveis é local da máquina e fica no `.ini`, não na produção.

### 7.3 `catalog.json`

```json
{
  "schema": "mmp.catalog/1",
  "production_id": "p_…",
  "generated_at": "…",
  "projects": [{"application": "MScript", "project_id": "…", "active_revision": "r0003", "revisions": ["r0001","r0002","r0003"]}],
  "artifacts": [{"artifact_id": "a_…", "application": "MVisual", "project_id": "…", "revision_id": "r0003",
                 "kind": "visual.object.reference", "scene_id": "sc_…", "entity_id": "ob_…",
                 "uri": "…", "sha256": "…", "bytes": 0, "status": "generated"}],
  "relinks": [{"artifact_id": "a_…", "old_uri": "…", "new_uri": "…", "sha256_verified": true, "at": "…"}]
}
```

## 8. Fluxos

### 8.1 Abrir app numa revisão

```mermaid
flowchart TD
  A[Usuário clica Abrir ▸ ou 'Abrir esta revisão'] --> B[Resolver executável: ini → ao lado do MMenu → ../bin]
  B -- não achou --> E[Diálogo: configurar caminho]
  B --> C{Lock ativo do app nesta produção?}
  C -- sim --> D[Aviso: já aberto por PID x. Abrir somente leitura?]
  C -- não --> F[TProcess: exe --production P --project-id ID --revision R]
  D --> F
  F --> G[Status: 'MScript iniciado (r0003)']
  F -- exceção --> H[MessageDlg erro, log]
```

### 8.2 Monitoramento

Timer de 5 s: relê `updated_at` dos `project.json`, lista `shared/events/inbox/*` e `shared/transactions/*`; atualiza cartões e painel de pendências sem perder a seleção.

### 8.3 Revinculação

1. Usuário escolhe o arquivo novo. 2. MMenu calcula SHA-256. 3. Se igual ao do manifesto: grava em `catalog.json.relinks` e informa "Revinculado". 4. Se diferente: avisa "Arquivo diferente do registrado (hash)"; não revincula.

Os apps, ao não encontrar um `uri`, consultam `catalog.json.relinks` antes de declarar ausência.

## 9. Mensagens

| Situação | Mensagem |
|---|---|
| Arquivo não é `production.json` | "Selecione o arquivo production.json da produção." (já existe) |
| Schema desconhecido | "Esta produção usa o protocolo <schema>, que esta versão do MMenu não reconhece." |
| Executável ausente | "Executável de <App> não encontrado. Configure o caminho em Configurações." (já existe) |
| Transação com falha | "A sincronização tx_… parou em <App>: <erro>. Nada foi marcado como concluído." |

## 10. Critérios de aceite (testáveis)

1. Grade mostra exatamente MScript, MVisual, MBoard, MSound, MScene, MCut, nessa ordem.
2. Com uma produção de fixture, "Abrir esta revisão" em r0002 lança o processo com `--production <pasta> --project-id <id> --revision r0002` (verificável com um executável falso que grava os argumentos).
3. Uma transação com estágio `failed` aparece com a etapa e o erro, e o MMenu nunca mostra `complete` para ela.
4. Mover um vídeo de lugar → verificação acusa "ausente"; revincular com o arquivo certo resolve; com arquivo errado é recusado.
5. Depois de usar o MMenu, nenhum `project.json`/manifesto de outro app teve `mtime` alterado.
6. Nova produção cria a árvore completa e `production.json` válido; criar de novo na mesma pasta falha.

## 11. Estrutura de código sugerida

- `ummenumain.pas` — formulário (já existe; migrar a montagem em código para `.lfm` é opcional).
- `ummenuproduction.pas` — leitura de produção, cartões, pendências (sem LCL).
- `ummenulauncher.pas` — resolução de executável e `TProcess` (extrair de `OpenApp`/`FindExecutable` atuais).
- `ummenuartifacts.pas` + `.lfm` — janela do painel de artefatos.
- `ummenunewprod.pas` + `.lfm` — diálogo de nova produção.
- `ummenusettings.pas` + `.lfm` — tela de configuração (substitui o diálogo sequencial atual).

## 12. Situação do código atual e diferenças

O `ummenumain.pas` atual já faz: janela com cabeçalho/painel/6 botões/status, escolha de `production.json`, `mmenu.ini`, descoberta de executáveis, lançamento com `--production`. Falta: `--project-id`/`--revision`, leitura de projetos e revisões, pendências, criação de produção, painel de artefatos, integridade, revinculação. O array local `AppNames` deve passar a usar `MMAppNames` de `mmpcommon`.
