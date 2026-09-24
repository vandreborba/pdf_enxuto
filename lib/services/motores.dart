import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/services/engines/motor_ghostscript.dart';
import 'package:pdf_enxuto/services/engines/motor_nativo.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/services/engines/motor_qpdf.dart';

/// Reúne os motores disponíveis e decide qual usar.
///
/// A regra é simples: o app sempre tem o motor nativo; se o Ghostscript ou o
/// qpdf estiverem instalados, eles entram na frente quando rendem mais.
class Motores {
  Motores();

  final MotorNativo nativo = MotorNativo();
  final MotorGhostscript ghostscript = MotorGhostscript();
  final MotorQpdf qpdf = MotorQpdf();

  List<MotorPdf> get todos => [nativo, ghostscript, qpdf];

  MotorPdf porTipo(EngineKind tipo) => switch (tipo) {
    EngineKind.ghostscript => ghostscript,
    EngineKind.qpdf => qpdf,
    EngineKind.nativo || EngineKind.automatico => nativo,
  };

  /// Procura os motores externos (uma vez, ou forçado pelo botão).
  Future<void> detectar({bool forcar = false}) async {
    await Future.wait([
      ghostscript.detectar(forcar: forcar),
      qpdf.detectar(forcar: forcar),
    ]);
  }

  /// Ordem de tentativa para as opções escolhidas.
  ///
  /// Se um motor falhar, o próximo da lista assume — o usuário nunca fica sem
  /// resultado.
  List<MotorPdf> cadeia(CompressionOptions opcoes) {
    // Rasterizar só o motor nativo faz de verdade.
    if (opcoes.textMode == TextMode.rasterizar) {
      return [nativo];
    }

    switch (opcoes.engine) {
      case EngineKind.ghostscript:
        return [if (ghostscript.disponivel) ghostscript, nativo];
      case EngineKind.qpdf:
        return [if (qpdf.disponivel) qpdf, nativo];
      case EngineKind.nativo:
        return [nativo];
      case EngineKind.automatico:
        return [if (ghostscript.disponivel) ghostscript, nativo];
    }
  }

  /// O motor que a cadeia realmente vai usar primeiro (para mostrar na UI).
  MotorPdf motorPrevisto(CompressionOptions opcoes) => cadeia(opcoes).first;

  /// Avisos sobre o que a escolha do usuário implica.
  List<String> avisosDaEscolha(CompressionOptions opcoes) {
    final motor = motorPrevisto(opcoes);
    final avisos = <String>[...motor.limitacoes(opcoes)];

    if (opcoes.engine.externo && !porTipo(opcoes.engine).disponivel) {
      avisos.insert(
        0,
        '${porTipo(opcoes.engine).nome} não está instalado neste computador: '
        'vamos usar o motor ${motor.nome}.',
      );
    }
    return avisos;
  }

  bool get algumExterno => ghostscript.disponivel || qpdf.disponivel;

  /// Diz se dá para "perseguir" um tamanho alvo com as opções escolhidas.
  ///
  /// Perseguir o alvo exige um motor com botões de qualidade: o Ghostscript
  /// ou o motor nativo no modo "vira imagem". O qpdf e a limpeza estrutural
  /// não têm o que ajustar.
  bool permiteBuscaDeAlvo(CompressionOptions opcoes) {
    if (opcoes.textMode == TextMode.rasterizar) return true;
    return motorPrevisto(opcoes).tipo == EngineKind.ghostscript;
  }
}
