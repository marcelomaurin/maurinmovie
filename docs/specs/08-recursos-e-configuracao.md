# Recursos externos e catálogo de configuração

> Levantamento de tudo o que a suíte precisa além do código: provedores de IA, ferramentas externas, credenciais, pastas, perfis de mídia, idiomas, prompts, políticas, rede e interface. **Todo item configurável aqui é editado somente no MMenu** (tela Configurações, [01-mmenu §6.4](01-mmenu.md#64-configurações-centralizadas)) e lido pelos demais programas via `mmpsettings` ([00-comum §12](00-comum.md#12-configuração-centralizada-no-mmenu)).
>
> Itens marcados **[PROPOSTA]** não constam da documentação original e foram identificados como necessários ao especificar os programas.

Legenda das colunas: **Nível** P = da produção (pasta `settings/`, viaja com o filme, sem segredos) · M = da máquina (pasta de configuração do usuário). **Obr.** = obrigatório para o app funcionar (com o provedor simulado, nenhum item de IA é obrigatório).

---

## 1. Arquivos de configuração

| Arquivo | Nível | Conteúdo | Seções deste documento |
|---|---|---|---|
| `settings/production.json` | P | dados gerais e formato técnico do filme | §4, §7 |
| `settings/ai-providers.json` | P | provedores de IA e seus parâmetros | §2 |
| `settings/apps.json` | P | qual provedor cada programa usa e padrões de geração | §2.3 |
| `settings/media-profiles.json` | P | perfis de imagem, áudio, vídeo de trabalho e render | §5 |
| `settings/presets.json` | P | estilos visuais, vistas padrão, sotaques, emoções, transições | §6 |
| `settings/prompts/<app>/<nome>.txt` | P | modelos de prompt que substituem os embutidos | §8 |
| `settings/policies.json` | P | aprovação, custos e limites, público e privacidade, armazenamento e backup | §9 |
| `mmenu.ini` (`GetAppConfigDir(False)/MaurinMovie/`) | M | usuário, executáveis, ferramentas, pastas, rede, interface, log | §3, §10, §11 |
| `secrets.ini` (mesma pasta, permissão 600; DPAPI no Windows) | M | chaves de API e credenciais | §3.3 |

Todos os JSON têm `schema` e `updated_at`, gravação atômica com `.bak`, e são validados pelo MMenu antes de salvar.

---

## 2. Provedores de IA

### 2.1 Tipos de provedor

| `kind` | Nome na tela | Para quê | Programas | Obr. |
|---|---|---|---|---|
| `text` | IA Texto | roteiro, reescrita, personagens, indexação, perfis vocais (IA A), índice de efeitos, análise de comentários | MScript, MVisual, MBoard, MSound, MCut | não (simulado) |
| `image` | IA Imagem/Foto | vistas de referência, figurinos, variantes, quadros de storyboard | MVisual, MBoard | não |
| `voice` | IA Som — Voz | síntese e clonagem de voz (IA B), falas do áudio-guia | MSound (MScene usa o resultado) | não |
| `sfx` | IA Som — Efeitos | geração de efeitos sonoros | MSound | não |
| `video` | IA Vídeo | vídeo de cada segmento | MScene | não |
| `vision` | IA Visão (verificação) [PROPOSTA] | comparar imagem/quadro com as referências aprovadas e apontar quebras de continuidade (identidade, figurino, objeto) antes da revisão humana; nunca aprova | MVisual, MBoard, MScene | não (opcional) |
| `asr` | IA Transcrição [PROPOSTA] | transcrever o áudio do vídeo/da síntese e conferir se a fala corresponde ao roteiro e ao tempo | MSound, MScene | não (opcional) |

### 2.2 Campos de cada provedor (`ai-providers.json`)

| Campo | Tipo | Padrão | Observação |
|---|---|---|---|
| `id` | texto | `<kind>.default` | único |
| `kind` | enum §2.1 | — | |
| `label` | texto | — | nome exibido |
| `adapter` | `mock`, `openai-compatible`, `chatgpt-lib`, `local-cli`, `http-generic` | `mock` | `local-cli` para modelos locais (ex.: servidor ou programa na própria máquina) |
| `base_url` | URL | — | obrigatório para adaptadores HTTP |
| `model` | texto | — | |
| `secret_ref` | texto | — | nome da chave no cofre (§3.3) ou variável de ambiente |
| `command` / `args_template` | texto | — | só `local-cli`; marcadores `{{input}}`, `{{output}}`, `{{prompt}}` |
| `timeout_s` | inteiro | 120 (vídeo: 1800) | |
| `max_retries` | inteiro | 3 | só para erros transitórios |
| `rate_limit_per_min` | inteiro | 0 = sem limite | |
| `max_concurrency` | inteiro | 1 | gerações simultâneas deste provedor |
| `cost_per_unit` / `unit` | número / `1k_tokens`, `image`, `second` | 0 | para estimativa de custo (§9.2) |
| `enabled` | lógico | true | |
| `params` | objeto | por tipo, abaixo | |

Parâmetros por tipo (`params`):

| Tipo | Parâmetros |
|---|---|
| text | `temperature` (0,7), `max_tokens` (8000), `json_mode` (true), `system_prompt_prefix` |
| image | `width`/`height` (1024), `steps` (30), `guidance` (7,0), `sampler`, `negative_prompt`, `supports_reference_images` (true), `max_references` (4) |
| voice | `sample_rate` (48000), `format` (`wav`), `allow_cloning` (false), `languages` (["pt-BR"]), `voice_presets` (lista) |
| sfx | `sample_rate` (48000), `max_duration_s` (20) |
| video | `width`/`height` (1920×1080), `fps` (24), `max_segment_s` (10), `lip_sync` (true), `accepts_start_end_frames` (true), `accepts_guide_audio` (true), `produces_audio` (false) |
| vision | `threshold` (0,8), `max_images` (8) |
| asr | `language` (`pt-BR`), `word_timestamps` (true) |

Os campos `max_segment_s`, `accepts_*` e `produces_audio` descrevem a capacidade do motor e alimentam regras dos programas (ex.: MScene pede subdivisão se o segmento passar de `max_segment_s`; lacunas L-11 e L-23).

### 2.3 Uso por programa (`apps.json` → `<App>.providers`)

| Programa | Tipos usados |
|---|---|
| MScript | text |
| MVisual | text, image, vision (opcional) |
| MBoard | text, image, vision (opcional) |
| MSound | text (IA A), voice (IA B), sfx, asr (opcional) |
| MScene | video, vision (opcional), asr (opcional) |
| MCut | text |

Padrões de geração de cada programa: ver [00-comum §12.4](00-comum.md#124-settingsappsjson).

---

## 3. Identidade, credenciais e licenças

### 3.1 Usuário (M, `mmenu.ini [User]`)

| Chave | Padrão | Uso |
|---|---|---|
| `Name` | nome do usuário do sistema | autor em `HistoryEntry` (`user:<Name>`) e revisor em `Approval`; sem nome configurado, aprovações ficam bloqueadas [PROPOSTA] |
| `Role` | `diretor` | exibição |
| `Email` | vazio | opcional; nunca gravado em exportações |

### 3.2 Biblioteca CHATGPT (M, `mmenu.ini [Libraries]`)

| Chave | Uso |
|---|---|
| `ChatGPTLibPath` | caminho do repositório/pacote CHATGPT, quando o adaptador `chatgpt-lib` for usado (docs/10). Verificar API antes de habilitar |

### 3.3 Cofre de credenciais (M, `secrets.ini`)

| Item | Uso |
|---|---|
| chaves de API por `secret_ref` | provedores de IA |
| usuário/senha de proxy | rede (§10) |
| credenciais de destino de backup remoto | §9.4 |

Regras: nunca em `settings/`, log, exportação ou Git; tela mostra mascarado; botão "Mostrar" exige confirmação.

### 3.4 Licenças e autorizações (P, `policies.json` + pastas)

| Item | Uso | Programa |
|---|---|---|
| Modelo de termo de autorização de voz (`settings/templates/autorizacao_voz.md`) [PROPOSTA] | anexar ao clonar voz real | MSound |
| Modelo de termo de consentimento do público (`settings/templates/consentimento_publico.md`) [PROPOSTA] | sessões de avaliação | MCut |
| Licença padrão de ativos gerados (`default_generated_license`) | gravada em cada artefato | todos |
| Licenças aceitas para mídia importada (lista) | validação ao importar efeitos, imagens, músicas | MVisual, MSound, MCut |

---

## 4. Produção e regionalização (P, `production.json`)

| Chave | Padrão | Uso | Programas |
|---|---|---|---|
| `title`, `name_base` | — | rótulos `<NomeBase>_<Tipo>_RNNN` | todos |
| `language` | `pt-BR` | idioma do roteiro, das falas e dos prompts | MScript, MSound, MScene |
| `dialects` | `["litoraneo-ptBR", "paulista", "carioca", "nordestino", "gaucho"]` [PROPOSTA] | lista de sotaques ofertada no perfil vocal | MSound |
| `target_duration_ms` | — | comparação com a soma das cenas | MScript, MBoard, MCut |
| `format` | `short` | curta/média/longa | MScript |
| `rating` | — | classificação indicativa | MScript |
| `fps` | 24 | timecode, vídeo, render | MBoard, MSound, MScene, MCut |
| `frame_size`, `aspect` | 1920×1080, 16:9 | quadros e vídeo | MBoard, MScene, MCut |
| `visual_style` | `realista cinematográfico` | estilo padrão de imagens | MVisual, MBoard, MScene |
| `timecode_format` | `HH:MM:SS:FF` | exibição | MSound, MScene, MCut |

Idioma da **interface** é da máquina (§11), não da produção.

---

## 5. Perfis de mídia (P, `media-profiles.json`)

| Perfil | Padrão | Uso |
|---|---|---|
| `image.reference` | PNG RGB 8 bits, 1024×1024, fundo `#808080` | vistas de personagem/objeto/figurino (MVisual) |
| `image.location` | PNG, 1920×1080 | locais (MVisual) |
| `image.frame` | PNG, `frame_size` da produção | quadros (MBoard) |
| `image.thumbnail` | JPEG 320 px de largura, qualidade 80 | miniaturas em cache (todos) |
| `audio.work` | WAV PCM 48 kHz 24 bits mono (voz) / estéreo (efeitos, prévias) | MSound, MScene |
| `audio.loudness_target` | −23 LUFS [PROPOSTA] | normalização das prévias e do render |
| `video.work` | MP4 H.264, CRF 16, `fps` e `frame_size` da produção, AAC 48 kHz | segmentos e cenas (MScene) |
| `render.presets[]` | `Prévia 720p` (H.264 CRF 23, AAC 128k), `Master 1080p` (H.264 CRF 18, AAC 320k), `Web 1080p` (H.264 CRF 21, faststart), `Arquivo ProRes` (MOV ProRes 422) | exportação (MCut); um marcado como padrão |
| `subtitles` | SRT UTF-8, gerado das falas aprovadas [PROPOSTA] | exportação opcional (MCut) |

---

## 6. Predefinições (P, `presets.json`)

| Lista | Conteúdo padrão | Programas |
|---|---|---|
| `visual_styles` | realista cinematográfico, storyboard colorido, esboço P&B, animação 2D | MVisual, MBoard |
| `reference_views` | personagem/figurino: front, back, right, left; objeto: front, back, right, left (+ top, bottom); local: wide + 2 ângulos | MVisual |
| `object_states` | intacto, aberto, fechado, danificado | MVisual |
| `emotions` | neutra, alegre, triste, tensa, raivosa, sussurrada | MSound |
| `effect_categories` | ambiente, objeto, mecanismo, movimento, ação | MSound |
| `transitions` | corte seco, fade in, fade out, fade cruzado (0,5 s), fade para preto (2 s), wipe | MCut |
| `review_checklists` | itens dos checklists de revisão de segmento (MScene) e de ligação entre cenas | MScene |
| `moods`, `times_of_day` | listas usadas nos combos do MScript | MScript |

---

## 7. Tempo, numeração e IDs (P, `production.json`)

| Chave | Padrão | Observação |
|---|---|---|
| `revision_label_digits` | 3 | `R001` nos rótulos (L-02) |
| `id_scheme` | `ulid` | fixo no MMP v1; exibido, não editável |

---

## 8. Modelos de prompt (P, `settings/prompts/`)

Cada programa embute seus prompts (`src/<app>/prompts/*.txt`). O MMenu (aba Prompts) lista todos, mostra o texto embutido e permite criar uma **substituição** da produção em `settings/prompts/<app>/<nome>.txt`, com "Restaurar original". Marcadores `{{campo}}` são validados (não pode faltar marcador obrigatório).

| Programa | Prompts |
|---|---|
| MScript | `gerar_roteiro`, `reescrever_cena`, `extrair_personagens`, `consistencia` |
| MVisual | `indexar_cena`, `vista_personagem`, `vista_objeto`, `vista_local`, `figurino` |
| MBoard | `quadro_inicial`, `quadro_final`, `quadro_fronteira` |
| MSound | `perfil_vocal`, `indexar_efeitos` |
| MScene | `segmento_video` |
| MCut | `agrupar_comentarios` |

---

## 9. Políticas (P, `policies.json`)

### 9.1 Aprovação e revisão

| Chave | Padrão | Uso |
|---|---|---|
| `require_approved_refs_for_board` | true | MBoard só usa referências aprovadas |
| `require_voice_approval_for_scene` | true | MScene bloqueia sem perfil vocal aprovado |
| `vision_check_before_review` | false | roda `vision` antes da revisão humana |
| `bulk_approve_allowed` | true | permite "Validar todos" |

### 9.2 Custos e limites [PROPOSTA]

| Chave | Padrão | Uso |
|---|---|---|
| `budget_total` / `currency` | 0 = sem limite / `BRL` | soma de `cost_per_unit` × uso; ao atingir 80% avisa, a 100% pede confirmação a cada geração |
| `confirm_batch_above_items` | 50 | confirma lotes grandes (MVisual, MBoard) mostrando a estimativa |
| `max_parallel_jobs` | 2 | gerações simultâneas na máquina |
| `cost_log` | true | registra custo estimado por geração no log |

### 9.3 Público e privacidade (MCut)

| Chave | Padrão |
|---|---|
| `rating_scale` | 5 |
| `default_identification` | `anonymous` |
| `consent_required` | true |
| `participant_data_retention_days` | 180 (L-13, a confirmar) |
| `exclude_personal_data_from_exports` | true |
| `fragment_context_s` | 5 |

### 9.4 Armazenamento, limpeza e backup

| Chave | Padrão | Uso |
|---|---|---|
| `cache_max_gb` | 20 | limpeza automática de `shared/cache` (descartável) |
| `temp_cleanup_hours` | 48 | apaga `shared/temp/<job>` órfãos |
| `keep_render_exports` | todas | renders antigos só apagados com confirmação |
| `backup.enabled` | false | cópia de `production.json`, `settings/`, `projects/*/project.json` e manifestos |
| `backup.destination` | `backups/` | pasta local ou remota (credencial no cofre) |
| `backup.interval_hours` / `backup.keep` | 24 / 10 | |
| `autosave_s` | 60 | rascunho em `work/` (todos os apps) |
| `lock_stale_minutes` | 5 | lock órfão (00-comum §7.4) |
| `monitor_interval_s` | 5 | atualização do MMenu |
| `min_free_disk_gb` | 10 | abaixo disso, gerações de vídeo são bloqueadas com aviso |

---

## 10. Ferramentas externas, executáveis e rede (M, `mmenu.ini`)

| Seção / chave | Padrão de detecção | Uso | Obr. |
|---|---|---|---|
| `[Applications] MScript…MCut` | `<dir do MMenu>/<app>[.exe]`, `../bin/<app>` | lançamento pelo MMenu e "Abrir fonte" | sim |
| `[Tools] ffmpeg` | PATH, `<dir>/tools/ffmpeg` | costura, mixagem, render, simulado de vídeo | sim para MSound, MScene, MCut |
| `[Tools] ffprobe` | ao lado do ffmpeg | duração e validação de mídia | idem |
| `[Tools] mpv` (ou `libmpv`) | PATH, `<dir>/tools/mpv` | reprodução embutida | sim para MScene, MCut; MSound (prévia) |
| `[Tools] OpenSSL` | DLLs ao lado do executável (Windows) | HTTPS para provedores | sim com provedores remotos |
| `[Paths] ProductionsDir` | `~/MaurinMovie/productions` | nova produção | sim |
| `[Paths] GlobalCacheDir` | `GetAppConfigDir/MaurinMovie/cache` | miniaturas fora da produção | não |
| `[Paths] SoundLibraryDir` [PROPOSTA] | vazio | banco de efeitos licenciados para importar | não |
| `[Paths] MusicLibraryDir` [PROPOSTA] | vazio | músicas licenciadas (depende de L-11) | não |
| `[Network] Proxy`, `ProxyUser` (senha no cofre) | sistema | provedores remotos | não |
| `[Network] CABundle` | sistema | certificados TLS | não |
| `[Network] Offline` | false | força o provedor simulado e bloqueia chamadas remotas | não |

O MMenu mostra ✔/✘ por item e a versão detectada (`ffmpeg -version`, `mpv --version`).

---

## 11. Interface e log (M, `mmenu.ini`)

| Chave | Padrão | Uso |
|---|---|---|
| `[Interface] Language` | `pt-BR` | idioma da interface (resourcestrings) |
| `[Interface] FontScale` | 100% | acessibilidade |
| `[Interface] Theme` | claro | claro/escuro (cores do MultiCNC, L-18) |
| `[Interface] ConfirmDestructive` | true | confirmações |
| `[Logging] Level` | `info` | todos os apps (o `--log-level` sobrepõe só naquela execução) |
| `[Logging] RetentionDays` | 30 | limpeza de `shared/logs` |

---

## 12. Verificação de prontidão

O MMenu tem o botão **"Verificar ambiente"** (aba Geral) [PROPOSTA] que percorre este catálogo e mostra, por programa, se ele pode rodar: executável encontrado, ferramentas obrigatórias, provedores configurados e testados, nome do usuário definido, espaço em disco. Os apps fazem a mesma verificação para o que usam ao abrir e, se faltar algo, mostram "Configuração incompleta: <item>. Abrir Configurações no MMenu".

## 13. Recursos a definir (sem configuração possível ainda)

| Recurso | Situação |
|---|---|
| Motores reais de IA para cada tipo | L-09 |
| Trilha musical e mixagem final | L-11 (sem programa responsável) |
| Distribuição/instalador com ffmpeg e mpv (licenças) | L-14 |
| Participação remota do público | L-12 |
| Paleta, ícones e fontes do MultiCNC | L-18 |
