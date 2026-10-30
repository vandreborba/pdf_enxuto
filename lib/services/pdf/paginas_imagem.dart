import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:pdf_enxuto/services/pdf/pdf_objects.dart';
import 'package:pdf_enxuto/services/pdf/pdf_writer.dart';

/// Uma página já convertida em imagem pronta para entrar no PDF.
class ImagemPagina {
  const ImagemPagina({
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

class TamanhoPagina {
  const TamanhoPagina({required this.largura, required this.altura});

  final double largura;
  final double altura;
}

/// Converte BGRA (pdfium) em JPEG ou em imagem de 1 bit comprimida.
ImagemPagina codificarPagina(
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
      return ImagemPagina(
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
      return ImagemPagina(
        dados: Uint8List.fromList(jpeg),
        largura: largura,
        altura: altura,
        filtro: 'DCTDecode',
        espacoCor: 'DeviceGray',
        bits: 8,
      );
    default:
      final jpeg = img.encodeJpg(imagem, quality: qualidade.clamp(1, 100));
      return ImagemPagina(
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
      final luminancia = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
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
///
/// Com [texto] (uma lista de palavras por página, em pixels da imagem), cada
/// página ganha uma camada de texto invisível por cima da imagem: o PDF fica
/// pesquisável e o texto selecionável, sem mudar a aparência da página.
Uint8List montarPdfDePaginas(
  List<ImagemPagina> imagens,
  List<TamanhoPagina> tamanhos, {
  List<List<PalavraPagina>>? texto,
}) {
  final escritor = PdfWriter(versao: '1.7');
  final refPaginas = escritor.reservar();
  final refs = <PdfRef>[];
  final refFonte = texto == null
      ? null
      : escritor.adicionar(
          PdfDict({
            'Type': const PdfName('Font'),
            'Subtype': const PdfName('Type1'),
            'BaseFont': const PdfName('Helvetica'),
            'Encoding': const PdfName('WinAnsiEncoding'),
          }),
        );

  for (var i = 0; i < imagens.length; i++) {
    final imagem = imagens[i];
    final tamanho = i < tamanhos.length
        ? tamanhos[i]
        : TamanhoPagina(
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
          palavras: texto != null && i < texto.length ? texto[i] : const [],
        ),
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
          if (refFonte != null) 'Font': PdfDict({'F0': refFonte}),
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
    PdfDict({'Type': PdfName.catalog, 'Pages': refPaginas}),
  );

  return escritor.escrever();
}

/// Uma palavra reconhecida, em pixels da imagem da página (origem no canto
/// superior esquerdo).
class PalavraPagina {
  const PalavraPagina({
    required this.texto,
    required this.x,
    required this.largura,
    required this.baseY,
    required this.alturaLinha,
  });

  final String texto;
  final double x;
  final double largura;

  /// Linha de base do texto (onde "descansam" as letras sem cauda).
  final double baseY;

  /// Altura da linha a que a palavra pertence; define o tamanho da fonte.
  final double alturaLinha;
}

/// Desenha a imagem ocupando a página inteira e, se houver, o texto invisível.
Uint8List _montarConteudo(
  double larguraPagina,
  double alturaPagina,
  int larguraImagem,
  int alturaImagem, {
  List<PalavraPagina> palavras = const [],
}) {
  final escala = math.min(
    larguraPagina / larguraImagem,
    alturaPagina / alturaImagem,
  );
  final largura = larguraImagem * escala;
  final altura = alturaImagem * escala;
  final x = (larguraPagina - largura) / 2;
  final y = (alturaPagina - altura) / 2;

  final saida = BytesBuilder();
  void escrever(String linha) => saida.add(linha.codeUnits);

  escrever(
    'q\n'
    '${_numero(largura)} 0 0 ${_numero(altura)} ${_numero(x)} ${_numero(y)} cm\n'
    '/Im0 Do\n'
    'Q\n',
  );

  if (palavras.isNotEmpty) {
    // 3 Tr = texto sem preenchimento e sem contorno (invisível).
    escrever('BT\n3 Tr\n');
    for (final palavra in palavras) {
      final bytes = TextoWinAnsi.codificar(palavra.texto);
      if (bytes.isEmpty) continue;
      final tamanho = (palavra.alturaLinha * escala * 0.85).clamp(1.0, 200.0);
      final natural = TextoWinAnsi.larguraHelvetica(palavra.texto) * tamanho;
      final alvo = palavra.largura * escala;
      if (natural <= 0 || alvo <= 0) continue;
      final horizontal = (alvo / natural * 100).clamp(10.0, 500.0);
      final px = x + palavra.x * escala;
      final py = y + (alturaImagem - palavra.baseY) * escala;

      escrever(
        '/F0 ${_numero(tamanho)} Tf\n'
        '${_numero(horizontal)} Tz\n'
        '1 0 0 1 ${_numero(px)} ${_numero(py)} Tm\n(',
      );
      for (final byte in bytes) {
        if (byte == 0x28 || byte == 0x29 || byte == 0x5C) saida.addByte(0x5C);
        saida.addByte(byte);
      }
      escrever(') Tj\n');
    }
    escrever('ET\n');
  }
  return saida.toBytes();
}

String _numero(double valor) => valor.toStringAsFixed(3);

/// Texto na codificação WinAnsi (a das fontes padrão do PDF) e a largura
/// aproximada em Helvetica, usada para esticar o texto invisível até cobrir a
/// palavra da imagem.
class TextoWinAnsi {
  TextoWinAnsi._();

  static const Map<String, int> _cp1252 = {
    '€': 0x80,
    '‚': 0x82,
    'ƒ': 0x83,
    '„': 0x84,
    '…': 0x85,
    '†': 0x86,
    '‡': 0x87,
    'ˆ': 0x88,
    '‰': 0x89,
    'Š': 0x8A,
    '‹': 0x8B,
    'Œ': 0x8C,
    'Ž': 0x8E,
    '‘': 0x91,
    '’': 0x92,
    '“': 0x93,
    '”': 0x94,
    '•': 0x95,
    '–': 0x96,
    '—': 0x97,
    '˜': 0x98,
    '™': 0x99,
    'š': 0x9A,
    '›': 0x9B,
    'œ': 0x9C,
    'ž': 0x9E,
    'Ÿ': 0x9F,
  };

  static const Map<String, String> _substituicoes = {
    'ﬁ': 'fi',
    'ﬂ': 'fl',
    'ﬀ': 'ff',
    '\u00A0': ' ',
    '\u2009': ' ',
    '\u200B': '',
  };

  /// Converte para bytes WinAnsi; o que não existe nessa tabela vira `?`.
  static List<int> codificar(String texto) {
    final bytes = <int>[];
    for (final rune in texto.runes) {
      final caractere = String.fromCharCode(rune);
      final troca = _substituicoes[caractere];
      if (troca != null) {
        bytes.addAll(troca.codeUnits);
        continue;
      }
      if (rune >= 0x20 && rune < 0x7F || rune >= 0xA0 && rune <= 0xFF) {
        bytes.add(rune);
      } else if (_cp1252[caractere] != null) {
        bytes.add(_cp1252[caractere]!);
      } else if (rune >= 0x20) {
        bytes.add(0x3F);
      }
    }
    return bytes;
  }

  // Larguras da Helvetica (em milésimos de em) para ASCII 32..126.
  static const List<int> _larguras = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278,
    278, // espaço .. /
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, // 0-9
    278, 278, 584, 584, 584, 556, 1015, // : .. @
    667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, // A-Z
    278, 278, 278, 469, 556, 333, // [ \ ] ^ _ `
    556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
    556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, // a-z
    334, 260, 334, 584, // { | } ~
  ];

  static const String _comAcento =
      'ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖòóôõöÙÚÛÜùúûü';
  static const String _base =
      'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOoooooUUUUuuuu';

  /// Largura do texto em "ems" (multiplique pelo tamanho da fonte).
  static double larguraHelvetica(String texto) {
    var total = 0;
    for (final rune in texto.runes) {
      var codigo = rune;
      final indiceAcento = _comAcento.indexOf(String.fromCharCode(rune));
      if (indiceAcento >= 0) codigo = _base.codeUnitAt(indiceAcento);
      total += codigo >= 32 && codigo <= 126 ? _larguras[codigo - 32] : 556;
    }
    return total / 1000;
  }
}
