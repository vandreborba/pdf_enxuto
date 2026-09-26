import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Uma aba (planilha) pronta para ser gravada.
class AbaPlanilha {
  const AbaPlanilha({required this.nome, required this.linhas});

  final String nome;
  final List<List<String>> linhas;

  int get colunas => linhas.fold<int>(
    0,
    (maior, linha) => linha.length > maior ? linha.length : maior,
  );

  bool get semConteudo => linhas.isEmpty || colunas == 0;
}

/// O que uma célula de texto virou: número, data ou nada (texto mesmo).
class CelulaTipada {
  const CelulaTipada(this.valor, {this.moeda = false});

  /// `int`, `double` ou `DateTime`; `null` quando é texto.
  final Object? valor;

  /// `true` quando o texto original trazia símbolo de dinheiro (R$ 1.234,56):
  /// o valor vira número — para poder somar — e a planilha mostra o símbolo.
  final bool moeda;
}

/// Descobre o tipo de uma célula de texto.
///
/// O app é brasileiro e os documentos também: "1.234,56" é mil duzentos e
/// trinta e quatro reais e cinquenta e seis centavos, não "1,23456". Números
/// assim viram número de verdade na planilha, datas viram data, e o resto
/// continua texto — sem perder nada pelo caminho.
class AnalisadorCelula {
  AnalisadorCelula._();

  /// Limite do Excel para o texto de uma célula (2^15 - 1).
  static const int limiteTexto = 32767;

  /// Acima disso um número deixa de ser confiável em ponto flutuante e é
  /// melhor manter como texto do que gravar um valor arredondado.
  static const int limiteInteiro = 9007199254740991;

  static final RegExp _inteiro = RegExp(r'^-?\d+$');
  static final RegExp _milhar = RegExp(r'^-?\d{1,3}(\.\d{3})+$');
  static final RegExp _decimalVirgula = RegExp(
    r'^-?(?:\d{1,3}(?:\.\d{3})+|\d+),\d+$',
  );
  static final RegExp _decimalPonto = RegExp(r'^-?\d+\.\d+$');
  static final RegExp _data = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

  /// Símbolo de dinheiro aceito antes (ou depois) do número.
  static final RegExp _moeda = RegExp(
    r'^(-)?\s*(R\$|US\$|\u20ac)\s*(-)?\s*([\d.,]+)$',
  );

  /// Devolve `int`, `double` ou `DateTime`; `null` quando é texto.
  static Object? valorDe(String texto) => analisar(texto).valor;

  /// Analisa a célula inteira: valor tipado e se era dinheiro.
  static CelulaTipada analisar(String texto) {
    final limpo = texto.trim();
    if (limpo.isEmpty) return const CelulaTipada(null);

    final dinheiro = _moeda.firstMatch(limpo);
    if (dinheiro != null) {
      final valor =
          valorDe(dinheiro.group(4)!) ??
          valorDe(dinheiro.group(4)!.replaceAll('.', '').replaceAll(',', '.'));
      if (valor is num) {
        final negativo = dinheiro.group(1) != null || dinheiro.group(3) != null;
        final final_ = negativo ? -valor.abs() : valor.abs();
        return CelulaTipada(
          final_ is int ? final_ : final_.toDouble(),
          moeda: true,
        );
      }
      return const CelulaTipada(null);
    }

    final data = _data.firstMatch(limpo);
    if (data != null) {
      final dia = int.parse(data.group(1)!);
      final mes = int.parse(data.group(2)!);
      final ano = int.parse(data.group(3)!);
      if (mes >= 1 && mes <= 12 && dia >= 1 && dia <= 31) {
        final resultado = DateTime.utc(ano, mes, dia);
        // Rejeita 31/02 e afins.
        if (resultado.day == dia && resultado.month == mes) {
          return CelulaTipada(resultado);
        }
      }
      return const CelulaTipada(null);
    }

    // Códigos com zero à esquerda ("01", "007") são identificadores, não
    // números: virar número destruiria o zero.
    if (_inteiro.hasMatch(limpo)) {
      if (limpo.length > 1 && RegExp(r'^-?0').hasMatch(limpo)) {
        return const CelulaTipada(null);
      }
      final valor = int.tryParse(limpo);
      if (valor == null || valor.abs() > limiteInteiro) {
        return const CelulaTipada(null);
      }
      return CelulaTipada(valor);
    }
    if (_milhar.hasMatch(limpo)) {
      final valor = int.tryParse(limpo.replaceAll('.', ''));
      if (valor == null || valor.abs() > limiteInteiro) {
        return const CelulaTipada(null);
      }
      return CelulaTipada(valor);
    }
    if (_decimalVirgula.hasMatch(limpo)) {
      return CelulaTipada(
        double.tryParse(limpo.replaceAll('.', '').replaceAll(',', '.')),
      );
    }
    if (_decimalPonto.hasMatch(limpo)) {
      return CelulaTipada(double.tryParse(limpo));
    }
    return const CelulaTipada(null);
  }

