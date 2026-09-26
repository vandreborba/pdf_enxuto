/// Todo o texto do aplicativo, em português.
///
/// Ficou centralizado em um único lugar para facilitar revisão de redação e
/// uma futura tradução. Os textos de ajuda (usados nos botões "?") explicam
/// o método com calma, porque é isso que o usuário leigo precisa.
class S {
  S._();

  // ------------------------------------------------------------------ Geral
  static const appName = 'PDF Enxuto';
  static const tagline =
      'Comprima, divida e converta PDFs sem sair do seu computador';
  static const ok = 'Entendi';
  static const cancelar = 'Cancelar';
  static const fechar = 'Fechar';
  static const continuar_ = 'Continuar';
  static const voltar = 'Voltar';
  static const aplicar = 'Aplicar';
  static const salvar = 'Salvar';
  static const limpar = 'Limpar';
  static const remover = 'Remover';
  static const removerTodos = 'Remover todos';
  static const copiar = 'Copiar';
  static const copiado = 'Copiado!';
  static const sim = 'Sim';
  static const nao = 'Não';
  static const aviso = 'Aviso';
  static const erro = 'Erro';
  static const sucesso = 'Pronto!';
  static const tentarNovamente = 'Tentar novamente';
  static const detalhes = 'Detalhes';
  static const opcional = 'opcional';
  static const recomendado = 'recomendado';
  static const indisponivel = 'indisponível';
  static const disponivel = 'disponível';

  // ----------------------------------------------------------- Navegação
  static const navComprimir = 'Comprimir';
  static const navDividir = 'Dividir';
  static const navHistorico = 'Histórico';
  static const navConfiguracoes = 'Configurações';
  static const navSobre = 'Sobre';

  // ------------------------------------------------------ Zona de arquivos
  static const solteArquivos = 'Solte os PDFs aqui';
  static const solteArquivosDica = 'ou clique para escolher os arquivos';
  static const arrasteAqui = 'Pode soltar!';
  static const escolherArquivos = 'Escolher PDFs';
  static const escolherPasta = 'Escolher pasta';
  static const nenhumArquivo = 'Nenhum arquivo na fila';
  static const nenhumArquivoDica =
      'Arraste PDFs para esta janela, cole do gerenciador de arquivos ou use o botão acima.';
  static const apenasPdf = 'Somente arquivos .pdf são aceitos';
  static const arquivoIgnorado = 'Ignorado (não é PDF)';
  static const arquivoDuplicado = 'Este arquivo já está na fila';
  static const arquivoProtegido =
      'Este PDF é protegido por senha. Remova a proteção para poder otimizar.';
  static const arquivoCorrompido =
      'Não foi possível ler este PDF. Ele pode estar corrompido.';
  static const pastaSaida = 'Pasta de saída';
  static const pastaSaidaPadrao = 'Ao lado do arquivo original';
  static const usarPastaPadrao = 'Usar pasta padrão';
  static const escolherPastaSaida = 'Escolher pasta de saída';
  static const abrirPasta = 'Abrir pasta';
  static const abrirArquivo = 'Abrir PDF';
  static const abrirOriginal = 'Abrir original';
  static const comparar = 'Comparar tamanhos';

