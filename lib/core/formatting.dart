import 'dart:math' as math;

/// Formatação de números em português (tamanhos, percentuais, durações,
/// contagens). Centralizado para que o app inteiro fale a mesma língua.
class Fmt {
  Fmt._();

  static const List<String> _unidades = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// 1536 → "1,5 KB"
  static String bytes(int value, {int? decimais}) {
    if (value < 0) value = 0;
    if (value < 1024) return '$value B';

    var tamanho = value.toDouble();
    var unidade = 0;
    while (tamanho >= 1024 && unidade < _unidades.length - 1) {
      tamanho /= 1024;
      unidade++;
    }

    if (decimais != null)
      return '${_numero(tamanho, decimais)} ${_unidades[unidade]}';
    // Até duas casas, sem zeros à direita: "1,5 KB", "5 MB", "12,25 MB".
    final casas = tamanho >= 100 ? 0 : 2;
    return '${_semZeros(_numero(tamanho, casas))} ${_unidades[unidade]}';
  }

  /// 1536 → "1,5 KB"; sem espaço, para espaços apertados.
  static String bytesCompacto(int value) => bytes(value).replaceAll(' ', '');

  /// 0.734 → "73,4%"
  static String percentual(double fracao, {int decimais = 1}) =>
      '${_numero(fracao * 100, decimais)}%';

  /// Redução de a para b: 1000 → 250 devolve "75%".
  static String reducao(int antes, int depois) {
    if (antes <= 0) return '0%';
    final reducao = (antes - depois) / antes;
    if (reducao <= 0) return '0%';
    if (reducao < 0.001) return '<0,1%';
    return percentual(reducao, decimais: reducao >= 0.1 ? 0 : 1);
  }

  /// 950 ms → "950 ms"; 125000 → "2 min 5 s"
  static String duracao(Duration d) {
    final ms = d.inMilliseconds;
    if (ms < 1000) return '$ms ms';
    final segundos = d.inSeconds;
    if (segundos < 60) {
      final resto = ms % 1000;
      return resto >= 100
          ? '${_numero(segundos + resto / 1000, 1)} s'
          : '$segundos s';
    }
    final minutos = segundos ~/ 60;
    final resto = segundos % 60;
    if (minutos < 60) {
      return resto == 0 ? '$minutos min' : '$minutos min $resto s';
    }
    final horas = minutos ~/ 60;
    return '$horas h ${minutos % 60} min';
  }

  /// "há 3 min", "há 2 dias", "12/03/2026" — usado no histórico.
  static String duracaoAtras(DateTime quando) {
    final diferenca = DateTime.now().difference(quando);
    if (diferenca.inSeconds < 60) return 'agora mesmo';
    if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
    if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
    if (diferenca.inDays < 30) return 'há ${diferenca.inDays} dias';
    final dia = quando.day.toString().padLeft(2, '0');
    final mes = quando.month.toString().padLeft(2, '0');
    return '$dia/$mes/${quando.year}';
  }

  /// 1234 → "1.234"; 1234567 → "1,2 mi"
  static String quantidade(int valor) {
    if (valor < 10000) return _milhar(valor);
    if (valor < 1000000) return '${_numero(valor / 1000, 1)} mil';
    return '${_numero(valor / 1000000, 1)} mi';
  }

  static String paginas(int valor) =>
      valor == 1 ? '1 página' : '${_milhar(valor)} páginas';

  static String arquivos(int valor) =>
      valor == 1 ? '1 arquivo' : '${_milhar(valor)} arquivos';

  static String partes(int valor) =>
      valor == 1 ? '1 parte' : '${_milhar(valor)} partes';

  /// Aceita "1.234,5" e "1234.5".
  static String _milhar(int valor) {
    final texto = valor.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return valor < 0 ? '-$buffer' : buffer.toString();
  }

  /// Remove zeros e vírgula sobrando ("1,50" → "1,5"; "5,00" → "5").
  static String _semZeros(String texto) {
    if (!texto.contains(',')) return texto;
    var resultado = texto.replaceFirst(RegExp(r'0+$'), '');
    if (resultado.endsWith(',')) {
      resultado = resultado.substring(0, resultado.length - 1);
    }
    return resultado;
  }

  static String _numero(double valor, int casas) {
    if (!valor.isFinite) return '—';
    final texto = valor.toStringAsFixed(casas);
    return texto.replaceAll('.', ',');
  }

  /// Converte um tamanho digitado pelo usuário ("5", "5mb", "1,5 GB") em bytes.
  /// Devolve `null` quando não dá para entender.
  static int? parseTamanho(String entrada) {
    final limpo = entrada
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (limpo.isEmpty) return null;

    final match = RegExp(
      r'^([0-9]*\.?[0-9]+)(b|kb|k|mb|m|gb|g|tb|t)?$',
    ).firstMatch(limpo);
    if (match == null) return null;

    final valor = double.tryParse(match.group(1)!);
    if (valor == null || valor <= 0) return null;

    final multiplicador = switch (match.group(2) ?? 'mb') {
      'b' => 1,
      'k' || 'kb' => 1024,
      'm' || 'mb' => 1024 * 1024,
      'g' || 'gb' => 1024 * 1024 * 1024,
      't' || 'tb' => 1024 * 1024 * 1024 * 1024,
      _ => 1024 * 1024,
    };

    final bytes = valor * multiplicador;
    if (bytes > 200 * 1024 * 1024 * 1024) return null;
    return math.max(1024, bytes.round());
  }

  /// "1,5 MB" a partir de "1,5" e unidade escolhida no seletor.
  static String tamanhoComUnidade(double valor, String unidade) =>
      '${_numero(valor, valor >= 100 ? 0 : 1)} $unidade';

  /// Último trecho do caminho, encurtado para caber em um aviso.
  static String nomeCurto(String caminho, {int limite = 42}) {
    final partes = caminho.split(RegExp(r'[/\\]'));
    final nome = partes.isEmpty ? caminho : partes.last;
    if (nome.length <= limite) return nome;
    return '…${nome.substring(nome.length - limite)}';
  }

  /// Nome de arquivo seguro (sem separadores nem caracteres proibidos).
  static String nomeSeguro(String nome) {
    final limpo = nome
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cortado = limpo.length > 120 ? limpo.substring(0, 120) : limpo;
    return cortado.isEmpty ? 'arquivo' : cortado;
  }
}
