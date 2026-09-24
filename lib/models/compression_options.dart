import 'package:pdf_enxuto/core/app_strings.dart';

/// O que fazer com o texto do documento.
enum TextMode {
  /// Recomprime imagens e limpa a estrutura mantendo o texto selecionável.
  manterTexto,

  /// Redesenha cada página como imagem (perde texto, reduz muito mais).
  rasterizar;

  String get rotulo => switch (this) {
        TextMode.manterTexto => S.modoTextoManter,
        TextMode.rasterizar => S.modoTextoRasterizar,
      };

  String get descricaoCurta => switch (this) {
        TextMode.manterTexto =>
          'Texto continua selecionável e pesquisável (Ctrl+F).',
        TextMode.rasterizar =>
          'Cada página vira uma imagem: menor tamanho, sem texto pesquisável.',
      };
}

/// Perfis prontos de compressão.
enum CompressionPreset {
  leve,
  equilibrado,
  forte,
  extremo,
  personalizado;

  String get rotulo => switch (this) {
        CompressionPreset.leve => S.presetLeve,
        CompressionPreset.equilibrado => S.presetEquilibrado,
        CompressionPreset.forte => S.presetForte,
        CompressionPreset.extremo => S.presetExtremo,
        CompressionPreset.personalizado => S.presetPersonalizado,
      };

  String get resumo => switch (this) {
        CompressionPreset.leve => S.presetLeveResumo,
        CompressionPreset.equilibrado => S.presetEquilibradoResumo,
        CompressionPreset.forte => S.presetForteResumo,
        CompressionPreset.extremo => S.presetExtremoResumo,
        CompressionPreset.personalizado => 'Ajustes feitos por você',
      };
}

/// Motor que executa a compressão.
enum EngineKind {
  automatico,
  nativo,
  ghostscript,
  qpdf;

  String get rotulo => switch (this) {
        EngineKind.automatico => S.motorAutomatico,
        EngineKind.nativo => S.motorNativo,
        EngineKind.ghostscript => S.motorGhostscript,
        EngineKind.qpdf => S.motorQpdf,
      };

  /// Motores externos podem não estar instalados.
  bool get externo => this == EngineKind.ghostscript || this == EngineKind.qpdf;

  /// Só o Ghostscript desenha páginas em imagem com qualidade.
  bool get suportaRasterizar =>
      this == EngineKind.ghostscript ||
      this == EngineKind.nativo ||
      this == EngineKind.automatico;

  bool get preservaTexto =>
      this == EngineKind.ghostscript ||
      this == EngineKind.qpdf ||
      this == EngineKind.automatico;

  bool get semPerdas => this == EngineKind.qpdf;
}

/// Cor das imagens após a compressão.
enum ColorMode {
  manter,
  cinza,
  mono;

  String get rotulo => switch (this) {
        ColorMode.manter => S.corManter,
        ColorMode.cinza => S.corCinza,
        ColorMode.mono => S.corMono,
      };
}

/// Como o tamanho alvo é distribuído quando há vários arquivos.
enum TargetScope {
  porArquivo,
  total;

  String get rotulo => switch (this) {
        TargetScope.porArquivo => S.tamanhoAlvoPorArquivo,
        TargetScope.total => S.tamanhoAlvoTotal,
      };
}

/// Todas as opções de compressão em um só lugar.
///
/// O objeto é imutável e serializável: assim a tela de opções pode ser
/// reconstruída a partir do preset, e o histórico guarda exatamente o que foi
/// usado naquela tarefa.
class CompressionOptions {
  const CompressionOptions({
    this.preset = CompressionPreset.equilibrado,
    this.textMode = TextMode.manterTexto,
    this.engine = EngineKind.automatico,
    this.targetEnabled = false,
    this.targetBytes = 5 * 1024 * 1024,
    this.targetScope = TargetScope.porArquivo,
    this.qualidadeMinima = 0.35,
    this.dpi = 150,
    this.jpegQuality = 82,
    this.colorMode = ColorMode.manter,
    this.removeMetadata = true,
    this.removeBookmarks = false,
    this.removeAnnotations = false,
    this.removeThumbnails = true,
    this.optimizeStructure = true,
    this.recompressStreams = true,
    this.compatibilidadeAntiga = false,
  });