  // ------------------------------------------------------------ Comprimir
  static const comprimirTitulo = 'Comprimir PDF';
  static const comprimirSubtitulo =
      'Reduza o tamanho dos arquivos mantendo a melhor qualidade possível.';
  static const comprimirAgora = 'Comprimir agora';
  static const comprimindo = 'Comprimindo…';
  static const comprimirN = 'Comprimir %d arquivos';
  static const nivelCompressao = 'Nível de compressão';
  static const modoTexto = 'O que fazer com o texto';
  static const modoTextoManter = 'Manter texto selecionável';
  static const modoTextoManterCurto = 'Manter texto';
  static const modoTextoRasterizarCurto = 'Vira imagem';
  static const modoTextoRasterizar = 'Máxima redução (vira imagem)';
  static const tamanhoAlvo = 'Tamanho alvo';
  static const tamanhoAlvoAtivar = 'Quero atingir um tamanho específico';
  static const tamanhoAlvoDica =
      'Ex.: para enviar por e-mail ou caber em um formulário.';
  static const tamanhoAlvoPorArquivo = 'Alvo por arquivo';
  static const tamanhoAlvoTotal = 'Alvo para o conjunto';
  static const tamanhoAlvoLivre =
      'Alvo total (o app distribui entre os arquivos)';
  static const alvoImpossivel =
      'Não foi possível chegar ao tamanho desejado sem destruir a qualidade. '
      'Entregamos o menor arquivo possível respeitando o mínimo de qualidade.';
  static const alvoAtingido = 'Tamanho alvo atingido!';
  static const qualidadeMinima = 'Qualidade mínima aceitável';
  static const opcoesAvancadas = 'Opções avançadas';
  static const motorCompressao = 'Motor de compressão';
  static const motorAutomatico = 'Automático';
  static const motorNativo = 'Nativo (embutido)';
  static const motorGhostscript = 'Ghostscript';
  static const motorQpdf = 'qpdf (sem perdas)';
  static const imagens = 'Imagens';
  static const resolucao = 'Resolução das imagens';
  static const qualidadeJpeg = 'Qualidade JPEG';
  static const corImagens = 'Cor das imagens';
  static const corManter = 'Manter original';
  static const corCinza = 'Converter para tons de cinza';
  static const corMono = 'Converter para preto e branco';
  static const removerMetadados = 'Remover metadados';
  static const removerMarcadores = 'Remover marcadores (sumário)';
  static const removerAnotacoes = 'Remover anotações e formulários';
  static const removerMiniaturas = 'Remover miniaturas internas';
  static const recompressaoSemPerdas = 'Otimização sem perdas';
  static const otimizarEstrutura = 'Limpar estrutura e objetos não usados';
  static const comprimirFluxos = 'Recomprimir fluxos internos';
  static const previsaoTamanho = 'Previsão';
  static const previsaoIndisponivel = 'Faça uma simulação para ver a previsão';
  static const simular = 'Simular (1ª página)';
  static const simulando = 'Simulando…';
  static const simulacaoTitulo = 'Simulação';
  static const simulacaoExplicacao =
      'A simulação comprime apenas a primeira página para estimar o resultado '
      'sem esperar pelo arquivo inteiro. O tamanho final pode variar.';
  static const comoComprimir = 'Como comprimir';
  static const perfisAjuda =
      'Escolha um perfil e o app comprime uma vez, exatamente nessa qualidade. '
      'Quer mirar um tamanho? Use a aba "Tamanho alvo".';
  static const presets = 'Perfis prontos';
  static const presetsOrdem = 'Qualidade da compressão';
  static const presetsComAlvo = 'Qualidade de partida';
  static const presetsComAlvoAviso =
      'Com o tamanho alvo ligado, o perfil vira o ponto de partida: o app '
      'começa nele e só desce até o piso de qualidade que você definir.';
  static const faixaDoAlvo = 'Faixa da busca';
  static const faixaDoAlvoTexto = 'de %s até %s';
  static const alvoDonoDaQualidade =
      'No modo tamanho alvo o perfil não é usado: a busca começa na melhor '
      'qualidade e desce (resolução e JPEG) até caber no alvo ou até o piso.';
  static const avancadasNoAlvo =
      'Resolução e qualidade JPEG são decididas pela busca do alvo — os '
      'controles manuais ficam disponíveis no modo "por perfil de qualidade".';
  static const alvoSemAjuste =
      'O motor escolhido não tem o que ajustar para perseguir o alvo: ele faz '
      'uma passada e informa o tamanho obtido. Para mirar um tamanho, use o '
      'Ghostscript ou o modo "vira imagem" (que ajusta resolução e JPEG).';
  static const presetLeve = 'Leve';
  static const presetEquilibrado = 'Equilibrado';
  static const presetForte = 'Forte';
  static const presetExtremo = 'Extremo';
  static const presetPersonalizado = 'Personalizado';
  static const presetLeveResumo = 'Qualidade quase intacta';
  static const presetEquilibradoResumo = 'Bom para enviar por e-mail';
  static const presetForteResumo = 'Arquivos bem menores';
  static const presetExtremoResumo = 'O menor tamanho possível';

  // -------------------------------------------------------------- Dividir
  static const dividirTitulo = 'Dividir PDF';
  static const dividirSubtitulo =
      'Corte um PDF em várias partes, do jeito que você precisar.';
  static const dividirAgora = 'Dividir agora';
  static const dividindo = 'Dividindo…';
  static const metodoDivisao = 'Como dividir';
  static const metodoPorIntervalos = 'Por intervalos de páginas';
  static const metodoCadaN = 'A cada N páginas';
  static const metodoPorTamanho = 'Por tamanho máximo';
  static const metodoExtrair = 'Extrair páginas específicas';
  static const metodoPorMarcadores = 'Por marcadores (sumário)';
  static const intervalosLabel = 'Intervalos';
  static const intervalosDica = 'Ex.: 1-3, 7, 10-12';
  static const cadaNLabel = 'Páginas por parte';
  static const tamanhoMaximoLabel = 'Tamanho máximo por parte';
  static const extrairLabel = 'Páginas a extrair';
  static const extrairDica = 'Ex.: 1, 4, 9-12 (viram um único PDF)';
  static const separarCadaPagina = 'Uma página por arquivo';
  static const previsaoPartes = 'Previsão';
  static const partesPrevistas = 'partes';
  static const paginasNaoUsadas =
      'Páginas fora dos intervalos não serão incluídas em nenhuma parte.';
  static const intervaloInvalido = 'Intervalo inválido';
  static const intervaloForaDoLimite =
      'O intervalo ultrapassa o total de páginas do documento';
  static const paginaInexistente = 'Página inexistente neste documento';
  static const numeracaoExplicacao =
      'A numeração é a ordem real das páginas no arquivo (1 = primeira página).';
  static const nomeDosArquivos = 'Nome das partes';
  static const padraoNome = 'Padrão do nome';
  static const variavelNome = '{nome}';
  static const variavelParte = '{parte}';
  static const variavelInicio = '{inicio}';
  static const variavelFim = '{fim}';
  static const variavelPaginas = '{paginas}';
  static const exemploNome = 'Exemplo';
  static const juntarEmUmArquivo = 'Gerar um único arquivo com tudo';
  static const marcarPartes = 'Incluir número da parte no nome';
  static const marcadoresVazio =
      'Este PDF não possui marcadores (sumário). Use outro método.';
  static const marcadoresEncontrados = 'marcadores encontrados';

