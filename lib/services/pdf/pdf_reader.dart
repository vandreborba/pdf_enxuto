import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'package:pdf_enxuto/services/pdf/pdf_objects.dart';

/// Erro de sintaxe ou estrutura do PDF.
class PdfSyntaxException implements Exception {
  PdfSyntaxException(this.mensagem, [this.posicao]);

  final String mensagem;
  final int? posicao;

  @override
  String toString() =>
      'PdfSyntaxException: $mensagem${posicao != null ? ' (byte $posicao)' : ''}';
}

/// Documento criptografado: o motor nativo não abre.
class PdfCriptografadoException implements Exception {
  @override
  String toString() => 'PDF protegido por senha';
}

/// Onde uma página vive no arquivo original.
class PaginaLocalizada {
  const PaginaLocalizada({
    required this.dict,
    this.numeroObjeto,
    this.herdados = const {},
  });

  final PdfDict dict;

  /// Número do objeto indireto, quando a página não está embutida no pai.
  final int? numeroObjeto;

  /// Atributos herdados da árvore (/Resources, /MediaBox, /CropBox, /Rotate,
  /// /UserUnit). Sem eles, uma página extraída perde as fontes e as imagens.
  final Map<String, PdfObject> herdados;
}

/// Um marcador do sumário.
class MarcadorPdf {
  const MarcadorPdf({
    required this.titulo,
    required this.pagina,
    this.nivel = 0,
  });

  final String titulo;

  /// Página de destino (1 = primeira). 0 quando o destino não foi resolvido.
  final int pagina;
  final int nivel;
}

class _EntradaXref {
  _EntradaXref({
    this.offset,
    this.geracao = 0,
    this.objStm,
    this.indiceStm,
    this.livre = false,
  });

  int? offset;
  int geracao;
  int? objStm;
  int? indiceStm;
  bool livre;
}

/// Leitor de PDF em Dart puro.
///
/// Cobre tabelas xref clássicas, fluxos xref (PDF 1.5+) e objetos dentro de
/// fluxos de objeto (/ObjStm). Quando a tabela está corrompida, reconstrói o
/// índice varrendo o arquivo — situação comum em PDFs gerados por ferramentas
/// antigas, e que outros programas recusam.
class PdfReader {
  PdfReader._(this._dados);

  final Uint8List _dados;

  final Map<int, _EntradaXref> _xref = {};
  final Map<int, PdfObject?> _cache = {};
  final Set<int> _emAndamento = {};

  PdfDict trailer = const PdfDict();
  double versao = 1.4;
  bool criptografado = false;
  int tamanhoDeclarado = 0;

  /// `true` quando o índice foi reconstruído por varredura (arquivo danificado).
  bool indiceReconstruido = false;

  String? _erroLeitura;

  String? get erroLeitura => _erroLeitura;

  /// Quantidade de objetos conhecidos pelo índice (para relatórios).
  int get objetosConhecidos => _xref.length;

  static PdfReader abrir(Uint8List dados) {
    final leitor = PdfReader._(dados);
    leitor._iniciar();
    return leitor;
  }

  static PdfReader abrirBytes(List<int> dados) =>
      abrir(Uint8List.fromList(dados));

  // ------------------------------------------------------------------ setup
  void _iniciar() {
    versao = _lerVersao();

    try {
      _construirXref();
    } catch (erro) {
      _erroLeitura = '$erro';
      _recuperarPorVarredura();
    }

    if (_xref.isEmpty) {
      _recuperarPorVarredura();
    }

    criptografado = trailer.tem('Encrypt');
    tamanhoDeclarado = trailer.inteiro('Size') ?? 0;

    // Sem catálogo não há documento: última tentativa pela varredura.
    if (_numeroDoCatalogo() == null && !criptografado) {
      _recuperarPorVarredura();
    }
  }

  double _lerVersao() {
    final inicio = _dados.length > 1024 ? 1024 : _dados.length;
    final cabecalho = latin1.decode(
      _dados.sublist(0, inicio),
      allowInvalid: true,
    );
    final match = RegExp(r'%PDF-(\d+)\.(\d+)').firstMatch(cabecalho);
    if (match == null) return 1.4;
    return double.tryParse('${match.group(1)}.${match.group(2)}') ?? 1.4;
  }

  void _construirXref() {
    final offset = _lerStartXref();
    if (offset == null) {
      throw PdfSyntaxException('startxref não encontrado');
    }
    _lerXrefEm(offset, profundidade: 0);
  }

  int? _lerStartXref() {
    final fim = _dados.length;
    final janela = fim > 2048 ? 2048 : fim;
    final trecho = latin1.decode(
      _dados.sublist(fim - janela, fim),
      allowInvalid: true,
    );
    final match = RegExp(r'startxref\s+(\d+)').allMatches(trecho);
    if (match.isEmpty) return null;
    return int.tryParse(match.last.group(1)!);
  }

  void _lerXrefEm(int offset, {required int profundidade}) {
    if (profundidade > 32 || offset <= 0 || offset >= _dados.length) return;

    final scanner = _Lexer(_dados)
      ..posicao = offset
      ..pularEspacos();

    final palavra = scanner.lerPalavraChave();

    if (palavra == 'xref') {
      _lerTabelaClassica(scanner);
      final trailerLido = _lerTrailer(scanner);
      _mesclarTrailer(trailerLido);
      _continuarCadeia(trailerLido, profundidade);
      return;
    }

    // Objeto de fluxo xref.
    final objeto = _lerObjetoIndiretoEm(offset);
    if (objeto == null) {
      throw PdfSyntaxException('fluxo xref inválido', offset);
    }
    final fluxo = objeto.$3;
    if (fluxo is! PdfStream) {
      throw PdfSyntaxException('objeto xref não é um fluxo', offset);
    }
    _lerFluxoXref(fluxo);
    _mesclarTrailer(fluxo.dict);
    _continuarCadeia(fluxo.dict, profundidade);
  }

