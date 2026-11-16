# MMenu — implementação inicial

Código: `src/mmenu/mmenu.lpi`, `src/mmenu/mmenu.lpr`, `src/mmenu/ummenumain.pas`.

## Recursos presentes no código
- Janela desktop LCL com cabeçalho, painel lateral, seis botões dos aplicativos e barra de status, inspirada na organização MultiCNC.
- Seleção de uma produção existente pelo arquivo `production.json`.
- Configuração manual do executável de cada aplicativo; descoberta automática em `bin/` ou ao lado do MMenu.
- Persistência local dos caminhos em `mmenu.ini` no diretório de configuração do usuário.
- Inicialização dos aplicativos via `TProcess` e envio de `--production <pasta>`.
- Mensagens para executável ausente ou falha de inicialização.

## Limitações e próximos passos
- Código publicado, **não compilado nem testado** neste ambiente.
- O MMenu ainda não cria projetos de produção, não lê o catálogo MMP, não valida o conteúdo de `production.json`, não lista revisões e não acompanha jobs de sincronização.
- Os demais aplicativos precisam implementar o parâmetro `--production`; até lá, recebem o argumento, mas não necessariamente carregam o projeto.
- Não há integração operacional com a biblioteca CHATGPT nesta primeira versão.
- O diálogo de configuração percorre os seis executáveis sequencialmente; uma tela dedicada de configurações é melhoria futura.

## Como testar
1. Abrir `src/mmenu/mmenu.lpi` no Lazarus com LCL instalada.
2. Compilar o projeto; corrigir eventuais incompatibilidades da versão instalada do Lazarus/FPC.
3. Executar `bin/mmenu` ou `bin/mmenu.exe`.
4. Selecionar `production.json` de uma produção existente.
5. Configurar os caminhos dos executáveis e iniciar cada aplicativo.
6. Verificar que o processo recebe `--production` e o caminho esperado.

A seleção de arquivo `production.json` é a primeira etapa do suporte MMP, não a implementação completa do protocolo.
