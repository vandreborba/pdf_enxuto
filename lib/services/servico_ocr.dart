import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/ocr_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/ocr/motor_tesseract.dart';
import 'package:pdf_enxuto/services/pdf/paginas_imagem.dart';
import 'package:pdf_enxuto/services/servico_arquivos.dart';
import 'package:pdf_enxuto/services/tabela/extrator_texto.dart';

/// O que o teste na primeira página mostra antes de processar tudo.
class PreviaOcr {
  const PreviaOcr({
    required this.pagina,
    required this.totalPaginas,
    required this.texto,
    required this.palavras,
    required this.confianca,
    required this.jaTinhaTexto,
  });

  /// Página testada (1 = primeira).
  final int pagina;
  final int totalPaginas;
  final String texto;
  final int palavras;
  final double? confianca;

  /// A página já tinha texto de verdade antes do reconhecimento.
  final bool jaTinhaTexto;

  bool get leuAlgo => palavras > 0;
}

/// Reconhecimento de texto (OCR): transforma páginas digitalizadas em PDF
/// pesquisável e/ou texto. Tudo local.
class ServicoOcr {
  ServicoOcr();

  final MotorTesseract motor = MotorTesseract();

  /// Teto de lado da imagem lida: uma página enorme (planta, cartaz) em 300
  /// dpi passaria de centenas de megapixels e esgotaria a memória.
  static const int maxLadoPixels = 9000;

  /// Nome do motor mostrado no resultado.
  String get rotuloMotor {
    final estado = motor.estado;
    final versao = estado.versao == null ? '' : ' ${estado.versao}';
    return 'Tesseract$versao${estado.embutido ? ' (embutido)' : ''}';
  }

  // ------------------------------------------------------------------ prévia
  /// Lê só a primeira página escolhida, com as mesmas opções da conversão.
  Future<PreviaOcr> previa({
    required String caminho,
    required OpcoesOcr opcoes,
    required Cancelamento cancelamento,
  }) async {
    await ExtratorTexto.garantirInicializacao();
    final documento = await PdfDocument.openFile(caminho);
    final pasta = Sistema.criarPastaTemporaria('ocr_previa_');
    try {
      final total = documento.pages.length;
      final paginas = _paginasEscolhidas(opcoes.paginas, total);
      if (paginas.isEmpty) throw FormatException(S.ocrPaginasInvalidas);

      final numero = paginas.first;
      final lida = await _lerPagina(
        documento: documento,
        numero: numero,
        opcoes: opcoes,
        pasta: pasta.path,
        gerarImagem: false,
        cancelamento: cancelamento,
      );
      return PreviaOcr(
        pagina: numero,
        totalPaginas: total,
        texto: lida.leitura.texto,
        palavras: lida.leitura.palavras.length,
        confianca: lida.leitura.confianca,
        jaTinhaTexto: lida.jaTinhaTexto,
      );
    } finally {
      await documento.dispose();
      _apagar(pasta);
    }
  }

