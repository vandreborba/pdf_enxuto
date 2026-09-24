import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/services/motores.dart';
import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';
import 'package:pdf_enxuto/services/servico_arquivos.dart';

/// Uma tentativa de compressão já executada.
class _Tentativa {
  _Tentativa({
    required this.caminho,
    required this.tamanho,
    required this.opcoes,
    required this.motor,
    this.detalhe,
  });

  final String caminho;
  final int tamanho;
  final CompressionOptions opcoes;
  final MotorPdf motor;
  final String? detalhe;
}

/// Executa a compressão: escolhe o motor, persegue o tamanho alvo e devolve
/// um resultado pronto para a interface mostrar.
class ServicoCompressao {
  ServicoCompressao(this.motores);

  final Motores motores;

  /// Comprime [entrada] e grava em [destino] (o nome final pode ganhar um
  /// número se já existir e a sobrescrita estiver desligada).
  Future<ItemResult> comprimir({
    required String entrada,
    required String destino,
    required CompressionOptions opcoes,
    int? alvoBytes,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
    required bool sobrescrever,
    int paginas = 0,
  }) async {
    final inicio = DateTime.now();
    final arquivoEntrada = File(entrada);
    final tamanhoOriginal = arquivoEntrada.existsSync()
        ? arquivoEntrada.lengthSync()
        : 0;

    if (tamanhoOriginal == 0) {
      return ItemResult(
        entrada: entrada,
        saidas: const [],
        bytesAntes: 0,
        bytesDepois: 0,
        duracao: DateTime.now().difference(inicio),
        erro: 'Arquivo vazio ou inacessível',
      );
    }

    final alvo =
        alvoBytes ??
        (opcoes.targetEnabled && opcoes.targetBytes > 0
            ? opcoes.targetBytes
            : null);

    // No modo "por tamanho" o perfil não entra: a busca começa sempre na
    // melhor qualidade e desce até o piso.
    final base = opcoes.targetEnabled
        ? opcoes.partidaDaBusca(
            rasterizando: opcoes.textMode == TextMode.rasterizar,
          )
        : opcoes;

    final avisos = <String>[];
    final temporaria = await Future.value(Sistema.criarPastaTemporaria());
    _Tentativa? melhor;
    String? ultimoErro;
    MotorPdf? motorEscolhido;

    try {
      for (final motor in motores.cadeia(opcoes)) {
        cancelamento.verificar();
        final tentativas = _escada(motor, base, alvo);
        var fracassoDoMotor = false;

        for (var i = 0; i < tentativas.length; i++) {
          cancelamento.verificar();
          final candidato = tentativas[i];
          final saida = File(
            '${temporaria.path}${Platform.pathSeparator}'
            'tentativa_${motor.tipo.index}_$i.pdf',
          ).path;

          final resultado = await motor.comprimir(
            entrada: entrada,
            saida: saida,
            opcoes: candidato,
            cancelamento: cancelamento,
            progresso: (fracao, etapa) {
              final total = tentativas.length;
              if (fracao < 0) {
                progresso(-1, etapa);
              } else {
                progresso((i + fracao) / total, etapa);
              }
            },
          );

          if (!resultado.sucesso) {
            ultimoErro = resultado.erro;
            fracassoDoMotor = true;
            break;
          }
          if (resultado.aviso != null && !avisos.contains(resultado.aviso)) {
            avisos.add(resultado.aviso!);
          }

          final arquivo = File(saida);
          if (!arquivo.existsSync()) {
            // O motor entendeu que não valia a pena gerar outro arquivo.
            break;
          }

          final tamanho = arquivo.lengthSync();
          final tentativa = _Tentativa(
            caminho: saida,
            tamanho: tamanho,
            opcoes: candidato,
            motor: motor,
            detalhe: resultado.detalhe,
          );

          if (melhor == null || tamanho < melhor.tamanho) {
            if (melhor != null && File(melhor.caminho).existsSync()) {
              File(melhor.caminho).deleteSync();
            }
            melhor = tentativa;
            motorEscolhido = motor;
          } else {
            arquivo.deleteSync();
          }

          if (alvo != null && tamanho <= alvo) break;

          // Sem alvo, a primeira tentativa que reduzir já resolve.
          if (alvo == null) break;

          // Pula direto para o degrau que deve caber (economiza tempo).
          if (i == 0) {
            final pulo = _proximoDegrau(tentativas, tamanho, alvo);
            if (pulo > i + 1) i = pulo - 1;
          }
        }

        if (fracassoDoMotor) continue;

        final atingiuAlvo =
            alvo == null || (melhor != null && melhor.tamanho <= alvo);
        final reduziu = melhor != null && melhor.tamanho < tamanhoOriginal;
        if ((atingiuAlvo && reduziu) || (alvo == null && reduziu)) break;
      }

      // Nada conseguiu reduzir: não entregamos um arquivo pior.
      if (melhor == null || melhor.tamanho >= tamanhoOriginal) {
        if (ultimoErro != null && melhor == null) {
          return ItemResult(
            entrada: entrada,
            saidas: const [],
            bytesAntes: tamanhoOriginal,
            bytesDepois: tamanhoOriginal,
            duracao: DateTime.now().difference(inicio),
            erro: ultimoErro,
          );
        }
        return ItemResult(
          entrada: entrada,
          saidas: const [],
          bytesAntes: tamanhoOriginal,
          bytesDepois: tamanhoOriginal,
          duracao: DateTime.now().difference(inicio),
          aviso: S.resultadoMaior,
          motor: motorEscolhido?.nome,
        );
      }

      cancelamento.verificar();

      final destinoFinal = ServicoArquivos.caminhoFinal(
        destino,
        sobrescrever: sobrescrever,
      );
      await File(melhor.caminho).copy(destinoFinal);

      final atingiuAlvo = alvo == null || melhor.tamanho <= alvo;
      if (alvo != null && !atingiuAlvo) {
        avisos.add(S.alvoImpossivel);
      }

      progresso(1, 'Concluído');

      return ItemResult(
        entrada: entrada,
        saidas: [destinoFinal],
        bytesAntes: tamanhoOriginal,
        bytesDepois: melhor.tamanho,
        duracao: DateTime.now().difference(inicio),
        motor: motorEscolhido?.nome,
        aviso: avisos.isEmpty ? null : avisos.join('\n\n'),
        alvoAtingido: alvo == null ? null : atingiuAlvo,
      );
    } on OperacaoCancelada {
      return ItemResult(
        entrada: entrada,
        saidas: const [],
        bytesAntes: tamanhoOriginal,
        bytesDepois: tamanhoOriginal,
        duracao: DateTime.now().difference(inicio),
        erro: S.erroCancelado,
      );
    } finally {
      try {
        if (temporaria.existsSync()) {
          await temporaria.delete(recursive: true);
        }
      } catch (_) {
        // Pasta temporária: se não puder apagar agora, o sistema limpa depois.
      }
    }
  }

