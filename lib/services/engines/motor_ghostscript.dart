import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';

/// Motor Ghostscript — o que dá os melhores resultados em qualquer tipo de PDF
/// e mantém o texto selecionável.
///
/// É opcional: se não estiver instalado, o app usa o motor nativo e continua
/// funcionando. Nada é baixado automaticamente.
class MotorGhostscript extends MotorPdf {
  MotorGhostscript();

  static const List<String> _nomesBinario = ['gs', 'gswin64c', 'gswin32c'];

  EstadoMotor _estado = const EstadoMotor.indisponivel();
  String? _binario;

  @override
  EngineKind get tipo => EngineKind.ghostscript;

  @override
  String get nome => 'Ghostscript';

  @override
  String get descricao =>
      'Motor profissional de PDF. Mantém o texto e comprime muito bem '
      'documentos digitalizados e vetoriais.';

  @override
  String get comoInstalar => Sistema.ehWindows
      ? 'Baixe em ghostscript.com/releases (instalador .exe) e marque a opção '
          'de adicionar ao PATH.'
      : 'Debian/Ubuntu: sudo apt install ghostscript\n'
          'Fedora: sudo dnf install ghostscript\n'
          'Arch: sudo pacman -S ghostscript';

  @override
  String get siteOficial => 'https://www.ghostscript.com/releases/gsdnld.html';

  @override
  EstadoMotor get estado => _estado;

  @override
  Future<EstadoMotor> detectar({bool forcar = false}) async {
    if (_estado.disponivel && !forcar) return _estado;

    final caminho = await Sistema.procurarPrograma(_nomesBinario);
    if (caminho == null) {
      _estado = const EstadoMotor.indisponivel('não encontrado no PATH');
      return _estado;
    }

    final versao = await Sistema.executar(caminho, ['--version']);
    if (versao == null || versao.isEmpty) {
      _estado = EstadoMotor(
        disponivel: false,
        caminho: caminho,
        erro: 'encontrado, mas não respondeu',
      );
      return _estado;
    }

    _binario = caminho;
    _estado = EstadoMotor(
      disponivel: true,
      caminho: caminho,
      versao: versao.split(RegExp(r'\s+')).first,
    );
    return _estado;
  }

  @override
  List<String> limitacoes(CompressionOptions opcoes) {
    final avisos = <String>[];
    if (opcoes.textMode == TextMode.rasterizar) {
      avisos.add(
        'O Ghostscript não redesenha páginas como imagem: nesse modo o app '
        'usa o motor nativo, que gera JPEG de verdade.',
      );
    }
    if (opcoes.colorMode == ColorMode.mono) {
      avisos.add(
        'Com o Ghostscript, "preto e branco" vira tons de cinza de alta '
        'compressão (o motor nativo gera 1 bit por pixel).',
      );
    }
    if (opcoes.removeMetadata == false && opcoes.textMode == TextMode.manterTexto) {
      avisos.add(
        'O Ghostscript sempre regrava as informações do documento; '
        'título e autor podem não ser preservados.',
      );
    }
    return avisos;
  }

  @override
  Future<ResultadoMotor> comprimir({
    required String entrada,
    required String saida,
    required CompressionOptions opcoes,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  }) async {
    final estado = await detectar();
    if (!estado.disponivel) {
      return ResultadoMotor.falha('Ghostscript não está disponível');
    }
    if (opcoes.textMode == TextMode.rasterizar) {
      return ResultadoMotor.falha(
        'O Ghostscript não redesenha páginas como imagem',
      );
    }

    progresso(-1, 'Comprimindo com Ghostscript…');
    return _executar(
      _argumentosCompressao(entrada, saida, opcoes),
      cancelamento: cancelamento,
      progresso: progresso,
      saida: saida,
    );
  }

  @override
  Future<ResultadoMotor> dividir({
    required String entrada,
    required List<List<PageRange>> partes,
    required List<String> destinos,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  }) async {
    final estado = await detectar();
    if (!estado.disponivel) {
      return ResultadoMotor.falha('Ghostscript não está disponível');
    }

    // Divisão sem perdas: qualidade máxima, só recortando o intervalo.
    for (var i = 0; i < partes.length; i++) {
      cancelamento.verificar();
      progresso(i / math.max(1, partes.length), 'Parte ${i + 1} de ${partes.length}');

      final primeira = partes[i].first.inicio;
      final ultima = partes[i].last.fim;
      final argumentos = [
        '-sDEVICE=pdfwrite',
        '-dNOPAUSE',
        '-dBATCH',
        '-dQUIET',
        '-dCompatibilityLevel=1.7',
        '-dPDFSETTINGS=/prepress',
        '-dAutoRotatePages=/None',
        '-dDetectDuplicateImages=true',
        '-dFirstPage=$primeira',
        '-dLastPage=$ultima',
      ];

      final resultado = await _executar(
        [...argumentos, '-sOutputFile=${destinos[i]}', '-f', entrada],
        cancelamento: cancelamento,
        progresso: (_, _) {},
        saida: destinos[i],
      );
      if (!resultado.sucesso) {
        return ResultadoMotor.falha(
          'Falha na parte ${i + 1}: ${resultado.erro}',
        );
      }
    }

    progresso(1, 'Concluído');
    return ResultadoMotor.ok(
      detalhe: 'Ghostscript ${estado.versao}',
      aviso: 'As páginas foram recortadas com o motor Ghostscript.',
    );
  }

