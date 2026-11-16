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
| L-10 | Médio | docs/06: IA B só sintetiza voz; não diz quem gera **efeitos sonoros** | Provedor `sfx` separado (ou biblioteca de sons importados com licença) | Origem dos efeitos: gerados por IA, banco licenciado, ou ambos |
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
| L-24 | Baixo | Esquemas JSON formais (docs/11 "Pendências") | Exemplos completos em cada especificação; gerar JSON Schema em `docs/schemas/` na implementação | — |

## Inconsistências encontradas no código atual

Sem alteração de código nesta tarefa; registradas para quem for implementar.

| ID | Local | Observação |
|---|---|---|
| C-01 | `src/common/mmpcommon.pas` | Comentário diz "não compilado nem testado", mas `src/common/README.md` diz que compila com FPC; nenhum app usa a unidade ainda |
| C-02 | `mmpcommon.ParseLaunchArgs` | Não aceita `--chave=valor`; não reconhece `--scene-id`, `--focus`, `--headless`, `--event`; não valida revisão no formato `rNNNN` |
| C-03 | `src/mmenu/ummenumain.pas` | Formulário montado em código (sem `.lfm`), enquanto os outros apps usam `.lfm`; duplica nomes dos apps em `AppNames` em vez de usar `MMAppNames` |
| C-04 | `src/mmenu/ummenumain.pas` | Envia só `--production`; falta `--project-id` e `--revision` (docs/00 §3) |
| C-05 | `src/<app>/README.md` | Apontam para a especificação funcional antiga; podem passar a apontar também para `docs/specs/<nn>-<app>.md` |

## Inconsistências entre documentos

| ID | Documentos | Observação | Tratamento |
|---|---|---|---|
| D-01 | docs/README × nomes de arquivo | "Software 3" está em `05-storyboard.md`, "Software 2" em `02-…`, mas `03-` e `04-` são modelo de dados e validação | As especificações novas usam numeração própria (`01-mmenu` … `07-mcut`) e indicam a fonte |
| D-02 | docs/00 × docs/09 | docs/00 fala em "seis aplicativos" no menu; docs/09 e docs/10 em "sete aplicativos" | Coerentes: o MMenu é o sétimo e lista os outros seis |
| D-03 | docs/03 (Projeto 2) × docs/02 | Tipos de vista do modelo (`front\|back\|right\|left\|other`) não cobrem superior/inferior/ângulos de cenário | Lista ampliada de vistas em [03-mvisual §7.2](03-mvisual.md#72-entitiesjson) |
| D-04 | docs/02 × docs/00-comum | Estados em português (`gerado_por_cascata`, `pendente_de_revisao_visual`) × inglês no MMP (`approved`) | Valores JSON em inglês com rótulo PT na interface ([00-comum §6.4](00-comum.md#64-estados-de-item-artefato-entidade-quadro-som-segmento)) |
