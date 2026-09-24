import 'dart:convert';
import 'dart:typed_data';

/// Modelo de objetos do PDF (ISO 32000-1, seção 7.3).
///
/// É deliberadamente pequeno: só o necessário para ler a estrutura de um
/// documento, copiar páginas e reescrever o arquivo sem tocar no conteúdo
/// das páginas (imagens, fontes e fluxos são copiados byte a byte).
sealed class PdfObject {
  const PdfObject();
}

class PdfNull extends PdfObject {
  const PdfNull();
  static const PdfNull instance = PdfNull();

  @override
  String toString() => 'null';
}

class PdfBool extends PdfObject {
  const PdfBool(this.value);

  final bool value;

  static const PdfBool verdadeiro = PdfBool(true);
  static const PdfBool falso = PdfBool(false);

  @override
  String toString() => '$value';
}

class PdfNumber extends PdfObject {
  const PdfNumber(this.value);

  final num value;

  int get comoInteiro => value is int ? value as int : value.round();

  double get comoDouble => value.toDouble();

  bool get ehInteiro => value is int || value == value.roundToDouble();

  @override
  String toString() => '$value';
}

class PdfName extends PdfObject {
  const PdfName(this.value);

  /// Nome já decodificado, **sem** a barra inicial ("Type", "Page").
  final String value;

  static const PdfName type = PdfName('Type');
  static const PdfName page = PdfName('Page');
  static const PdfName pages = PdfName('Pages');
  static const PdfName catalog = PdfName('Catalog');
  static const PdfName parent = PdfName('Parent');
  static const PdfName kids = PdfName('Kids');
  static const PdfName count = PdfName('Count');
  static const PdfName length = PdfName('Length');
  static const PdfName filter = PdfName('Filter');
  static const PdfName flate = PdfName('FlateDecode');
  static const PdfName root = PdfName('Root');
  static const PdfName objStm = PdfName('ObjStm');
  static const PdfName xref = PdfName('XRef');
  static const PdfName metadata = PdfName('Metadata');
  static const PdfName outlines = PdfName('Outlines');
  static const PdfName annots = PdfName('Annots');
  static const PdfName thumb = PdfName('Thumb');
  static const PdfName encrypt = PdfName('Encrypt');

  @override
  String toString() => '/$value';
}

class PdfString extends PdfObject {
  const PdfString(this.bytes, {this.hex = false});

  /// Cria a partir de texto: UTF-16BE com BOM quando há acentos (é o que a
  /// especificação recomenda para metadados), Latin-1 quando é só ASCII.
  factory PdfString.fromTexto(String texto) {
    if (texto.codeUnits.every((codigo) => codigo < 128)) {
      return PdfString(Uint8List.fromList(texto.codeUnits));
    }
    final bytes = <int>[0xFE, 0xFF];
    for (final unidade in texto.codeUnits) {
      bytes.add((unidade >> 8) & 0xFF);
      bytes.add(unidade & 0xFF);
    }
    return PdfString(Uint8List.fromList(bytes));
  }

  /// Bytes crus, como estão no arquivo.
  final Uint8List bytes;

  /// Se foi escrito em hexadecimal (`<...>`).
  final bool hex;

  /// Texto legível: entende UTF-16BE com BOM e cai para Latin-1.
  String get texto {
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final unidades = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        unidades.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(unidades);
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  @override
  String toString() => '($texto)';
}

class PdfArray extends PdfObject {
  const PdfArray([this.items = const []]);

  final List<PdfObject> items;

  int get length => items.length;

  PdfObject? operator [](int index) =>
      index >= 0 && index < items.length ? items[index] : null;

  @override
  String toString() => '[${items.join(' ')}]';
}

class PdfDict extends PdfObject {
  const PdfDict([this.entries = const {}]);

  final Map<String, PdfObject> entries;

  /// Iterável de conveniência: `entries` é o mapa; `entradas` são os pares.
  Iterable<MapEntry<String, PdfObject>> get entradas => entries.entries;

  PdfObject? operator [](String chave) => entries[chave];

  bool tem(String chave) => entries.containsKey(chave);

  String? nome(String chave) {
    final objeto = entries[chave];
    return objeto is PdfName ? objeto.value : null;
  }

  int? inteiro(String chave) {
    final objeto = entries[chave];
    return objeto is PdfNumber ? objeto.comoInteiro : null;
  }

  double? real(String chave) {
    final objeto = entries[chave];
    return objeto is PdfNumber ? objeto.comoDouble : null;
  }

  bool? booleano(String chave) {
    final objeto = entries[chave];
    return objeto is PdfBool ? objeto.value : null;
  }

  PdfArray? lista(String chave) {
    final objeto = entries[chave];
    return objeto is PdfArray ? objeto : null;
  }

  PdfDict? dicionario(String chave) {
    final objeto = entries[chave];
    return objeto is PdfDict ? objeto : null;
  }

  PdfString? texto(String chave) {
    final objeto = entries[chave];
    return objeto is PdfString ? objeto : null;
  }

  PdfDict copiarCom(Map<String, PdfObject> extras) =>
      PdfDict({...entries, ...extras});

  PdfDict sem(Iterable<String> chaves) {
    final novo = Map<String, PdfObject>.from(entries);
    for (final chave in chaves) {
      novo.remove(chave);
    }
    return PdfDict(novo);
  }

  @override
  String toString() => '<<${entries.entries.map((e) => '/${e.key} ${e.value}').join(' ')}>>';
}

/// Dicionário + fluxo de bytes crus (ainda codificados, como no arquivo).
class PdfStream extends PdfObject {
  const PdfStream(this.dict, this.raw);

  final PdfDict dict;
  final Uint8List raw;

  int get tamanho => raw.length;

  /// Filtros do fluxo, normalizados em lista.
  List<String> get filtros {
    final filtro = dict['Filter'];
    if (filtro is PdfName) return [filtro.value];
    if (filtro is PdfArray) {
      return filtro.items.whereType<PdfName>().map((n) => n.value).toList();
    }
    return const [];
  }

  @override
  String toString() => '${dict.toString()} stream(${raw.length} bytes)';
}

/// Referência indireta ("12 0 R").
class PdfRef extends PdfObject {
  const PdfRef(this.numero, [this.geracao = 0]);

  final int numero;
  final int geracao;

  @override
  String toString() => '$numero $geracao R';

  @override
  bool operator ==(Object other) =>
      other is PdfRef && other.numero == numero && other.geracao == geracao;

  @override
  int get hashCode => Object.hash(numero, geracao);
}

/// Acesso a valores que podem estar diretos ou atrás de referências.
extension PdfDictExt on PdfDict {
  /// Nome em `chave`, seguindo uma referência se necessário (o resolvedor é
  /// fornecido pelo leitor).
  String? nomeResolvido(String chave, PdfObject? Function(PdfObject?) resolver) {
    final objeto = resolver(entries[chave]);
    return objeto is PdfName ? objeto.value : null;
  }

  int? inteiroResolvido(String chave, PdfObject? Function(PdfObject?) resolver) {
    final objeto = resolver(entries[chave]);
    return objeto is PdfNumber ? objeto.comoInteiro : null;
  }
}
