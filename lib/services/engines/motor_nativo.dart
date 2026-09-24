import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/services/pdf/pdf_objects.dart';
import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';
import 'package:pdf_enxuto/services/pdf/pdf_writer.dart';

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
          aviso: 'Este PDF já estava bem otimizado: o resultado ficou do mesmo '
              'tamanho (ou um pouco maior) e foi descartado.',
          detalhe: 'sem ganho',
        );
      }

      await _gravar(saida, resultado.bytes);
      progresso(1, 'Concluído');
      return ResultadoMotor.ok(
        detalhe: 'objetos ${resultado.objetosOriginais} → '
            '${resultado.objetosMantidos}, '
            'fluxos recomprimidos ${resultado.fluxosRecomprimidos}',
      );
    } on PdfCriptografadoException {
      return ResultadoMotor.falha(
        'PDF protegido por senha: remova a proteção antes de comprimir',
      );
    } catch (erro) {
      return ResultadoMotor.falha('Não foi possível otimizar', detalhe: '$erro');
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
      final imagens = <_ImagemPagina>[];
      final tamanhos = <_TamanhoPagina>[];

      for (var i = 0; i < total; i++) {
        cancelamento.verificar();
        progresso(
          i / total * 0.75,
          'Desenhando página ${i + 1} de $total…',
        );

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
          () => _codificarPagina(
            pixels,
            larguraReal,
            alturaReal,
            qualidade,
            modo.name,
          ),
        );

        imagens.add(codificada);
        tamanhos.add(
          _TamanhoPagina(
            largura: pagina.width,
            altura: pagina.height,
          ),
        );
      }

      if (imagens.isEmpty) {
        return ResultadoMotor.falha('Nenhuma página pôde ser desenhada');
      }

      cancelamento.verificar();
      progresso(0.8, 'Montando o PDF…');

      final bytes = await Isolate.run(() => _montarPdf(imagens, tamanhos));
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

/// Uma página já convertida em imagem pronta para entrar no PDF.
class _ImagemPagina {
  const _ImagemPagina({
    required this.dados,
    required this.largura,
    required this.altura,
    required this.filtro,
    required this.espacoCor,
    required this.bits,
  });

  final Uint8List dados;
  final int largura;
  final int altura;

  /// /DCTDecode (JPEG) ou /FlateDecode (1 bit por pixel).
  final String filtro;
  final String espacoCor;
  final int bits;
}

class _TamanhoPagina {
  const _TamanhoPagina({required this.largura, required this.altura});

  final double largura;
  final double altura;
}

/// Converte BGRA (pdfium) em JPEG ou em imagem de 1 bit comprimida.
_ImagemPagina _codificarPagina(
  Uint8List bgra,
  int largura,
  int altura,
  int qualidade,
  String modoCor,
) {
  final imagem = img.Image.fromBytes(
    width: largura,
    height: altura,
    bytes: bgra.buffer,
    order: img.ChannelOrder.bgra,
  );

  switch (modoCor) {
    case 'mono':
      final dados = _empacotarUmBit(imagem);
      return _ImagemPagina(
        dados: dados,
        largura: largura,
        altura: altura,
        filtro: 'FlateDecode',
        espacoCor: 'DeviceGray',
        bits: 1,
      );
    case 'cinza':
      img.grayscale(imagem);
      final jpeg = img.encodeJpg(imagem, quality: qualidade.clamp(1, 100));
      return _ImagemPagina(
        dados: Uint8List.fromList(jpeg),
        largura: largura,
        altura: altura,
        filtro: 'DCTDecode',
        espacoCor: 'DeviceGray',
        bits: 8,
      );
    default:
      final jpeg = img.encodeJpg(imagem, quality: qualidade.clamp(1, 100));
      return _ImagemPagina(
        dados: Uint8List.fromList(jpeg),
        largura: largura,
        altura: altura,
        filtro: 'DCTDecode',
        espacoCor: 'DeviceRGB',
        bits: 8,
      );
  }
}

