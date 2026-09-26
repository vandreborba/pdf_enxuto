import 'dart:convert';

import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';

/// O que a tarefa está fazendo.
enum TaskKind {
  comprimir,
  dividir,
  planilha;

  String get rotulo => switch (this) {
    TaskKind.comprimir => 'Compressão',
    TaskKind.dividir => 'Divisão',
    TaskKind.planilha => 'Conversão',
  };

  String get particulo => switch (this) {
    TaskKind.comprimir => 'comprimido',
    TaskKind.dividir => 'dividido',
    TaskKind.planilha => 'convertido',
  };
}

/// Situação de um item da fila.
enum JobStatus { aguardando, processando, concluido, falhou, cancelado }

extension JobStatusX on JobStatus {
  bool get ativo => this == JobStatus.processando;
  bool get finalizado =>
      this == JobStatus.concluido ||
      this == JobStatus.falhou ||
      this == JobStatus.cancelado;
}

/// Resultado de um arquivo processado.
class ItemResult {
  const ItemResult({
    required this.entrada,
    required this.saidas,
    required this.bytesAntes,
    required this.bytesDepois,
    required this.duracao,
    this.motor,
    this.aviso,
    this.erro,
    this.alvoAtingido,
    this.detalhe,
  });

  final String entrada;
  final List<String> saidas;
  final int bytesAntes;
  final int bytesDepois;
  final Duration duracao;
  final String? motor;
  final String? aviso;
  final String? erro;

  /// Preenchido só quando havia tamanho alvo.
  final bool? alvoAtingido;

  /// Informação curta do resultado, do jeito que o usuário entende
  /// (por exemplo "4 abas" na conversão para planilha).
  final String? detalhe;

  bool get sucesso => erro == null;

  bool get reduziu => bytesDepois < bytesAntes;

  double get reducao {
    if (bytesAntes <= 0) return 0;
    return ((bytesAntes - bytesDepois) / bytesAntes).clamp(0, 1);
  }

  Map<String, dynamic> toJson() => {
    'entrada': entrada,
    'saidas': saidas,
    'antes': bytesAntes,
    'depois': bytesDepois,
    'ms': duracao.inMilliseconds,
    'motor': motor,
    'aviso': aviso,
    'erro': erro,
    'alvoOk': alvoAtingido,
    'detalhe': detalhe,
  };

  static ItemResult fromJson(Map<String, dynamic> json) => ItemResult(
    entrada: json['entrada'] as String? ?? '',
    saidas: (json['saidas'] as List?)?.cast<String>() ?? const [],
    bytesAntes: (json['antes'] as num?)?.toInt() ?? 0,
    bytesDepois: (json['depois'] as num?)?.toInt() ?? 0,
    duracao: Duration(milliseconds: (json['ms'] as num?)?.toInt() ?? 0),
    motor: json['motor'] as String?,
    aviso: json['aviso'] as String?,
    erro: json['erro'] as String?,
    alvoAtingido: json['alvoOk'] as bool?,
    detalhe: json['detalhe'] as String?,
  );
}

/// Uma entrada do histórico (persistida em disco).
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.quando,
    required this.kind,
    required this.resultado,
    required this.resumo,
  });

  final String id;
  final DateTime quando;
  final TaskKind kind;
  final ItemResult resultado;

  /// Resumo das opções usadas ("Equilibrado • texto preservado • 150dpi").
  final String resumo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'quando': quando.toIso8601String(),
    'kind': kind.name,
    'resumo': resumo,
    'resultado': resultado.toJson(),
  };

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String? ?? '',
    quando:
        DateTime.tryParse(json['quando'] as String? ?? '') ?? DateTime.now(),
    kind: TaskKind.values.firstWhere(
      (valor) => valor.name == json['kind'],
      orElse: () => TaskKind.comprimir,
    ),
    resumo: json['resumo'] as String? ?? '',
    resultado: ItemResult.fromJson(
      (json['resultado'] as Map?)?.cast<String, dynamic>() ?? {},
    ),
  );
}

/// Plano de divisão: uma parte por arquivo de saída.
class SplitPart {
  const SplitPart({
    required this.indice,
    required this.intervalos,
    required this.paginas,
    required this.bytesEstimados,
    required this.nomeSugerido,
  });

  /// 1, 2, 3…
  final int indice;

  /// Intervalos cobertos por esta parte (normalmente um só).
  final List<PageRange> intervalos;

  /// Quantidade total de páginas da parte.
  final int paginas;

  /// Estimativa de tamanho, baseada na média do arquivo original.
  final int bytesEstimados;

  final String nomeSugerido;

  int get primeiraPagina => intervalos.first.inicio;
  int get ultimaPagina => intervalos.last.fim;

  int get primeiraPaginaOriginal => primeiraPagina;

  String get rotuloPaginas => PageRangeParser.formatar(intervalos);

  @override
  String toString() => 'parte $indice: $rotuloPaginas';
}

/// Como dividir o PDF.
enum SplitMethod {
  intervalos,
  cadaN,
  porTamanho,
  extrair,
  marcadores;