  // ------------------------------------------------------------ Histórico
  static const historicoTitulo = 'Histórico';
  static const historicoSubtitulo =
      'Tudo o que já passou por aqui, com o quanto você economizou.';
  static const historicoVazio = 'Nada por aqui ainda';
  static const historicoVazioDica =
      'Assim que você comprimir ou dividir um PDF, o resultado aparece nesta lista.';
  static const totalEconomizado = 'Espaço economizado';
  static const totalProcessado = 'Arquivos processados';
  static const taxaMedia = 'Redução média';
  static const limparHistorico = 'Limpar histórico';
  static const limparHistoricoConfirmar =
      'Isso apaga apenas a lista de tarefas. Nenhum arquivo será removido.';
  static const mostrarNoGerenciador = 'Mostrar no gerenciador de arquivos';
  static const repetirTarefa = 'Repetir com as mesmas opções';

  // -------------------------------------------------------------- Planilha
  static const navPlanilha = 'Para planilha';
  static const planilhaTitulo = 'Converter em planilha';
  static const planilhaSubtitulo =
      'Transforme as tabelas do PDF em planilha (Excel/Calc) ou CSV, prontas '
      'para somar, ordenar e filtrar.';
  static const planilhaAgora = 'Converter agora';
  static const planilhaConvertendo = 'Convertendo…';
  static const planilhaArquivos = 'Arquivos';
  static const planilhaFormato = 'Formato do arquivo';
  static const planilhaModoLeitura = 'Como ler o PDF';
  static const planilhaSeparacao = 'Separação das colunas';
  static const planilhaOrganizacao = 'Como organizar as abas';
  static const planilhaOpcoes = 'Detalhes da conversão';
  static const planilhaCabecalho = 'Primeira linha é o título das colunas';
  static const planilhaIgnorarCabecalho =
      'Ignorar cabeçalho e rodapé repetidos';
  static const planilhaProteger = 'Proteger contra fórmulas';
  static const planilhaSeparador = 'Separador do CSV';
  static const planilhaSeparadorPontoVirgula = 'Ponto e vírgula (;)';
  static const planilhaSeparadorVirgula = 'Vírgula (,)';
  static const planilhaPrevia = 'Prévia das tabelas';
  static const planilhaPreviaVazio = 'Adicione um PDF para ver as tabelas';
  static const planilhaPreviaDica =
      'A prévia mostra as primeiras páginas do primeiro arquivo da fila. É o '
      'mesmo caminho da conversão: o que você vê aqui é o que sai na planilha.';
  static const planilhaPreviaLendo = 'Procurando tabelas…';
  static const planilhaPreviaNada =
      'Não encontramos tabelas nas primeiras páginas. Dá para converter mesmo '
      'assim: o texto sai em uma coluna só (modo "Texto corrido").';
  static const planilhaPreviaDigitalizada =
      'Estas páginas são imagens (digitalização), sem texto para ler.';
  static const planilhaPreviaResumo = 'tabelas encontradas';
  static const planilhaPreviaLinhas = 'linhas';
  static const planilhaPreviaColunas = 'colunas';
  static const planilhaPreviaPagina = 'Página %d';
  static const planilhaOndeSalvar = 'Onde salvar';
  static const planilhaSemPaginas =
      'Não foi possível ler as páginas deste PDF.';
  static const planilhaDigitalizada =
      'Este PDF é uma imagem (digitalização): não tem texto para converter. '
      'Seria preciso um programa de OCR antes — o PDF Enxuto não faz OCR.';
  static const planilhaSemTabela =
      'Não sobrou nenhum conteúdo para gravar. O PDF pode estar em branco.';
  static const planilhaFalhou = 'Não foi possível converter';
  static const planilhaMotorIndisponivel =
      'O leitor de PDF do aplicativo não pôde ser carregado. Feche e abra o '
      'PDF Enxuto novamente; se continuar, reinstale o aplicativo.';
  static const planilhaPaginasSemTabela =
      'Em algumas páginas não encontramos tabela: o texto delas entrou em uma '
      'coluna só, para nada se perder.';
  static const planilhaAvisoXlsx =
      'O XLSX abre no Excel e no LibreOffice Calc. O CSV abre em praticamente '
      'qualquer programa, mas é texto puro.';

