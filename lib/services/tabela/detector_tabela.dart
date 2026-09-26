import 'dart:math' as math;

import 'package:pdf_enxuto/models/planilha_options.dart';

/// Uma palavra com a sua posição na página, em pontos de PDF (1/72 polegada).
///
/// O eixo Y cresce para cima, como manda o padrão PDF: [base] é o limite
/// inferior e [topo] o superior.
class PalavraTexto {
  const PalavraTexto({
    required this.texto,
    required this.esquerda,
    required this.direita,
    required this.base,
    required this.topo,
  });

  final String texto;
  final double esquerda;
  final double direita;
  final double base;
  final double topo;

  double get altura => topo - base;
  double get centroVertical => (base + topo) / 2;
  double get centroHorizontal => (esquerda + direita) / 2;

  @override
  String toString() => '"$texto" ($esquerda..$direita, $base..$topo)';
}

/// Uma tabela reconstruída a partir de uma página.
class TabelaDetectada {
  const TabelaDetectada({
    required this.pagina,
    required this.linhas,
    this.indiceNaPagina = 1,
  });

  /// Página de origem (1 = primeira).
  final int pagina;

  /// Quando a tabela é a segunda, terceira… da mesma página.
  final int indiceNaPagina;

  /// Linhas × colunas já alinhadas (todas com a mesma quantidade de colunas).
  final List<List<String>> linhas;

  int get colunas => linhas.isEmpty ? 0 : linhas.first.length;

  int get linhasUteis =>
      linhas.where((linha) => linha.any((c) => c.trim().isNotEmpty)).length;

  bool get vazia => linhas.isEmpty || colunas == 0 || linhasUteis == 0;

  /// `true` quando a detecção encontrou mesmo uma tabela.
  ///
  /// Quando nada é encontrado, o detector devolve o texto da página em uma
  /// coluna só, para o usuário não ficar sem nada — e isso não é uma tabela.
  bool get pareceTabela => colunas >= 2 && linhasUteis >= 2;
}

/// Reconstrói tabelas a partir de palavras posicionadas.
///
/// O método é o "stream" (o mesmo usado por pdfplumber e Camelot no modo sem
/// linhas): agrupa palavras em linhas pela vertical, procura os vãos
/// horizontais que se repetem em várias linhas — que são as fronteiras entre
/// colunas — e encaixa cada palavra na coluna correspondente.
///
/// A vantagem de trabalhar com vãos repetidos é que uma palavra solta no meio
/// de uma célula não cria coluna nenhuma: para virar coluna, o vão precisa
/// aparecer na maioria das linhas da região.
class DetectorTabela {
  const DetectorTabela._();

  /// Agrupa as palavras em linhas visuais, da primeira para a última.
  ///
  /// Útil para quem precisa da estrutura de linhas sem montar tabela nenhuma
  /// (o modo "texto corrido" e a limpeza de cabeçalho/rodapé usam isto).
  static List<List<PalavraTexto>> linhasDe(List<PalavraTexto> palavras) {
    if (palavras.isEmpty) return const [];
    return [for (final linha in _agruparEmLinhas(palavras)) linha.palavras];
  }