  /// `true` quando o texto vira número ou data na planilha.
  static bool ehTipado(String texto) => valorDe(texto) != null;
}

/// Grava CSV no padrão que o Excel brasileiro abre sem susto.
class EscritorCsv {
  EscritorCsv._();

  /// Separador padrão para o Brasil: o Excel em português usa `;` porque a
  /// vírgula já é o separador decimal.
  static const String separadorPadrao = ';';

  static final RegExp _precisaAspas = RegExp(r'["\n\r;\t]');
  static final RegExp _comecaComFormula = RegExp(r'^[=+@\t\r]');

  /// Uma aba em texto CSV (sem BOM — quem grava decide o BOM).
  static String gerar(
    AbaPlanilha aba, {
    String separador = separadorPadrao,
    bool protegerFormulas = true,
  }) {
    final buffer = StringBuffer();
    for (final linha in aba.linhas) {
      for (var i = 0; i < linha.length; i++) {
        if (i > 0) buffer.write(separador);
        buffer.write(_campo(linha[i], separador, protegerFormulas));
      }
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _campo(String valor, String separador, bool protegerFormulas) {
    var texto = valor;
    if (protegerFormulas && _ehFormula(texto)) {
      texto = "'$texto";
    }
    if (texto.isEmpty) return '';
    final precisa =
        _precisaAspas.hasMatch(texto) ||
        texto.contains(separador) ||
        texto.startsWith(' ') ||
        texto.endsWith(' ');
    if (!precisa) return texto;
    return '"${texto.replaceAll('"', '""')}"';
  }

  /// Proteção contra injeção de fórmula (CWE-1236).
  ///
  /// O cuidado aqui é não estragar valores negativos: "-1.234,56" é número e
  /// continua número; só o que *não* é número e começa com caractere de
  /// fórmula recebe o apóstrofo.
  static bool _ehFormula(String texto) {
    if (texto.isEmpty) return false;
    if (_comecaComFormula.hasMatch(texto)) return true;
    // Usa a mesma noção de número do XLSX: assim a proteção do CSV e a
    // tipagem da planilha nunca discordam sobre o que é valor.
    if (texto.startsWith('-')) return !AnalisadorCelula.ehTipado(texto.trim());
    return false;
  }
}

/// Escreve XLSX (o formato do Excel, aberto também pelo LibreOffice Calc).
///
/// É um ZIP com algumas partes de XML. Este escritor monta o subconjunto
/// mínimo que o Excel e o Calc entendem bem: textos em `sharedStrings` (que é
/// o que o próprio Excel escreve), números e datas como valores tipados, linha
/// de cabeçalho congelada e largura de coluna calculada pelo conteúdo.
class EscritorXlsx {
  EscritorXlsx._();

  static const int limiteLinhas = 1048576;
  static const int limiteColunas = 16384;
  static const int limiteNomeAba = 31;

  /// Gera o arquivo. Devolve os bytes prontos para gravar.
  ///
  /// [congelarCabecalho] prende a primeira linha no topo e a deixa em negrito
  /// — é o que se espera de uma tabela com títulos de coluna.
  static Uint8List gerar(
    List<AbaPlanilha> abas, {
    bool congelarCabecalho = true,
  }) {
    final preparadas = <AbaPlanilha>[
      for (final aba in abas)
        if (!aba.semConteudo)
          AbaPlanilha(
            nome: aba.nome,
            linhas: [
              for (final linha in aba.linhas.take(limiteLinhas))
                linha.take(limiteColunas).toList(),
            ],
          ),
    ];
    final efetivas = preparadas.isEmpty
        ? <AbaPlanilha>[const AbaPlanilha(nome: 'Planilha', linhas: [])]
        : preparadas;

    final nomes = _nomesDeAbas(efetivas);

    final textos = <String, int>{};
    var totalTextos = 0;
    final corpos = <String>[];
    final larguras = <List<double>>[];

    for (final aba in efetivas) {
      final colunas = aba.colunas.clamp(1, limiteColunas);
      final larguraColunas = List<double>.filled(colunas, 0);
      final linhas = StringBuffer();
      final negrito = congelarCabecalho && aba.linhas.length > 1;

      for (var l = 0; l < aba.linhas.length; l++) {
        final linha = aba.linhas[l];
        final celulas = StringBuffer();
        for (var c = 0; c < linha.length; c++) {
          final texto = linha[c];
          if (texto.trim().isEmpty) continue;
          if (texto.length > larguraColunas[c]) {
            larguraColunas[c] = texto.length.toDouble();
          }
          final referencia = '${_letra(c)}${l + 1}';
          final estilo = l == 0 && negrito ? ' s="1"' : '';
          final analisada = AnalisadorCelula.analisar(texto);
          final valor = analisada.valor;

          if (valor is DateTime) {
            celulas.write(
              '<c r="$referencia" s="2"><v>${_serialDe(valor)}</v></c>',
            );
          } else if (valor is num && valor.isFinite) {
            // Dinheiro vira número (dá para somar) e mantém o R$ na tela.
            final moeda = analisada.moeda && !(l == 0 && negrito);
            final estiloNumero = moeda ? ' s="3"' : estilo;
            celulas.write(
              '<c r="$referencia"$estiloNumero><v>${_numero(valor)}</v></c>',
            );
          } else {
            final indice = textos.putIfAbsent(texto, () => textos.length);
            totalTextos++;
            celulas.write('<c r="$referencia" t="s"$estilo><v>$indice</v></c>');
          }
        }
        linhas.write('<row r="${l + 1}">$celulas</row>');
      }

      corpos.add(linhas.toString());
      larguras.add(larguraColunas);
    }

    final arquivo = Archive();
    void adicionar(String caminho, String conteudo) {
      final bytes = utf8.encode(conteudo);
      arquivo.addFile(ArchiveFile(caminho, bytes.length, bytes));
    }

    adicionar('[Content_Types].xml', _contentTypes(efetivas.length));
    adicionar('_rels/.rels', _rels);
    adicionar('xl/workbook.xml', _workbook(nomes));
    adicionar('xl/_rels/workbook.xml.rels', _relsWorkbook(efetivas.length));
    for (var i = 0; i < efetivas.length; i++) {
      adicionar(
        'xl/worksheets/sheet${i + 1}.xml',
        _planilha(
          corpo: corpos[i],
          larguras: larguras[i],
          linhas: efetivas[i].linhas.length,
          colunas: efetivas[i].colunas,
          congelar: congelarCabecalho && efetivas[i].linhas.length > 1,
        ),
      );
    }
    adicionar('xl/styles.xml', _styles);
    adicionar(
      'xl/sharedStrings.xml',
      _textosCompartilhados(textos, totalTextos),
    );

    return Uint8List.fromList(ZipEncoder().encode(arquivo));
  }

  // ------------------------------------------------------------------ partes
  static String _contentTypes(int abas) {
    final linhas = <String>[
      _declaracao,
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
      '<Default Extension="xml" ContentType="application/xml"/>',
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
      for (var i = 1; i <= abas; i++)
        '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>',
      '</Types>',
    ];
    return linhas.join('\n');
  }

  static String get _rels => [
    _declaracao,
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
    '</Relationships>',
  ].join('\n');

  static String _workbook(List<String> nomes) => [
    _declaracao,
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    '<sheets>',
    for (var i = 0; i < nomes.length; i++)
      '<sheet name="${_escaparAtributo(nomes[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    '</sheets>',
    '</workbook>',
  ].join('\n');

  static String _relsWorkbook(int abas) => [
    _declaracao,
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    for (var i = 1; i <= abas; i++)
      '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>',
    '<Relationship Id="rId${abas + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    '<Relationship Id="rId${abas + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>',
    '</Relationships>',
  ].join('\n');

  static String _planilha({
    required String corpo,
    required List<double> larguras,
    required int linhas,
    required int colunas,
    required bool congelar,
  }) {
    final ultimaLinha = linhas < 1 ? 1 : linhas;
    final ultimaColuna = _letra(colunas < 1 ? 0 : colunas - 1);
    final colunasXml = larguras.isEmpty
        ? ''
        : '<cols>${[for (var i = 0; i < larguras.length; i++)
            if (larguras[i] > 0) '<col min="${i + 1}" max="${i + 1}" width="${_largura(larguras[i])}" customWidth="1"/>'].join()}</cols>';
    final painel = congelar
        ? '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
              '<selection pane="bottomLeft" activeCell="A2" sqref="A2"/>'
        : '';
    return [
      _declaracao,
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      '<dimension ref="A1:$ultimaColuna$ultimaLinha"/>',
      '<sheetViews><sheetView workbookViewId="0">$painel</sheetView></sheetViews>',
      '<sheetFormatPr defaultRowHeight="15"/>',
      colunasXml,
      '<sheetData>$corpo</sheetData>',
      '</worksheet>',
    ].where((linha) => linha.isNotEmpty).join('\n');
  }