  List<String> _argumentosCompressao(
    String entrada,
    String saida,
    CompressionOptions opcoes,
  ) {
    final dpi = opcoes.dpi.clamp(36, 600);
    final qualidade = opcoes.jpegQuality.clamp(10, 100);

    final argumentos = <String>[
      '-sDEVICE=pdfwrite',
      '-dNOPAUSE',
      '-dBATCH',
      '-dQUIET',
      '-dCompatibilityLevel=${opcoes.compatibilidadeAntiga ? '1.4' : '1.7'}',
      '-dAutoRotatePages=/None',
      '-dDetectDuplicateImages=true',
      '-dCompressFonts=true',
      '-dSubsetFonts=true',
      '-dEmbedAllFonts=true',
      '-dPreserveEPSInfo=false',
      '-dPreserveOPIComments=false',
      '-dPreserveOverprintSettings=false',
      '-dPreserveMarkedContent=false',
      if (opcoes.compatibilidadeAntiga) ...[
        '-dCompressPages=false',
      ] else ...[
        '-dCompressPages=true',
        '-dCompressStreams=true',
      ],
      // Imagens coloridas
      '-dDownsampleColorImages=true',
      '-dColorImageDownsampleType=/Bicubic',
      '-dColorImageResolution=$dpi',
      '-dAutoFilterColorImages=false',
      '-dColorImageFilter=/DCTEncode',
      // Imagens em tons de cinza
      '-dDownsampleGrayImages=true',
      '-dGrayImageDownsampleType=/Bicubic',
      '-dGrayImageResolution=$dpi',
      '-dAutoFilterGrayImages=false',
      '-dGrayImageFilter=/DCTEncode',
      // Imagens de 1 bit (digitalizações em preto e branco)
      '-dDownsampleMonoImages=true',
      '-dMonoImageDownsampleType=/Subsample',
      '-dMonoImageResolution=${math.max(dpi, 150)}',
      '-dJPEGQ=$qualidade',
    ];

    if (opcoes.colorMode != ColorMode.manter) {
      argumentos.addAll([
        '-sColorConversionStrategy=Gray',
        '-dProcessColorModel=/DeviceGray',
      ]);
    }

    if (opcoes.removeAnnotations) {
      argumentos.add('-dShowAnnots=false');
    }

    argumentos
      ..add('-sOutputFile=$saida')
      ..add('-f')
      ..add(entrada);
    return argumentos;
  }

  /// Executa o Ghostscript e observa o processo, permitindo cancelar.
  Future<ResultadoMotor> _executar(
    List<String> argumentos, {
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
    required String saida,
  }) async {
    final binario = _binario;
    if (binario == null) {
      return ResultadoMotor.falha('Ghostscript não está disponível');
    }

    final parcial = '$saida.parcial';
    final argumentosFinais = [
      for (final argumento in argumentos)
        argumento == '-sOutputFile=$saida' ? '-sOutputFile=$parcial' : argumento,
    ];

    try {
      final processo = await Process.start(binario, argumentosFinais);
      final assinatura = cancelamento.quandoCancelar.listen((_) {
        try {
          processo.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });

      final erros = StringBuffer();
      final consumidor = processo.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(erros.write);
      await processo.stdout.drain<void>();

      var codigo = await processo.exitCode;
      await consumidor.cancel();
      await assinatura.cancel();

      final parcialArquivo = File(parcial);
      if (codigo != 0 || !parcialArquivo.existsSync()) {
        if (parcialArquivo.existsSync()) parcialArquivo.deleteSync();
        final mensagem = erros.toString().trim();
        return ResultadoMotor.falha(
          mensagem.isEmpty
              ? 'Ghostscript terminou com código $codigo'
              : mensagem.split(RegExp(r'\r?\n')).last,
          detalhe: mensagem.isEmpty ? null : mensagem,
        );
      }

      _mover(parcial, saida);
      progresso(1, 'Concluído');
      return const ResultadoMotor.ok();
    } on ProcessException catch (erro) {
      return ResultadoMotor.falha('Não foi possível executar o Ghostscript',
          detalhe: '$erro');
    }
  }

  static void _mover(String origem, String destino) {
    final arquivoDestino = File(destino);
    if (arquivoDestino.existsSync()) arquivoDestino.deleteSync();
    File(origem).renameSync(destino);
  }
}
