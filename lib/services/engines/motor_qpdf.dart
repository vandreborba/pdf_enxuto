import 'dart:io';
import 'dart:math' as math;

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';

/// Motor qpdf: reorganiza o arquivo sem tocar no conteúdo.
///
/// O ganho é pequeno, mas é 100% sem perdas e muito rápido. Bom para PDFs
/// gerados por vários programas e para quem não quer nenhuma alteração visual.
class MotorQpdf extends MotorPdf {
  MotorQpdf();

  static const List<String> _nomesBinario = ['qpdf', 'qpdf.exe'];

  EstadoMotor _estado = const EstadoMotor.indisponivel();
  String? _binario;

  @override
  EngineKind get tipo => EngineKind.qpdf;

  @override
  String get nome => 'qpdf';

  @override
  String get descricao =>
      'Otimização estrutural sem perdas: junta objetos repetidos, recomprime '
      'os fluxos e remove o que não é usado. O conteúdo fica idêntico.';

  @override
  String get comoInstalar => Sistema.ehWindows
      ? 'Baixe em qpdf.sourceforge.io (ou use o MSYS2: pacman -S mingw-w64-x86_64-qpdf).'
      : 'Debian/Ubuntu: sudo apt install qpdf\n'
          'Fedora: sudo dnf install qpdf\n'
          'Arch: sudo pacman -S qpdf';

  @override
  String get siteOficial => 'https://qpdf.sourceforge.io/';

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
      versao: versao.replaceFirst('qpdf version ', '').split(' ').first,
    );
    return _estado;
  }

  @override
  List<String> limitacoes(CompressionOptions opcoes) {
    final avisos = <String>[
      'O qpdf não reduz imagens: em PDFs com fotos o ganho é pequeno.',
    ];
    if (opcoes.textMode == TextMode.rasterizar) {
      avisos.add('O qpdf não redesenha páginas como imagem.');
    }
    if (!opcoes.removeMetadata) {
      avisos.add('O qpdf mantém os metadados do documento.');
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
      return ResultadoMotor.falha('qpdf não está disponível');
    }
    if (opcoes.textMode == TextMode.rasterizar) {
      return ResultadoMotor.falha('O qpdf não redesenha páginas como imagem');
    }

    progresso(-1, 'Otimizando com qpdf…');

    final parcial = '$saida.parcial';
    final argumentos = <String>[
      '--object-streams=generate',
      '--compress-streams=y',
      '--recompress-flate',
      '--compression-level=9',
      '--decode-level=generalized',
      '--remove-unreferenced-resources=yes',
      '--no-warn',
      entrada,
      parcial,
    ];

    final resultado = await _rodar(argumentos, cancelamento);
    if (!resultado.sucesso) return resultado;

    // O qpdf preserva os metadados; se o usuário pediu para removê-los,
    // aplicamos a limpeza estrutural do motor nativo por cima.
    if (opcoes.removeMetadata) {
      try {
        progresso(-1, 'Removendo metadados…');
        final bytes = File(parcial).readAsBytesSync();
        final leitor = PdfReader.abrir(bytes);
        if (!leitor.criptografado) {
          final limpo = PdfOperations.reescrever(
            leitor,
            manterMetadados: false,
            manterAnotacoes: !opcoes.removeAnnotations,
            manterMiniaturas: !opcoes.removeThumbnails,
            manterMarcadores: !opcoes.removeBookmarks,
            reescreverFluxos: opcoes.recompressStreams,
            usarFluxosDeObjeto: !opcoes.compatibilidadeAntiga,
          );
          if (limpo.bytes.length < bytes.length) {
            File(parcial).writeAsBytesSync(limpo.bytes);
          }
        }
      } catch (_) {
        // A limpeza extra é um bônus: se falhar, mantemos o resultado do qpdf.
      }
    }

    _mover(parcial, saida);
    progresso(1, 'Concluído');
    return ResultadoMotor.ok(detalhe: 'qpdf ${estado.versao}');
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
      return ResultadoMotor.falha('qpdf não está disponível');
    }

    for (var i = 0; i < partes.length; i++) {
      cancelamento.verificar();
      progresso(i / math.max(1, partes.length), 'Parte ${i + 1} de ${partes.length}');

      final selecao = partes[i].map((intervalo) => intervalo.rotulo).join(',');
      final parcial = '${destinos[i]}.parcial';
      final resultado = await _rodar([
        '--empty',
        '--pages',
        entrada,
        selecao,
        '--',
        parcial,
      ], cancelamento);

      if (!resultado.sucesso) {
        return ResultadoMotor.falha('Falha na parte ${i + 1}: ${resultado.erro}');
      }
      _mover(parcial, destinos[i]);
    }

    progresso(1, 'Concluído');
    return ResultadoMotor.ok(detalhe: 'qpdf ${estado.versao}');
  }

  Future<ResultadoMotor> _rodar(
    List<String> argumentos,
    Cancelamento cancelamento,
  ) async {
    final binario = _binario;
    if (binario == null) {
      return ResultadoMotor.falha('qpdf não está disponível');
    }
    try {
      final processo = await Process.start(binario, argumentos);
      final assinatura = cancelamento.quandoCancelar.listen((_) {
        try {
          processo.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });

      final saida = StringBuffer();
      final consumidor = processo.stdout.listen(
        (dados) => saida.write(String.fromCharCodes(dados)),
      );
      final erros = StringBuffer();
      final consumidorErro = processo.stderr.listen(
        (dados) => erros.write(String.fromCharCodes(dados)),
      );

      final codigo = await processo.exitCode;
      await consumidor.cancel();
      await consumidorErro.cancel();
      await assinatura.cancel();

      if (codigo != 0) {
        final mensagem = erros.toString().trim();
        return ResultadoMotor.falha(
          mensagem.isEmpty ? 'qpdf terminou com código $codigo' : mensagem,
        );
      }
      return const ResultadoMotor.ok();
    } on ProcessException catch (erro) {
      return ResultadoMotor.falha('Não foi possível executar o qpdf',
          detalhe: '$erro');
    }
  }

  static void _mover(String origem, String destino) {
    final arquivo = File(destino);
    if (arquivo.existsSync()) arquivo.deleteSync();
    File(origem).renameSync(destino);
  }
}