  static const String _declaracao =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

  static String get _styles => [
    _declaracao,
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    '<numFmts count="2">',
    '<numFmt numFmtId="164" formatCode="DD/MM/YYYY"/>',
    '<numFmt numFmtId="165" formatCode="R\$ #,##0.00"/>',
    '</numFmts>',
    '<fonts count="2">',
    '<font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>',
    '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>',
    '</fonts>',
    '<fills count="2">',
    '<fill><patternFill patternType="none"/></fill>',
    '<fill><patternFill patternType="gray125"/></fill>',
    '</fills>',
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>',
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
    '<cellXfs count="4">',
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>',
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>',
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>',
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>',
    '</cellXfs>',
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>',
    '</styleSheet>',
  ].join('\n');

  static String _textosCompartilhados(Map<String, int> textos, int total) {
    final itens = List<String>.filled(textos.length, '');
    textos.forEach((texto, indice) {
      itens[indice] = texto;
    });
    return [
      _declaracao,
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="$total" uniqueCount="${itens.length}">',
      for (final item in itens)
        '<si><t xml:space="preserve">${_escapar(item)}</t></si>',
      '</sst>',
    ].join('\n');
  }

  // --------------------------------------------------------------- auxiliares
  /// Nomes de aba válidos e únicos: até 31 caracteres, sem `[ ] : * ? / \`.
  ///
  /// O Excel recusa nomes repetidos, então o segundo "p3" vira "p3 (2)".
  static List<String> _nomesDeAbas(List<AbaPlanilha> abas) {
    final usados = <String>{};
    final nomes = <String>[];
    for (var i = 0; i < abas.length; i++) {
      final base = _limparNome(abas[i].nome, i);
      var candidato = base;
      var sufixo = 2;
      while (usados.contains(candidato.toLowerCase())) {
        final marca = ' ($sufixo)';
        candidato = base.length + marca.length > limiteNomeAba
            ? '${base.substring(0, limiteNomeAba - marca.length)}$marca'
            : '$base$marca';
        sufixo++;
      }
      usados.add(candidato.toLowerCase());
      nomes.add(candidato);
    }
    return nomes;
  }