  /// Detecta as tabelas de uma página.
  ///
  /// [palavras] são todas as palavras da página, em qualquer ordem. [linhas]
  /// permite reaproveitar o agrupamento já feito (por exemplo, pelo removedor
  /// de cabeçalho/rodapé) em vez de agrupar as mesmas palavras de novo.
  static List<TabelaDetectada> detectar(
    List<PalavraTexto> palavras, {
    SensibilidadeColunas sensibilidade = SensibilidadeColunas.equilibrada,
    ModoPlanilha modo = ModoPlanilha.tabelas,
    int pagina = 1,
    List<List<PalavraTexto>>? linhas,
  }) {
    if (palavras.isEmpty) return const [];

    final linhasVisuais = linhas == null
        ? _agruparEmLinhas(palavras)
        : [for (final linha in linhas) _Linha(linha)];
    if (linhasVisuais.isEmpty) return const [];

    if (modo == ModoPlanilha.texto) {
      return [_tabelaDeTexto(linhasVisuais, pagina)];
    }

    final mediana = _medianaAltura(palavras);
    final vaoMinimo = math.max(sensibilidade.fatorVao * mediana, 1.5);

    // Linhas com pelo menos dois blocos separados: candidatas a linha de tabela.
    final candidatas = <int>[];
    for (var i = 0; i < linhasVisuais.length; i++) {
      if (_temVao(linhasVisuais[i], vaoMinimo)) candidatas.add(i);
    }
    if (candidatas.isEmpty) {
      // Nenhuma tabela: devolve o texto como uma coluna, para o usuário não
      // ficar sem nada (é o que um leitor humano faria).
      return [_tabelaDeTexto(linhasVisuais, pagina)];
    }

    // Regiões: sequências de linhas candidatas. Uma linha sozinha não é tabela.
    final tabelas = <TabelaDetectada>[];
    var inicio = 0;
    while (inicio < candidatas.length) {
      var fim = inicio;
      // Uma linha "solta" no meio (a segunda linha de uma célula que quebrou)
      // não interrompe a tabela — ela entra na região e depois é colada na
      // linha de cima. Só uma linha assim, e só quando ela tem cara de
      // continuação de célula.
      while (fim + 1 < candidatas.length) {
        final salto = candidatas[fim + 1] - candidatas[fim];
        if (salto == 1) {
          fim++;
          continue;
        }
        if (salto == 2 &&
            _pareceContinuacao(
              linhasVisuais[candidatas[fim] + 1],
              linhasVisuais[candidatas[fim]],
            )) {
          fim++;
          continue;
        }
        break;
      }
      final regiao = [
        for (var i = candidatas[inicio]; i <= candidatas[fim]; i++)
          linhasVisuais[i],
      ];
      if (regiao.length >= 2) {
        final tabela = _montarTabela(
          regiao,
          pagina: pagina,
          indiceNaPagina: tabelas.length + 1,
          vaoMinimo: vaoMinimo,
        );
        if (!tabela.vazia) tabelas.add(tabela);
      }
      inicio = fim + 1;
    }

    if (tabelas.isEmpty) return [_tabelaDeTexto(linhasVisuais, pagina)];
    return tabelas;
  }

  /// Máximo de colunas: planilhas ficam ilegíveis muito antes disso, e o
  /// XLSX tem limites próprios.
  static const int maxColunas = 256;
  static const int maxLinhas = 100000;

  // ------------------------------------------------------------------ linhas
  static List<_Linha> _agruparEmLinhas(List<PalavraTexto> palavras) {
    final mediana = _medianaAltura(palavras);
    final ordenadas = [...palavras]
      ..sort((a, b) => b.centroVertical.compareTo(a.centroVertical));
    final linhas = <_Linha>[];

    for (final palavra in ordenadas) {
      if (linhas.isEmpty) {
        linhas.add(_Linha([palavra]));
        continue;
      }
      final atual = linhas.last;
      if (atual.aceita(palavra, mediana)) {
        atual.adicionar(palavra);
      } else {
        linhas.add(_Linha([palavra]));
      }
    }
    // Ordena uma vez por linha: `adicionar` só acrescenta.
    for (final linha in linhas) {
      linha.palavras.sort((a, b) => a.esquerda.compareTo(b.esquerda));
    }
    return linhas;
  }

  static double _medianaAltura(List<PalavraTexto> palavras) {
    if (palavras.isEmpty) return 10;
    final alturas = [for (final p in palavras) p.altura]..sort();
    final mediana = alturas[alturas.length ~/ 2];
    return mediana.isFinite && mediana > 0 ? mediana : 10;
  }