  void _continuarCadeia(PdfDict dict, int profundidade) {
    final anterior = dict.inteiro('Prev');
    if (anterior != null) {
      _lerXrefEm(anterior, profundidade: profundidade + 1);
    }
    final hibrido = dict.inteiro('XRefStm');
    if (hibrido != null) {
      _lerXrefEm(hibrido, profundidade: profundidade + 1);
    }
  }

  void _mesclarTrailer(PdfDict novo) {
    if (novo.entries.isEmpty) return;
    if (trailer.entries.isEmpty) {
      trailer = novo;
      return;
    }
    // O trailer mais recente tem prioridade.
    trailer = PdfDict({...novo.entries, ...trailer.entries});
  }

  void _lerTabelaClassica(_Lexer scanner) {
    while (true) {
      scanner.pularEspacos();
      if (scanner.estaEm('trailer')) return;

      final inicio = scanner.lerInteiro();
      if (inicio == null) {
        // Alguns arquivos terminam a tabela sem trailer.
        return;
      }
      final quantidade = scanner.lerInteiro();
      if (quantidade == null) return;
      scanner.pularEspacos();

      for (var i = 0; i < quantidade; i++) {
        final offsetTexto = scanner.lerPalavraChave();
        final geracaoTexto = scanner.lerPalavraChave();
        final tipo = scanner.lerPalavraChave();
        if (offsetTexto == null || geracaoTexto == null || tipo == null) return;

        final numero = inicio + i;
        if (_xref.containsKey(numero)) continue;

        final offset = int.tryParse(offsetTexto);
        final geracao = int.tryParse(geracaoTexto) ?? 0;
        if (tipo.startsWith('n') && offset != null) {
          _xref[numero] = _EntradaXref(offset: offset, geracao: geracao);
        } else {
          _xref[numero] = _EntradaXref(livre: true, geracao: geracao);
        }
      }
    }
  }

  PdfDict _lerTrailer(_Lexer scanner) {
    scanner.pularEspacos();
    if (!scanner.estaEm('trailer')) return const PdfDict();
    scanner.avancar('trailer'.length);
    scanner.pularEspacos();
    final objeto = scanner.lerObjeto();
    return objeto is PdfDict ? objeto : const PdfDict();
  }

  void _lerFluxoXref(PdfStream fluxo) {
    final dados = decodificarFluxo(fluxo);
    if (dados == null) {
      throw PdfSyntaxException('não foi possível decodificar o fluxo xref');
    }

    final w = fluxo.dict.lista('W');
    if (w == null || w.length < 3) {
      throw PdfSyntaxException('fluxo xref sem /W');
    }
    final larguras = [
      for (final item in w.items) item is PdfNumber ? item.comoInteiro : 0,
    ];
    while (larguras.length < 3) {
      larguras.add(0);
    }

    final tamanho = fluxo.dict.inteiro('Size') ?? 0;
    final indice = fluxo.dict.lista('Index');
    final pares = <int>[];
    if (indice != null) {
      for (final item in indice.items) {
        if (item is PdfNumber) pares.add(item.comoInteiro);
      }
    } else {
      pares.addAll([0, tamanho]);
    }

    final tamanhoEntrada = larguras[0] + larguras[1] + larguras[2];
    if (tamanhoEntrada <= 0) return;

    var posicao = 0;
    for (var p = 0; p + 1 < pares.length; p += 2) {
      final inicio = pares[p];
      final quantidade = pares[p + 1];
      for (var i = 0; i < quantidade; i++) {
        if (posicao + tamanhoEntrada > dados.length) return;
        final tipo = _lerCampo(dados, posicao, larguras[0], padrao: 1);
        final campo2 = _lerCampo(dados, posicao + larguras[0], larguras[1]);
        final campo3 = _lerCampo(
          dados,
          posicao + larguras[0] + larguras[1],
          larguras[2],
        );
        posicao += tamanhoEntrada;

        final numero = inicio + i;
        if (_xref.containsKey(numero)) continue;

        switch (tipo) {
          case 1:
            _xref[numero] = _EntradaXref(offset: campo2, geracao: campo3);
          case 2:
            _xref[numero] = _EntradaXref(objStm: campo2, indiceStm: campo3);
          default:
            _xref[numero] = _EntradaXref(livre: true, geracao: campo3);
        }
      }
    }
  }

  int _lerCampo(Uint8List dados, int posicao, int largura, {int padrao = 0}) {
    if (largura <= 0) return padrao;
    var valor = 0;
    for (var i = 0; i < largura; i++) {
      final indice = posicao + i;
      if (indice >= dados.length) return valor;
      valor = (valor << 8) | dados[indice];
    }
    return valor;
  }