  // ------------------------------------------------------- Configurações
  static const configTitulo = 'Configurações';
  static const configSubtitulo = 'Ajuste o app do seu jeito.';
  static const aparencia = 'Aparência';
  static const tema = 'Tema';
  static const temaSistema = 'Seguir o sistema';
  static const temaClaro = 'Claro';
  static const temaEscuro = 'Escuro';
  static const corDestaque = 'Cor de destaque';
  static const animacoesReduzidas = 'Reduzir animações';
  static const animacoesReduzidasDica =
      'Deixa as transições instantâneas. Útil em máquinas mais lentas.';
  static const comportamento = 'Comportamento';
  static const abrirPastaAoTerminar = 'Abrir a pasta ao terminar';
  static const notificarAoTerminar = 'Avisar quando terminar';
  static const sobrescrever = 'Sobrescrever arquivos existentes';
  static const sobrescreverDica =
      'Se desligado, o app cria um nome novo (relatorio (1).pdf) em vez de substituir.';
  static const manterOriginal = 'Nunca apagar o arquivo original';
  static const desempenho = 'Desempenho';
  static const processarEmParalelo = 'Processar vários arquivos ao mesmo tempo';
  static const simultaneos = 'Arquivos simultâneos';
  static const simultaneosDica =
      '2 é um bom número na maioria dos computadores. Aumente se tiver muitos núcleos.';
  static const atualizacoes = 'Atualizações';
  static const verificarAoAbrir = 'Verificar atualizações ao abrir';
  static const verificarAgora = 'Verificar agora';
  static const verificando = 'Verificando…';
  static const ultimaVerificacao = 'Última verificação';
  static const nuncaVerificado = 'nunca';
  static const atualizacoesDesligadas =
      'Os avisos de atualização estão desligados.';
  static const reativarAvisos = 'Reativar avisos de atualização';
  static const motoresInstalados = 'Motores encontrados';
  static const motoresOpcionais = 'Motores opcionais (instalação)';
  static const paginaSiteOficial = 'Site oficial';
  static const motoresDescricao =
      'O PDF Enxuto funciona sem instalar nada. Estes programas, se '
      'estiverem no sistema, são usados para obter resultados ainda melhores.';
  static const motorInstalado = 'Instalado';
  static const motorNaoEncontrado = 'Não encontrado';
  static const comoInstalar = 'Como instalar';
  static const copiarComando = 'Copiar comando';
  static const comandoCopiado = 'Comando copiado para a área de transferência';
  static const instalacaoTitulo = 'Como instalar o %s';
  static const instalacaoExplicacao =
      'O PDF Enxuto funciona sem instalar nada — o motor nativo já vem junto. '
      'Estes programas são opcionais: instale apenas se quiser resultados '
      'ainda melhores.';
  static const instalacaoSemPermissao =
      'Precisa de senha de administrador: o app não instala nada sozinho.';
  static const motorEmUso = 'Em uso agora';
  static const usarEsteMotor = 'Usar este motor';
  static const motorIndisponivelAviso = 'não instalado';
  static const revalidarMotores = 'Procurar novamente';
  static const parar = 'Parar';
  static const sobre = 'Sobre';
  static const versao = 'Versão';
  static const codigoFonte = 'Código-fonte';
  static const relatarBug = 'Relatar um problema';
  static const solicitarRecurso = 'Solicitar um recurso';
  static const relatarTitulo = 'Falar com o desenvolvedor';
  static const relatarSubtitulo =
      'Conte o que aconteceu ou o que você gostaria que existisse. A mensagem '
      'vai direto para o e-mail do desenvolvedor.';
  static const relatarProblemaAba = 'Problema';
  static const relatarRecursoAba = 'Ideia de recurso';
  static const relatarDescricaoProblema = 'Descreva o problema';
  static const relatarDescricaoRecurso = 'Descreva a ideia';
  static const relatarDicaProblema =
      'Conte o que você fez, o que esperava e o que aconteceu. Se puder, diga '
      'qual arquivo (tipo e tamanho) e qual motor estava em uso.';
  static const relatarDicaRecurso =
      'Explique para que você usaria o recurso e como ele deveria se comportar.';
  static const relatarAnexarInfo = 'Incluir versão do app e do sistema';
  static const relatarEnviar = 'Abrir meu e-mail';
  static const relatarCopiar = 'Copiar mensagem';
  static const relatarCopiado =
      'Mensagem copiada. Envie para vandreapps@gmail.com';
  static const relatarSemCliente =
      'Não encontrei um programa de e-mail configurado. Copiei a mensagem: '
      'envie para vandreapps@gmail.com';
  static const relatarVazio = 'Escreva uma mensagem antes de enviar';
  static const relatarObrigado =
      'Obrigado! Seu retorno ajuda o projeto a melhorar.';
  static const abrirNoGitHub = 'Abrir no GitHub';
  static const relatarViaGitHub = 'Prefere o GitHub? Abra uma issue';
  static const verNovidades = 'Ver novidades';
  static const licenca = 'Licença';
  static const feitoCom =
      'Feito com Flutter. Sem nuvem, sem contas, sem espiar.';
  static const privacidade = 'Privacidade';
  static const privacidadeTexto =
      'Nenhum documento é enviado para lugar nenhum. A única conexão de rede '
      'que o app faz é a consulta de versão no GitHub (e apenas se você deixar).';