  static String _limparNome(String bruto, int indice) {
    var nome = bruto
        .replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (nome.isEmpty) nome = 'Planilha ${indice + 1}';
    if (nome.length > limiteNomeAba) {
      nome = nome.substring(0, limiteNomeAba).trim();
    }
    // "History" é um nome reservado do Excel.
    if (nome.toLowerCase() == 'history') nome = 'Planilha ${indice + 1}';
    return nome;
  }

  /// 0 → A, 25 → Z, 26 → AA.
  static String _letra(int coluna) {
    var restante = coluna;
    final letras = <int>[];
    while (true) {
      letras.add(65 + (restante % 26));
      restante = restante ~/ 26 - 1;
      if (restante < 0) break;
    }
    return String.fromCharCodes(letras.reversed);
  }

  static String _numero(num valor) =>
      valor is int ? '$valor' : valor.toString();

  /// Data do Excel: dias desde 30/12/1899 (o Excel conta 1900 como bissexto).
  static int _serialDe(DateTime data) => DateTime.utc(
    data.year,
    data.month,
    data.day,
  ).difference(DateTime.utc(1899, 12, 30)).inDays;

  static String _largura(double caracteres) =>
      (caracteres + 2).clamp(8.0, 60.0).toStringAsFixed(1);

  /// Escapa o texto e remove caracteres que o XML 1.0 proíbe.
  static String _escapar(String texto) => _escaparBase(
    texto.length > AnalisadorCelula.limiteTexto
        ? texto.substring(0, AnalisadorCelula.limiteTexto)
        : texto,
    atributo: false,
  );

  static String _escaparAtributo(String texto) =>
      _escaparBase(texto, atributo: true);

  static String _escaparBase(String texto, {required bool atributo}) {
    final buffer = StringBuffer();
    for (final rune in texto.runes) {
      switch (rune) {
        case 0x09:
        case 0x0A:
        case 0x0D:
          buffer.writeCharCode(rune);
        case 0x26:
          buffer.write('&amp;');
        case 0x3C:
          buffer.write('&lt;');
        case 0x3E:
          buffer.write('&gt;');
        case 0x22:
          buffer.write(atributo ? '&quot;' : '"');
        case 0x27:
          buffer.write(atributo ? '&apos;' : "'");
        default:
          // Controles que o XML não aceita (e o U+FFFD que alguns PDFs
          // deixam para trás) são trocados por espaço para o arquivo nunca
          // sair corrompido.
          if (rune < 0x20 ||
              rune == 0xFFFE ||
              rune == 0xFFFF ||
              rune == 0xFFFD) {
            buffer.write(' ');
          } else {
            buffer.writeCharCode(rune);
          }
      }
    }
    return buffer.toString();
  }
}
