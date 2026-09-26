/// Como o PDF é lido na conversão para planilha.
enum ModoPlanilha {
  /// Procura tabelas e reconstrói linhas e colunas.
  tabelas(
    'Detectar tabelas',
    'Procura as tabelas do PDF e separa linhas e colunas',
  ),

  /// Cada linha visível do PDF vira uma linha, com uma coluna só.
  texto('Texto corrido', 'Cada linha do PDF vira uma linha, em uma coluna');

  const ModoPlanilha(this.rotulo, this.descricao);

  final String rotulo;
  final String descricao;
}

/// Quanto o detector deve "forçar" a separação de colunas.
///
/// Um vão entre palavras é ambíguo: pode ser o espaço dentro de uma célula
/// ("VANDRÉ BORBA") ou a fronteira entre duas colunas. O usuário decide o
/// quanto separar e confere o resultado na pré-visualização.
enum SensibilidadeColunas {
  /// Junta células: menos colunas, menos risco de separar o que é uma célula.
  menos('Menos colunas', 'Juntar', 1.0),

  /// Equilíbrio entre separar e juntar.
  equilibrada('Equilibrado', 'Equilíbrio', 0.7),

  /// Separa mais: bom para colunas de números alinhados à direita.
  mais('Mais colunas', 'Separar', 0.45);

  const SensibilidadeColunas(this.rotulo, this.rotuloCurto, this.fatorVao);

  final String rotulo;
  final String rotuloCurto;

  /// Vão mínimo para valer como separador, em múltiplos da altura da fonte.
  final double fatorVao;
}

/// O arquivo que será gerado.
enum FormatoPlanilha {
  xlsx(
    'Planilha (XLSX)',
    'Planilha',
    'xlsx',
    'Abre no Excel e no LibreOffice Calc, com abas',
  ),
  csv('CSV', 'CSV', 'csv', 'Texto puro, aceito por qualquer programa');

  const FormatoPlanilha(
    this.rotulo,
    this.rotuloCurto,
    this.extensao,
    this.descricao,
  );

  final String rotulo;
  final String rotuloCurto;
  final String extensao;
  final String descricao;
}

/// Como as tabelas detectadas são distribuídas nas abas (ou nos arquivos).
enum EscopoPlanilha {
  porTabela(
    'Uma aba por tabela',
    'Por tabela',
    'Cada tabela detectada vira uma aba (no CSV, um arquivo)',
  ),
  porPagina(
    'Uma aba por página',
    'Por página',
    'Cada página do PDF vira uma aba',
  ),
  porArquivo('Tudo junto', 'Tudo junto', 'O PDF inteiro vira uma aba só');

  const EscopoPlanilha(this.rotulo, this.rotuloCurto, this.descricao);

  final String rotulo;
  final String rotuloCurto;
  final String descricao;
}

/// Todas as escolhas da tela de conversão, persistíveis.
class OpcoesPlanilha {
  const OpcoesPlanilha({
    this.formato = FormatoPlanilha.xlsx,
    this.modo = ModoPlanilha.tabelas,
    this.sensibilidade = SensibilidadeColunas.equilibrada,
    this.escopo = EscopoPlanilha.porTabela,
    this.primeiraLinhaCabecalho = true,
    this.ignorarCabecalhoRodape = true,
    this.protegerFormulas = true,
    this.separadorPontoVirgula = true,
  });

  final FormatoPlanilha formato;
  final ModoPlanilha modo;
  final SensibilidadeColunas sensibilidade;
  final EscopoPlanilha escopo;

  /// Marca a primeira linha como título de coluna (negrito e congelada).
  final bool primeiraLinhaCabecalho;

  /// Descarta cabeçalho e rodapé que se repetem em quase todas as páginas.
  final bool ignorarCabecalhoRodape;

  /// Neutraliza células que o Excel interpretaria como fórmula.
  final bool protegerFormulas;

  /// `true` = separador `;` (padrão do Excel em português).
  final bool separadorPontoVirgula;

  /// Separador usado no CSV.
  String get separadorCsv => separadorPontoVirgula ? ';' : ',';

  /// Extensão dos arquivos gerados.
  String get extensao => formato.extensao;

  /// Quantas abas cabem num arquivo (o Excel aguenta muitas, mas a lista de
  /// abas deixa de ser útil muito antes disso).
  static const int maxAbas = 200;

  OpcoesPlanilha copyWith({
    FormatoPlanilha? formato,
    ModoPlanilha? modo,
    SensibilidadeColunas? sensibilidade,
    EscopoPlanilha? escopo,
    bool? primeiraLinhaCabecalho,
    bool? ignorarCabecalhoRodape,
    bool? protegerFormulas,
    bool? separadorPontoVirgula,
  }) {
    return OpcoesPlanilha(
      formato: formato ?? this.formato,
      modo: modo ?? this.modo,
      sensibilidade: sensibilidade ?? this.sensibilidade,
      escopo: escopo ?? this.escopo,
      primeiraLinhaCabecalho:
          primeiraLinhaCabecalho ?? this.primeiraLinhaCabecalho,
      ignorarCabecalhoRodape:
          ignorarCabecalhoRodape ?? this.ignorarCabecalhoRodape,
      protegerFormulas: protegerFormulas ?? this.protegerFormulas,
      separadorPontoVirgula:
          separadorPontoVirgula ?? this.separadorPontoVirgula,
    );
  }

  static const OpcoesPlanilha padrao = OpcoesPlanilha();

  Map<String, dynamic> toJson() => {
    'formato': formato.name,
    'modo': modo.name,
    'sensibilidade': sensibilidade.name,
    'escopo': escopo.name,
    'cabecalho': primeiraLinhaCabecalho,
    'ignorarCabecalhoRodape': ignorarCabecalhoRodape,
    'protegerFormulas': protegerFormulas,
    'pontoVirgula': separadorPontoVirgula,
  };

  factory OpcoesPlanilha.fromJson(Map<String, dynamic> json) => OpcoesPlanilha(
    formato: FormatoPlanilha.values.firstWhere(
      (valor) => valor.name == json['formato'],
      orElse: () => FormatoPlanilha.xlsx,
    ),
    modo: ModoPlanilha.values.firstWhere(
      (valor) => valor.name == json['modo'],
      orElse: () => ModoPlanilha.tabelas,
    ),
    sensibilidade: SensibilidadeColunas.values.firstWhere(
      (valor) => valor.name == json['sensibilidade'],
      orElse: () => SensibilidadeColunas.equilibrada,
    ),
    escopo: EscopoPlanilha.values.firstWhere(
      (valor) => valor.name == json['escopo'],
      orElse: () => EscopoPlanilha.porTabela,
    ),
    primeiraLinhaCabecalho: json['cabecalho'] as bool? ?? true,
    ignorarCabecalhoRodape: json['ignorarCabecalhoRodape'] as bool? ?? true,
    protegerFormulas: json['protegerFormulas'] as bool? ?? true,
    separadorPontoVirgula: json['pontoVirgula'] as bool? ?? true,
  );
}
