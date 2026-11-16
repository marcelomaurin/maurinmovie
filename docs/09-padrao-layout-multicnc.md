# Padrão de interface — referência MultiCNC / MultiSuite

## Decisão
**Todos os sete aplicativos do MaurinMovie (MMenu, MScript, MVisual, MBoard, MSound, MScene e MCut) devem adotar o MultiCNC como referência de layout e experiência de uso**, com adaptações necessárias ao domínio audiovisual. Esta é uma diretriz de design; não significa que as telas já foram implementadas.

## Referências consultadas
- Repositório: https://github.com/marcelomaurin/multicnc
- Guia do painel: https://github.com/marcelomaurin/multicnc/blob/HEAD/src/app/README.md
- Capturas reais documentadas: https://github.com/marcelomaurin/multicnc/tree/HEAD/imgs/manual_multicnc_0_1_0_3
- Suíte com lançador: MultiSuite Bandeja, descrita no README do MultiCNC.

## Elementos observados a reutilizar
1. **Aplicativo desktop com áreas bem definidas**: cabeçalho com contexto e estado, painel lateral de controles/configuração, área principal de trabalho, abas para tarefas específicas e rodapé de progresso.
2. **Operações visíveis e diretas**: abrir projeto, configurar, executar/gerar, pausar quando aplicável, visualizar, salvar, acessar console/log e acompanhar progresso.
3. **Separação de configurações e execução**: ajustes persistentes em área própria; telas de trabalho preservam contexto do projeto atual.
4. **Visualização e análise**: prévia central com controles, painéis auxiliares de parâmetros e avisos; adaptar a mídia (roteiro, imagens, storyboard, ondas de áudio, vídeo e timeline).
5. **Feedback operacional**: progresso, status claro, erros recuperáveis, log e confirmação de ações destrutivas.
6. **Integração de suíte**: MMenu inspirado no conceito de lançador MultiSuite, com acesso rápido aos aplicativos, arquivos recentes e revisões exatas.

## Esqueleto comum proposto
- **Cabeçalho**: logotipo/nome do aplicativo, projeto, arquivo, revisão ativa, status de validação/sincronização e atalhos Abrir/Salvar.
- **Painel esquerdo**: árvore de cenas/entidades/projetos e comandos relacionados à etapa.
- **Área central**: editor ou visualização principal; roteiro em MScript, catálogo visual em MVisual, quadros em MBoard, áudio em MSound, prévia de cena em MScene, timeline do filme em MCut.
- **Painel direito ou abas**: propriedades, parâmetros de IA, revisões, vínculos e critérios de validação.
- **Rodapé**: progresso, estado da geração, avisos, fila e acesso ao log.
- **Navegação de etapas**: indicar claramente etapa atual, anteriores e próximas; não permitir marcar aprovação ou sincronização sem validação.
- **MMenu**: grade/lista de seis aplicativos, projetos recentes, revisão de cada projeto e pendências de integração.

## Regras de consistência
- Mesmos termos, posicionamento geral e ícones para ações equivalentes entre aplicativos.
- Identidade visual coerente com o MultiCNC; cores, dimensões e componentes exatos devem ser extraídos das telas/código de referência durante o desenho técnico, **não presumidos**.
- Telas redimensionáveis, painéis ajustáveis e persistência de preferências quando suportado.
- Projetos e revisões sempre visíveis, sem confundir revisão do projeto com versão do executável.
- Acessibilidade: rótulos, foco por teclado, atalhos e mensagens legíveis.
- Pré-visualização não é aprovação: separar Gerar, Revisar, Aprovar e Salvar.

## Próxima fase
Na implementação, levantar as propriedades reais dos formulários/componentes do MultiCNC e produzir protótipos para os sete aplicativos antes de congelar tamanhos, paleta, tipografia e posicionamento. Não copiar controles de máquina que não façam sentido no fluxo audiovisual.

## Critérios de aceite
1. Todos os aplicativos apresentam cabeçalho, navegação, trabalho central e estado/progresso com linguagem visual consistente.
2. MMenu segue o padrão de suíte/lançador do MultiCNC/MultiSuite.
3. Projetos, revisões e status são visíveis e acessíveis em cada tela.
4. Fluxos de geração, revisão, aprovação, sincronização e erros seguem o mesmo padrão de interação.
5. Interfaces são adaptadas à tarefa específica sem perder identidade comum.
