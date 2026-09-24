import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/models/pdf_file_info.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';

/// Lê um PDF e devolve o que o app precisa saber: páginas, marcadores,
/// metadados e problemas (senha, arquivo corrompido, base64).
class InspecaoPdf {
  InspecaoPdf._();

  /// Detecta o cabeçalho em qualquer lugar dos primeiros KB: alguns arquivos
  /// chegam com lixo antes do `%PDF-`.
  static bool parecePdf(Uint8List dados) {
    final limite = dados.length < 4096 ? dados.length : 4096;
    for (var i = 0; i + 5 <= limite; i++) {
      if (dados[i] == 0x25 && // %
          dados[i + 1] == 0x50 && // P
          dados[i + 2] == 0x44 && // D
          dados[i + 3] == 0x46 && // F
          dados[i + 4] == 0x2D) {
        return true;
      }
    }
    return false;
  }

  /// Alguns downloads vêm com o PDF codificado em base64. O app percebe e
  /// usa o conteúdo de verdade.
  static Uint8List? decodificarBase64(Uint8List dados) {
    if (dados.length < 8) return null;
    final inicio = latin1.decode(dados.sublist(0, 8), allowInvalid: true);
    if (!inicio.startsWith('JVBERi0')) return null;
    try {
      final texto = utf8
          .decode(dados, allowMalformed: true)
          .replaceAll(RegExp(r'\s'), '');
      final decodificado = base64.decode(texto);
      return Uint8List.fromList(decodificado);
    } catch (_) {
      return null;
    }
  }

  /// Lê o arquivo e monta o [PdfFileInfo]. O trabalho pesado roda em isolate
  /// para a janela não travar em PDFs grandes.
  static Future<PdfFileInfo> inspecionar(String caminho) async {
    final arquivo = File(caminho);
    if (!await arquivo.exists()) {
      return PdfFileInfo.comErro(caminho, 'Arquivo não encontrado');
    }

    final tamanho = await arquivo.length();
    if (tamanho == 0) {
      return PdfFileInfo.comErro(caminho, 'O arquivo está vazio');
    }

    final bytes = await arquivo.readAsBytes();

    // PDF em base64: decodifica antes de qualquer coisa.
    var dados = bytes;
    var eraBase64 = false;
    if (!parecePdf(bytes)) {
      final decodificado = decodificarBase64(bytes);
      if (decodificado != null) {
        dados = decodificado;
        eraBase64 = true;
      }
    }

    if (!parecePdf(dados)) {
      return PdfFileInfo.comErro(
        caminho,
        'O arquivo não parece ser um PDF',
      ).copyWith(bytes: tamanho);
    }

    final resumo = await Isolate.run(() => _lerResumo(dados, tamanho));
    return resumo.copyWith(
      bytes: eraBase64 ? dados.length : tamanho,
      aviso: eraBase64
          ? 'O arquivo estava codificado em base64 e foi lido normalmente.'
          : null,
    );
  }

  static PdfFileInfo _lerResumo(Uint8List dados, int tamanho) {
    try {
      final leitor = PdfReader.abrir(dados);
      if (leitor.criptografado) {
        return PdfFileInfo(
          caminho: '',
          bytes: tamanho,
          paginas: 0,
          criptografado: true,
          erro: 'PDF protegido por senha',
        );
      }

      final paginas = leitor.paginas();
      if (paginas.isEmpty) {
        return PdfFileInfo.comErro(
          '',
          'Não foi possível encontrar as páginas deste PDF',
        ).copyWith(bytes: tamanho);
      }

      return PdfFileInfo(
        caminho: '',
        bytes: tamanho,
        paginas: paginas.length,
        marcadores: [
          for (final marcador in leitor.marcadores())
            PdfBookmark(
              titulo: marcador.titulo,
              pagina: marcador.pagina,
              nivel: marcador.nivel,
            ),
        ],
        titulo: leitor.titulo,
        autor: leitor.autor,
        produtor: leitor.produtor,
      );
    } catch (erro) {
      return PdfFileInfo.comErro(
        '',
        'Falha ao ler o PDF: $erro',
      ).copyWith(bytes: tamanho);
    }
  }

  // ------------------------------------------------------------- miniaturas
  static final Map<String, Uint8List?> _cacheMiniaturas = {};
  static bool _pdfiumPronto = false;

  /// Desenha a primeira página em miniatura (PNG), para os cards da fila.
  static Future<Uint8List?> miniatura(
    String caminho, {
    int largura = 150,
  }) async {
    if (_cacheMiniaturas.containsKey(caminho)) {
      return _cacheMiniaturas[caminho];
    }

    PdfDocument? documento;
    try {
      if (!_pdfiumPronto) {
        await pdfrxFlutterInitialize();
        _pdfiumPronto = true;
      }

      documento = await PdfDocument.openFile(caminho);
      if (documento.pages.isEmpty) return null;

      final pagina = documento.pages.first;
      final escala = largura / pagina.width;
      final renderizada = await pagina.render(
        fullWidth: largura.toDouble(),
        fullHeight: (pagina.height * escala).roundToDouble(),
        backgroundColor: 0xFFFFFFFF,
      );
      if (renderizada == null) return null;

      final imagem = img.Image.fromBytes(
        width: renderizada.width,
        height: renderizada.height,
        bytes: renderizada.pixels.buffer,
        order: img.ChannelOrder.bgra,
      );
      renderizada.dispose();

      final png = Uint8List.fromList(img.encodePng(imagem, level: 6));
      if (_cacheMiniaturas.length > 60) _cacheMiniaturas.clear();
      _cacheMiniaturas[caminho] = png;
      return png;
    } catch (_) {
      _cacheMiniaturas[caminho] = null;
      return null;
    } finally {
      await documento?.dispose();
    }
  }

  static void limparMiniaturas() => _cacheMiniaturas.clear();
}