/// Limiar de luminância + empacotamento em 1 bit por pixel (linhas alinhadas
/// em byte), que é o formato que o PDF espera em /BitsPerComponent 1.
Uint8List _empacotarUmBit(img.Image imagem) {
  final largura = imagem.width;
  final altura = imagem.height;
  final bytesPorLinha = (largura + 7) ~/ 8;
  final dados = Uint8List(bytesPorLinha * altura);

  for (var y = 0; y < altura; y++) {
    var indiceByte = y * bytesPorLinha;
    var mascara = 0x80;
    for (var x = 0; x < largura; x++) {
      final pixel = imagem.getPixel(x, y);
      final luminancia =
          0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      // 0 = preto, 1 = branco (DeviceGray com 1 bit).
      if (luminancia >= 160) dados[indiceByte] |= mascara;
      mascara >>= 1;
      if (mascara == 0) {
        mascara = 0x80;
        indiceByte++;
      }
    }
  }
  return dados;
}

/// Monta um PDF com uma página por imagem.
Uint8List _montarPdf(
  List<_ImagemPagina> imagens,
  List<_TamanhoPagina> tamanhos,
) {
  final escritor = PdfWriter(versao: '1.7');
  final refPaginas = escritor.reservar();
  final refs = <PdfRef>[];

  for (var i = 0; i < imagens.length; i++) {
    final imagem = imagens[i];
    final tamanho = i < tamanhos.length
        ? tamanhos[i]
        : _TamanhoPagina(
            largura: imagem.largura * 72 / 150,
            altura: imagem.altura * 72 / 150,
          );

    final refImagem = escritor.adicionar(
      PdfStream(
        PdfDict({
          'Type': PdfName('XObject'),
          'Subtype': PdfName('Image'),
          'Width': PdfNumber(imagem.largura),
          'Height': PdfNumber(imagem.altura),
          'ColorSpace': PdfName(imagem.espacoCor),
          'BitsPerComponent': PdfNumber(imagem.bits),
          'Filter': PdfName(imagem.filtro),
        }),
        imagem.dados,
      ),
    );

    final conteudo = PdfStream(
      const PdfDict(),
      Uint8List.fromList(
        _montarConteudo(
          tamanho.largura,
          tamanho.altura,
          imagem.largura,
          imagem.altura,
        ).codeUnits,
      ),
    );
    final refConteudo = escritor.adicionar(conteudo);

    final refPagina = escritor.adicionar(
      PdfDict({
        'Type': PdfName.page,
        'Parent': refPaginas,
        'MediaBox': PdfArray([
          const PdfNumber(0),
          const PdfNumber(0),
          PdfNumber(tamanho.largura),
          PdfNumber(tamanho.altura),
        ]),
        'Resources': PdfDict({
          'XObject': PdfDict({'Im0': refImagem}),
        }),
        'Contents': refConteudo,
      }),
    );
    refs.add(refPagina);
  }

  escritor.definirRef(
    refPaginas,
    PdfDict({
      'Type': PdfName.pages,
      'Kids': PdfArray(refs),
      'Count': PdfNumber(refs.length),
    }),
  );

  escritor.raiz = escritor.adicionar(
    PdfDict({
      'Type': PdfName.catalog,
      'Pages': refPaginas,
    }),
  );

  return escritor.escrever();
}

/// Desenha a imagem ocupando a página inteira.
String _montarConteudo(
  double larguraPagina,
  double alturaPagina,
  int larguraImagem,
  int alturaImagem,
) {
  final escala = math.min(
    larguraPagina / larguraImagem,
    alturaPagina / alturaImagem,
  );
  final largura = larguraImagem * escala;
  final altura = alturaImagem * escala;
  final x = (larguraPagina - largura) / 2;
  final y = (alturaPagina - altura) / 2;

  return 'q\n'
      '${_numero(largura)} 0 0 ${_numero(altura)} ${_numero(x)} ${_numero(y)} cm\n'
      '/Im0 Do\n'
      'Q\n';
}

String _numero(double valor) => valor.toStringAsFixed(3);