  /// Plano B: varre o arquivo procurando "N G obj" e remonta o índice.
  void _recuperarPorVarredura() {
    indiceReconstruido = true;
    _xref.clear();

    final texto = latin1.decode(_dados, allowInvalid: true);
    final padrao = RegExp(r'(\d{1,10})\s+(\d{1,5})\s+obj\b');
    for (final match in padrao.allMatches(texto)) {
      final numero = int.tryParse(match.group(1)!);
      final geracao = int.tryParse(match.group(2)!) ?? 0;
      if (numero == null) continue;
      // Fica com a última ocorrência: em arquivos incrementais, a mais nova.
      _xref[numero] = _EntradaXref(offset: match.start, geracao: geracao);
    }

    // Reconstrói um trailer mínimo a partir do que existir no arquivo.
    final dictsComCatalogo = <int>[];
    for (final numero in _xref.keys.toList()) {
      final objeto = _lerObjetoIndireto(_xref[numero]!.offset!);
      if (objeto == null) continue;
      final valor = objeto.$3;
      if (valor is PdfStream) {
        if (valor.dict.nome('Type') == 'XRef') {
          try {
            _lerFluxoXref(valor);
          } catch (_) {
            // Ignora fluxo xref inválido.
          }
          _mesclarTrailer(valor.dict);
          continue;
        }
      }
      if (valor is PdfDict) {
        if (valor.nome('Type') == 'Catalog') {
          dictsComCatalogo.add(numero);
        }
        if (valor.tem('Root') || valor.tem('Encrypt')) {
          _mesclarTrailer(valor);
        }
      }
    }

    if (trailer.inteiro('Size') == null) {
      final maior = _xref.keys.isEmpty
          ? 1
          : _xref.keys.reduce((a, b) => a > b ? a : b) + 1;
      trailer = trailer.copiarCom({'Size': PdfNumber(maior)});
    }

    if (!trailer.tem('Root') && dictsComCatalogo.isNotEmpty) {
      trailer = trailer.copiarCom({'Root': PdfRef(dictsComCatalogo.last)});
    }

    // Melhora o trailer com o último dict "trailer" encontrado no arquivo.
    final ultimoTrailer = RegExp(r'trailer').allMatches(texto);
    if (ultimoTrailer.isNotEmpty) {
      final scanner = _Lexer(_dados)..posicao = ultimoTrailer.last.end;
      scanner.pularEspacos();
      final objeto = scanner.lerObjeto();
      if (objeto is PdfDict) {
        _mesclarTrailer(objeto);
      }
    }
  }

  // ---------------------------------------------------------------- objetos
  int? _numeroDoCatalogo() {
    final raiz = trailer['Root'];
    if (raiz is PdfRef) return raiz.numero;
    return null;
  }

  /// Resolve referências em cadeia até chegar a um objeto concreto.
  PdfObject? resolver(PdfObject? objeto, [int profundidade = 0]) {
    var atual = objeto;
    var restantes = profundidade;
    while (atual is PdfRef && restantes < 32) {
      atual = objeto_(_numero(objeto: atual));
      restantes++;
    }
    return atual;
  }

  int _numero({required PdfRef objeto}) => objeto.numero;

  /// Lê um objeto indireto pelo número.
  PdfObject? objeto_(int numero) {
    if (_cache.containsKey(numero)) return _cache[numero];
    if (_emAndamento.contains(numero)) return null;
    _emAndamento.add(numero);
    try {
      final valor = _carregarObjeto(numero);
      if (valor != null) _cache[numero] = valor;
      return valor;
    } finally {
      _emAndamento.remove(numero);
    }
  }

  /// Versão pública de [objeto_], com nome mais amigável.
  PdfObject? objeto(int numero) => objeto_(numero);

  PdfDict? dicionario(int numero) {
    final valor = objeto_(numero);
    if (valor is PdfDict) return valor;
    if (valor is PdfStream) return valor.dict;
    return null;
  }

  PdfObject? _carregarObjeto(int numero) {
    final entrada = _xref[numero];
    if (entrada == null) return null;

    if (entrada.objStm != null) {
      return _objetoDeFluxo(numero, entrada.objStm!, entrada.indiceStm ?? 0);
    }
    final offset = entrada.offset;
    if (offset == null) return null;

    final resultado = _lerObjetoIndireto(offset);
    if (resultado == null) return null;
    return resultado.$3;
  }

  /// (numero, geracao, objeto) a partir de um deslocamento.
  (int, int, PdfObject)? _lerObjetoIndireto(int offset) {
    final scanner = _Lexer(_dados, resolvedorDeTamanho: _resolverTamanho)
      ..posicao = offset;
    return _lerObjetoIndiretoCom(scanner);
  }

  (int, int, PdfObject)? _lerObjetoIndiretoEm(int offset) =>
      _lerObjetoIndireto(offset);

  (int, int, PdfObject)? _lerObjetoIndiretoCom(_Lexer scanner) {
    scanner.pularEspacos();
    final numero = scanner.lerInteiro();
    final geracao = scanner.lerInteiro();
    if (numero == null || geracao == null) return null;
    scanner.pularEspacos();
    final palavra = scanner.lerPalavraChave();
    if (palavra != 'obj') return null;
    final valor = scanner.lerObjeto();
    if (valor == null) return null;
    return (numero, geracao, valor);
  }

  int? _resolverTamanho(PdfRef referencia) {
    final valor = objeto_(referencia.numero);
    return valor is PdfNumber ? valor.comoInteiro : null;
  }

  final Map<int, List<Object?>> _cacheObjStm = {};

  PdfObject? _objetoDeFluxo(int numero, int numeroStm, int indice) {
    final lista = _objetosDoFluxo(numeroStm);
    if (lista == null) return null;
    if (indice < 0 || indice >= lista.length) return null;
    final entrada = lista[indice];
    if (entrada is! List) return null;
    if (entrada[0] != numero) {
      // O índice pode estar fora de ordem; procura pelo número.
      for (final item in lista) {
        if (item is List && item[0] == numero) return item[1] as PdfObject?;
      }
      return null;
    }
    return entrada[1] as PdfObject?;
  }