  // ---------------------------------------------------------- Atualizações
  static const atualizacaoDisponivel = 'Nova versão disponível';
  static const atualizacaoBaixar = 'Baixar atualização';
  static const atualizacaoDepois = 'Depois';
  static const atualizacaoIgnorar = 'Não avisar sobre esta versão';
  static const atualizacaoAtualizado = 'Você já está na versão mais recente';
  static const atualizacaoErro =
      'Não foi possível verificar agora. Verifique sua conexão.';
  static const atualizacaoNotas = 'O que mudou';
  static const atualizacaoBannerTitulo = 'Versão %s disponível';
  static const atualizacaoBannerAcao = 'Ver novidades';

  // ---------------------------------------------------------------- Erros
  static const erroGenerico = 'Algo deu errado';
  static const erroEscrita = 'Não foi possível gravar o arquivo de saída';
  static const erroPermissao = 'Sem permissão para escrever nesta pasta';
  static const erroSemEspaco = 'Espaço em disco insuficiente';
  static const erroMotorFalhou = 'O motor de compressão falhou';
  static const erroCancelado = 'Operação cancelada';
  static const erroNaoReduziu =
      'O arquivo resultante ficou maior que o original, então mantivemos o original.';
  static const concluidoComErros = 'Concluído com falhas';
  static const resultadoMaior =
      'Este PDF já estava otimizado: não foi possível reduzi-lo.';
}

/// Textos de ajuda exibidos nos botões "?". Cada um explica o método, quando
/// usar e o que ele custa — sem jargão.
class Ajuda {
  Ajuda._();

  static const nivelCompressao =
      'O nível define o quanto o app pode "apertar" o arquivo.\n\n'
      '• Leve: quase não se nota diferença. Ideal para PDFs que serão impressos.\n'
      '• Equilibrado: bom para enviar por e-mail e ler na tela.\n'
      '• Forte: reduz bastante; textos pequenos podem ficar um pouco borrados.\n'
      '• Extremo: o menor arquivo possível; use quando o tamanho importa mais que a nitidez.\n\n'
      'Todos os níveis preservam o texto selecionável quando o motor escolhido consegue fazer isso.';

  static const modoCompressao =
      'Escolha como quer decidir a compressão. São dois caminhos separados, '
      'para não misturar as coisas:\n\n'
      '• Por perfil de qualidade: você escolhe Leve, Equilibrado, Forte ou '
      'Extremo e o app comprime uma vez, exatamente naquela qualidade. Bom '
      'quando você quer previsibilidade e não liga para o tamanho exato.\n\n'
      '• Por tamanho alvo: você diz o tamanho que precisa (por arquivo ou '
      'somando todos) e o app procura a melhor qualidade que caiba, descendo '
      'resolução e JPEG até atingir — sem passar do piso de qualidade. Bom '
      'quando o tamanho é o que importa, como anexo de e-mail.\n\n'
      'Nenhum dos dois modos mexe no conteúdo além do que você permitir nas '
      'opções avançadas.';

  static const presetsExplicacao =
      'Os perfis definem a qualidade da compressão.\n\n'
      'Sem tamanho alvo: o app usa exatamente o perfil escolhido, uma vez só.\n\n'
      'Com tamanho alvo: o perfil passa a ser o ponto de partida (a melhor '
      'qualidade que o app vai tentar) e ele desce a partir dali — resolução e '
      'JPEG — até caber no tamanho pedido, sem passar do piso de qualidade.\n\n'
      'Exemplo: perfil Equilibrado (150 dpi, JPEG 82) com alvo de 5 MB. O app '
      'tenta 150 dpi; se não couber, tenta 130, 115, 100… até caber ou até o '
      'piso. Ou seja: o perfil continua importando — ele decide onde a busca '
      'começa e quanto ela pode descer.';

  static const tamanhoAlvo =
      'Em vez de escolher um nível "no escuro", você diz o tamanho que precisa '
      '(por exemplo, 5 MB) e o app testa combinações de qualidade até caber.\n\n'
      '• Ele começa pela melhor qualidade e vai descendo até atingir o alvo.\n'
      '• Respeita a "qualidade mínima": se não for possível caber sem destruir '
      'o arquivo, ele entrega o menor resultado possível e avisa você.\n'
      '• Com vários arquivos você pode definir um alvo por arquivo ou um alvo '
      'para o conjunto inteiro (o app divide a "cota" entre eles).\n\n'
      'Dica: o alvo é uma meta, não uma promessa. PDFs que são apenas texto já '
      'nascem pequenos e podem não reduzir mais.';