  /// Degraus de qualidade, do melhor para o pior, usados para perseguir o alvo.
  List<CompressionOptions> _escada(
    MotorPdf motor,
    CompressionOptions base,
    int? alvo,
  ) {
    // O qpdf não tem botões para girar: uma tentativa só.
    if (alvo == null || alvo <= 0 || motor.tipo == EngineKind.qpdf) {
      return [base];
    }
    // O modo "manter texto" do motor nativo também não tem o que ajustar.
    if (motor.tipo == EngineKind.nativo &&
        base.textMode == TextMode.manterTexto) {
      return [base];
    }

    const passos = 6;
    final dpiMinimo = math.max(
      60.0,
      72 + (base.dpi - 72) * base.qualidadeMinima,
    );
    final qualidadeMinima = math.max(
      25.0,
      30 + (base.jpegQuality - 30) * base.qualidadeMinima,
    );
    final lista = <CompressionOptions>[base];

    for (var k = 1; k <= passos; k++) {
      final t = k / passos;
      final dpi = math.max(dpiMinimo, base.dpi * (1 - 0.72 * t));
      final qualidade = math.max(
        qualidadeMinima,
        base.jpegQuality - (base.jpegQuality - 28) * t,
      );
      final candidato = base.copyWith(
        dpi: dpi.round(),
        jpegQuality: qualidade.round(),
        preset: CompressionPreset.personalizado,
      );
      if (candidato.dpi != lista.last.dpi ||
          candidato.jpegQuality != lista.last.jpegQuality) {
        lista.add(candidato);
      }
    }
    return lista;
  }