  List<Object?>? _objetosDoFluxo(int numeroStm) {
    if (_cacheObjStm.containsKey(numeroStm)) return _cacheObjStm[numeroStm];

    final objeto = objeto_(numeroStm);
    if (objeto is! PdfStream) return null;
    final dados = decodificarFluxo(objeto);
    if (dados == null) return null;

    final quantidade = objeto.dict.inteiro('N') ?? 0;
    final primeiro = objeto.dict.inteiro('First') ?? 0;
    if (quantidade <= 0 || primeiro > dados.length) {
      _cacheObjStm[numeroStm] = const [];
      return const [];
    }

    final cabecalho = _Lexer(dados);
    final pares = <List<int>>[];
    for (var i = 0; i < quantidade; i++) {
      final numero = cabecalho.lerInteiro();
      final deslocamento = cabecalho.lerInteiro();
      if (numero == null || deslocamento == null) break;
      pares.add([numero, deslocamento]);
    }

    final resultado = <Object?>[];
    for (final par in pares) {
      final posicao = primeiro + par[1];
      if (posicao < 0 || posicao >= dados.length) {
        resultado.add(null);
        continue;
      }
      final scanner = _Lexer(dados, resolvedorDeTamanho: _resolverTamanho)
        ..posicao = posicao;
      final valor = scanner.lerObjeto();
      resultado.add([par[0], valor]);
    }

    _cacheObjStm[numeroStm] = resultado;
    return resultado;
  }

  // ---------------------------------------------------------------- páginas
  PdfDict? get catalogo {
    final numero = _numeroDoCatalogo();
    if (numero == null) return null;
    return dicionario(numero);
  }

  /// Todas as páginas, na ordem do documento.
  List<PaginaLocalizada> paginas() {
    final resultado = <PaginaLocalizada>[];
    final cat = catalogo;
    if (cat == null) return resultado;

    final raiz = cat['Pages'];
    final visitados = <int>{};
    _percorrerArvore(raiz, resultado, visitados, 0, const {});
    return resultado;
  }

  /// Chaves que uma página pode herdar do nó pai (ISO 32000-1, 7.7.3.4).
  static const List<String> _chavesHerdaveis = [
    'Resources',
    'MediaBox',
    'CropBox',
    'Rotate',
    'UserUnit',
  ];

  void _percorrerArvore(
    PdfObject? no,
    List<PaginaLocalizada> destino,
    Set<int> visitados,
    int profundidade,
    Map<String, PdfObject> herdados,
  ) {
    if (no == null || profundidade > 64) return;

    final numero = no is PdfRef ? no.numero : null;
    if (numero != null) {
      if (visitados.contains(numero)) return;
      visitados.add(numero);
    }

    final dict = resolver(no);
    if (dict is! PdfDict) return;

    // Acumula o que este nó acrescenta ao que já vinha sendo herdado.
    var herdadosAqui = herdados;
    for (final chave in _chavesHerdaveis) {
      final valor = dict[chave];
      if (valor != null) {
        herdadosAqui = {...herdadosAqui, chave: valor};
      }
    }

    final tipo = dict.nome('Type');
    if (tipo == 'Page') {
      destino.add(
        PaginaLocalizada(
          dict: dict,
          numeroObjeto: numero,
          herdados: _apenasNaoPresentes(dict, herdadosAqui),
        ),
      );
      return;
    }

    final kids = dict['Kids'];
    final lista = resolver(kids);
    if (lista is! PdfArray) {
      if (tipo == null) {
        // Nó sem /Type: tratamos como folha se tiver conteúdo.
        destino.add(
          PaginaLocalizada(
            dict: dict,
            numeroObjeto: numero,
            herdados: _apenasNaoPresentes(dict, herdadosAqui),
          ),
        );
      }
      return;
    }

    for (final filho in lista.items) {
      _percorrerArvore(
        filho,
        destino,
        visitados,
        profundidade + 1,
        herdadosAqui,
      );
    }
  }

  Map<String, PdfObject> _apenasNaoPresentes(
    PdfDict pagina,
    Map<String, PdfObject> herdados,
  ) {
    final faltantes = <String, PdfObject>{};
    for (final entrada in herdados.entries) {
      if (!pagina.tem(entrada.key)) faltantes[entrada.key] = entrada.value;
    }
    return faltantes;
  }

  /// Quantidade de páginas — primeiro pelo /Count, que é mais barato.
  int contarPaginas() {
    final contagem = catalogo?.dicionario('Pages')?.inteiro('Count');
    if (contagem != null && contagem > 0) return contagem;
    final raiz = catalogo?['Pages'];
    final resolvido = resolver(raiz);
    if (resolvido is PdfDict) {
      final contagem2 = resolvido.inteiro('Count');
      if (contagem2 != null && contagem2 > 0) return contagem2;
    }
    return paginas().length;
  }

  // ------------------------------------------------------------- marcadores
  List<MarcadorPdf> marcadores() {
    final cat = catalogo;
    if (cat == null) return const [];

    // Mapeia referência de página → número (1-based).
    final mapaPaginas = <int, int>{};
    final lista = paginas();
    for (var i = 0; i < lista.length; i++) {
      final numero = lista[i].numeroObjeto;
      if (numero != null) mapaPaginas[numero] = i + 1;
    }

    final raiz = cat['Outlines'] ?? cat.dicionario('Outlines');
    final resolvido = resolver(raiz);
    if (resolvido is! PdfDict) return const [];

    final destino = <MarcadorPdf>[];
    _percorrerOutlines(resolvido, destino, mapaPaginas, 0, 0);
    return destino;
  }

  int _percorrerOutlines(
    PdfDict no,
    List<MarcadorPdf> destino,
    Map<int, int> mapaPaginas,
    int nivel,
    int visitados,
  ) {
    var atual = resolver(no['First']);
    var contador = visitados;

    while (atual is PdfDict && contador < 5000 && nivel < 16) {
      contador++;
      final titulo = resolver(atual['Title']) is PdfString
          ? (resolver(atual['Title']) as PdfString).texto.trim()
          : '(sem título)';
      final pagina = _paginaDoDestino(atual, mapaPaginas);
      destino.add(MarcadorPdf(titulo: titulo, pagina: pagina, nivel: nivel));

      final temFilhos = atual.tem('First');
      if (temFilhos) {
        contador = _percorrerOutlines(
          atual,
          destino,
          mapaPaginas,
          nivel + 1,
          contador,
        );
      }
      atual = resolver(atual['Next']);
    }
    return contador;
  }