  final CompressionPreset preset;
  final TextMode textMode;
  final EngineKind engine;

  /// Tamanho alvo (usado quando [targetEnabled]).
  final bool targetEnabled;
  final int targetBytes;
  final TargetScope targetScope;

  /// Piso de qualidade da busca pelo alvo: 0 = pode degradar ao máximo,
  /// 1 = nunca abaixo da qualidade do preset.
  final double qualidadeMinima;

  final int dpi;
  final int jpegQuality;
  final ColorMode colorMode;

  final bool removeMetadata;
  final bool removeBookmarks;
  final bool removeAnnotations;
  final bool removeThumbnails;

  /// Limpa objetos não usados e reescreve a estrutura (sem perdas).
  final bool optimizeStructure;
  final bool recompressStreams;

  /// Gera PDF compatível com leitores antigos (1.4 em vez de 1.7).
  final bool compatibilidadeAntiga;

  /// Aplica o preset escolhido, mantendo as escolhas que não fazem parte dele.
  CompressionOptions comPreset(CompressionPreset novo) {
    final base = switch (novo) {
      CompressionPreset.leve => const CompressionOptions(
          preset: CompressionPreset.leve,
          dpi: 300,
          jpegQuality: 92,
          qualidadeMinima: 0.6,
        ),
      CompressionPreset.equilibrado => const CompressionOptions(
          preset: CompressionPreset.equilibrado,
          dpi: 150,
          jpegQuality: 82,
          qualidadeMinima: 0.4,
        ),
      CompressionPreset.forte => const CompressionOptions(
          preset: CompressionPreset.forte,
          dpi: 120,
          jpegQuality: 68,
          qualidadeMinima: 0.25,
        ),
      CompressionPreset.extremo => const CompressionOptions(
          preset: CompressionPreset.extremo,
          dpi: 96,
          jpegQuality: 52,
          qualidadeMinima: 0.15,
        ),
      CompressionPreset.personalizado => this,
    };

    if (novo == CompressionPreset.personalizado) return this;

    return base.copyWith(
      textMode: textMode,
      engine: engine,
      targetEnabled: targetEnabled,
      targetBytes: targetBytes,
      targetScope: targetScope,
      colorMode: colorMode,
      removeMetadata: removeMetadata,
      removeBookmarks: removeBookmarks,
      removeAnnotations: removeAnnotations,
      removeThumbnails: removeThumbnails,
      optimizeStructure: optimizeStructure,
      recompressStreams: recompressStreams,
      compatibilidadeAntiga: compatibilidadeAntiga,
      // O piso pode ser aumentado pelo usuário em relação ao preset.
      qualidadeMinima: qualidadeMinima > base.qualidadeMinima
          ? qualidadeMinima
          : base.qualidadeMinima,
    );
  }

  CompressionOptions copyWith({
    CompressionPreset? preset,
    TextMode? textMode,
    EngineKind? engine,
    bool? targetEnabled,
    int? targetBytes,
    TargetScope? targetScope,
    double? qualidadeMinima,
    int? dpi,
    int? jpegQuality,
    ColorMode? colorMode,
    bool? removeMetadata,
    bool? removeBookmarks,
    bool? removeAnnotations,
    bool? removeThumbnails,
    bool? optimizeStructure,
    bool? recompressStreams,
    bool? compatibilidadeAntiga,
  }) {
    return CompressionOptions(
      preset: preset ?? this.preset,
      textMode: textMode ?? this.textMode,
      engine: engine ?? this.engine,
      targetEnabled: targetEnabled ?? this.targetEnabled,
      targetBytes: targetBytes ?? this.targetBytes,
      targetScope: targetScope ?? this.targetScope,
      qualidadeMinima: qualidadeMinima ?? this.qualidadeMinima,
      dpi: dpi ?? this.dpi,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      colorMode: colorMode ?? this.colorMode,
      removeMetadata: removeMetadata ?? this.removeMetadata,
      removeBookmarks: removeBookmarks ?? this.removeBookmarks,
      removeAnnotations: removeAnnotations ?? this.removeAnnotations,
      removeThumbnails: removeThumbnails ?? this.removeThumbnails,
      optimizeStructure: optimizeStructure ?? this.optimizeStructure,
      recompressStreams: recompressStreams ?? this.recompressStreams,
      compatibilidadeAntiga:
          compatibilidadeAntiga ?? this.compatibilidadeAntiga,
    );
  }