  static const modoTexto =
      'Define o que acontece com o texto do documento.\n\n'
      '• Manter texto selecionável: o texto continua podendo ser selecionado, '
      'copiado e pesquisado (Ctrl+F). O app recomprime imagens e limpa a '
      'estrutura interna. É a opção certa para documentos, contratos e apostilas.\n'
      '• Máxima redução (vira imagem): cada página é redesenhada como uma '
      'imagem JPEG. O arquivo fica bem menor, mas o texto deixa de ser '
      'selecionável e a busca interna não encontra mais nada.\n\n'
      'Escolha "vira imagem" apenas para digitalizações e apresentações, onde o '
      'que importa é o visual.';

  static const motor =
      'O app tem mais de um "motor" para fazer o serviço. Ele escolhe sozinho o '
      'melhor disponível, mas você pode forçar um deles.\n\n'
      '• Automático: usa o melhor motor instalado para o modo escolhido.\n'
      '• Nativo (embutido): já vem dentro do app, não precisa instalar nada. '
      'Reduz bem digitalizações, mas no modo "manter texto" só limpa a '
      'estrutura (ganho pequeno).\n'
      '• Ghostscript: motor profissional, excelente em qualquer tipo de PDF e '
      'mantém o texto. Precisa estar instalado no sistema (o app mostra como).\n'
      '• qpdf (sem perdas): reorganiza o arquivo sem tocar no conteúdo. O ganho '
      'é pequeno, porém 100% sem perdas e muito rápido.\n\n'
      'Nenhum motor envia nada pela internet: todos rodam na sua máquina.';

  static const resolucao =
      'Quantos pontos por polegada (DPI) as imagens terão depois de comprimidas.\n\n'
      '• 72 dpi: leitura em tela. Arquivos bem pequenos.\n'
      '• 150 dpi: bom equilíbrio para leitura e impressão simples.\n'
      '• 300 dpi: qualidade de impressão. Reduz menos.\n\n'
      'Imagens nunca são aumentadas: se o PDF já tem 100 dpi, pedir 300 dpi não '
      'melhora nada (e não aumenta o arquivo).';

  static const qualidadeJpeg =
      'Controla o quanto as imagens são comprimidas no formato JPEG.\n\n'
      '• 90–100: praticamente sem perda visível.\n'
      '• 75–85: ótimo para fotos e digitalizações comuns.\n'
      '• 50–70: aparecem artefatos ao redor de letras; use só quando precisar.\n\n'
      'Este ajuste só afeta imagens; textos e vetores continuam nítidos.';

  static const corImagens =
      'Define a cor das imagens do documento.\n\n'
      '• Manter original: nada muda.\n'
      '• Tons de cinza: remove a cor. Reduz bem em fotos coloridas.\n'
      '• Preto e branco: converte para 1 bit por pixel. É o que mais reduz, '
      'ideal para documentos digitalizados só com texto.';

  static const removerMetadados =
      'Metadados são informações escondidas no arquivo: autor, empresa, '
      'programa que gerou, datas e até histórico de edição.\n\n'
      'Removê-los deixa o arquivo menor e mais privado. Alguns visualizadores '
      'deixam de mostrar o título e o autor no cabeçalho — nada que afete o conteúdo.';

  static const removerMarcadores =
      'Marcadores (bookmarks) são o "sumário" clicável que aparece na lateral '
      'de alguns leitores.\n\n'
      'Removê-los economiza um pouco de espaço. Se o PDF é um manual ou um livro, '
      'talvez você queira mantê-los.';

  static const removerAnotacoes =
      'Remove comentários, destaques, carimbos, campos de formulário e '
      'assinaturas digitais visíveis.\n\n'
      'Atenção: se o documento tem um formulário que precisa ser preenchido '
      'depois, não use esta opção.';

  static const otimizarEstrutura =
      'Reescreve a estrutura interna do PDF: junta objetos repetidos, remove '
      'sobras de edições antigas e recomprime os fluxos de dados.\n\n'
      'É uma otimização sem perdas: o conteúdo fica idêntico, apenas mais '
      'organizado. O ganho costuma ser pequeno em PDFs modernos e maior em '
      'arquivos antigos ou gerados por vários programas diferentes.';

  static const divisaoMetodo =
      'Escolha como o PDF será cortado. Todos os métodos trabalham com a ordem '
      'real das páginas (1 = primeira).\n\n'
      '• Por intervalos: você escreve os pedaços, por exemplo "1-3, 7, 10-12" → '
      'três arquivos.\n'
      '• A cada N páginas: partes iguais e automáticas.\n'
      '• Por tamanho máximo: o app corta para que nenhuma parte passe do limite; '
      'útil para anexos de e-mail.\n'
      '• Extrair páginas: junta as páginas escolhidas em um único arquivo novo.\n'
      '• Por marcadores: usa o sumário do próprio PDF como divisão (um arquivo '
      'por capítulo).';