  int _paginaDoDestino(PdfDict item, Map<int, int> mapaPaginas) {
    var destino = item['Dest'];

    if (destino == null) {
      final acao = resolver(item['A']);
      if (acao is PdfDict) destino = acao['D'];
    }

    // Destino nomeado pode vir como nome (/Dest /cap1) ou como texto
    // (/Dest (cap1)) — este último é o mais comum em PDFs modernos.
    if (destino is PdfName) {
      destino = _destinoNomeado(destino.value);
    } else if (destino is PdfString) {
      destino = _destinoNomeado(destino.texto);
    }

    final lista = resolver(destino);
    if (lista is PdfArray && lista.items.isNotEmpty) {
      final alvo = lista.items.first;
      if (alvo is PdfRef) return mapaPaginas[alvo.numero] ?? 0;
      if (alvo is PdfNumber) return alvo.comoInteiro;
    }
    return 0;
  }

  /// Destinos nomeados (/Dests no catálogo ou em /Names).
  PdfObject? _destinoNomeado(String nome) {
    final cat = catalogo;
    if (cat == null) return null;

    final direto = resolver(cat['Dests']);
    if (direto is PdfDict) {
      final valor = direto[nome];
      if (valor != null) {
        final resolvido = resolver(valor);
        if (resolvido is PdfDict) return resolvido['D'];
        return resolvido;
      }
    }

    final arvore = resolver(cat['Names']);
    if (arvore is PdfDict) {
      final dests = resolver(arvore['Dests']);
      if (dests is PdfDict) {
        return _buscarNaArvoreDeNomes(dests, nome, 0);
      }
    }
    return null;
  }

  PdfObject? _buscarNaArvoreDeNomes(PdfDict no, String nome, int profundidade) {
    if (profundidade > 16) return null;

    final nomes = resolver(no['Names']);
    if (nomes is PdfArray) {
      for (var i = 0; i + 1 < nomes.items.length; i += 2) {
        final chave = resolver(nomes.items[i]);
        if (chave is PdfString && chave.texto == nome) {
          final valor = resolver(nomes.items[i + 1]);
          if (valor is PdfDict) return valor['D'];
          return valor;
        }
      }
    }

    final filhos = resolver(no['Kids']);
    if (filhos is PdfArray) {
      for (final filho in filhos.items) {
        final resultado = _buscarNaArvoreDeNomes(
          resolver(filho) as PdfDict? ?? const PdfDict(),
          nome,
          profundidade + 1,
        );
        if (resultado != null) return resultado;
      }
    }
    return null;
  }

  // --------------------------------------------------------------- metadados
  PdfDict? get info {
    final referencia = trailer['Info'];
    final resolvido = resolver(referencia);
    return resolvido is PdfDict ? resolvido : null;
  }

  String? get titulo => info?.texto('Title')?.texto;
  String? get autor => info?.texto('Author')?.texto;
  String? get produtor => info?.texto('Producer')?.texto;

  /// O catálogo, como referência (usado para remontar o documento).
  PdfRef? get referenciaCatalogo {
    final raiz = trailer['Root'];
    return raiz is PdfRef ? raiz : null;
  }

  // ---------------------------------------------------------------- filtros
  /// Decodifica um fluxo. Suporta FlateDecode (com preditores), ASCIIHex e
  /// ASCII85 — o bastante para xref, object streams e fluxos de conteúdo.
  /// Devolve `null` quando o filtro não é suportado (ex.: DCTDecode).
  Uint8List? decodificarFluxo(PdfStream fluxo) {
    var dados = fluxo.raw;
    final filtros = fluxo.filtros;
    final parametros = _parametrosDoFluxo(fluxo);

    for (var i = 0; i < filtros.length; i++) {
      final nome = filtros[i];
      final parametro = i < parametros.length ? parametros[i] : null;
      switch (nome) {
        case 'FlateDecode':
        case 'Fl':
          dados = _inflar(dados);
          dados = _aplicarPreditor(dados, parametro);
        case 'ASCIIHexDecode':
        case 'AHx':
          dados = _asciiHex(dados);
        case 'ASCII85Decode':
        case 'A85':
          dados = _ascii85(dados);
        default:
          return null;
      }
    }
    return dados;
  }

  List<PdfDict?> _parametrosDoFluxo(PdfStream fluxo) {
    final bruto = resolver(fluxo.dict['DecodeParms'] ?? fluxo.dict['DP']);
    if (bruto is PdfDict) return [bruto];
    if (bruto is PdfArray) {
      return [
        for (final item in bruto.items)
          resolver(item) is PdfDict ? resolver(item) as PdfDict : null,
      ];
    }
    return const [];
  }

  Uint8List _inflar(Uint8List dados) {
    try {
      return Uint8List.fromList(ZLibDecoder().convert(dados));
    } catch (_) {
      try {
        return Uint8List.fromList(ZLibDecoder(raw: true).convert(dados));
      } catch (_) {
        return dados;
      }
    }
  }

