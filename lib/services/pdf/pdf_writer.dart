import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

import 'package:pdf_enxuto/services/pdf/pdf_objects.dart';

/// Escreve um arquivo PDF novo a partir de objetos montados em memória.
///
/// Dois formatos de saída:
/// * fluxos de objeto + fluxo xref (PDF 1.5+, arquivos menores) — padrão;
/// * tabela xref clássica (máxima compatibilidade).
///
/// O escritor nunca reinterpreta o conteúdo das páginas: fluxos de imagem,
/// fonte ou conteúdo são gravados byte a byte, exatamente como vieram.
class PdfWriter {
  PdfWriter({this.versao = '1.7'});

  final String versao;

  final Map<int, PdfObject> _objetos = {};
  int _proximo = 1;

  /// Objeto raiz (catálogo).
  PdfRef? raiz;

  /// Dicionário /Info opcional (autor, título, produtor).
  PdfRef? info;

  /// Metadados XMP opcionais.
  PdfRef? metadadosXmp;

  /// Extras acrescentados ao trailer.
  final Map<String, PdfObject> trailerExtra = {};

  int get quantidadeObjetos => _objetos.length;

  /// Reserva um número de objeto para preencher depois (evita ciclos).
  PdfRef reservar() {
    final referencia = PdfRef(_proximo);
    _proximo++;
    return referencia;
  }

  void definir(int numero, PdfObject objeto) {
    _objetos[numero] = objeto;
    if (numero >= _proximo) _proximo = numero + 1;
  }

  void definirRef(PdfRef referencia, PdfObject objeto) =>
      definir(referencia.numero, objeto);

  PdfRef adicionar(PdfObject objeto) {
    final referencia = reservar();
    definirRef(referencia, objeto);
    return referencia;
  }

  PdfObject? obter(int numero) => _objetos[numero];

  /// Serializa um objeto (sem stream) para bytes.
  static Uint8List serializar(PdfObject objeto) {
    final buffer = BytesBuilder(copy: false);
    _escrever(objeto, buffer);
    return buffer.takeBytes();
  }

  Uint8List escrever({bool usarFluxosDeObjeto = true}) {
    if (raiz == null) {
      throw StateError('PDF sem objeto raiz (catálogo)');
    }
    return usarFluxosDeObjeto
        ? _escreverComFluxosDeObjeto()
        : _escreverClassico();
  }

  // ------------------------------------------------------------- clássico
  Uint8List _escreverClassico() {
    final saida = BytesBuilder(copy: false);
    _cabecalho(saida);
    final offsets = <int, int>{};

    final numeros = _objetos.keys.toList()..sort();
    for (final numero in numeros) {
      offsets[numero] = saida.length;
      saida.add(latin1.encode('$numero 0 obj\n'));
      _escrever(_objetos[numero]!, saida);
      saida.add(latin1.encode('\nendobj\n'));
    }

    final posicaoXref = saida.length;
    final tamanho = _proximo;
    saida.add(latin1.encode('xref\n0 $tamanho\n'));
    saida.add(latin1.encode('0000000000 65535 f \n'));
    for (var numero = 1; numero < tamanho; numero++) {
      final offset = offsets[numero];
      if (offset == null) {
        saida.add(latin1.encode('0000000000 65535 f \n'));
      } else {
        saida.add(
          latin1.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'),
        );
      }
    }

    saida.add(latin1.encode('trailer\n'));
    _escrever(_montarTrailer(tamanho), saida);
    saida.add(latin1.encode('\nstartxref\n$posicaoXref\n%%EOF\n'));
    return saida.takeBytes();
  }