  static const intervalos =
      'Escreva os intervalos separados por vírgula. Cada intervalo vira um arquivo.\n\n'
      'Exemplos:\n'
      '• 1-3, 7, 10-12 → 3 arquivos (páginas 1 a 3, página 7 e páginas 10 a 12)\n'
      '• 5 → um arquivo só com a página 5\n'
      '• 1- → da primeira até a última\n'
      '• -4 → da primeira até a quarta\n\n'
      'As páginas fora dos intervalos simplesmente não entram em nenhuma parte.';

  static const tamanhoMaximo =
      'O app corta o documento em partes que caibam no limite informado.\n\n'
      'Como o tamanho final depende do conteúdo de cada página, a divisão é '
      'feita por páginas inteiras: uma parte pode ficar menor que o limite, mas '
      'nunca maior (a não ser que uma única página já ultrapasse o limite).';

  static const nomePadrao =
      'Monte o nome dos arquivos de saída usando variáveis:\n\n'
      '• {nome} — nome do arquivo original\n'
      '• {parte} — número da parte (1, 2, 3…)\n'
      '• {inicio} — primeira página da parte\n'
      '• {fim} — última página da parte\n'
      '• {paginas} — quantidade de páginas da parte\n\n'
      'Exemplo: "{nome} - parte {parte} ({inicio}-{fim})" gera '
      '"contrato - parte 2 (11-20).pdf".';

  static const marcadores =
      'Usa o sumário (bookmarks) gravado dentro do PDF para decidir os cortes.\n\n'
      'É o método mais confortável em livros, apostilas e relatórios longos: '
      'cada capítulo vira um arquivo. Se o PDF não tiver sumário, use outro método.';

  static const previsao =
      'A previsão é calculada antes de processar, olhando o número de páginas e '
      'o tamanho do arquivo. Ela serve para você conferir se a divisão faz '
      'sentido — o tamanho real de cada parte só é conhecido depois de gerar.';

  static const simulacao =
      'A simulação comprime só a primeira página para estimar o resultado '
      'final. Ela é rápida e ajuda a comparar níveis, mas páginas com muitas '
      'fotos pesam mais que a média: o número final pode variar.';

  static const paralelismo =
      'Quantos arquivos são processados ao mesmo tempo.\n\n'
      'Valores altos aceleram muitas tarefas pequenas, mas competem por memória '
      'e processador. Em máquinas com 4 núcleos ou menos, deixe em 2.';

  static const autoUpdate =
      'O app pergunta ao GitHub qual é a última versão publicada e, se houver '
      'algo novo, mostra um aviso com o que mudou e um botão para baixar.\n\n'
      'Nada é baixado nem instalado sem você mandar, e os seus documentos nunca '
      'são enviados. Desligue esta opção se preferir 100% offline.';

  static const privacidade =
      'O PDF Enxuto não tem servidor. Seus PDFs são lidos e gravados apenas no '
      'seu computador.\n\n'
      'A única conexão de rede é a consulta de versão no GitHub (pode ser '
      'desligada nas configurações) e os links que você abrir manualmente.';

  static const tituloJanela =
      'O PDF Enxuto usa uma barra própria no topo da janela. Arraste por ela '
      'para mover a janela, clique duas vezes para maximizar e use os botões à '
      'direita para minimizar, maximizar e fechar.\n\n'
      'Fechar por aqui passa pelo app: se houver uma tarefa em andamento, '
      'ele avisa antes de sair.';

  static const motores =
      'Motores são programas que fazem o trabalho pesado. O app já traz um '
      'motor próprio embutido (nativo), então funciona sem instalar nada.\n\n'
      'Se o Ghostscript ou o qpdf estiverem instalados no sistema, o app passa a '
      'usá-los quando isso trouxer vantagem — é só instalar e clicar em '
      '"Procurar novamente".';

  // ------------------------------------------------------------- Planilha
  static const planilhaModo =
      'Um PDF não guarda tabelas: guarda pedaços de texto, cada um com uma '
      'posição na página. Converter em planilha é descobrir, por essas '
      'posições, o que era linha e o que era coluna.\n\n'
      '• Detectar tabelas: o app procura os blocos em que várias linhas têm '
      'colunas alinhadas e reconstrói a grade. É o modo certo para extratos, '
      'notas fiscais, relatórios, listagens e declarações.\n'
      '• Texto corrido: cada linha do PDF vira uma linha da planilha, em uma '
      'coluna só. Serve para PDFs que não são tabela (um contrato, uma carta), '
      'quando você só quer o texto em algo editável.\n\n'
      'Confira sempre a prévia: ela mostra as tabelas que o app encontrou nas '
      'primeiras páginas antes de você converter.';