  Uint8List _aplicarPreditor(Uint8List dados, PdfDict? parametros) {
    if (parametros == null) return dados;
    final preditor = parametros.inteiro('Predictor') ?? 1;
    if (preditor <= 1) return dados;

    final colunas = parametros.inteiro('Columns') ?? 1;
    final cores = parametros.inteiro('Colors') ?? 1;
    final bits = parametros.inteiro('BitsPerComponent') ?? 8;

    if (preditor == 2) {
      return _preditorTiff(dados, colunas, cores, bits);
    }
    if (preditor < 10) return dados;

    final bytesPorPixel = ((cores * bits) + 7) ~/ 8;
    final linhaBytes = ((colunas * cores * bits) + 7) ~/ 8;
    final resultado = Uint8List(dados.length);
    var anterior = Uint8List(linhaBytes);
    var origem = 0;
    var destino = 0;

    while (origem < dados.length) {
      if (origem >= dados.length) break;
      final tipo = dados[origem];
      origem++;
      final restante = dados.length - origem;
      if (restante <= 0) break;
      final tamanhoLinha = restante < linhaBytes ? restante : linhaBytes;
      final linha = Uint8List.fromList(
        dados.sublist(origem, origem + tamanhoLinha),
      );
      origem += tamanhoLinha;

      for (var i = 0; i < linha.length; i++) {
        final esquerda = i >= bytesPorPixel ? linha[i - bytesPorPixel] : 0;
        final acima = i < anterior.length ? anterior[i] : 0;
        final cimaEsquerda =
            i >= bytesPorPixel && i - bytesPorPixel < anterior.length
            ? anterior[i - bytesPorPixel]
            : 0;
        var valor = linha[i];
        switch (tipo) {
          case 0:
            break;
          case 1:
            valor = valor + esquerda;
          case 2:
            valor = valor + acima;
          case 3:
            valor = valor + ((esquerda + acima) ~/ 2);
          case 4:
            valor = valor + _paeth(esquerda, acima, cimaEsquerda);
        }
        linha[i] = valor & 0xFF;
      }

      for (var i = 0; i < linha.length && destino < resultado.length; i++) {
        resultado[destino++] = linha[i];
      }
      anterior = linha;
    }

    return Uint8List.sublistView(resultado, 0, destino);
  }

  Uint8List _preditorTiff(Uint8List dados, int colunas, int cores, int bits) {
    if (bits != 8) return dados;
    final linhaBytes = colunas * cores;
    if (linhaBytes <= 0) return dados;
    final resultado = Uint8List(dados.length);
    for (
      var linha = 0;
      linha + linhaBytes <= dados.length;
      linha += linhaBytes
    ) {
      for (var i = 0; i < linhaBytes; i++) {
        final valor = dados[linha + i];
        resultado[linha + i] = i >= cores
            ? (valor + resultado[linha + i - cores]) & 0xFF
            : valor;
      }
    }
    return resultado;
  }

  int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  Uint8List _asciiHex(Uint8List dados) {
    final saida = <int>[];
    var alto = -1;
    for (final byte in dados) {
      if (byte == 0x3E) break; // '>'
      final valor = _valorHex(byte);
      if (valor < 0) continue;
      if (alto < 0) {
        alto = valor;
      } else {
        saida.add((alto << 4) | valor);
        alto = -1;
      }
    }
    if (alto >= 0) saida.add(alto << 4);
    return Uint8List.fromList(saida);
  }

  int _valorHex(int byte) {
    if (byte >= 0x30 && byte <= 0x39) return byte - 0x30;
    if (byte >= 0x41 && byte <= 0x46) return byte - 0x41 + 10;
    if (byte >= 0x61 && byte <= 0x66) return byte - 0x61 + 10;
    return -1;
  }

  Uint8List _ascii85(Uint8List dados) {
    final saida = <int>[];
    final grupo = <int>[];
    for (var i = 0; i < dados.length; i++) {
      final byte = dados[i];
      if (byte == 0x7E) break; // '~'
      if (byte == 0x3C && i + 1 < dados.length && dados[i + 1] == 0x7E) {
        // "<~" inicial
        i++;
        continue;
      }
      if (byte == 0x7A && grupo.isEmpty) {
        saida.addAll([0, 0, 0, 0]);
        continue;
      }
      if (byte < 0x21 || byte > 0x75) continue;
      grupo.add(byte - 0x21);
      if (grupo.length == 5) {
        var valor = 0;
        for (final digito in grupo) {
          valor = valor * 85 + digito;
        }
        saida.addAll([
          (valor >> 24) & 0xFF,
          (valor >> 16) & 0xFF,
          (valor >> 8) & 0xFF,
          valor & 0xFF,
        ]);
        grupo.clear();
      }
    }
    if (grupo.isNotEmpty) {
      final faltando = 5 - grupo.length;
      for (var i = 0; i < faltando; i++) {
        grupo.add(84);
      }
      var valor = 0;
      for (final digito in grupo) {
        valor = valor * 85 + digito;
      }
      final bytes = [
        (valor >> 24) & 0xFF,
        (valor >> 16) & 0xFF,
        (valor >> 8) & 0xFF,
        valor & 0xFF,
      ];
      saida.addAll(bytes.take(4 - faltando));
    }
    return Uint8List.fromList(saida);
  }
}

/// Analisador léxico de PDF.
class _Lexer {
  _Lexer(this.dados, {this.resolvedorDeTamanho});

  final Uint8List dados;
  final int? Function(PdfRef)? resolvedorDeTamanho;
  int posicao = 0;

  static const int _nulo = 0;
  static const int _tab = 9;
  static const int _lf = 10;
  static const int _ff = 12;
  static const int _cr = 13;
  static const int _espaco = 32;

  bool get acabou => posicao >= dados.length;

  int? _byteAt(int indice) =>
      indice >= 0 && indice < dados.length ? dados[indice] : null;

  bool _ehEspaco(int byte) =>
      byte == _nulo ||
      byte == _tab ||
      byte == _lf ||
      byte == _ff ||
      byte == _cr ||
      byte == _espaco;