  // ------------------------------------------- fluxos de objeto + xref stm
  Uint8List _escreverComFluxosDeObjeto() {
    const maxPorFluxo = 120;
    const maxBytesFluxo = 4 * 1024 * 1024;

    final streams = <int>[];
    final simples = <int>[];
    // Catálogo e /Info ficam fora dos fluxos de objeto: assim até leitores
    // antigos que ignoram /ObjStm ainda encontram a raiz do documento.
    final foraDoFluxo = <int>{
      if (raiz != null) raiz!.numero,
      if (info != null) info!.numero,
      if (metadadosXmp != null) metadadosXmp!.numero,
    };
    for (final numero in _objetos.keys) {
      if (_objetos[numero] is PdfStream || foraDoFluxo.contains(numero)) {
        streams.add(numero);
      } else {
        simples.add(numero);
      }
    }
    streams.sort();
    simples.sort();

    final saida = BytesBuilder(copy: false);
    _cabecalho(saida);

    final offsets = <int, int>{};
    final emFluxo = <int, (int, int)>{};
    final fluxosGerados = <int>[];

    // Agrupa objetos simples em /ObjStm comprimidos.
    for (var i = 0; i < simples.length; i += maxPorFluxo) {
      // Descobre quantos objetos cabem neste fluxo antes de montá-lo.
      var limite = i;
      var acumulado = 0;
      while (limite < simples.length && limite - i < maxPorFluxo) {
        final bytes = serializar(_objetos[simples[limite]]!);
        if (limite > i && acumulado + bytes.length > maxBytesFluxo) break;
        acumulado += bytes.length + 1;
        limite++;
      }

      final usados = simples.sublist(i, limite);
      if (usados.isEmpty) continue;

      final corpo = BytesBuilder(copy: false);
      final cabecalhoStm = StringBuffer();
      var deslocamento = 0;
      for (final numero in usados) {
        final bytes = serializar(_objetos[numero]!);
        cabecalhoStm.write('$numero $deslocamento ');
        corpo.add(bytes);
        corpo.addByte(0x20);
        deslocamento += bytes.length + 1;
      }

      final cabecalhoBytes = latin1.encode(cabecalhoStm.toString());
      final conteudo = BytesBuilder(copy: false)
        ..add(cabecalhoBytes)
        ..add(corpo.takeBytes());
      final comprimido = _comprimir(conteudo.takeBytes());

      final referencia = reservar();
      final dict = PdfDict({
        'Type': PdfName.objStm,
        'N': PdfNumber(usados.length),
        'First': PdfNumber(cabecalhoBytes.length),
        'Filter': PdfName.flate,
        'Length': PdfNumber(comprimido.length),
      });
      definirRef(referencia, PdfStream(dict, comprimido));
      fluxosGerados.add(referencia.numero);

      for (var j = 0; j < usados.length; j++) {
        emFluxo[usados[j]] = (referencia.numero, j);
      }
    }

    // Objetos de nível superior (fluxos de verdade e os fluxos de objeto).
    fluxosGerados.sort();
    for (final numero in [...streams, ...fluxosGerados]) {
      offsets[numero] = saida.length;
      saida.add(latin1.encode('$numero 0 obj\n'));
      _escrever(_objetos[numero]!, saida);
      saida.add(latin1.encode('\nendobj\n'));
    }

    // Fluxo xref (que também guarda o trailer).
    final referenciaXref = reservar();
    final posicaoXref = saida.length;
    offsets[referenciaXref.numero] = posicaoXref;
    final xref = _montarFluxoXref(referenciaXref.numero + 1, offsets, emFluxo);

    saida.add(latin1.encode('${referenciaXref.numero} 0 obj\n'));
    _escrever(xref, saida);
    saida.add(latin1.encode('\nendobj\n'));

    saida.add(latin1.encode('startxref\n$posicaoXref\n%%EOF\n'));
    return saida.takeBytes();
  }

  PdfStream _montarFluxoXref(
    int tamanho,
    Map<int, int> offsets,
    Map<int, (int, int)> emFluxo,
  ) {
    // O campo de deslocamento tem 4 bytes: cobre arquivos de até 4 GB.
    const larguraOffset = 4;
    const mascaraOffset = 0xFFFFFFFF;
    final linhas = <List<int>>[];

    for (var numero = 0; numero < tamanho; numero++) {
      if (numero == 0) {
        linhas.add([0, 0, 65535]);
        continue;
      }
      final offset = offsets[numero];
      if (offset != null) {
        linhas.add([1, offset & mascaraOffset, 0]);
        continue;
      }
      final dentro = emFluxo[numero];
      if (dentro != null) {
        linhas.add([2, dentro.$1 & mascaraOffset, dentro.$2]);
        continue;
      }
      linhas.add([0, 0, 0]);
    }

    final bytes = Uint8List(linhas.length * (1 + larguraOffset + 2));
    var posicao = 0;
    for (final linha in linhas) {
      bytes[posicao++] = linha[0];
      var offset = linha[1];
      for (var i = larguraOffset - 1; i >= 0; i--) {
        bytes[posicao + i] = offset & 0xFF;
        offset >>= 8;
      }
      posicao += larguraOffset;
      bytes[posicao++] = (linha[2] >> 8) & 0xFF;
      bytes[posicao++] = linha[2] & 0xFF;
    }

    final comprimido = _comprimir(bytes);
    final dict = PdfDict({
      'Type': PdfName.xref,
      'Size': PdfNumber(tamanho),
      'W': PdfArray([
        const PdfNumber(1),
        const PdfNumber(larguraOffset),
        const PdfNumber(2),
      ]),
      'Filter': PdfName.flate,
      'Length': PdfNumber(comprimido.length),
      'Root': ?raiz,
      'Info': ?info,
      ..._extrasSimples(),
    });
    return PdfStream(dict, comprimido);
  }

  PdfDict _montarTrailer(int tamanho) {
    return PdfDict({
      'Size': PdfNumber(tamanho),
      'Root': ?raiz,
      'Info': ?info,
      ..._extrasSimples(),
    });
  }

  Map<String, PdfObject> _extrasSimples() {
    final mapa = <String, PdfObject>{};
    for (final entrada in trailerExtra.entries) {
      if (entrada.key == 'Size' ||
          entrada.key == 'Root' ||
          entrada.key == 'Info' ||
          entrada.key == 'Prev' ||
          entrada.key == 'XRefStm' ||
          entrada.key == 'Type' ||
          entrada.key == 'W' ||
          entrada.key == 'Index' ||
          entrada.key == 'Filter' ||
          entrada.key == 'Length') {
        continue;
      }
      mapa[entrada.key] = entrada.value;
    }
    return mapa;
  }

