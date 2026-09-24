import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

import 'package:pdf_enxuto/services/pdf/pdf_objects.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';
import 'package:pdf_enxuto/services/pdf/pdf_writer.dart';

/// Contexto em que um objeto está sendo copiado — muda as regras de poda.
enum _Ctx { catalogo, pagina, normal }

/// Resultado de uma reescrita nativa.
class ResultadoReescrita {
  const ResultadoReescrita({
    required this.bytes,
    required this.objetosMantidos,
    required this.objetosOriginais,
    required this.fluxosRecomprimidos,
  });

  final Uint8List bytes;
  final int objetosMantidos;
  final int objetosOriginais;
  final int fluxosRecomprimidos;
}

/// Operações de estruturação feitas no próprio app, sem depender de programas
/// externos: extrair páginas e reescrever o documento.
///
/// A cópia é feita objeto a objeto, deduplicando recursos compartilhados e
/// **sem tocar no conteúdo** dos fluxos: um JPEG dentro do PDF continua sendo
/// exatamente o mesmo JPEG. Por isso a operação é sem perdas.
class PdfOperations {
  PdfOperations._();

  /// Cria um PDF novo com as páginas indicadas (1 = primeira), na ordem dada.
  static ResultadoReescrita extrairPaginas(
    PdfReader leitor,
    List<int> paginas, {
    bool manterAnotacoes = true,
    bool manterMetadados = true,
    bool manterMiniaturas = false,
    bool reescreverFluxos = true,
    bool usarFluxosDeObjeto = true,
    String produtor = 'PDF Enxuto',
  }) {
    final todas = leitor.paginas();
    final selecionadas = <PaginaLocalizada>[
      for (final numero in paginas)
        if (numero >= 1 && numero <= todas.length) todas[numero - 1],
    ];

    return _construir(
      leitor: leitor,
      selecionadas: selecionadas,
      modoCompleto: false,
      manterAnotacoes: manterAnotacoes,
      manterMetadados: manterMetadados,
      manterMiniaturas: manterMiniaturas,
      manterMarcadores: false,
      reescreverFluxos: reescreverFluxos,
      usarFluxosDeObjeto: usarFluxosDeObjeto,
      produtor: produtor,
    );
  }

  /// Reescreve o documento inteiro: remove objetos não usados, miniaturas,
  /// metadados e (opcionalmente) marcadores e anotações, recomprimindo os
  /// fluxos que não estavam comprimidos.
  static ResultadoReescrita reescrever(
    PdfReader leitor, {
    bool manterAnotacoes = true,
    bool manterMetadados = false,
    bool manterMiniaturas = false,
    bool manterMarcadores = true,
    bool reescreverFluxos = true,
    bool usarFluxosDeObjeto = true,
    String produtor = 'PDF Enxuto',
  }) {
    final todas = leitor.paginas();
    return _construir(
      leitor: leitor,
      selecionadas: todas,
      modoCompleto: true,
      manterAnotacoes: manterAnotacoes,
      manterMetadados: manterMetadados,
      manterMiniaturas: manterMiniaturas,
      manterMarcadores: manterMarcadores,
      reescreverFluxos: reescreverFluxos,
      usarFluxosDeObjeto: usarFluxosDeObjeto,
      produtor: produtor,
    );
  }