  bool _ehDelimitador(int byte) =>
      byte == 0x28 || // (
      byte == 0x29 || // )
      byte == 0x3C || // <
      byte == 0x3E || // >
      byte == 0x5B || // [
      byte == 0x5D || // ]
      byte == 0x7B || // {
      byte == 0x7D || // }
      byte == 0x2F || // /
      byte == 0x25; // %

  void pularEspacos() {
    while (posicao < dados.length) {
      final byte = dados[posicao];
      if (_ehEspaco(byte)) {
        posicao++;
        continue;
      }
      if (byte == 0x25) {
        while (posicao < dados.length &&
            dados[posicao] != _lf &&
            dados[posicao] != _cr) {
          posicao++;
        }
        continue;
      }
      break;
    }
  }

  bool estaEm(String palavra) {
    final fim = posicao + palavra.length;
    if (fim > dados.length) return false;
    for (var i = 0; i < palavra.length; i++) {
      if (dados[posicao + i] != palavra.codeUnitAt(i)) return false;
    }
    return true;
  }

  void avancar(int quantidade) {
    posicao = (posicao + quantidade).clamp(0, dados.length);
  }

  String? lerPalavraChave() {
    pularEspacos();
    final inicio = posicao;
    while (posicao < dados.length) {
      final byte = dados[posicao];
      if (_ehEspaco(byte) || _ehDelimitador(byte)) break;
      posicao++;
    }
    if (posicao == inicio) return null;
    return latin1.decode(dados.sublist(inicio, posicao), allowInvalid: true);
  }

  int? lerInteiro() {
    pularEspacos();
    final inicio = posicao;
    if (posicao < dados.length &&
        (dados[posicao] == 0x2B || dados[posicao] == 0x2D)) {
      posicao++;
    }
    while (posicao < dados.length) {
      final byte = dados[posicao];
      if (byte < 0x30 || byte > 0x39) break;
      posicao++;
    }
    if (posicao == inicio) return null;
    return int.tryParse(
      latin1.decode(dados.sublist(inicio, posicao), allowInvalid: true),
    );
  }

  /// Lê o próximo objeto a partir da posição atual.
  PdfObject? lerObjeto() {
    pularEspacos();
    if (posicao >= dados.length) return null;

    final byte = dados[posicao];
    switch (byte) {
      case 0x2F: // /
        return _lerNome();
      case 0x28: // (
        return _lerStringLiteral();
      case 0x5B: // [
        return _lerArray();
      case 0x3C: // <
        if (_byteAt(posicao + 1) == 0x3C) {
          return _lerDicionario();
        }
        return _lerStringHex();
      case 0x5D: // ]
      case 0x3E: // >
      case 0x29: // )
        posicao++;
        return null;
    }

    final palavra = lerPalavraChave();
    if (palavra == null) return null;

    switch (palavra) {
      case 'true':
        return PdfBool.verdadeiro;
      case 'false':
        return PdfBool.falso;
      case 'null':
        return PdfNull.instance;
    }

    // Número — pode ser referência ("12 0 R").
    if (_pareceNumero(palavra)) {
      final valor = num.tryParse(palavra);
      if (valor == null) return null;
      if (valor is int && valor >= 0) {
        final referencia = _tentarReferencia(valor);
        if (referencia != null) return referencia;
      }
      return PdfNumber(valor);
    }

    // Palavra desconhecida: devolvemos como nome para não travar a leitura.
    return PdfName(palavra);
  }

  bool _pareceNumero(String texto) {
    if (texto.isEmpty) return false;
    final primeiro = texto.codeUnitAt(0);
    if (primeiro == 0x2B || primeiro == 0x2D || primeiro == 0x2E) {
      return texto.length > 1;
    }
    return primeiro >= 0x30 && primeiro <= 0x39;
  }

  PdfRef? _tentarReferencia(int numero) {
    final guardado = posicao;
    pularEspacos();
    final geracao = lerInteiro();
    if (geracao == null || geracao < 0) {
      posicao = guardado;
      return null;
    }
    pularEspacos();
    if (posicao < dados.length &&
        dados[posicao] ==
            0x52 // R
            ) {
      final proximo = _byteAt(posicao + 1);
      if (proximo == null || _ehEspaco(proximo) || _ehDelimitador(proximo)) {
        posicao++;
        return PdfRef(numero, geracao);
      }
    }
    posicao = guardado;
    return null;
  }

  PdfName _lerNome() {
    posicao++; // consome '/'
    final bytes = <int>[];
    while (posicao < dados.length) {
      final byte = dados[posicao];
      if (_ehEspaco(byte) || _ehDelimitador(byte)) break;
      if (byte == 0x23 && posicao + 2 < dados.length) {
        final alto = _hex(dados[posicao + 1]);
        final baixo = _hex(dados[posicao + 2]);
        if (alto >= 0 && baixo >= 0) {
          bytes.add((alto << 4) | baixo);
          posicao += 3;
          continue;
        }
      }
      bytes.add(byte);
      posicao++;
    }
    return PdfName(latin1.decode(bytes, allowInvalid: true));
  }

  int _hex(int byte) {
    if (byte >= 0x30 && byte <= 0x39) return byte - 0x30;
    if (byte >= 0x41 && byte <= 0x46) return byte - 0x41 + 10;
    if (byte >= 0x61 && byte <= 0x66) return byte - 0x61 + 10;
    return -1;
  }

