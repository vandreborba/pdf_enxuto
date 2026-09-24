import 'dart:math' as math;

/// Um intervalo de páginas, inclusivo nas duas pontas (1 = primeira página).
class PageRange {
  const PageRange(this.inicio, this.fim);

  final int inicio;
  final int fim;

  int get quantidade => fim - inicio + 1;

  bool contem(int pagina) => pagina >= inicio && pagina <= fim;

  String get rotulo => inicio == fim ? '$inicio' : '$inicio-$fim';

  /// Lista concreta de páginas do intervalo.
  List<int> get paginas => [for (var p = inicio; p <= fim; p++) p];

  @override
  String toString() => rotulo;

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(inicio, fim);
}

/// Resultado da leitura de um campo de intervalos.
class RangeParseResult {
  const RangeParseResult({
    required this.intervalos,
    required this.erros,
    this.aviso,
  });

  final List<PageRange> intervalos;
  final List<String> erros;
  final String? aviso;

  bool get valido => erros.isEmpty && intervalos.isNotEmpty;

  int get totalPaginas =>
      intervalos.fold(0, (soma, intervalo) => soma + intervalo.quantidade);

  static const RangeParseResult vazio =
      RangeParseResult(intervalos: [], erros: []);
}

/// Lê textos como "1-3, 7, 10-12" (e também "1-", "-4", "5").
///
/// [totalPaginas] é usado para validar os limites; quando informado, um
/// intervalo que passa do fim do documento é limitado e vira aviso em vez de
/// erro (mais amigável para quem digitou "1-999" sem saber o total).
class PageRangeParser {
  PageRangeParser._();

  static RangeParseResult parse(String texto, {int? totalPaginas}) {
    final bruto = texto.trim();
    if (bruto.isEmpty) {
      return const RangeParseResult(intervalos: [], erros: []);
    }

    final intervalos = <PageRange>[];
    final erros = <String>[];
    var limitado = false;

    final tokens = bruto
        .split(RegExp(r'[,;]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty);

    for (final token in tokens) {
      final match = RegExp(r'^(\d*)\s*[-–a]\s*(\d*)$').firstMatch(token);
      if (match != null) {
        final inicioTexto = match.group(1)!;
        final fimTexto = match.group(2)!;

        if (inicioTexto.isEmpty && fimTexto.isEmpty) {
          erros.add('"$token" não indica nenhuma página');
          continue;
        }

        final inicio = inicioTexto.isEmpty ? 1 : int.tryParse(inicioTexto);
        final fim =
            fimTexto.isEmpty ? (totalPaginas ?? 1 << 30) : int.tryParse(fimTexto);

        if (inicio == null || fim == null) {
          erros.add('"$token" não é um intervalo válido');
          continue;
        }
        if (inicio < 1) {
          erros.add('A numeração começa em 1 ("$token")');
          continue;
        }
        if (fim < inicio) {
          erros.add('"$token": o fim vem antes do início');
          continue;
        }
        var fimFinal = fim;
        if (totalPaginas != null && fim > totalPaginas) {
          fimFinal = totalPaginas;
          limitado = true;
        }
        if (totalPaginas != null && inicio > totalPaginas) {
          erros.add('A página $inicio não existe (o PDF tem $totalPaginas)');
          continue;
        }
        intervalos.add(PageRange(inicio, fimFinal));
        continue;
      }

      final pagina = int.tryParse(token);
      if (pagina == null) {
        erros.add('"$token" não é um número de página nem um intervalo');
        continue;
      }
      if (pagina < 1) {
        erros.add('A numeração começa em 1 ("$token")');
        continue;
      }
      if (totalPaginas != null && pagina > totalPaginas) {
        erros.add('A página $pagina não existe (o PDF tem $totalPaginas)');
        continue;
      }
      intervalos.add(PageRange(pagina, pagina));
    }

    return RangeParseResult(
      intervalos: intervalos,
      erros: erros,
      aviso: limitado
          ? 'Alguns intervalos passavam do fim do documento e foram ajustados.'
          : null,
    );
  }

  /// Divide em partes iguais de [paginasPorParte] páginas.
  static List<PageRange> cadaNPaginas(int totalPaginas, int paginasPorParte) {
    if (totalPaginas <= 0 || paginasPorParte <= 0) return const [];
    final partes = <PageRange>[];
    for (var inicio = 1; inicio <= totalPaginas; inicio += paginasPorParte) {
      partes.add(
        PageRange(inicio, math.min(inicio + paginasPorParte - 1, totalPaginas)),
      );
    }
    return partes;
  }

  /// Normaliza uma lista de intervalos em texto ("1-3, 7").
  static String formatar(List<PageRange> intervalos) =>
      intervalos.map((i) => i.rotulo).join(', ');

  /// Junta e ordena intervalos sobrepostos ou vizinhos.
  static List<PageRange> normalizar(List<PageRange> intervalos) {
    if (intervalos.isEmpty) return const [];
    final ordenados = [...intervalos]..sort((a, b) => a.inicio.compareTo(b.inicio));
    final resultado = <PageRange>[ordenados.first];
    for (final atual in ordenados.skip(1)) {
      final ultimo = resultado.last;
      if (atual.inicio <= ultimo.fim + 1) {
        resultado[resultado.length - 1] =
            PageRange(ultimo.inicio, math.max(ultimo.fim, atual.fim));
      } else {
        resultado.add(atual);
      }
    }
    return resultado;
  }
}