  // --------------------------------------------------------------- conversão
  Future<ItemResult> reconhecer({
    required String entrada,
    required OpcoesOcr opcoes,
    required Cancelamento cancelamento,
    required void Function(double fracao, String etapa) progresso,
    required bool sobrescrever,
    String? pastaSaida,
  }) async {
    final cronometro = Stopwatch()..start();
    final bytesEntrada = ServicoArquivos.tamanho(entrada);

    ItemResult falha(String mensagem) => ItemResult(
      entrada: entrada,
      saidas: const [],
      bytesAntes: bytesEntrada,
      bytesDepois: bytesEntrada,
      duracao: cronometro.elapsed,
      motor: rotuloMotor,
      erro: mensagem,
    );

    if (!motor.disponivel) return falha(S.ocrSemMotor);
    if (!opcoes.temSaida) return falha(S.ocrSemSaida);

    Directory? pasta;
    PdfDocument? documento;
    try {
      progresso(0, 'Abrindo o PDF…');
      await ExtratorTexto.garantirInicializacao();
      documento = await PdfDocument.openFile(entrada);

      final total = documento.pages.length;
      final paginas = _paginasEscolhidas(opcoes.paginas, total);
      if (total == 0) return falha(S.planilhaSemPaginas);
      if (paginas.isEmpty) return falha(S.ocrPaginasInvalidas);

      // Todas as páginas já têm texto: não há o que reconhecer. A checagem
      // para na primeira página sem texto, então é barata em digitalizações.
      if (!opcoes.refazerComTexto &&
          await _todasComTexto(documento, paginas, cancelamento)) {
        return falha(S.ocrJaTemTexto);
      }

      pasta = Sistema.criarPastaTemporaria('ocr_');
      final quantidade = paginas.length;
      final lidas = List<PaginaReconhecida?>.filled(quantidade, null);
      final imagens = List<ImagemPagina?>.filled(quantidade, null);
      final tamanhos = List<TamanhoPagina?>.filled(quantidade, null);
      var jaTinhamTexto = 0;
      var prontas = 0;
      var proxima = 0;
      Object? erroTrabalho;
      StackTrace? pilhaTrabalho;

      Future<void> trabalhador() async {
        while (erroTrabalho == null) {
          cancelamento.verificar();
          final indice = proxima++;
          if (indice >= quantidade) return;
          try {
            final pagina = await _lerPagina(
              documento: documento!,
              numero: paginas[indice],
              opcoes: opcoes,
              pasta: pasta!.path,
              gerarImagem: opcoes.gerarPdf,
              cancelamento: cancelamento,
            );
            lidas[indice] = pagina.leitura;
            imagens[indice] = pagina.imagem;
            tamanhos[indice] = pagina.tamanho;
            if (pagina.jaTinhaTexto) jaTinhamTexto++;
          } catch (erro, pilha) {
            erroTrabalho ??= erro;
            pilhaTrabalho ??= pilha;
            return;
          }
          prontas++;
          progresso(
            0.92 * prontas / quantidade,
            'Lendo a página $prontas de $quantidade…',
          );
        }
      }

      await Future.wait([
        for (var i = 0; i < _trabalhadores(quantidade); i++) trabalhador(),
      ]);
      if (erroTrabalho != null) {
        Error.throwWithStackTrace(
          erroTrabalho!,
          pilhaTrabalho ?? StackTrace.current,
        );
      }
      cancelamento.verificar();

      final palavrasTotal = lidas.fold<int>(
        0,
        (soma, pagina) => soma + (pagina?.palavras.length ?? 0),
      );
      if (palavrasTotal == 0) return falha(S.ocrSemTexto);

      progresso(0.94, 'Gravando…');
      final saidas = <String>[];

      if (opcoes.gerarPdf) {
        final bytes = await _montarPdf(
          [for (final i in imagens) i!],
          [for (final t in tamanhos) t!],
          [for (final l in lidas) l!.palavras],
        );
        cancelamento.verificar();
        final caminho = ServicoArquivos.caminhoFinal(
          ServicoArquivos.caminhoComprimido(
            entrada,
            pastaSaida,
            sufixo: ServicoArquivos.sufixoOcr,
          ),
          sobrescrever: sobrescrever,
        );
        await _gravar(caminho, bytes);
        saidas.add(caminho);
      }

      if (opcoes.gerarTxt) {
        final texto = [
          for (final pagina in lidas)
            if (pagina != null && pagina.texto.isNotEmpty) pagina.texto,
        ].join('\n\n');
        final caminho = ServicoArquivos.caminhoFinal(
          ServicoArquivos.caminhoSaida(entrada, pastaSaida, 'txt'),
          sobrescrever: sobrescrever,
        );
        await _gravar(caminho, Uint8List.fromList(_utf8ComBom(texto)));
        saidas.add(caminho);
      }

      var bytesSaida = 0;
      for (final saida in saidas) {
        bytesSaida += ServicoArquivos.tamanho(saida);
      }
      progresso(1, '');

      final confiancas = [
        for (final pagina in lidas)
          if (pagina?.confianca != null) pagina!.confianca!,
      ];
      final media = confiancas.isEmpty
          ? null
          : confiancas.reduce((a, b) => a + b) / confiancas.length;

      return ItemResult(
        entrada: entrada,
        saidas: saidas,
        bytesAntes: bytesEntrada,
        bytesDepois: bytesSaida,
        duracao: cronometro.elapsed,
        motor: rotuloMotor,
        aviso: montarAviso(
          paginasLidas: quantidade,
          paginasSemTexto: lidas.where((l) => l?.vazia ?? true).length,
          confianca: media,
          jaTinhamTexto: jaTinhamTexto,
          gerouPdf: opcoes.gerarPdf,
        ),
        detalhe:
            '$quantidade ${quantidade == 1 ? 'página' : 'páginas'}'
            '${media == null ? '' : ' • confiança ${media.round()}%'}',
      );
    } on OperacaoCancelada {
      return falha(S.erroCancelado);
    } catch (erro) {
      final texto = '$erro';
      if (texto.contains('PDFium') ||
          texto.contains('pdfium') ||
          texto.contains('Native assets')) {
        return falha(S.planilhaMotorIndisponivel);
      }
      return falha('${S.ocrFalhou}: $erro');
    } finally {
      await documento?.dispose();
      if (pasta != null) _apagar(pasta);
    }
  }

