import 'dart:io';

import 'package:pdf_enxuto/core/formatting.dart';

/// Caminhos de saída: nomes bonitos, sem sobrescrever nada por acidente.
class ServicoArquivos {
  ServicoArquivos._();

  /// Sufixo usado nas compressões: "relatorio.pdf" → "relatorio_enxuto.pdf".
  static const String sufixoComprimido = '_enxuto';

  /// Sugere o caminho de saída para a compressão.
  static String caminhoComprimido(
    String entrada,
    String? pastaSaida, {
    String sufixo = sufixoComprimido,
  }) {
    final arquivo = File(entrada);
    final nome = arquivo.uri.pathSegments.last;
    final ponto = nome.lastIndexOf('.');
    final base = ponto > 0 ? nome.substring(0, ponto) : nome;
    final pasta = pastaSaida ?? arquivo.parent.path;
    return '$pasta${Platform.pathSeparator}${Fmt.nomeSeguro('$base$sufixo')}.pdf';
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
    return Fmt.nomeSeguro(nome.trim().isEmpty ? '$nomeBase - parte $parte' : nome);
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
  static String? proximoNomeLivre(String caminho, {required bool sobrescrever}) {
    if (sobrescrever || !File(caminho).existsSync()) return null;

    final pasta = File(caminho).parent.path;
    final nome = File(caminho).uri.pathSegments.last;
    final ponto = nome.lastIndexOf('.');
    final base = ponto > 0 ? nome.substring(0, ponto) : nome;
    final extensao = ponto > 0 ? nome.substring(ponto) : '';

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
