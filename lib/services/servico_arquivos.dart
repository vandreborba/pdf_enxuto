import 'dart:io';

import 'package:pdf_enxuto/core/formatting.dart';

/// Caminhos de saída: nomes bonitos, sem sobrescrever nada por acidente.
class ServicoArquivos {
  ServicoArquivos._();

  /// Sufixo usado nas compressões: "relatorio.pdf" → "relatorio_enxuto.pdf".
  static const String sufixoComprimido = '_enxuto';

  /// Separa pasta, nome-base (sem extensão) e extensão (com o ponto) de um
  /// caminho. Ponto de verdade: os três usos de nome de arquivo passam aqui.
  static (String pasta, String base, String extensao) _dividirCaminho(
    String caminho,
  ) {
    final arquivo = File(caminho);
    final nome = arquivo.uri.pathSegments.last;
    final ponto = nome.lastIndexOf('.');
    return (
      arquivo.parent.path,
      ponto > 0 ? nome.substring(0, ponto) : nome,
      ponto > 0 ? nome.substring(ponto) : '',
    );
  }

  /// Sugere o caminho de saída para a compressão.
  static String caminhoComprimido(
    String entrada,
    String? pastaSaida, {
    String sufixo = sufixoComprimido,
  }) {
    final (pasta, base, _) = _dividirCaminho(entrada);
    final destino = pastaSaida ?? pasta;
    return '$destino${Platform.pathSeparator}${Fmt.nomeSeguro('$base$sufixo')}.pdf';
  }

  /// Caminho de saída para outro formato (planilha, CSV): troca a extensão e,
  /// se pedido, acrescenta algo ao nome ("extrato - p3.csv").
  static String caminhoSaida(
    String entrada,
    String? pastaSaida,
    String extensao, {
    String? acrescimo,
  }) {
    final (pasta, base, _) = _dividirCaminho(entrada);
    final destino = pastaSaida ?? pasta;
    final completo = acrescimo == null || acrescimo.trim().isEmpty
        ? base
        : '$base - ${acrescimo.trim()}';
    return '$destino${Platform.pathSeparator}${Fmt.nomeSeguro(completo)}.$extensao';
  }

  /// Monta o nome de uma parte a partir do padrão escolhido.
  static String nomeDaParte({
    required String padrao,
    required String nomeBase,
    required int parte,
    required int inicio,
    required int fim,
    required int paginas,
  }) {
    final nome = padrao
        .replaceAll('{nome}', nomeBase)
        .replaceAll('{parte}', '$parte')
        .replaceAll('{inicio}', '$inicio')
        .replaceAll('{fim}', '$fim')
        .replaceAll('{paginas}', '$paginas');
    return Fmt.nomeSeguro(
      nome.trim().isEmpty ? '$nomeBase - parte $parte' : nome,
    );
  }

  /// Exemplo de nome gerado pelo padrão (mostrado na tela de divisão).
  static String exemploNome(String padrao) {
    final exemplo = nomeDaParte(
      padrao: padrao,
      nomeBase: 'relatorio',
      parte: 2,
      inicio: 11,
      fim: 20,
      paginas: 10,
    );
    return '$exemplo.pdf';
  }

  /// Evita sobrescrever: "arquivo.pdf" → "arquivo (1).pdf".
  ///
  /// Devolve `null` quando a sobrescrita está liberada.
  static String? proximoNomeLivre(
    String caminho, {
    required bool sobrescrever,
  }) {
    if (sobrescrever || !File(caminho).existsSync()) return null;

    final (pasta, base, extensao) = _dividirCaminho(caminho);

    for (var i = 1; i < 9999; i++) {
      final tentativa = '$pasta${Platform.pathSeparator}$base ($i)$extensao';
      if (!File(tentativa).existsSync()) return tentativa;
    }
    return '$pasta${Platform.pathSeparator}$base (${DateTime.now().millisecondsSinceEpoch})$extensao';
  }

  /// Caminho final considerando a política de sobrescrita.
  static String caminhoFinal(String caminho, {required bool sobrescrever}) =>
      proximoNomeLivre(caminho, sobrescrever: sobrescrever) ?? caminho;

  /// Nome de arquivo já existente na pasta, para montar a lista de saídas.
  static String pastaDe(String caminho) => File(caminho).parent.path;

  static bool existe(String caminho) => File(caminho).existsSync();

  static int tamanho(String caminho) {
    final arquivo = File(caminho);
    return arquivo.existsSync() ? arquivo.lengthSync() : 0;
  }
}