  // ------------------------------------------------------------------ apoio
  /// Páginas a reconhecer (1 = primeira). Texto vazio = todas.
  static List<int> _paginasEscolhidas(String texto, int total) {
    if (texto.trim().isEmpty) return [for (var i = 1; i <= total; i++) i];
    final leitura = PageRangeParser.parse(texto, totalPaginas: total);
    if (!leitura.valido) return const [];
    final vistas = <int>{};
    for (final intervalo in leitura.intervalos) {
      vistas.addAll(intervalo.paginas);
    }
    return (vistas.toList()..sort());
  }

  static Future<bool> _todasComTexto(
    PdfDocument documento,
    List<int> paginas,
    Cancelamento cancelamento,
  ) async {
    for (final numero in paginas) {
      cancelamento.verificar();
      final texto = await documento.pages[numero - 1].loadStructuredText();
      if (ExtratorTexto.palavrasDe(texto).isEmpty) return false;
    }
    return true;
  }

  /// Quantas páginas lidas ao mesmo tempo. Cada processo do Tesseract usa uma
  /// thread; mais que isso só gasta memória com páginas esperando.
  static int _trabalhadores(int paginas) {
    final porNucleos = (Sistema.nucleos / 2).floor().clamp(1, 4);
    return paginas < porNucleos ? paginas : porNucleos;
  }