  void _cabecalho(BytesBuilder saida) {
    saida.add(latin1.encode('%PDF-$versao\n'));
    // Comentário binário: sinaliza aos programas que o arquivo tem bytes >127.
    saida.add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  }

  static Uint8List _comprimir(Uint8List dados) {
    try {
      return Uint8List.fromList(ZLibEncoder(level: 9).convert(dados));
    } catch (_) {
      return dados;
    }
  }

  // ---------------------------------------------------------- serialização
  static void _escrever(PdfObject objeto, BytesBuilder saida) {
    switch (objeto) {
      case PdfNull():
        saida.add(latin1.encode('null'));
      case PdfBool(:final value):
        saida.add(latin1.encode(value ? 'true' : 'false'));
      case PdfNumber(:final value):
        saida.add(latin1.encode(_formatarNumero(value)));
      case PdfName(:final value):
        _escreverNome(value, saida);
      case PdfString():
        _escreverString(objeto, saida);
      case PdfArray(:final items):
        saida.addByte(0x5B);
        for (var i = 0; i < items.length; i++) {
          if (i > 0) saida.addByte(0x20);
          _escrever(items[i], saida);
        }
        saida.addByte(0x5D);
      case PdfDict():
        _escreverDict(objeto, saida);
      case PdfStream():
        _escreverStream(objeto, saida);
      case PdfRef():
        saida.add(latin1.encode('${objeto.numero} ${objeto.geracao} R'));
    }
  }

  static void _escreverDict(PdfDict dict, BytesBuilder saida) {
    saida.add(latin1.encode('<<'));
    for (final entrada in dict.entradas) {
      saida.addByte(0x20);
      _escreverNome(entrada.key, saida);
      saida.addByte(0x20);
      _escrever(entrada.value, saida);
    }
    saida.add(latin1.encode(' >>'));
  }

  static void _escreverStream(PdfStream stream, BytesBuilder saida) {
    final dict = stream.dict.copiarCom({
      'Length': PdfNumber(stream.raw.length),
    });
    _escreverDict(dict, saida);
    saida.add(latin1.encode('\nstream\n'));
    saida.add(stream.raw);
    saida.add(latin1.encode('\nendstream'));
  }

  static void _escreverNome(String nome, BytesBuilder saida) {
    saida.addByte(0x2F);
    for (final codigo in nome.codeUnits) {
      final precisaEscape = codigo < 0x21 ||
          codigo > 0x7E ||
          codigo == 0x23 ||
          codigo == 0x2F ||
          codigo == 0x28 ||
          codigo == 0x29 ||
          codigo == 0x3C ||
          codigo == 0x3E ||
          codigo == 0x5B ||
          codigo == 0x5D ||
          codigo == 0x7B ||
          codigo == 0x7D ||
          codigo == 0x25;
      if (precisaEscape) {
        saida.add(latin1.encode('#${codigo.toRadixString(16).padLeft(2, '0').toUpperCase()}'));
      } else {
        saida.addByte(codigo);
      }
    }
  }

  static void _escreverString(PdfString texto, BytesBuilder saida) {
    var imprimivel = true;
    for (final byte in texto.bytes) {
      if (byte < 0x20 || byte > 0x7E) {
        imprimivel = false;
        break;
      }
    }

    if (!imprimivel && texto.bytes.isNotEmpty) {
      saida.addByte(0x3C);
      final hex = StringBuffer();
      for (final byte in texto.bytes) {
        hex.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
      saida.add(latin1.encode(hex.toString()));
      saida.addByte(0x3E);
      return;
    }

    saida.addByte(0x28);
    for (final byte in texto.bytes) {
      switch (byte) {
        case 0x28:
        case 0x29:
        case 0x5C:
          saida.addByte(0x5C);
          saida.addByte(byte);
        case 0x0A:
          saida.add(latin1.encode(r'\n'));
        case 0x0D:
          saida.add(latin1.encode(r'\r'));
        case 0x09:
          saida.add(latin1.encode(r'\t'));
        default:
          if (byte < 0x20) {
            saida.add(
              latin1.encode('\\${byte.toRadixString(8).padLeft(3, '0')}'),
            );
          } else {
            saida.addByte(byte);
          }
      }
    }
    saida.addByte(0x29);
  }

  static String _formatarNumero(num valor) {
    if (valor is int) return '$valor';
    if (valor == valor.roundToDouble() && valor.abs() < 1e15) {
      return valor.toInt().toString();
    }
    var texto = valor.toStringAsFixed(6);
    texto = texto.replaceFirst(RegExp(r'0+$'), '');
    if (texto.endsWith('.')) texto = texto.substring(0, texto.length - 1);
    return texto.isEmpty ? '0' : texto;
  }
}
