import 'package:flutter/material.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/task_models.dart';

/// Todas as preferências do usuário, em um objeto imutável e serializável.
class AppSettings {
  const AppSettings({
    this.tema = ThemeMode.system,
    this.corDestaque = 0,
    this.reduzirAnimacoes = false,
    this.confirmarSaida = true,
    this.abrirPastaAoTerminar = false,
    this.notificarAoTerminar = true,
    this.sobrescrever = false,
    this.processarEmParalelo = true,
    this.simultaneos = 2,
    this.verificarAtualizacoes = true,
    this.avisosDesligados = false,
    this.versaoIgnorada,
    this.ultimaVerificacao,
    this.pastaSaida,
    this.compressao = CompressionOptions.padrao,
    this.divisao = SplitOptions.padrao,
    this.onboardingVisto = false,
  });

  final ThemeMode tema;

  /// Índice em [AccentPalette.todas].
  final int corDestaque;

  final bool reduzirAnimacoes;
  final bool confirmarSaida;
  final bool abrirPastaAoTerminar;
  final bool notificarAoTerminar;
  final bool sobrescrever;

  final bool processarEmParalelo;
  final int simultaneos;

  final bool verificarAtualizacoes;

  /// Usuário pediu para parar de avisar sobre atualizações.
  final bool avisosDesligados;

  /// Versão que o usuário pediu para não avisar de novo.
  final String? versaoIgnorada;
  final DateTime? ultimaVerificacao;

  /// Pasta de saída padrão; `null` = ao lado do arquivo original.
  final String? pastaSaida;

  final CompressionOptions compressao;
  final SplitOptions divisao;

  final bool onboardingVisto;

  int get paralelismo => processarEmParalelo ? simultaneos.clamp(1, 8) : 1;

  AppSettings copyWith({
    ThemeMode? tema,
    int? corDestaque,
    bool? reduzirAnimacoes,
    bool? confirmarSaida,
    bool? abrirPastaAoTerminar,
    bool? notificarAoTerminar,
    bool? sobrescrever,
    bool? processarEmParalelo,
    int? simultaneos,
    bool? verificarAtualizacoes,
    bool? avisosDesligados,
    String? versaoIgnorada,
    bool? limparVersaoIgnorada,
    DateTime? ultimaVerificacao,
    String? pastaSaida,
    bool? limparPastaSaida,
    CompressionOptions? compressao,
    SplitOptions? divisao,
    bool? onboardingVisto,
  }) {
    return AppSettings(
      tema: tema ?? this.tema,
      corDestaque: corDestaque ?? this.corDestaque,
      reduzirAnimacoes: reduzirAnimacoes ?? this.reduzirAnimacoes,
      confirmarSaida: confirmarSaida ?? this.confirmarSaida,
      abrirPastaAoTerminar: abrirPastaAoTerminar ?? this.abrirPastaAoTerminar,
      notificarAoTerminar: notificarAoTerminar ?? this.notificarAoTerminar,
      sobrescrever: sobrescrever ?? this.sobrescrever,
      processarEmParalelo: processarEmParalelo ?? this.processarEmParalelo,
      simultaneos: simultaneos ?? this.simultaneos,
      verificarAtualizacoes: verificarAtualizacoes ?? this.verificarAtualizacoes,
      avisosDesligados: avisosDesligados ?? this.avisosDesligados,
      versaoIgnorada: limparVersaoIgnorada == true
          ? null
          : (versaoIgnorada ?? this.versaoIgnorada),
      ultimaVerificacao: ultimaVerificacao ?? this.ultimaVerificacao,
      pastaSaida:
          limparPastaSaida == true ? null : (pastaSaida ?? this.pastaSaida),
      compressao: compressao ?? this.compressao,
      divisao: divisao ?? this.divisao,
      onboardingVisto: onboardingVisto ?? this.onboardingVisto,
    );
  }

  Map<String, dynamic> toJson() => {
        'tema': tema.name,
        'cor': corDestaque,
        'reduzirAnimacoes': reduzirAnimacoes,
        'confirmarSaida': confirmarSaida,
        'abrirPasta': abrirPastaAoTerminar,
        'notificar': notificarAoTerminar,
        'sobrescrever': sobrescrever,
        'paralelo': processarEmParalelo,
        'simultaneos': simultaneos,
        'verificarAtualizacoes': verificarAtualizacoes,
        'avisosDesligados': avisosDesligados,
        'versaoIgnorada': versaoIgnorada,
        'ultimaVerificacao': ultimaVerificacao?.toIso8601String(),
        'pastaSaida': pastaSaida,
        'compressao': compressao.toJson(),
        'divisao': divisao.toJson(),
        'onboarding': onboardingVisto,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final comp = (json['compressao'] as Map?)?.cast<String, dynamic>() ?? {};
    final div = (json['divisao'] as Map?)?.cast<String, dynamic>() ?? {};

    return AppSettings(
      tema: ThemeMode.values.firstWhere(
        (t) => t.name == json['tema'],
        orElse: () => ThemeMode.system,
      ),
      corDestaque: (json['cor'] as num?)?.toInt() ?? 0,
      reduzirAnimacoes: json['reduzirAnimacoes'] as bool? ?? false,
      confirmarSaida: json['confirmarSaida'] as bool? ?? true,
      abrirPastaAoTerminar: json['abrirPasta'] as bool? ?? false,
      notificarAoTerminar: json['notificar'] as bool? ?? true,
      sobrescrever: json['sobrescrever'] as bool? ?? false,
      processarEmParalelo: json['paralelo'] as bool? ?? true,
      simultaneos: (json['simultaneos'] as num?)?.toInt() ?? 2,
      verificarAtualizacoes: json['verificarAtualizacoes'] as bool? ?? true,
      avisosDesligados: json['avisosDesligados'] as bool? ?? false,
      versaoIgnorada: json['versaoIgnorada'] as String?,
      ultimaVerificacao: DateTime.tryParse(json['ultimaVerificacao'] as String? ?? ''),
      pastaSaida: json['pastaSaida'] as String?,
      compressao: comp.isEmpty
          ? CompressionOptions.padrao
          : CompressionOptions.fromJson(comp),
      divisao: div.isEmpty ? SplitOptions.padrao : SplitOptions.fromJson(div),
      onboardingVisto: json['onboarding'] as bool? ?? false,
    );
  }

  static const AppSettings padrao = AppSettings();
}