  static const planilhaColunas =
      'Controla o quanto o app separa as colunas.\n\n'
      'Um espaço entre duas palavras pode ser o espaço dentro de uma célula '
      '("VANDRÉ BORBA") ou a fronteira entre duas colunas. Não existe como '
      'saber com certeza — então quem decide é você:\n\n'
      '• Menos colunas: só separa quando o vão é grande. Use quando o app está '
      'cortando no meio do que era uma célula só.\n'
      '• Equilibrado: o padrão. Funciona bem na maioria dos extratos e '
      'listagens.\n'
      '• Mais colunas: separa mais, inclusive colunas de números alinhados à '
      'direita (débito, crédito, saldo). Use quando o app está deixando duas '
      'colunas grudadas.\n\n'
      'Cada tabela tem o seu jeito: mude a opção e olhe a prévia, que muda na '
      'hora.\n\n'
      'Limite honesto: colunas de números muito próximas, alinhadas à direita '
      '(débito, crédito e saldo, por exemplo), às vezes saem juntas na mesma '
      'célula. Nesse caso tente "Mais colunas" — e, se ainda assim não '
      'separar, separe na própria planilha, ou exporte em CSV e ajuste onde '
      'for usar.';

  static const planilhaEscopo =
      'Como as tabelas viram abas (ou arquivos).\n\n'
      '• Uma aba por tabela: cada tabela detectada vira uma aba própria. É o '
      'mais fiel ao documento.\n'
      '• Uma aba por página: tudo o que está na mesma página fica junto.\n'
      '• Tudo junto: o PDF inteiro vira uma aba só, com as tabelas separadas '
      'por uma linha em branco e a página indicada.\n\n'
      'No CSV não existem abas: cada aba vira um arquivo. Se você quer um '
      'único CSV, escolha "Tudo junto".';

  static const planilhaFormato =
      'O que será gravado.\n\n'
      '• Planilha (XLSX): o formato do Excel, aberto também pelo LibreOffice '
      'Calc. Aceita várias abas, prende a primeira linha como título e guarda '
      'números e datas como números e datas de verdade — dá para somar, '
      'ordenar e filtrar. Valores com R\$ viram número (para somar) e continuam '
      'aparecendo com o símbolo.\n'
      '• CSV: texto puro, uma tabela por arquivo, aceito por praticamente '
      'qualquer programa. Aqui tudo é texto.\n\n'
      'Para usar no dia a dia, o XLSX costuma ser melhor. O CSV é o mais '
      'compatível, e sai em UTF-8 com BOM e ponto e vírgula, que é o que o '
      'Excel em português espera.';

  static const planilhaCabecalho =
      'Marca a primeira linha como título das colunas: na planilha ela fica em '
      'negrito e congelada no topo — ao rolar para baixo, os títulos continuam '
      'à vista.\n\n'
      'Desligue quando a primeira linha já for um dado (uma tabela sem '
      'cabeçalho).';

  static const planilhaIgnorarCabecalho =
      'Relatórios costumam repetir o nome da empresa no topo e "Página 3 de '
      '23" no pé de cada página.\n\n'
      'Se a mesma linha aparece na primeira (ou na última) posição da maioria '
      'das páginas, o app entende que aquilo é moldura e tira da planilha. '
      'Números são comparados de forma genérica, então "Página 3 de 23" e '
      '"Página 7 de 23" contam como a mesma linha.\n\n'
      'Desligue se você quiser o documento exatamente como está no PDF.';

  static const planilhaProteger =
      'Uma célula que começa com =, +, @ ou uma tabulação pode ser entendida '
      'como fórmula ao abrir o arquivo em outro programa — inclusive para '
      'executar comandos na sua máquina.\n\n'
      'Com esta opção ligada, o app marca essas células como texto, e o que '
      'aparece na tela continua igual. Valores negativos ("-1.234,56") e '
      'telefones ("+55") não são estragados: números continuam números.';

  static const planilhaSeparador =
      'Qual caractere separa as colunas do CSV.\n\n'
      '• Ponto e vírgula (;): o padrão do Excel em português, porque a vírgula '
      'já é usada para os centavos. Com vírgula como separador, "1.234,56" '
      'viraria duas colunas.\n'
      '• Vírgula (,): o padrão internacional e o que a maioria dos programas '
      'de planilha e bancos de dados espera.\n\n'
      'Se o arquivo abrir com tudo em uma coluna só, troque esta opção: é '
      'quase sempre isso.';

  static const planilhaDigitalizada =
      'Para virar planilha, o PDF precisa ter texto de verdade. Uma '
      'digitalização (foto ou scanner) é só uma imagem: para ler seria preciso '
      'OCR, e o PDF Enxuto não faz OCR — ele lê o texto que já existe no '
      'arquivo, sem chutar.\n\n'
      'Como saber: abra o PDF e tente selecionar uma palavra com o mouse. Se '
      'não conseguir selecionar nada, é digitalização.\n\n'
      'O caminho, nesse caso, é passar o PDF por um programa de OCR antes de '
      'converter.';
}