  /// Desenha a página, entrega ao Tesseract e (se pedido) prepara a imagem
  /// que vai para dentro do PDF pesquisável.
  Future<
    ({
      PaginaReconhecida leitura,
      ImagemPagina? imagem,
      TamanhoPagina tamanho,
      bool jaTinhaTexto,
    })
  >
  _lerPagina({
    required PdfDocument documento,
    required int numero,
    required OpcoesOcr opcoes,
    required String pasta,
    required bool gerarImagem,
    required Cancelamento cancelamento,
  }) async {
    final pagina = documento.pages[numero - 1];
    final jaTinhaTexto = ExtratorTexto.palavrasDe(
      await pagina.loadStructuredText(),
    ).isNotEmpty;

    var escala = opcoes.qualidade.dpi / 72.0;
    final maior = pagina.width > pagina.height ? pagina.width : pagina.height;
    if (maior * escala > maxLadoPixels) escala = maxLadoPixels / maior;
    final largura = (pagina.width * escala).round().clamp(32, maxLadoPixels);
    final altura = (pagina.height * escala).round().clamp(32, maxLadoPixels);

    cancelamento.verificar();
    final renderizada = await pagina.render(
      fullWidth: largura.toDouble(),
      fullHeight: altura.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (renderizada == null) {
      throw StateError('Não foi possível desenhar a página $numero');
    }
    final pixels = Uint8List.fromList(renderizada.pixels);
    final larguraReal = renderizada.width;
    final alturaReal = renderizada.height;
    renderizada.dispose();

    final arquivo =
        '$pasta${Platform.pathSeparator}p$numero.pgm';
    final jpeg = opcoes.qualidadeImagem.jpeg;
    final modoCor = opcoes.cor.name;
    final imagem = await Isolate.run(
      () => prepararPagina(
        pixels,
        larguraReal,
        alturaReal,
        arquivo,
        gerarImagem ? jpeg : null,
        modoCor,
      ),
    );
    cancelamento.verificar();

    try {
      final leitura = await motor.reconhecer(
        imagem: arquivo,
        idiomas: opcoes.idiomasTesseract,
        psm: opcoes.tipoPagina.psm,
        dpi: (larguraReal / pagina.width * 72).round().clamp(70, 600),
        cancelamento: cancelamento,
      );
      return (
        leitura: leitura,
        imagem: imagem,
        tamanho: TamanhoPagina(largura: pagina.width, altura: pagina.height),
        jaTinhaTexto: jaTinhaTexto,
      );
    } finally {
      try {
        File(arquivo).deleteSync();
      } catch (_) {
        // A pasta toda é apagada no fim.
      }
    }
  }

  /// Grava a página em PGM (o que o Tesseract lê sem custo de decodificação)
  /// e, se pedido, codifica a imagem do PDF. Roda em isolate.
  @pragma('vm:entry-point')
  static ImagemPagina? prepararPagina(
    Uint8List bgra,
    int largura,
    int altura,
    String arquivo,
    int? qualidadeJpeg,
    String modoCor,
  ) {
    final cabecalho = 'P5\n$largura $altura\n255\n'.codeUnits;
    final pgm = Uint8List(cabecalho.length + largura * altura);
    pgm.setRange(0, cabecalho.length, cabecalho);
    var destino = cabecalho.length;
    for (var i = 0; i < bgra.length; i += 4) {
      // Luminância inteira: (0,30 R + 0,59 G + 0,11 B).
      pgm[destino++] = (bgra[i + 2] * 77 + bgra[i + 1] * 151 + bgra[i] * 28) >> 8;
    }
    File(arquivo).writeAsBytesSync(pgm, flush: true);

    if (qualidadeJpeg == null) return null;
    return codificarPagina(bgra, largura, altura, qualidadeJpeg, modoCor);
  }

  /// Monta o PDF em outro isolate. Fica em um método à parte de propósito: a
  /// closure do `Isolate.run` não pode enxergar o documento do pdfium, que
  /// não atravessa isolates.
  static Future<Uint8List> _montarPdf(
    List<ImagemPagina> imagens,
    List<TamanhoPagina> tamanhos,
    List<List<PalavraPagina>> texto,
  ) => Isolate.run(() => montarPdfDePaginas(imagens, tamanhos, texto: texto));

  static void _apagar(Directory pasta) {
    try {
      pasta.deleteSync(recursive: true);
    } catch (_) {
      // Limpeza é cortesia: o app apaga temporários antigos ao abrir.
    }
  }

  static Future<void> _gravar(String caminho, Uint8List bytes) async {
    final arquivo = File(caminho);
    await arquivo.parent.create(recursive: true);
    // Grava primeiro em um arquivo temporário: nada de arquivo pela metade.
    final temporario = File('$caminho.parcial');
    await temporario.writeAsBytes(bytes, flush: true);
    if (arquivo.existsSync()) arquivo.deleteSync();
    await temporario.rename(caminho);
  }

  /// UTF-8 com marca de ordem: o Bloco de Notas do Windows só reconhece
  /// acentos assim.
  static List<int> _utf8ComBom(String texto) => [
    0xEF,
    0xBB,
    0xBF,
    ...const Utf8Encoder().convert(texto),
  ];

  /// Avisos do resultado, em português claro.
  static String? montarAviso({
    required int paginasLidas,
    required int paginasSemTexto,
    required double? confianca,
    required int jaTinhamTexto,
    required bool gerouPdf,
  }) {
    final avisos = <String>[];
    if (paginasSemTexto > 0) {
      avisos.add(
        '${paginasSemTexto == 1 ? '1 página não teve texto reconhecido' : '$paginasSemTexto páginas não tiveram texto reconhecido'} '
        '(em branco ou só imagem).',
      );
    }
    if (confianca != null && confianca < 70) {
      avisos.add(S.ocrConfiancaBaixa);
    }
    if (jaTinhamTexto > 0 && gerouPdf) {
      avisos.add(
        '${jaTinhamTexto == 1 ? '1 página já tinha texto' : '$jaTinhamTexto páginas já tinham texto'}: '
        'no PDF novo ${jaTinhamTexto == 1 ? 'ela virou' : 'elas viraram'} imagem.',
      );
    }
    return avisos.isEmpty ? null : avisos.join(' ');
  }

  /// Resumo curto das opções, usado no histórico.
  static String descrever(OpcoesOcr opcoes) {
    final idiomas = [
      for (final codigo in opcoes.idiomas)
        IdiomaOcr.porCodigo(codigo)?.nome ?? codigo,
    ].join(' + ');
    final saidas = [
      if (opcoes.gerarPdf) 'PDF pesquisável',
      if (opcoes.gerarTxt) 'texto',
    ].join(' + ');
    return '$saidas • $idiomas • ${opcoes.qualidade.rotulo.toLowerCase()}';
  }
}
