import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/services/tabela/detector_tabela.dart';

/// Uma página lida: as palavras com posição e o tamanho da página.
class PaginaLida {
  const PaginaLida({
    required this.numero,
    required this.palavras,
    this.linhasVisuais,
  });

  /// 1 = primeira página.
  final int numero;
  final List<PalavraTexto> palavras;

  /// Agrupamento de [palavras] em linhas visuais, quando já foi calculado
  /// (o removedor de cabeçalho/rodapé faz isso). Evita reagrupar na detecção.
  /// Fica `null` quando as palavras mudaram depois do agrupamento.
  final List<List<PalavraTexto>>? linhasVisuais;
}

/// Resultado da leitura de um PDF inteiro.
class LeituraPdf {
  const LeituraPdf({
    required this.paginas,
    required this.paginasSemTexto,
    required this.cabecalhosIgnorados,
    this.totalPaginas = 0,
  });

  final List<PaginaLida> paginas;

  /// Quantas páginas o documento tem (mesmo que só algumas tenham sido lidas).
  final int totalPaginas;

  /// Quantas páginas parecem digitalização (imagem, sem texto).
  final int paginasSemTexto;

  /// Textos de cabeçalho/rodapé repetidos que foram descartados.
  final List<String> cabecalhosIgnorados;

  bool get soImagem => paginas.isNotEmpty && paginasSemTexto == paginas.length;
}

/// Lê o texto de um PDF com posição, usando o pdfium que já vem no app.
///
/// Nada é enviado para fora: o pdfium roda dentro do próprio programa.
class ExtratorTexto {
  ExtratorTexto._();

  /// Inicialização alternativa usada pelos testes (o app usa a padrão, que
  /// depende dos plugins do Flutter).
  static Future<void> Function()? inicializadorAlternativo;

  static bool _pronto = false;

  /// Teto de palavras por página: um PDF hostil não pode forçar memória nem
  /// processamento sem limite. Muito acima do que uma página real costuma ter.
  static const int maxPalavrasPagina = 20000;

  static Future<void> garantirInicializacao() async {
    if (_pronto) return;
    final alternativo = inicializadorAlternativo;
    if (alternativo != null) {
      await alternativo();
    } else {
      await pdfrxFlutterInitialize();
    }
    _pronto = true;
  }

  /// Lê o texto de todas as páginas (ou só das [paginas] indicadas, 1-based).
  ///
  /// [parar] permite encerrar a leitura cedo: recebe quantas páginas já foram
  /// lidas e quantas tinham texto, e devolve `true` quando não vale continuar.
  static Future<LeituraPdf> ler(
    String caminho, {
    List<int>? paginas,
    void Function(int atual, int total)? progresso,
    Cancelamento? cancelamento,
    bool ignorarCabecalhoRodape = true,
    bool Function(int lidas, int comTexto)? parar,
  }) async {
    await garantirInicializacao();
    cancelamento?.verificar();

    final documento = await PdfDocument.openFile(caminho);
    try {
      final desejadas = paginas == null
          ? [for (var i = 1; i <= documento.pages.length; i++) i]
          : [
              for (final p in paginas)
                if (p >= 1 && p <= documento.pages.length) p,
            ];

      final lidas = <PaginaLida>[];
      var semTexto = 0;
      var comTexto = 0;

      for (var i = 0; i < desejadas.length; i++) {
        cancelamento?.verificar();
        final numero = desejadas[i];
        progresso?.call(i, desejadas.length);

        final pagina = documento.pages[numero - 1];
        final texto = await pagina.loadStructuredText();
        final palavras = palavrasDe(texto);

        if (palavras.isEmpty) {
          semTexto++;
        } else {
          comTexto++;
        }
        lidas.add(PaginaLida(numero: numero, palavras: palavras));
        progresso?.call(i + 1, desejadas.length);
        if (parar != null && parar(lidas.length, comTexto)) break;
      }

      final ignorados = <String>[];
      final paginasFinais = ignorarCabecalhoRodape
          ? RemovedorRepetido.remover(lidas, ignorados)
          : lidas;

      return LeituraPdf(
        paginas: paginasFinais,
        paginasSemTexto: semTexto,
        cabecalhosIgnorados: ignorados,
        totalPaginas: documento.pages.length,
      );
    } finally {
      await documento.dispose();
    }
  }

