import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/services/pdf/paginas_imagem.dart';
import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';

/// Motor nativo: roda dentro do app, sem instalar nada.
///
/// Tem dois comportamentos:
/// * **Manter texto** — reescreve a estrutura do PDF (junta objetos repetidos,
///   remove o que não é usado, recomprime fluxos). Sem perdas.
/// * **Vira imagem** — desenha cada página com o pdfium e remonta o PDF com
///   JPEG (ou 1 bit por pixel, no modo preto e branco). É o que mais reduz.
class MotorNativo extends MotorPdf {
  MotorNativo();

  bool _pdfiumPronto = false;

  @override
  EngineKind get tipo => EngineKind.nativo;

  @override
  String get nome => 'Nativo (embutido)';

  @override
  String get descricao =>
      'Já vem dentro do PDF Enxuto (pdfium + código próprio). Funciona sem '
      'instalar nada e nunca envia seus arquivos para lugar nenhum.';

  @override
  String get comoInstalar => 'Nada a instalar: é o motor que acompanha o app.';

  @override
  String get siteOficial => 'https://github.com/vandreborba/pdf_enxuto';

  @override
  EstadoMotor get estado =>
      const EstadoMotor(disponivel: true, versao: 'embutido');

  @override
  bool get suportaRasterizar => true;

  @override
  Future<EstadoMotor> detectar({bool forcar = false}) async => estado;

  @override
  List<String> limitacoes(CompressionOptions opcoes) {
    if (opcoes.textMode == TextMode.manterTexto) {
      return const [
        'Sem o Ghostscript, o modo "manter texto" só limpa a estrutura: '
            'o ganho costuma ser pequeno (mas é sem perdas).',
      ];
    }
    return const [
      'Redesenhar as páginas é mais lento e o texto deixa de ser '
          'selecionável.',
    ];
  }

  // ------------------------------------------------------------- compressão
  @override
  Future<ResultadoMotor> comprimir({
    required String entrada,
    required String saida,
    required CompressionOptions opcoes,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  }) async {
    if (opcoes.textMode == TextMode.manterTexto) {
      return _estrutural(
        entrada: entrada,
        saida: saida,
        opcoes: opcoes,
        cancelamento: cancelamento,
        progresso: progresso,
      );
    }
    return _rasterizar(
      entrada: entrada,
      saida: saida,
      opcoes: opcoes,
      cancelamento: cancelamento,
      progresso: progresso,
    );
  }

  Future<ResultadoMotor> _estrutural({
    required String entrada,
    required String saida,
    required CompressionOptions opcoes,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  }) async {
    progresso(-1, 'Lendo o arquivo…');
    final arquivo = File(entrada);
    if (!arquivo.existsSync()) {
      return ResultadoMotor.falha('Arquivo não encontrado');
    }

    final bytes = await arquivo.readAsBytes();
    cancelamento.verificar();
    progresso(-1, 'Reorganizando a estrutura…');

    try {
      final resultado = await Isolate.run(
        () => _reescreverEmIsolate(
          bytes,
          opcoes.removeAnnotations,
          opcoes.removeMetadata,
          opcoes.removeThumbnails,
          opcoes.removeBookmarks,
          opcoes.recompressStreams,
          opcoes.compatibilidadeAntiga,
        ),
      );
      cancelamento.verificar();

      // Se o resultado não ficou menor, não vale a pena entregar um arquivo
      // pior: o serviço decide o que fazer com a ausência do arquivo.
      if (resultado.bytes.length >= bytes.length) {
        progresso(1, 'Concluído');
        return ResultadoMotor.ok(
          aviso:
              'Este PDF já estava bem otimizado: o resultado ficou do mesmo '
              'tamanho (ou um pouco maior) e foi descartado.',
          detalhe: 'sem ganho',
        );
      }

      await _gravar(saida, resultado.bytes);
      progresso(1, 'Concluído');
      return ResultadoMotor.ok(
        detalhe:
            'objetos ${resultado.objetosOriginais} → '
            '${resultado.objetosMantidos}, '
            'fluxos recomprimidos ${resultado.fluxosRecomprimidos}',
      );
    } on PdfCriptografadoException {
      return ResultadoMotor.falha(
        'PDF protegido por senha: remova a proteção antes de comprimir',
      );
    } catch (erro) {
      return ResultadoMotor.falha(
        'Não foi possível otimizar',
        detalhe: '$erro',
      );
    }
  }