  static ResultadoReescrita _construir({
    required PdfReader leitor,
    required List<PaginaLocalizada> selecionadas,
    required bool modoCompleto,
    required bool manterAnotacoes,
    required bool manterMetadados,
    required bool manterMiniaturas,
    required bool manterMarcadores,
    required bool reescreverFluxos,
    required bool usarFluxosDeObjeto,
    required String produtor,
  }) {
    final escritor = PdfWriter(versao: leitor.versao >= 1.5 ? '1.7' : '1.5');
    final copiador = _Copiador(
      leitor: leitor,
      escritor: escritor,
      modoCompleto: modoCompleto,
      manterAnotacoes: manterAnotacoes,
      manterMetadados: manterMetadados,
      manterMiniaturas: manterMiniaturas,
      manterMarcadores: manterMarcadores,
      reescreverFluxos: reescreverFluxos,
    );

    // A árvore nova já nasce com número reservado (as páginas apontam para ela).
    final refPaginas = escritor.reservar();
    copiador.refPaginas = refPaginas;

    final refsPaginas = <PdfRef>[];
    for (final pagina in selecionadas) {
      final nova = escritor.reservar();
      final numeroOrigem = pagina.numeroObjeto;
      if (numeroOrigem != null) {
        copiador.registrarPagina(numeroOrigem, nova);
      }
      refsPaginas.add(nova);
      copiador.copiarPagina(pagina, nova);
    }

    escritor.definirRef(
      refPaginas,
      PdfDict({
        'Type': PdfName.pages,
        'Kids': PdfArray(refsPaginas),
        'Count': PdfNumber(refsPaginas.length),
      }),
    );

    // Catálogo
    final origemCatalogo = leitor.catalogo;
    final catalogo = <String, PdfObject>{
      'Type': PdfName.catalog,
      'Pages': refPaginas,
    };

    if (modoCompleto && origemCatalogo != null) {
      for (final chave in _chavesDeCatalogoMantidas) {
        if (chave == 'Pages') continue;
        if (chave == 'Outlines' && !manterMarcadores) continue;
        if (chave == 'Metadata' && !manterMetadados) continue;
        final valor = origemCatalogo[chave];
        if (valor == null) continue;
        final copiado = copiador.copiarValor(valor, _Ctx.catalogo, chave);
        if (copiado != null) catalogo[chave] = copiado;
      }
    } else if (origemCatalogo != null) {
      for (final chave in _chavesDeCatalogoSimples) {
        final valor = origemCatalogo[chave];
        if (valor == null) continue;
        final copiado = copiador.copiarValor(valor, _Ctx.catalogo, chave);
        if (copiado != null) catalogo[chave] = copiado;
      }
      if (manterMetadados) {
        final xmp = origemCatalogo['Metadata'];
        if (xmp != null) {
          final copiado = copiador.copiarValor(xmp, _Ctx.catalogo, 'Metadata');
          if (copiado != null) catalogo['Metadata'] = copiado;
        }
      }
    }

    final refCatalogo = escritor.adicionar(PdfDict(catalogo));
    escritor.raiz = refCatalogo;

    // /Info preservado (título, autor) com o produtor atualizado.
    if (manterMetadados) {
      final infoOrigem = leitor.info;
      final info = <String, PdfObject>{
        'Producer': PdfString(Uint8List.fromList(produtor.codeUnits)),
      };
      if (infoOrigem != null) {
        for (final chave in ['Title', 'Author', 'Subject', 'Keywords', 'Creator']) {
          final valor = infoOrigem[chave];
          if (valor == null) continue;
          final copiado = copiador.copiarValor(valor, _Ctx.normal, chave);
          if (copiado != null) info[chave] = copiado;
        }
      }
      escritor.info = escritor.adicionar(PdfDict(info));
    }

    final bytes = escritor.escrever(usarFluxosDeObjeto: usarFluxosDeObjeto);

    return ResultadoReescrita(
      bytes: bytes,
      objetosMantidos: escritor.quantidadeObjetos,
      objetosOriginais: leitor.objetosConhecidos,
      fluxosRecomprimidos: copiador.fluxosRecomprimidos,
    );
  }

  /// Chaves do catálogo copiadas quando o documento inteiro é reescrito.
  static const List<String> _chavesDeCatalogoMantidas = [
    'Pages',
    'Outlines',
    'Metadata',
    'Names',
    'Dests',
    'PageLayout',
    'PageMode',
    'ViewerPreferences',
    'OpenAction',
    'AcroForm',
    'StructTreeRoot',
    'MarkInfo',
    'Lang',
    'Threads',
    'OutputIntents',
    'OCProperties',
  ];

  /// Subconjunto seguro para documentos parciais (páginas extraídas).
  static const List<String> _chavesDeCatalogoSimples = [
    'PageLayout',
    'PageMode',
    'ViewerPreferences',
    'MarkInfo',
    'Lang',
  ];
}

class _Copiador {
  _Copiador({
    required this.leitor,
    required this.escritor,
    required this.modoCompleto,
    required this.manterAnotacoes,
    required this.manterMetadados,
    required this.manterMiniaturas,
    required this.manterMarcadores,
    required this.reescreverFluxos,
  });

  final PdfReader leitor;
  final PdfWriter escritor;
  final bool modoCompleto;
  final bool manterAnotacoes;
  final bool manterMetadados;
  final bool manterMiniaturas;
  final bool manterMarcadores;
  final bool reescreverFluxos;

  late PdfRef refPaginas;

  /// origem → novo (objetos já copiados).
  final Map<int, PdfRef> _mapa = {};

  /// Objetos de origem que apontam para páginas (destinos, anotações).
  final Map<int, PdfRef> _paginas = {};

  /// Objetos que nunca devem ser copiados (nós da árvore de páginas).
  final Set<int> _proibidos = {};

  int fluxosRecomprimidos = 0;

  void registrarPagina(int numeroOrigem, PdfRef novo) {
    _paginas[numeroOrigem] = novo;
    _mapa[numeroOrigem] = novo;
  }

  /// Copia um dicionário de página para o objeto [destino].
  void copiarPagina(PaginaLocalizada pagina, PdfRef destino) {
    final entradas = <String, PdfObject>{};

    for (final entrada in pagina.dict.entradas) {
      final chave = entrada.key;
      if (chave == 'Parent') continue;
      if (chave == 'Annots' && !manterAnotacoes) continue;
      if (chave == 'Thumb' && !manterMiniaturas) continue;
      if (chave == 'B' || chave == 'StructParents') continue;
      final copiado = copiarValor(entrada.value, _Ctx.pagina, chave);
      if (copiado != null) entradas[chave] = copiado;
    }

    // Atributos herdados da árvore (Resources, MediaBox, CropBox, Rotate).
    for (final entrada in pagina.herdados.entries) {
      if (entradas.containsKey(entrada.key)) continue;
      final copiado = copiarValor(entrada.value, _Ctx.pagina, entrada.key);
      if (copiado != null) entradas[entrada.key] = copiado;
    }

    entradas['Type'] = PdfName.page;
    entradas['Parent'] = refPaginas;
    escritor.definirRef(destino, PdfDict(entradas));
  }

