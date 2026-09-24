import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';

/// Aviso de progresso: fração de 0 a 1 e uma etapa legível.
typedef ProgressoCallback = void Function(double fracao, String etapa);

/// Situação de um motor externo.
class EstadoMotor {
  const EstadoMotor({
    required this.disponivel,
    this.caminho,
    this.versao,
    this.erro,
  });

  const EstadoMotor.indisponivel([this.erro])
      : disponivel = false,
        caminho = null,
        versao = null;

  final bool disponivel;
  final String? caminho;
  final String? versao;
  final String? erro;
}

/// Resultado de uma execução de motor.
class ResultadoMotor {
  const ResultadoMotor.ok({this.aviso, this.detalhe})
      : sucesso = true,
        erro = null;

  const ResultadoMotor.falha(this.erro, {this.detalhe})
      : sucesso = false,
        aviso = null;

  final bool sucesso;
  final String? erro;
  final String? aviso;
  final String? detalhe;
}

/// Contrato de todo motor de PDF.
///
/// Um motor sabe comprimir, dividir e dizer o que não consegue fazer. O app
/// sempre tem o motor nativo disponível, então nunca fica sem opção.
abstract class MotorPdf {
  EngineKind get tipo;

  String get nome;

  String get descricao;

  /// Instrução curta de instalação, mostrada nas configurações.
  String get comoInstalar;

  /// Página oficial de download (aberta pelo app).
  String get siteOficial;

  EstadoMotor get estado;

  bool get disponivel => estado.disponivel;

  Future<EstadoMotor> detectar({bool forcar = false});

  /// Comprime [entrada] gravando em [saida].
  Future<ResultadoMotor> comprimir({
    required String entrada,
    required String saida,
    required CompressionOptions opcoes,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  });

  /// Grava as partes em [destinos] (mesma ordem de [partes]).
  Future<ResultadoMotor> dividir({
    required String entrada,
    required List<List<PageRange>> partes,
    required List<String> destinos,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  });

  /// O que este motor não consegue fazer com estas opções (texto para o
  /// usuário). Lista vazia = faz tudo.
  List<String> limitacoes(CompressionOptions opcoes) => const [];

  /// Só o motor nativo redesenha as páginas como imagem.
  bool get suportaRasterizar => false;

  /// Estimativa de tamanho, quando o motor consegue simular rapidamente.
  /// Devolve `null` quando não há como estimar.
  Future<int?> estimarTamanho({
    required String entrada,
    required CompressionOptions opcoes,
    required Cancelamento cancelamento,
  }) async =>
      null;
}
