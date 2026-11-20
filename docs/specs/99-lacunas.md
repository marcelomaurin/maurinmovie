# Lacunas, inconsistências e decisões propostas

> Levantamento feito ao escrever as especificações de `docs/specs/`. Cada lacuna diz o que falta na documentação original, o que as especificações adotaram para permitir a implementação, e o que precisa ser confirmado. Nenhuma proposta altera a semântica de IDs, manifestos e revisões do MMP v1.

Legenda de impacto: **Alto** = bloqueia ou muda a arquitetura; **Médio** = afeta um app inteiro; **Baixo** = detalhe.

| ID | Impacto | Lacuna | Proposta adotada | A confirmar |
|---|---|---|---|---|
| L-01 | Alto | Formato físico e extensão dos projetos "a definir" (docs 01, 05, 06, 07, 08) | Sem arquivo único com extensão: o projeto é a pasta `projects/NN-app/` com `project.json` + `revisions/rNNNN/` em JSON (docs/11 e 12) | Se haverá também um pacote exportável (ex.: `.mmp` = zip da produção) |
| L-02 | Médio | Duas convenções de revisão: `<NomeBase>_Roteiro_R001` (3 dígitos, docs 01–08) × `r0001` (4 dígitos, docs/11) | Diretório `rNNNN` é a autoridade; o nome `<NomeBase>_<Tipo>_RNNN` vira rótulo em `project.json.revision_labels` ([00-comum §5.2](00-comum.md#52-projectjson-todos-os-apps)) | Número de dígitos do rótulo |
| L-03 | Alto | Não existe área de rascunho: docs/11 só tem revisões imutáveis | `projects/NN-app/work/` mutável com autosave; "Publicar" cria a revisão ([00-comum §5.1](00-comum.md#51-rascunho-e-publicação)) | — |
| L-04 | Alto | Como aprovar algo depois de publicado, se o manifesto é imutável | Aprovação posterior gera nova revisão; `manifest.state` = `published` ou `approved` ([00-comum §6.5](00-comum.md#65-estados-de-revisão-tarefa-e-sincronização)) | Se aceitável o número de revisões resultante (alternativa: arquivo de aprovações anexável por revisão) |
| L-05 | Alto | Transporte entre apps: "fila em arquivos ou IPC, a escolher" (docs/11) e "aplicar sem abrir o Software 1" (docs/01) exigem modo sem janela | Fila em arquivos `shared/events/inbox/<App>/` + modo `--headless --event` em todos os apps ([00-comum §7](00-comum.md#7-eventos-e-cascata-entre-apps)) | — |
| L-06 | Alto | Quem orquestra a cascata não está definido | O app de origem (`TMMCascade`), com arquivo de transação em `shared/transactions/`; o MMenu só monitora e oferece "Retomar" | Alternativa: MMenu como orquestrador (exigiria MMenu aberto) |
| L-07 | Médio | O exemplo de argumentos do docs/11 não tem como indicar a cena do MScene | `--scene-id` e `--focus` ([00-comum §4](00-comum.md#4-linha-de-comando-protocolo-mmp-v1)) | — |
| L-08 | Alto | docs/05 limita a cascata a MScript → MVisual → MBoard, mas docs/11 §6 descreve o grafo inteiro até o MCut | Nesta versão a cascata automática vai até o MBoard; MSound, MScene e MCut recebem **aviso de desatualização** (pendência no MMenu, `scene.sources_changed` no MScene) sem regeneração automática de áudio/vídeo (custo) | Se áudio e vídeo devem ser regenerados automaticamente |
| L-09 | Alto | Motores de IA não escolhidos; API real da biblioteca CHATGPT não verificada | Interfaces de adaptador em `mmpai.pas` + provedor simulado obrigatório + adaptador HTTP "compatível com OpenAI" para texto ([00-comum §9](00-comum.md#9-provedores-de-ia)) | Provedores reais de texto, imagem, voz, efeitos e vídeo; o que a biblioteca CHATGPT já oferece |
| L-10 | Médio | docs/06: IA B só sintetiza voz; não diz quem gera **efeitos sonoros** | Provedor `sfx` separado (aba IA Som — Efeitos no MMenu) e pasta de banco de efeitos licenciados | Origem dos efeitos: gerados por IA, banco licenciado, ou ambos |
| L-11 | Alto | Nenhum app produz o **áudio final** do filme: MSound faz só prévias, MScene usa áudio-guia, MCut "renderiza com som". Trilha musical não aparece em nenhum documento | MScene usa o áudio do vídeo gerado ou o áudio-guia; MCut só faz crossfade entre cenas | Se haverá etapa de mixagem final e música (novo app ou etapa no MCut/MSound) |
| L-12 | Médio | Sessões de público com "convite" e "controle de acesso" sugerem participação remota, mas os apps são desktop | Modo exibição local no MCut (participante assiste e avalia na máquina do operador) | Necessidade de participação remota (web/formulário externo) |
| L-13 | Médio | Política de privacidade e retenção dos dados dos avaliadores (LGPD) a definir (docs/08) | Dados pessoais em arquivo separado, fora das exportações por padrão; anonimato configurável | Prazo de retenção, termo de consentimento, quem acessa |
| L-14 | Médio | Mecanismo de reprodução, timeline e render não definido | `ffmpeg`/`ffprobe` externos + `mpv` embutido (`--wid`) | Licenças (ffmpeg LGPL/GPL), empacotamento no instalador; alternativa PasLibVlc |
| L-15 | Baixo | SHA-256 exigido (docs/11), mas não há garantia de unidade na FPC 3.2.2 instalada | Verificar `fpsha256`/fcl-hash; senão HashLib4Pascal ou DCPcrypt | Biblioteca escolhida |
| L-16 | Médio | Sistemas operacionais, CPU, GPU, RAM, processamento local × remoto (docs/10) | Linux e Windows; IA via adaptadores (local ou remota) | Requisitos mínimos |
| L-17 | Médio | Conflitos de edição simultânea (docs/04 "Pendências adicionais") | Lock por projeto `.lock` + leitura livre de revisões publicadas ([00-comum §7.4](00-comum.md#74-lock-de-projeto)) | Uso multiusuário em rede |
| L-18 | Baixo | Cores, ícones e medidas do MultiCNC "não presumir" (docs/09) | Wireframes usam só as medidas e a cor do cabeçalho já presentes no esqueleto atual | Extrair paleta e ícones do repositório MultiCNC antes do desenho final |
| L-19 | Baixo | Conteúdo do projeto `00-mmenu` não especificado | Instantâneo do estado da produção (`workspace.registry`, `sync.status`) por revisão ([01-mmenu §7.2](01-mmenu.md#72-projeto-do-mmenu-projects00-mmenu)) | Se o MMenu precisa de projeto versionado |
| L-20 | Baixo | Escala de nota do público não definida | 1 a 5 estrelas | — |
| L-21 | Baixo | Unidade de duração ("segundos e minutos", docs/05) | JSON em milissegundos inteiros; exibição `HH:MM:SS(:FF)` | — |
| L-22 | Médio | Dono dos IDs de local e objeto: MScript tem `location_ref`, MVisual cria entidades | MScript cria `lo_` dos locais do cabeçalho e `ch_` dos personagens; MVisual reutiliza esses e cria `ob_`, `co_` e `vr_` | — |
| L-23 | Médio | Duração máxima de segmento de vídeo e limites dos modelos (docs/07) | Segmento ≥ 1 s; sem máximo fixo; o adaptador de vídeo informa o máximo e o MScene pede subdivisão no MBoard se exceder | Limites reais do motor escolhido |
| L-25 | Alto | Onde ficam as configurações não estava definido | **Decidido pelo usuário (16/11/2026):** toda configuração fica no MMenu; os demais programas só leem ([00-comum §12](00-comum.md#12-configuração-centralizada-no-mmenu), catálogo em [08-recursos-e-configuracao](08-recursos-e-configuracao.md)) | — |
| L-26 | Médio | Recursos não previstos nos documentos: identidade do usuário que aprova, custo/orçamento de IA, IA de visão para continuidade, transcrição para conferir falas, perfis de render, modelos de termo (voz e público), backup, proxy, modo offline | Incluídos no catálogo e na tela Configurações do MMenu como [PROPOSTA] | Quais manter |
| L-24 | Baixo | Esquemas JSON formais (docs/11 "Pendências") | Exemplos completos em cada especificação; gerar JSON Schema em `docs/schemas/` na implementação | — |

## Inconsistências encontradas no código

| ID | Local | Observação | Situação |
|---|---|---|---|
| C-01 | `src/common/mmpcommon.pas` | Comentário dizia "não compilado nem testado" | Resolvida: usada por todos os apps e pelos testes |
| C-02 | `mmpcommon.ParseLaunchArgs` | Não aceitava `--chave=valor` nem `--scene-id`, `--focus`, `--headless`, `--event` | Resolvida |
| C-03 | `src/mmenu/ummenumain.pas` | Formulário montado em código (sem `.lfm`), como agora todos os apps; `ummpprotocol.MmpAppNames` ainda duplica `mmpcommon.MMAppNames` | Aberta (baixo impacto) |
| C-04 | `src/mmenu/ummenumain.pas` | Enviava só `--production` | Resolvida: envia `--project-id`, `--revision` e, para projeto de cena, `--scene-id` |
| C-05 | `src/<app>/README.md` | Descreviam os apps como esqueletos vazios | Resolvida (20/11/2026) |
| C-06 | `src/common/ummpappbase.pas` | No Linux não compilava (faltava a unidade `Unix` para `FpFlock`) | Resolvida (20/11/2026) |
| C-07 | `src/common/ummpdb.pas` | Procurava só `sqlite3.dll`; no Linux a produção não era criada | Resolvida: `libsqlite3.so.0`/`.dylib` |
| C-08 | `mmpsettings.LoadMachineIni` | Sem `mmenu.ini`, os provedores de IA salvos na máquina eram ignorados | Resolvida |
| C-09 | MVisual, MBoard, MSound, MScene | Gravavam imagens/áudios/índices dentro da revisão publicada aberta (quebrava a imutabilidade e os hashes do manifesto) | Resolvida: rascunho em `work/draft/` |
| C-10 | `PublishProjectRevision` | Artefatos sem ID recebiam um `artifact_id` no manifesto e outro no SQLite | Resolvida |
| C-11 | `RebuildCatalog` / auditoria | Reconstruir o catálogo apagava `relinks[]`, e a auditoria não consultava as revinculações | Resolvida |
| C-12 | MScript | `character_id` mudava a cada extração e objetos entravam no mapa de personagens (o MSound criava voz para objetos) | Resolvida |
| C-13 | MScript headless | Evento sem `event_id` era dado como "já aplicado"; campo `dialogue` não casava com `dialogue_text`; `replace_entity` e eventos sem operações publicavam revisão sem mudança; fonte desatualizada não era verificada | Resolvida |
| C-14 | MVisual, MBoard, MSound | "Publicar" gravava `approved` mesmo com itens não aprovados | Resolvida: `published` até todos serem aprovados |
| C-15 | Cascata | Nenhum programa processava os eventos; o evento do MBoard não tinha operações | Parcial: o MBoard gera `script.patch` e executa o MScript headless; estágios MVisual/MBoard continuam manuais |
| C-17 | Telas montadas em código | Controles ancorados à direita/abaixo saíam da janela (botões do cabeçalho e das abas invisíveis no GTK2) e o `&` das abas virava atalho ("Sinopse _IA") | Resolvida: `MmpPrepareAligned`/`MmpPrepareTabSheet` e `&&` nos títulos |
| C-16 | Executáveis LCL no Linux | GTK2 exige display até em `--version`/`--headless` | Aberta: usar `xvfb-run` ou separar um executável sem LCL para o modo headless |

## Inconsistências entre documentos

| ID | Documentos | Observação | Tratamento |
|---|---|---|---|
| D-01 | docs/README × nomes de arquivo | "Software 3" está em `05-storyboard.md`, "Software 2" em `02-…`, mas `03-` e `04-` são modelo de dados e validação | As especificações novas usam numeração própria (`01-mmenu` … `07-mcut`) e indicam a fonte |
| D-02 | docs/00 × docs/09 | docs/00 fala em "seis aplicativos" no menu; docs/09 e docs/10 em "sete aplicativos" | Coerentes: o MMenu é o sétimo e lista os outros seis |
| D-03 | docs/03 (Projeto 2) × docs/02 | Tipos de vista do modelo (`front\|back\|right\|left\|other`) não cobrem superior/inferior/ângulos de cenário | Lista ampliada de vistas em [03-mvisual §7.2](03-mvisual.md#72-entitiesjson) |
| D-04 | docs/02 × docs/00-comum | Estados em português (`gerado_por_cascata`, `pendente_de_revisao_visual`) × inglês no MMP (`approved`) | Valores JSON em inglês com rótulo PT na interface ([00-comum §6.4](00-comum.md#64-estados-de-item-artefato-entidade-quadro-som-segmento)) |