  PdfString _lerStringLiteral() {
    posicao++; // consome '('
    final bytes = <int>[];
    var nivel = 1;
    while (posicao < dados.length) {
      final byte = dados[posicao++];
      if (byte == 0x5C) {
        if (posicao >= dados.length) break;
        final escapado = dados[posicao++];
        switch (escapado) {
          case 0x6E:
            bytes.add(_lf);
          case 0x72:
            bytes.add(_cr);
          case 0x74:
            bytes.add(_tab);
          case 0x62:
            bytes.add(8);
          case 0x66:
            bytes.add(_ff);
          case 0x28:
            bytes.add(0x28);
          case 0x29:
            bytes.add(0x29);
          case 0x5C:
            bytes.add(0x5C);
          case _cr:
            if (posicao < dados.length && dados[posicao] == _lf) posicao++;
          case _lf:
            break;
          default:
            if (escapado >= 0x30 && escapado <= 0x37) {
              var valor = escapado - 0x30;
              for (var i = 0; i < 2; i++) {
                if (posicao < dados.length &&
                    dados[posicao] >= 0x30 &&
                    dados[posicao] <= 0x37) {
                  valor = valor * 8 + (dados[posicao] - 0x30);
                  posicao++;
                } else {
                  break;
                }
              }
              bytes.add(valor & 0xFF);
            } else {
              bytes.add(escapado);
            }
        }
        continue;
      }
      if (byte == 0x28) {
        nivel++;
        bytes.add(byte);
        continue;
      }
      if (byte == 0x29) {
        nivel--;
        if (nivel == 0) break;
        bytes.add(byte);
        continue;
      }
      bytes.add(byte);
    }
    return PdfString(Uint8List.fromList(bytes));
  }

  PdfString _lerStringHex() {
    posicao++; // consome '<'
    final bytes = <int>[];
    var alto = -1;
    while (posicao < dados.length) {
      final byte = dados[posicao++];
      if (byte == 0x3E) break;
      final valor = _hex(byte);
      if (valor < 0) continue;
      if (alto < 0) {
        alto = valor;
      } else {
        bytes.add((alto << 4) | valor);
        alto = -1;
      }
    }
    if (alto >= 0) bytes.add(alto << 4);
    return PdfString(Uint8List.fromList(bytes), hex: true);
  }

  PdfArray _lerArray() {
    posicao++; // consome '['
    final itens = <PdfObject>[];
    while (true) {
      pularEspacos();
      if (posicao >= dados.length) break;
      if (dados[posicao] == 0x5D) {
        posicao++;
        break;
      }
      final objeto = lerObjeto();
      if (objeto == null) {
        if (posicao >= dados.length) break;
        // Evita laço infinito em dados corrompidos.
        if (dados[posicao] == 0x5D) {
          posicao++;
          break;
        }
        posicao++;
        continue;
      }
      itens.add(objeto);
    }
    return PdfArray(itens);
  }

  PdfObject _lerDicionario() {
    posicao += 2; // consome '<<'
    final entradas = <String, PdfObject>{};

    while (true) {
      pularEspacos();
      if (posicao >= dados.length) break;
      if (dados[posicao] == 0x3E && _byteAt(posicao + 1) == 0x3E) {
        posicao += 2;
        break;
      }
      if (dados[posicao] != 0x2F) {
        // Chave inválida: tenta pular um objeto para não travar.
        final antes = posicao;
        final lixo = lerObjeto();
        if (lixo == null && posicao == antes) posicao++;
        continue;
      }
      final chave = _lerNome();
      pularEspacos();
      if (posicao < dados.length &&
          dados[posicao] == 0x3E &&
          _byteAt(posicao + 1) == 0x3E) {
        posicao += 2;
        break;
      }
      final valor = lerObjeto();
      if (valor != null) entradas[chave.value] = valor;
    }

    final dicionario = PdfDict(entradas);

    // Um dicionário pode ser seguido da palavra `stream`.
    pularEspacos();
    if (estaEm('stream')) {
      posicao += 'stream'.length;
      // Após `stream` vem CRLF ou LF (alguns arquivos erram e usam só CR).
      if (_byteAt(posicao) == _cr) posicao++;
      if (_byteAt(posicao) == _lf) posicao++;
      return _lerFluxo(dicionario);
    }

    return dicionario;
  }

  PdfStream _lerFluxo(PdfDict dicionario) {
    final inicio = posicao;
    var tamanho = dicionario.inteiro('Length');

    final referencia = dicionario['Length'];
    if (tamanho == null && referencia is PdfRef) {
      tamanho = resolvedorDeTamanho?.call(referencia);
    }

    var fim = -1;
    if (tamanho != null && tamanho >= 0 && inicio + tamanho <= dados.length) {
      // Confere se logo depois vem `endstream`; se não vier, o tamanho mente.
      final candidato = inicio + tamanho;
      final scanner = _Lexer(dados)..posicao = candidato;
      scanner.pularEspacos();
      if (scanner.estaEm('endstream')) {
        fim = candidato;
      }
    }

    if (fim < 0) {
      fim = _procurarEndstream(inicio);
    }

    if (fim < 0) fim = dados.length;

    final bytes = Uint8List.sublistView(dados, inicio, fim);
    posicao = fim;
    final scanner = _Lexer(dados)..posicao = posicao;
    scanner.pularEspacos();
    if (scanner.estaEm('endstream')) {
      posicao = scanner.posicao + 'endstream'.length;
    }

    return PdfStream(dicionario, bytes);
  }

  int _procurarEndstream(int inicio) {
    // Procura a palavra `endstream` a partir do início dos dados.
    for (var i = inicio; i + 9 <= dados.length; i++) {
      if (dados[i] == 0x65 && // e
          dados[i + 1] == 0x6E && // n
          dados[i + 2] == 0x64 && // d
          dados[i + 3] == 0x73) {
        var fim = i;
        // Remove o EOL que precede `endstream`.
        if (fim > inicio && dados[fim - 1] == _lf) fim--;
        if (fim > inicio && dados[fim - 1] == _cr) fim--;
        return fim;
      }
    }
    return -1;
  }
}
