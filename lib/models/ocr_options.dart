import 'package:pdf_enxuto/models/compression_options.dart';

/// Um idioma que o reconhecimento sabe ler.
///
/// Só entram idiomas de alfabeto latino: o PDF pesquisável usa a fonte padrão
/// do PDF, que não tem outros alfabetos.
class IdiomaOcr {
  const IdiomaOcr(this.codigo, this.nome);

  /// Código do Tesseract (nome do arquivo `.traineddata`).
  final String codigo;
  final String nome;

  static const List<IdiomaOcr> todos = [
    IdiomaOcr('por', 'Português'),
    IdiomaOcr('eng', 'Inglês'),
    IdiomaOcr('spa', 'Espanhol'),
    IdiomaOcr('fra', 'Francês'),
    IdiomaOcr('deu', 'Alemão'),
    IdiomaOcr('ita', 'Italiano'),
  ];

  static IdiomaOcr? porCodigo(String codigo) {
    for (final idioma in todos) {
      if (idioma.codigo == codigo) return idioma;
    }
    return null;
  }
}

/// Quanto cuidado o reconhecimento dedica a cada página.
enum QualidadeOcr {
  rapido('Rápido', 150, 'Boa para texto grande e limpo; o mais veloz'),
  equilibrado('Equilibrado', 200, 'Serve para a maioria dos documentos'),
  preciso('Preciso', 300, 'Letra miúda ou digitalização ruim; mais lento');

  const QualidadeOcr(this.rotulo, this.dpi, this.descricao);

  final String rotulo;

  /// Resolução em que a página é desenhada antes de ser lida.
  final int dpi;
  final String descricao;
}

/// Como o programa deve entender o desenho da página (modo de segmentação).
enum TipoPaginaOcr {
  automatico(
    'Automático',
    3,
    'Descobre sozinho colunas, títulos e parágrafos',
  ),
  umaColuna('Uma coluna', 4, 'Texto em uma coluna só, como cartas e laudos'),
  bloco('Bloco único', 6, 'A página é um bloco de texto uniforme'),
  esparso(
    'Texto solto',
    11,
    'Formulários, recibos e tabelas: acha texto em qualquer lugar',
  );

  const TipoPaginaOcr(this.rotulo, this.psm, this.descricao);

  final String rotulo;

  /// Valor de `--psm` do Tesseract.
  final int psm;
  final String descricao;
}

/// Qualidade da imagem que fica dentro do PDF pesquisável.
enum QualidadeImagemOcr {
  leve('Leve', 60, 'Arquivo menor; a imagem perde um pouco de nitidez'),
  equilibrada('Equilibrada', 78, 'Bom meio-termo entre tamanho e nitidez'),
  alta('Alta', 90, 'Mais fiel à página; o arquivo fica maior');

  const QualidadeImagemOcr(this.rotulo, this.jpeg, this.descricao);

  final String rotulo;
  final int jpeg;
  final String descricao;
}

/// Todas as escolhas da tela de reconhecimento de texto, persistíveis.
class OpcoesOcr {
  const OpcoesOcr({
    this.idiomas = const ['por', 'eng'],
    this.qualidade = QualidadeOcr.equilibrado,
    this.tipoPagina = TipoPaginaOcr.automatico,
    this.gerarPdf = true,
    this.gerarTxt = false,
    this.cor = ColorMode.manter,
    this.qualidadeImagem = QualidadeImagemOcr.equilibrada,
    this.paginas = '',
    this.refazerComTexto = false,
  });

  /// Códigos dos idiomas usados juntos (o programa lê todos de uma vez).
  final List<String> idiomas;
  final QualidadeOcr qualidade;
  final TipoPaginaOcr tipoPagina;

  /// Gera o PDF pesquisável.
  final bool gerarPdf;

  /// Gera também um arquivo `.txt` com o texto reconhecido.
  final bool gerarTxt;

  /// Cor da imagem dentro do PDF pesquisável.
  final ColorMode cor;
  final QualidadeImagemOcr qualidadeImagem;

  /// Páginas a reconhecer, no formato "1-3, 7". Vazio = todas.
  final String paginas;

  /// Reconhecer mesmo que o PDF já tenha texto.
  final bool refazerComTexto;

  bool get temSaida => gerarPdf || gerarTxt;

  /// Idiomas no formato do Tesseract: "por+eng".
  String get idiomasTesseract => idiomas.isEmpty ? 'eng' : idiomas.join('+');

  OpcoesOcr copyWith({
    List<String>? idiomas,
    QualidadeOcr? qualidade,
    TipoPaginaOcr? tipoPagina,
    bool? gerarPdf,
    bool? gerarTxt,
    ColorMode? cor,
    QualidadeImagemOcr? qualidadeImagem,
    String? paginas,
    bool? refazerComTexto,
  }) {
    return OpcoesOcr(
      idiomas: idiomas ?? this.idiomas,
      qualidade: qualidade ?? this.qualidade,
      tipoPagina: tipoPagina ?? this.tipoPagina,
      gerarPdf: gerarPdf ?? this.gerarPdf,
      gerarTxt: gerarTxt ?? this.gerarTxt,
      cor: cor ?? this.cor,
      qualidadeImagem: qualidadeImagem ?? this.qualidadeImagem,
      paginas: paginas ?? this.paginas,
      refazerComTexto: refazerComTexto ?? this.refazerComTexto,
    );
  }

  static const OpcoesOcr padrao = OpcoesOcr();

  Map<String, dynamic> toJson() => {
    'idiomas': idiomas,
    'qualidade': qualidade.name,
    'tipoPagina': tipoPagina.name,
    'gerarPdf': gerarPdf,
    'gerarTxt': gerarTxt,
    'cor': cor.name,
    'qualidadeImagem': qualidadeImagem.name,
    'paginas': paginas,
    'refazerComTexto': refazerComTexto,
  };

  factory OpcoesOcr.fromJson(Map<String, dynamic> json) {
    final idiomas = [
      for (final codigo in (json['idiomas'] as List?) ?? const [])
        if (codigo is String && IdiomaOcr.porCodigo(codigo) != null) codigo,
    ];
    final gerarPdf = json['gerarPdf'] as bool? ?? true;
    final gerarTxt = json['gerarTxt'] as bool? ?? false;
    return OpcoesOcr(
      idiomas: idiomas.isEmpty ? padrao.idiomas : idiomas,
      qualidade: QualidadeOcr.values.firstWhere(
        (valor) => valor.name == json['qualidade'],
        orElse: () => QualidadeOcr.equilibrado,
      ),
      tipoPagina: TipoPaginaOcr.values.firstWhere(
        (valor) => valor.name == json['tipoPagina'],
        orElse: () => TipoPaginaOcr.automatico,
      ),
      // Sem nenhuma saída marcada o botão não faria nada.
      gerarPdf: gerarPdf || !gerarTxt,
      gerarTxt: gerarTxt,
      cor: ColorMode.values.firstWhere(
        (valor) => valor.name == json['cor'],
        orElse: () => ColorMode.manter,
      ),
      qualidadeImagem: QualidadeImagemOcr.values.firstWhere(
        (valor) => valor.name == json['qualidadeImagem'],
        orElse: () => QualidadeImagemOcr.equilibrada,
      ),
      paginas: json['paginas'] as String? ?? '',
      refazerComTexto: json['refazerComTexto'] as bool? ?? false,
    );
  }
}
