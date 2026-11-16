# MMenu — Programa 0 (Portal MaurinMovie)

Código-fonte:
- `src/mmenu/mmenu.lpi`, `src/mmenu/mmenu.lpr`, `src/mmenu/ummenumain.pas`, `src/mmenu/ummenusettings.pas`
- Protocolo e utilitários compartilhados MMP v1: `src/common/ummpprotocol.pas`, `src/common/ummpsha256.pas`
- Testes automatizados do protocolo: `tests/test_mmp_protocol.pas`

## Recursos implementados
- **Layout desktop LCL inspirado no MultiCNC / MultiSuite**: cabeçalho com versão do executável (`v1.0.0`) separada da revisão do projeto, painel lateral com produção ativa e produções recentes, área central em abas e barra de rodapé com progresso.
- **Criação e abertura de produções MMP v1**:
  - `Nova Produção`: cria a árvore completa (`production.json`, `catalog.json`, `settings/`, `projects/00-mmenu`..`06-mcut` com `project.json` e `revisions/r0001/manifest.json`, `shared/` e `backups/`) com IDs únicos e sem sobrescrever pastas existentes.
  - `Abrir Produção`: valida `production.json`, carrega os projetos de `00-mmenu` a `06-mcut` (incluindo projetos por cena em `05-mscene/scenes/<scene_id>/`), e registra em produções recentes (`mmenu.ini`).
  - `Localizar movida...`: localiza pastas de produção movidas buscando pelo `production_id`.
- **Portal dos 6 aplicativos**: exibe `MScript`, `MVisual`, `MBoard`, `MSound`, `MScene` e `MCut` com grafia oficial, `project_id`, revisão ativa, status do projeto e status do executável.
- **Projetos, revisões e vínculos**:
  - Lista projetos, revisões disponíveis (`revision_history` + `revisions/rNNNN`), manifesto (`manifest.json`), SHA-256 e dependências de origem (`sources[]`).
  - Abre o aplicativo responsável passando `--production "<pasta-raiz>" --project-id "<project_id>" --revision "<revision_id>"`.
  - Não sobrescreve projetos nem revisões dos demais aplicativos; revinculações manuais de `project.json` são gravadas apenas em `projects/00-mmenu/relinks.json`.
- **Sincronizações em cascata & integridade**:
  - Lê eventos/jobs em `shared/sync/*.json` e `projects/00-mmenu/sync_jobs.json`, exibindo etapa, status e erro sem declarar conclusão quando há falhas ou pendências, com botão **Ir para aplicativo responsável**.
  - Audita hashes **SHA-256** de manifestos fonte e artefatos, identifica arquivos ausentes/corrompidos, tenta localizar arquivos movidos por `artifact_id` ou `sha256` dentro da produção e sinaliza links para revinculação.
- **Artefatos & Catálogo**: filtros por aplicativo, integridade e busca textual, além de reconstrução atômica de `catalog.json` (com `.bak`).
- **Configurações dedicadas (`ummenusettings.pas`)**: diálogo único para pasta padrão de produções, seleção individual dos 6 executáveis e autodetecção em `bin/`.

## Como compilar e testar
1. Compilar o MMenu com Lazarus (`lazbuild`):
   ```powershell
   C:\lazarus\lazbuild.exe -B src\mmenu\mmenu.lpi
   ```
   O executável será gerado em `bin\mmenu.exe`.
2. Compilar e executar os testes do protocolo MMP v1:
   ```powershell
   C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe -MObjFPC -Scghi -O1 -Fusrc\common -FUbuild\tests -obuild\tests\test_mmp_protocol.exe tests\test_mmp_protocol.pas
   build\tests\test_mmp_protocol.exe
   ```