  bool get usaIntervalos =>
      this == SplitMethod.intervalos || this == SplitMethod.extrair;

  String get rotulo => switch (this) {
    SplitMethod.intervalos => 'Por intervalos',
    SplitMethod.cadaN => 'A cada N páginas',
    SplitMethod.porTamanho => 'Por tamanho máximo',
    SplitMethod.extrair => 'Extrair páginas',
    SplitMethod.marcadores => 'Por marcadores',
  };
}

/// Opções da tela de divisão.
class SplitOptions {
  const SplitOptions({
    this.metodo = SplitMethod.intervalos,
    this.intervalosTexto = '',
    this.paginasPorParte = 10,
    this.maxBytes = 10 * 1024 * 1024,
    this.extrairTexto = '',
    this.padraoNome = '{nome} - parte {parte}',
    this.umArquivoSo = false,
    this.umaPaginaPorArquivo = false,
    this.incluirNumeroParte = true,
  });

  final SplitMethod metodo;

  /// Texto do campo de intervalos ("1-3, 7").
  final String intervalosTexto;

  /// Para o método "a cada N páginas".
  final int paginasPorParte;

  /// Para o método "por tamanho máximo".
  final int maxBytes;

  /// Páginas escolhidas no método "extrair".
  final String extrairTexto;

  final String padraoNome;

  /// Junta todas as partes em um único PDF (só no método "extrair").
  final bool umArquivoSo;

  /// Uma página por arquivo.
  final bool umaPaginaPorArquivo;

  final bool incluirNumeroParte;

  SplitOptions copyWith({
    SplitMethod? metodo,
    String? intervalosTexto,
    int? paginasPorParte,
    int? maxBytes,
    String? extrairTexto,
    String? padraoNome,
    bool? umArquivoSo,
    bool? umaPaginaPorArquivo,
    bool? incluirNumeroParte,
  }) {
    return SplitOptions(
      metodo: metodo ?? this.metodo,
      intervalosTexto: intervalosTexto ?? this.intervalosTexto,
      paginasPorParte: paginasPorParte ?? this.paginasPorParte,
      maxBytes: maxBytes ?? this.maxBytes,
      extrairTexto: extrairTexto ?? this.extrairTexto,
      padraoNome: padraoNome ?? this.padraoNome,
      umArquivoSo: umArquivoSo ?? this.umArquivoSo,
      umaPaginaPorArquivo: umaPaginaPorArquivo ?? this.umaPaginaPorArquivo,
      incluirNumeroParte: incluirNumeroParte ?? this.incluirNumeroParte,
    );
  }

  static const SplitOptions padrao = SplitOptions();

  Map<String, dynamic> toJson() => {
    'metodo': metodo.name,
    'intervalos': intervalosTexto,
    'porParte': paginasPorParte,
    'maxBytes': maxBytes,
    'extrair': extrairTexto,
    'padrao': padraoNome,
    'umArquivo': umArquivoSo,
    'umaPagina': umaPaginaPorArquivo,
    'numerar': incluirNumeroParte,
  };

  factory SplitOptions.fromJson(Map<String, dynamic> json) => SplitOptions(
    metodo: SplitMethod.values.firstWhere(
      (m) => m.name == json['metodo'],
      orElse: () => SplitMethod.intervalos,
    ),
    intervalosTexto: json['intervalos'] as String? ?? '',
    paginasPorParte: (json['porParte'] as num?)?.toInt() ?? 10,
    maxBytes: (json['maxBytes'] as num?)?.toInt() ?? 10 * 1024 * 1024,
    extrairTexto: json['extrair'] as String? ?? '',
    padraoNome: json['padrao'] as String? ?? '{nome} - parte {parte}',
    umArquivoSo: json['umArquivo'] as bool? ?? false,
    umaPaginaPorArquivo: json['umaPagina'] as bool? ?? false,
    incluirNumeroParte: json['numerar'] as bool? ?? true,
  );
}

/// Opções completas de uma tarefa (compressão ou divisão), persistível.
class TaskOptions {
  const TaskOptions({this.compressao, this.divisao});

  final CompressionOptions? compressao;
  final SplitOptions? divisao;

  Map<String, dynamic> toJson() => {
    if (compressao != null)
      'compressao': {
        'preset': compressao!.preset.name,
        'textMode': compressao!.textMode.name,
        'engine': compressao!.engine.name,
        'target': compressao!.targetEnabled,
        'targetBytes': compressao!.targetBytes,
        'targetScope': compressao!.targetScope.name,
        'dpi': compressao!.dpi,
        'jpeg': compressao!.jpegQuality,
        'cor': compressao!.colorMode.name,
        'metadados': compressao!.removeMetadata,
        'marcadores': compressao!.removeBookmarks,
        'anotacoes': compressao!.removeAnnotations,
        'miniaturas': compressao!.removeThumbnails,
        'estrutura': compressao!.optimizeStructure,
        'fluxos': compressao!.recompressStreams,
      },
    if (divisao != null) 'divisao': divisao!.toJson(),
  };

  String encode() => jsonEncode(toJson());
}