  /// Copia um valor (direto ou por referência), aplicando as regras de poda.
  PdfObject? copiarValor(PdfObject valor, _Ctx ctx, String chave) {
    switch (valor) {
      case PdfRef():
        return _copiarReferencia(valor, ctx, chave);
      case PdfStream():
        return _copiarStream(valor, ctx, chave);
      case PdfDict():
        return _copiarDict(valor, ctx, chave);
      case PdfArray():
        final itens = <PdfObject>[];
        for (final item in valor.items) {
          final copiado = copiarValor(item, ctx, chave);
          if (copiado != null) itens.add(copiado);
        }
        return PdfArray(itens);
      default:
        return valor;
    }
  }

  PdfRef? _copiarReferencia(PdfRef referencia, _Ctx ctx, String chave) {
    if (referencia.numero == 0) return null;

    final existente = _mapa[referencia.numero];
    if (existente != null) return existente;

    final daPagina = _paginas[referencia.numero];
    if (daPagina != null) return daPagina;

    if (_proibidos.contains(referencia.numero)) return null;

    final origem = leitor.objeto(referencia.numero);
    if (origem == null) return null;

    if (origem is PdfDict && origem.nome('Type') == 'Pages') {
      _proibidos.add(referencia.numero);
      return null;
    }
    if (origem is PdfDict && origem.nome('Type') == 'Page') {
      // Página fora da seleção (extração parcial): destino deixa de existir.
      _proibidos.add(referencia.numero);
      return null;
    }
    if (origem is PdfStream &&
        origem.dict.nome('Type') == 'XRef') {
      return null;
    }
    if (origem is PdfStream && origem.dict.nome('Type') == 'ObjStm') {
      return null;
    }

    final nova = escritor.reservar();
    _mapa[referencia.numero] = nova;

    switch (origem) {
      case PdfStream():
        final novo = _copiarStream(origem, ctx, chave);
        escritor.definirRef(nova, novo ?? PdfNull.instance);
      case PdfDict():
        final novo = _copiarDict(origem, ctx, chave);
        escritor.definirRef(nova, novo ?? PdfNull.instance);
      default:
        escritor.definirRef(nova, origem);
    }
    return nova;
  }

  PdfDict? _copiarDict(PdfDict dict, _Ctx ctx, String chave) {
    final tipo = dict.nome('Type');
    if (tipo == 'Pages' || tipo == 'XRef' || tipo == 'ObjStm') return null;

    final entradas = <String, PdfObject>{};
    for (final entrada in dict.entradas) {
      final nome = entrada.key;
      if (!_manterChave(nome, dict, ctx)) continue;
      final copiado = copiarValor(entrada.value, ctx, nome);
      if (copiado != null) entradas[nome] = copiado;
    }
    return PdfDict(entradas);
  }

  bool _manterChave(String chave, PdfDict dict, _Ctx ctx) {
    switch (chave) {
      case 'Metadata':
        return manterMetadados;
      case 'PieceInfo':
      case 'LastModified':
      case 'StructParents':
      case 'B':
        return modoCompleto && ctx != _Ctx.pagina;
      case 'Outlines':
        return manterMarcadores;
      case 'Annots':
        return manterAnotacoes;
      case 'Thumb':
        return manterMiniaturas;
      case 'Parent':
        return ctx != _Ctx.pagina && dict.nome('Type') != 'Page';
      default:
        return true;
    }
  }

  PdfStream? _copiarStream(PdfStream stream, _Ctx ctx, String chave) {
    final dict = _copiarDict(stream.dict, ctx, chave) ?? const PdfDict();
    var raw = stream.raw;
    var novoDict = dict;

    if (reescreverFluxos &&
        stream.filtros.isEmpty &&
        raw.length > 128 &&
        dict.nome('Subtype') != 'XML' &&
        !_pareceXml(raw)) {
      final comprimido = _comprimir(raw);
      if (comprimido.length < raw.length) {
        raw = comprimido;
        novoDict = dict.copiarCom({'Filter': PdfName.flate}).sem(['DecodeParms']);
        fluxosRecomprimidos++;
      }
    }

    return PdfStream(novoDict.sem(['Length']), raw);
  }

  bool _pareceXml(Uint8List dados) {
    if (dados.length < 5) return false;
    return dados[0] == 0x3C &&
        (dados[1] == 0x3F || dados[1] == 0x78 || dados[1] == 0x21);
  }

  static Uint8List _comprimir(Uint8List dados) {
    try {
      return Uint8List.fromList(ZLibEncoder(level: 9).convert(dados));
    } catch (_) {
      return dados;
    }
  }
}
