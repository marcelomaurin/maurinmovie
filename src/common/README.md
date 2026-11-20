# common — código compartilhado

Unidades usadas por todos os programas (todos os `.lpi` incluem `../common` no caminho de busca). As marcadas "sem LCL" também compilam no programa de testes e no modo headless.

| Unidade | Conteúdo |
|---|---|
| `mmpcommon.pas` (sem LCL) | constantes do protocolo MMP v1 (schemas, pastas `projects/NN-app`, códigos de saída), leitura dos argumentos de linha de comando, rótulos de revisão `<NomeBase>_<Tipo>_RNNN`, presets de resolução e gênero |
| `ummpsha256.pas` (sem LCL) | SHA-256 de texto e de arquivo |
| `mmpsettings.pas` (sem LCL) | configuração centralizada (gravada só pelo MMenu): máquina (`mmenu.ini`, `secrets.ini`, provedores de IA da máquina) e produção (`settings/*.json`), controle de acesso |
| `ummpdb.pas` (sem LCL) | banco SQLite da produção (`maurinmovie.db`, criado a partir de `maurinmovie_empty.db`), pastas `media/`, log centralizado |
| `ummpprotocol.pas` (sem LCL) | criação e leitura de produções, auditoria de integridade (hashes, fontes, arquivos movidos, revinculações de `catalog.json`), catálogo, locks, log JSON Lines, estado das etapas e histórico |
| `ummpappbase.pas` | publicação de revisões, eventos e transações de cascata, execução headless de outro aplicativo, rascunho `work/draft/`, validação do lançamento pelo MMenu e instância única |
| `ummpaibridge.pas` | ponte com os provedores de IA (biblioteca CHATGPT) usando a configuração do MMenu |

## Regras importantes
- Revisões publicadas (`revisions/rNNNN`) são imutáveis. Arquivos em edição ficam em `projects/NN-app/work/draft/` (`MmpDraftDir`, `MmpResolveDraftOrRevisionFile`) e são copiados para a nova revisão ao publicar.
- `PublishProjectRevision` grava o manifesto e atualiza `project.json` e o SQLite com os mesmos `artifact_id`.
- `EmitSyncEventEx` grava o evento completo (envelope de docs/11 §4) e a transação; `MmpUpdateTransactionStage` só marca a transação como `complete` quando todos os estágios completam.

Testes: [tests/test_mmp_protocol.pas](../../tests/test_mmp_protocol.pas).
