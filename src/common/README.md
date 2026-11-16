# common — código compartilhado

Unidades usadas por todos os programas. Todos os `.lpi` já incluem `../common` no caminho de busca.

- `mmpcommon.pas` — constantes do protocolo MMP v1 (schemas, nomes de arquivos, pastas `projects/NN-app`), leitura de `--production`, `--project-id` e `--revision`, e nome de revisão `rNNNN`.

Próximos passos: leitura/escrita de `production.json`, `project.json` e `manifest.json`, cálculo de SHA-256, geração de IDs e a ponte com a biblioteca CHATGPT. Nada disso está implementado ainda. O `mmpcommon.pas` compila com FPC, mas ainda não é usado pelos programas nem tem testes.