  /// Rasteriza as páginas com o pdfium e remonta o PDF com as imagens.
  Future<ResultadoMotor> _rasterizar({
    required String entrada,
    required String saida,
    required CompressionOptions opcoes,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  }) async {
    progresso(0, 'Preparando…');
    await _garantirPdfium();

    PdfDocument? documento;
    try {
      documento = await PdfDocument.openFile(entrada);
    } catch (erro) {
      return ResultadoMotor.falha(
        'Não foi possível abrir o PDF',
        detalhe: '$erro',
      );
    }

    try {
      final total = documento.pages.length;
      if (total == 0) {
        return ResultadoMotor.falha('O PDF não tem páginas');
      }

      final escala = opcoes.dpi / 72.0;
      final imagens = <ImagemPagina>[];
      final tamanhos = <TamanhoPagina>[];

      for (var i = 0; i < total; i++) {
        cancelamento.verificar();
        progresso(i / total * 0.75, 'Desenhando página ${i + 1} de $total…');

        final pagina = documento.pages[i];
        final largura = (pagina.width * escala).round().clamp(32, 20000);
        final altura = (pagina.height * escala).round().clamp(32, 20000);

        final renderizada = await pagina.render(
          fullWidth: largura.toDouble(),
          fullHeight: altura.toDouble(),
          backgroundColor: 0xFFFFFFFF,
        );
        if (renderizada == null) continue;

        final pixels = Uint8List.fromList(renderizada.pixels);
        final larguraReal = renderizada.width;
        final alturaReal = renderizada.height;
        renderizada.dispose();

        progresso(
          (i + 0.5) / total * 0.75,
          'Comprimindo página ${i + 1} de $total…',
        );

        final modo = opcoes.colorMode;
        final qualidade = opcoes.jpegQuality;
        final codificada = await Isolate.run(
          () => codificarPagina(
            pixels,
            larguraReal,
            alturaReal,
            qualidade,
            modo.name,
          ),
        );

        imagens.add(codificada);
        tamanhos.add(
          TamanhoPagina(largura: pagina.width, altura: pagina.height),
        );
      }

      if (imagens.isEmpty) {
        return ResultadoMotor.falha('Nenhuma página pôde ser desenhada');
      }

      cancelamento.verificar();
      progresso(0.8, 'Montando o PDF…');

      final bytes = await Isolate.run(() => montarPdfDePaginas(imagens, tamanhos));
      await _gravar(saida, bytes);
      progresso(1, 'Concluído');

      return ResultadoMotor.ok(
        detalhe: '${imagens.length} páginas em ${opcoes.dpi} dpi',
        aviso: 'As páginas viraram imagens: o texto não é mais selecionável.',
      );
    } finally {
      await documento.dispose();
    }
  }

  Future<void> _garantirPdfium() async {
    if (_pdfiumPronto) return;
    await pdfrxFlutterInitialize();
    _pdfiumPronto = true;
  }

  // ---------------------------------------------------------------- divisão
  @override
  Future<ResultadoMotor> dividir({
    required String entrada,
    required List<List<PageRange>> partes,
    required List<String> destinos,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
  }) async {
    final arquivo = File(entrada);
    if (!arquivo.existsSync()) {
      return ResultadoMotor.falha('Arquivo não encontrado');
    }

    final bytes = await arquivo.readAsBytes();
    final leitor = PdfReader.abrir(bytes);
    if (leitor.criptografado) {
      return ResultadoMotor.falha(
        'PDF protegido por senha: remova a proteção antes de dividir',
      );
    }

    final total = leitor.paginas().length;
    final totalPartes = partes.length;

    for (var i = 0; i < totalPartes; i++) {
      cancelamento.verificar();
      progresso(i / totalPartes, 'Parte ${i + 1} de $totalPartes…');

      final paginas = <int>[
        for (final intervalo in partes[i])
          for (var p = intervalo.inicio; p <= intervalo.fim; p++) p,
      ];
      if (paginas.isEmpty) continue;

      // Cada parte é montada no seu próprio isolate para não travar a janela.
      final listaPaginas = List<int>.from(paginas);
      final resultado = await Isolate.run(
        () => PdfOperations.extrairPaginas(
          PdfReader.abrirBytes(bytes),
          listaPaginas,
          manterAnotacoes: true,
          manterMetadados: true,
        ).bytes,
      );
      await _gravar(destinos[i], resultado);
    }

    progresso(1, 'Concluído');
    return ResultadoMotor.ok(
      detalhe: '$totalPartes partes de $total páginas no total',
    );
  }

  static Future<void> _gravar(String caminho, Uint8List bytes) async {
    final arquivo = File(caminho);
    await arquivo.parent.create(recursive: true);
    // Grava primeiro em um arquivo temporário: nada de PDF pela metade.
    final temporario = File('$caminho.parcial');
    await temporario.writeAsBytes(bytes, flush: true);
    if (arquivo.existsSync()) arquivo.deleteSync();
    await temporario.rename(caminho);
  }
}

// ---------------------------------------------------------------------------
// Trabalho pesado (roda em isolate)
// ---------------------------------------------------------------------------

class _ResultadoReescrita {
  const _ResultadoReescrita({
    required this.bytes,
    required this.objetosOriginais,
    required this.objetosMantidos,
    required this.fluxosRecomprimidos,
  });

  final Uint8List bytes;
  final int objetosOriginais;
  final int objetosMantidos;
  final int fluxosRecomprimidos;
}

_ResultadoReescrita _reescreverEmIsolate(
  Uint8List bytes,
  bool removerAnotacoes,
  bool removerMetadados,
  bool removerMiniaturas,
  bool removerMarcadores,
  bool recomprimirFluxos,
  bool compatibilidadeAntiga,
) {
  final leitor = PdfReader.abrir(bytes);
  if (leitor.criptografado) throw PdfCriptografadoException();

  final resultado = PdfOperations.reescrever(
    leitor,
    manterAnotacoes: !removerAnotacoes,
    manterMetadados: !removerMetadados,
    manterMiniaturas: !removerMiniaturas,
    manterMarcadores: !removerMarcadores,
    reescreverFluxos: recomprimirFluxos,
    usarFluxosDeObjeto: !compatibilidadeAntiga,
  );

  return _ResultadoReescrita(
    bytes: resultado.bytes,
    objetosOriginais: resultado.objetosOriginais,
    objetosMantidos: resultado.objetosMantidos,
    fluxosRecomprimidos: resultado.fluxosRecomprimidos,
  );
}