  /// Monta as palavras de uma página a partir dos fragmentos do pdfium.
  ///
  /// Os fragmentos já vêm agrupados por palavra na enorme maioria dos PDFs.
  /// Quando um fragmento traz espaços dentro, ele é partido em partes na
  /// ordem em que aparecem — o índice do fragmento diz exatamente onde ele
  /// começa, então não há o que procurar.
  ///
  /// Dois cuidados que vêm do próprio pdfium: fragmentos que são só espaço ou
  /// quebra de linha são descartados (não são palavras), e os "espaços" que
  /// ele cria entre colunas vêm limitados a uma fração da altura da linha —
  /// quem mede coluna é o vão entre as palavras, não esses espaços.
  static List<PalavraTexto> palavrasDe(PdfPageText texto) {
    final palavras = <PalavraTexto>[];
    for (final fragmento in texto.fragments) {
      if (palavras.length >= maxPalavrasPagina) break;
      if (fragmento.text.trim().isEmpty) continue;
      final partes = fragmento.text
          .split(RegExp(r'\s+'))
          .where((parte) => parte.isNotEmpty)
          .toList();

      if (partes.length == 1) {
        palavras.add(_palavra(partes.first, fragmento.bounds));
        continue;
      }

      var indice = fragmento.index;
      for (final parte in partes) {
        if (palavras.length >= maxPalavrasPagina) break;
        final inicio = indice;
        final fim = inicio + parte.length;
        final de = (inicio - fragmento.index).clamp(
          0,
          fragmento.charRects.length,
        );
        final ate = (fim - fragmento.index).clamp(
          0,
          fragmento.charRects.length,
        );
        final recortes = de < ate
            ? fragmento.charRects.sublist(de, ate)
            : const <PdfRect>[];
        palavras.add(
          recortes.isEmpty
              ? _palavra(parte, fragmento.bounds)
              : PalavraTexto(
                  texto: parte,
                  esquerda: recortes.map((r) => r.left).reduce(math.min),
                  direita: recortes.map((r) => r.right).reduce(math.max),
                  base: recortes.map((r) => r.bottom).reduce(math.min),
                  topo: recortes.map((r) => r.top).reduce(math.max),
                ),
        );
        indice = fim + 1;
      }
    }
    return palavras;
  }

  static PalavraTexto _palavra(String texto, PdfRect limites) => PalavraTexto(
    texto: texto,
    esquerda: limites.left,
    direita: limites.right,
    base: limites.bottom,
    topo: limites.top,
  );
}

/// Descarta cabeçalhos e rodapés que se repetem em quase todas as páginas.
///
/// Relatórios costumam trazer o nome da empresa no topo e "Página X de Y" no
/// pé. Se a mesma linha aparece na primeira (ou na última) posição da maioria
/// das páginas, ela é moldura, não conteúdo — e sai da planilha. Números são
/// normalizados, então "Página 3 de 23" e "Página 7 de 23" contam como a mesma.
class RemovedorRepetido {
  RemovedorRepetido._();

  static const double fracaoMinima = 0.6;

  static List<PaginaLida> remover(
    List<PaginaLida> paginas,
    List<String> ignorados, {
    double fracao = fracaoMinima,
  }) {
    if (paginas.length < 3) return paginas;

    final linhasPorPagina = [
      for (final pagina in paginas) DetectorTabela.linhasDe(pagina.palavras),
    ];

    final primeiras = <String, int>{};
    final ultimas = <String, int>{};
    for (final linhas in linhasPorPagina) {
      if (linhas.isEmpty) continue;
      _contar(primeiras, _chave(linhas.first));
      _contar(ultimas, _chave(linhas.last));
    }

    final minimo = (paginas.length * fracao).ceil();
    final repetidos = <String>{
      for (final entrada in primeiras.entries)
        if (entrada.value >= minimo && entrada.key.isNotEmpty) entrada.key,
      for (final entrada in ultimas.entries)
        if (entrada.value >= minimo && entrada.key.isNotEmpty) entrada.key,
    };
    // Sem linhas repetidas, nada é removido: o agrupamento já feito pode ser
    // reaproveitado pela detecção em vez de refeito.
    if (repetidos.isEmpty) {
      return [
        for (var i = 0; i < paginas.length; i++)
          _comLinhas(paginas[i], linhasPorPagina[i]),
      ];
    }

    final resultado = <PaginaLida>[];
    for (var i = 0; i < paginas.length; i++) {
      final pagina = paginas[i];
      final linhas = linhasPorPagina[i];
      if (linhas.isEmpty) {
        resultado.add(_comLinhas(pagina, linhas));
        continue;
      }
      final descartar = <PalavraTexto>{};
      for (final linha in [linhas.first, linhas.last]) {
        final chave = _chave(linha);
        if (repetidos.contains(chave)) {
          descartar.addAll(linha);
          if (!ignorados.contains(chave)) ignorados.add(chave);
        }
      }
      if (descartar.isEmpty) {
        resultado.add(_comLinhas(pagina, linhas));
        continue;
      }
      // Só as linhas dos extremos saíram: as do meio seguem válidas, então o
      // agrupamento é reaproveitado em vez de refeito.
      final restantes = [
        for (final linha in linhas)
          if (!linha.any(descartar.contains)) linha,
      ];
      resultado.add(
        PaginaLida(
          numero: pagina.numero,
          palavras: [
            for (final p in pagina.palavras)
              if (!descartar.contains(p)) p,
          ],
          linhasVisuais: restantes,
        ),
      );
    }
    return resultado;
  }

  static PaginaLida _comLinhas(
    PaginaLida pagina,
    List<List<PalavraTexto>> linhas,
  ) => PaginaLida(
    numero: pagina.numero,
    palavras: pagina.palavras,
    linhasVisuais: linhas,
  );

  static void _contar(Map<String, int> mapa, String chave) {
    if (chave.isEmpty) return;
    mapa[chave] = (mapa[chave] ?? 0) + 1;
  }

  /// Texto normalizado: sem números (viram "#") e em minúsculas.
  static String _chave(List<PalavraTexto> linha) => linha
      .map((p) => p.texto)
      .join(' ')
      .replaceAll(RegExp(r'\d+'), '#')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}