  /// Estima em qual degrau o arquivo deve caber e devolve o índice.
  int _proximoDegrau(
    List<CompressionOptions> tentativas,
    int tamanhoAtual,
    int alvo,
  ) {
    if (tamanhoAtual <= 0) return 1;
    final base = tentativas.first;
    final necessario = (alvo / tamanhoAtual) * 0.94;

    double peso(CompressionOptions opcoes) {
      final fatorDpi = math.pow(opcoes.dpi / base.dpi, 1.5).toDouble();
      final fatorQualidade = math
          .pow((opcoes.jpegQuality + 20) / (base.jpegQuality + 20), 1.2)
          .toDouble();
      final fatorCor = switch (opcoes.colorMode) {
        ColorMode.manter => 1.0,
        ColorMode.cinza => 0.6,
        ColorMode.mono => 0.3,
      };
      return fatorDpi * fatorQualidade * fatorCor;
    }

    for (var i = 1; i < tentativas.length; i++) {
      if (peso(tentativas[i]) <= necessario) return i;
    }
    return tentativas.length - 1;
  }

  /// Simulação rápida: comprime só a primeira página e estima o total.
  ///
  /// Serve para o usuário comparar níveis antes de esperar pelo arquivo todo.
  Future<int?> simular({
    required String entrada,
    required CompressionOptions opcoes,
    required int paginas,
    required Cancelamento cancelamento,
  }) async {
    if (paginas <= 0) return null;

    final temporaria = await Future.value(
      Sistema.criarPastaTemporaria('simulacao_'),
    );
    try {
      final bytes = await File(entrada).readAsBytes();
      final recorte = await Isolate.run(
        () => PdfOperations.extrairPaginas(PdfReader.abrirBytes(bytes), const [
          1,
        ]).bytes,
      );

      final amostra = '${temporaria.path}${Platform.pathSeparator}pagina1.pdf';
      await File(amostra).writeAsBytes(recorte, flush: true);

      final saida =
          '${temporaria.path}${Platform.pathSeparator}pagina1_saida.pdf';
      final motor = motores.cadeia(opcoes).first;

      final resultado = await motor.comprimir(
        entrada: amostra,
        saida: saida,
        opcoes: opcoes,
        cancelamento: cancelamento,
        progresso: (_, _) {},
      );
      if (!resultado.sucesso) return null;

      final arquivo = File(saida);
      if (!arquivo.existsSync()) return null;

      final tamanhoPagina = arquivo.lengthSync();
      final tamanhoOriginal = await File(entrada).length();
      final mediaPorPagina = tamanhoOriginal / paginas;

      // Se a primeira página é típica, a estimativa é boa; se for mais leve
      // que a média, corrigimos um pouco para não prometer demais.
      final proporcao = mediaPorPagina <= 0
          ? 1.0
          : (tamanhoPagina / mediaPorPagina).clamp(0.5, 2.0);
      final estimativa = tamanhoPagina * paginas * (0.75 + 0.25 * proporcao);
      return math.max(1024, estimativa.round());
    } catch (_) {
      return null;
    } finally {
      try {
        if (temporaria.existsSync()) {
          await temporaria.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Resume o que vai acontecer, para mostrar antes de começar.
  String descrever(CompressionOptions opcoes) {
    final motor = motores.motorPrevisto(opcoes);
    return '${opcoes.resumo} • motor: ${motor.nome}';
  }

  /// Texto curto do resultado, usado nos cards e no histórico.
  static String resumoDoResultado(ItemResult resultado) {
    if (!resultado.sucesso) return resultado.erro ?? S.erroGenerico;
    if (resultado.saidas.isEmpty) return S.resultadoMaior;
    return '${Fmt.bytes(resultado.bytesAntes)} → '
        '${Fmt.bytes(resultado.bytesDepois)} '
        '(${Fmt.reducao(resultado.bytesAntes, resultado.bytesDepois)} menor)';
  }
}