  /// Marca como "personalizado" sempre que um ajuste fino é mexido.
  CompressionOptions personalizado() =>
      preset == CompressionPreset.personalizado
          ? this
          : copyWith(preset: CompressionPreset.personalizado);

  /// Resumo curto mostrado no card do arquivo e no histórico.
  String get resumo {
    final partes = <String>[
      preset.rotulo,
      textMode == TextMode.manterTexto ? 'texto preservado' : 'páginas como imagem',
      '${dpi}dpi',
      'JPEG $jpegQuality',
    ];
    if (colorMode != ColorMode.manter) partes.add(colorMode.rotulo.toLowerCase());
    if (targetEnabled) partes.add('alvo ${targetScope.rotulo.toLowerCase()}');
    return partes.join(' • ');
  }

  /// Estimativa grosseira de fator de tamanho por página, usada apenas para
  /// ordenar as tentativas da busca por tamanho alvo (não é uma promessa).
  double get fatorEstimado {
    final fatorDpi = (dpi / 150).clamp(0.35, 2.4);
    final fatorQualidade = 0.5 + (jpegQuality / 100) * 0.9;
    final fatorCor = switch (colorMode) {
      ColorMode.manter => 1.0,
      ColorMode.cinza => 0.42,
      ColorMode.mono => 0.18,
    };
    final fatorModo = textMode == TextMode.rasterizar ? 1.0 : 0.85;
    return fatorDpi * fatorQualidade * fatorCor * fatorModo;
  }

  static const CompressionOptions padrao = CompressionOptions();

  Map<String, dynamic> toJson() => {
        'preset': preset.name,
        'textMode': textMode.name,
        'engine': engine.name,
        'target': targetEnabled,
        'targetBytes': targetBytes,
        'targetScope': targetScope.name,
        'qualidadeMinima': qualidadeMinima,
        'dpi': dpi,
        'jpeg': jpegQuality,
        'cor': colorMode.name,
        'metadados': removeMetadata,
        'marcadores': removeBookmarks,
        'anotacoes': removeAnnotations,
        'miniaturas': removeThumbnails,
        'estrutura': optimizeStructure,
        'fluxos': recompressStreams,
        'compat': compatibilidadeAntiga,
      };

  factory CompressionOptions.fromJson(Map<String, dynamic> json) {
    return CompressionOptions(
      preset: CompressionPreset.values.firstWhere(
        (valor) => valor.name == json['preset'],
        orElse: () => CompressionPreset.equilibrado,
      ),
      textMode: TextMode.values.firstWhere(
        (valor) => valor.name == json['textMode'],
        orElse: () => TextMode.manterTexto,
      ),
      engine: EngineKind.values.firstWhere(
        (valor) => valor.name == json['engine'],
        orElse: () => EngineKind.automatico,
      ),
      targetEnabled: json['target'] as bool? ?? false,
      targetBytes: (json['targetBytes'] as num?)?.toInt() ?? 5 * 1024 * 1024,
      targetScope: TargetScope.values.firstWhere(
        (valor) => valor.name == json['targetScope'],
        orElse: () => TargetScope.porArquivo,
      ),
      qualidadeMinima: (json['qualidadeMinima'] as num?)?.toDouble() ?? 0.35,
      dpi: (json['dpi'] as num?)?.toInt() ?? 150,
      jpegQuality: (json['jpeg'] as num?)?.toInt() ?? 82,
      colorMode: ColorMode.values.firstWhere(
        (valor) => valor.name == json['cor'],
        orElse: () => ColorMode.manter,
      ),
      removeMetadata: json['metadados'] as bool? ?? true,
      removeBookmarks: json['marcadores'] as bool? ?? false,
      removeAnnotations: json['anotacoes'] as bool? ?? false,
      removeThumbnails: json['miniaturas'] as bool? ?? true,
      optimizeStructure: json['estrutura'] as bool? ?? true,
      recompressStreams: json['fluxos'] as bool? ?? true,
      compatibilidadeAntiga: json['compat'] as bool? ?? false,
    );
  }
}