  /// A linha [solta] parece a continuação de uma célula da linha [acima]?
  ///
  /// Vale como continuação quando é curta (poucas palavras) e cabe dentro da
  /// largura da linha de cima. Um parágrafo no meio de duas tabelas costuma
  /// ser largo e cheio de palavras: esse não passa.
  static bool _pareceContinuacao(_Linha solta, _Linha acima) {
    if (solta.palavras.length > maxPalavrasPonte) return false;
    const tolerancia = 2.0;
    return solta.esquerda >= acima.esquerda - tolerancia &&
        solta.direita <= acima.direita + tolerancia;
  }

  /// Quantas palavras uma linha solta pode ter para ser tratada como
  /// continuação da linha de cima.
  static const int maxPalavrasPonte = 12;

  static bool _temVao(_Linha linha, double vaoMinimo) {
    for (var i = 1; i < linha.palavras.length; i++) {
      if (linha.palavras[i].esquerda - linha.palavras[i - 1].direita >=
          vaoMinimo) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------------ colunas
  static TabelaDetectada _montarTabela(
    List<_Linha> regiao, {
    required int pagina,
    required int indiceNaPagina,
    required double vaoMinimo,
  }) {
    final limites = _limitesDeColuna(regiao, vaoMinimo);
    final colunas = limites.length + 1;

    // Cada palavra vai para a coluna onde o seu centro cai.
    final porLinha = <List<List<PalavraTexto>>>[];
    for (final linha in regiao) {
      final celulas = List<List<PalavraTexto>>.generate(colunas, (_) => []);
      for (final palavra in linha.palavras) {
        var coluna = 0;
        while (coluna < limites.length &&
            palavra.centroHorizontal > limites[coluna]) {
          coluna++;
        }
        celulas[coluna].add(palavra);
      }
      porLinha.add(celulas);
    }

    final juntas = _juntarContinuacoes(porLinha);

    // Colunas que ficaram vazias na tabela inteira não ajudam ninguém.
    final manter = <int>[];
    for (var c = 0; c < colunas; c++) {
      if (juntas.any((linha) => linha[c].isNotEmpty)) manter.add(c);
    }
    final linhas = <List<String>>[
      for (final linha in juntas)
        if (manter.isNotEmpty)
          [for (final c in manter) _textoDaCelula(linha[c])]
        else
          <String>[],
    ];

    return TabelaDetectada(
      pagina: pagina,
      indiceNaPagina: indiceNaPagina,
      linhas: _cortar(linhas),
    );
  }

  /// Máximo de linhas extras que podem ser coladas na mesma linha da planilha.
  static const int maxContinuacoes = 6;

  /// Junta na linha anterior o texto que é continuação de uma célula.
  ///
  /// Em extratos e notas fiscais é comum o nome do favorecido ou o histórico
  /// ocupar duas ou três linhas dentro da mesma célula. Sem isso, cada pedaço
  /// viraria uma linha solta da planilha.
  ///
  /// A junção só acontece quando todos os sinais apontam para continuação:
  /// a linha tem uma única célula preenchida, essa célula não é a primeira
  /// coluna, a linha de cima existe e já tem texto naquela mesma coluna, e as
  /// duas estão encostadas na vertical.
  static List<List<List<PalavraTexto>>> _juntarContinuacoes(
    List<List<List<PalavraTexto>>> porLinha,
  ) {
    final resultado = <List<List<PalavraTexto>>>[];
    var seguidas = 0;

    for (final linha in porLinha) {
      final preenchidas = [
        for (var c = 0; c < linha.length; c++)
          if (linha[c].isNotEmpty) c,
      ];

      final podeJuntar =
          preenchidas.length == 1 &&
          preenchidas.first > 0 &&
          resultado.isNotEmpty &&
          _preenchidas(resultado.last) >= 2 &&
          resultado.last[preenchidas.first].isNotEmpty &&
          _encostada(resultado.last, linha);

      if (podeJuntar && seguidas < maxContinuacoes) {
        resultado.last[preenchidas.first].addAll(linha[preenchidas.first]);
        seguidas++;
        continue;
      }

      resultado.add([
        for (final celula in linha) [...celula],
      ]);
      seguidas = 0;
    }
    return resultado;
  }

  static int _preenchidas(List<List<PalavraTexto>> linha) =>
      linha.where((celula) => celula.isNotEmpty).length;

  /// A linha de baixo está logo abaixo da de cima (mesmo bloco de texto)?
  static bool _encostada(
    List<List<PalavraTexto>> acima,
    List<List<PalavraTexto>> abaixo,
  ) {
    final deCima = [for (final celula in acima) ...celula];
    final deBaixo = [for (final celula in abaixo) ...celula];
    if (deCima.isEmpty || deBaixo.isEmpty) return false;

    final baseDeCima = deCima.map((p) => p.base).reduce(math.min);
    final topoDeBaixo = deBaixo.map((p) => p.topo).reduce(math.max);
    final altura = deCima.map((p) => p.altura).reduce((a, b) => a > b ? a : b);
    final vao = baseDeCima - topoDeBaixo;
    // Vão pequeno (ou até uma leve sobreposição) = mesma célula quebrada.
    return vao <= 0.9 * altura;
  }

  /// Junta as palavras de uma célula sem estragar números.
  ///
  /// "1.234" + ",56" ou "R$" + "1.234,56" são um valor só: separar com espaço
  /// transformaria o número em texto quebrado.
  static String _textoDaCelula(List<PalavraTexto> palavras) {
    final buffer = StringBuffer();
    String? anterior;
    for (final palavra in palavras) {
      final atual = palavra.texto.trim();
      if (atual.isEmpty) continue;
      if (anterior != null && !_continuaNumero(anterior, atual)) {
        buffer.write(' ');
      }
      buffer.write(atual);
      anterior = atual;
    }
    return buffer.toString();
  }

  static final RegExp _comecaComSeparador = RegExp(r'^[,.]\d');
  static final RegExp _terminaComSeparador = RegExp(r'[,.]$');
  static final RegExp _terminaComSimbolo = RegExp(r'(R\$|US\$|€)\s*$');
  static final RegExp _comecaComValor = RegExp(r'^-?\d');

  static bool _continuaNumero(String anterior, String seguinte) {
    if (_terminaComSimbolo.hasMatch(anterior)) return true;
    if (!_comecaComValor.hasMatch(seguinte) &&
        !_comecaComSeparador.hasMatch(seguinte)) {
      return false;
    }
    if (_terminaComSeparador.hasMatch(anterior)) return true;
    return _comecaComSeparador.hasMatch(seguinte) &&
        RegExp(r'\d$').hasMatch(anterior);
  }

  /// Fronteiras de coluna: pontos X onde a maioria das linhas tem um vão.
  ///
  /// A contagem é feita em faixas de 1 ponto: uma faixa recebe um voto de cada
  /// linha em que nenhuma palavra a ocupa, ou seja, onde existe espaço em
  /// branco. Um X só vira separador se ficar em branco na maioria das linhas
  /// da região e se o corredor tiver largura de um espaço de verdade — é isso
  /// que impede que o espaço entre duas palavras da mesma célula vire coluna.
  static List<double> _limitesDeColuna(
    List<_Linha> regiao,
    double vaoMinimo, {
    double fracaoSuporte = 0.45,
  }) {
    if (regiao.length < 2) return const [];

    var minimo = double.infinity;
    var maximo = -double.infinity;
    for (final linha in regiao) {
      for (final palavra in linha.palavras) {
        if (palavra.esquerda < minimo) minimo = palavra.esquerda;
        if (palavra.direita > maximo) maximo = palavra.direita;
      }
    }
    if (!minimo.isFinite || maximo <= minimo) return const [];

    // O passo cresce junto com a largura para o número de faixas nunca
    // explodir com coordenadas fora do normal (PDF malformado ou hostil).
    const maxFaixas = 20000;
    final passo = math.max(1.0, (maximo - minimo) / maxFaixas);
    final faixas = ((maximo - minimo) / passo).ceil() + 1;
    final suporte = List<int>.filled(faixas, 0);

    for (final linha in regiao) {
      final coberto = List<bool>.filled(faixas, false);
      for (final palavra in linha.palavras) {
        final primeira = ((palavra.esquerda - minimo) / passo).floor().clamp(
          0,
          faixas - 1,
        );
        final ultima = ((palavra.direita - minimo) / passo).ceil().clamp(
          0,
          faixas - 1,
        );
        for (var f = primeira; f <= ultima; f++) {
          coberto[f] = true;
        }
      }
      for (var f = 0; f < faixas; f++) {
        if (!coberto[f]) suporte[f]++;
      }
    }

    final minimoSuporte = math.max(2, (regiao.length * fracaoSuporte).ceil());
    final larguraMinima = math.max(1.5, vaoMinimo * 0.5);
    final brutos = <double>[];
    var inicio = -1;
    for (var f = 0; f <= faixas; f++) {
      final ativo = f < faixas && suporte[f] >= minimoSuporte;
      if (ativo && inicio < 0) {
        inicio = f;
      } else if (!ativo && inicio >= 0) {
        if ((f - inicio) * passo >= larguraMinima) {
          brutos.add(minimo + (inicio + (f - inicio) / 2) * passo);
        }
        inicio = -1;
      }
    }

    // Separações muito próximas são a mesma coluna.
    final limpos = <double>[];
    for (final corte in brutos) {
      if (limpos.isEmpty || corte - limpos.last > vaoMinimo * 0.8) {
        limpos.add(corte);
      } else {
        limpos[limpos.length - 1] = (limpos.last + corte) / 2;
      }
    }
    if (limpos.length > maxColunas - 1) {
      return limpos.sublist(0, maxColunas - 1);
    }
    return limpos;
  }

  // ------------------------------------------------------------ texto corrido
  static TabelaDetectada _tabelaDeTexto(List<_Linha> linhas, int pagina) {
    final recortadas = <List<String>>[
      for (final linha in linhas.take(maxLinhas)) [linha.texto],
    ];
    return TabelaDetectada(pagina: pagina, linhas: recortadas);
  }

  static List<List<String>> _cortar(List<List<String>> linhas) =>
      linhas.length <= maxLinhas ? linhas : linhas.sublist(0, maxLinhas);
}
/// Uma linha de texto da página: palavras agrupadas pela posição vertical.
class _Linha {
  _Linha(this.palavras) {
    for (final palavra in palavras) {
      _acrescentarMedidas(palavra);
    }
  }

  final List<PalavraTexto> palavras;

  // Medidas mantidas de forma incremental: sem varrer a linha a cada palavra.
  double _somaCentro = 0;
  double _altura = 0;
  double _maxTopo = double.negativeInfinity;
  double _minBase = double.infinity;

  void _acrescentarMedidas(PalavraTexto palavra) {
    _somaCentro += palavra.centroVertical;
    if (palavra.altura > _altura) _altura = palavra.altura;
    if (palavra.topo > _maxTopo) _maxTopo = palavra.topo;
    if (palavra.base < _minBase) _minBase = palavra.base;
  }

  double get centroVertical =>
      palavras.isEmpty ? 0 : _somaCentro / palavras.length;

  double get altura => _altura;

  double get esquerda => palavras.first.esquerda;

  double get direita => palavras.last.direita;

  String get texto => palavras.map((p) => p.texto).join(' ');

  bool aceita(PalavraTexto palavra, double mediana) {
    final tolerancia = 0.42 * mediana;
    if ((palavra.centroVertical - centroVertical).abs() <= tolerancia) {
      return true;
    }
    if (palavras.isEmpty) return false;
    // Sobreposição vertical clara: subscrito, sobrescrito ou fonte maior.
    // A faixa da linha é comparada de uma vez, sem varrer todas as palavras.
    final sobreposicao =
        math.min(_maxTopo, palavra.topo) - math.max(_minBase, palavra.base);
    return sobreposicao > 0.4 * math.min(altura, palavra.altura);
  }

  void adicionar(PalavraTexto palavra) {
    palavras.add(palavra);
    _acrescentarMedidas(palavra);
  }
}
