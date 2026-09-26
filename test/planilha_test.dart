import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_enxuto/models/planilha_options.dart';
import 'package:pdf_enxuto/services/servico_planilha.dart';
import 'package:pdf_enxuto/services/tabela/detector_tabela.dart';
import 'package:pdf_enxuto/services/tabela/escritor_planilha.dart';
import 'package:pdf_enxuto/services/tabela/extrator_texto.dart';

/// Monta uma palavra como o pdfium entregaria: um retângulo por palavra.
PalavraTexto palavra(
  String texto,
  double esquerda,
  double base, {
  double altura = 10,
  double largura = 5,
}) => PalavraTexto(
  texto: texto,
  esquerda: esquerda,
  direita: esquerda + texto.length * largura,
  base: base,
  topo: base + altura,
);

/// Uma linha de tabela: as colunas começam sempre nas mesmas posições.
List<PalavraTexto> linhaDeTabela(
  List<String> celulas,
  double base, {
  List<double> colunas = const [50, 250, 420],
}) {
  final palavras = <PalavraTexto>[];
  for (var i = 0; i < celulas.length && i < colunas.length; i++) {
    palavras.add(palavra(celulas[i], colunas[i], base));
  }
  return palavras;
}

/// Uma página com um cabeçalho repetido, um título e uma tabela de verdade.
PaginaLida paginaComTabela({int numero = 1, bool comRodape = true}) {
  final palavras = <PalavraTexto>[
    palavra('RELATÓRIO MENSAL', 200, 800),
    ...linhaDeTabela(['Data', 'Histórico', 'Valor'], 770),
    ...linhaDeTabela(['01/03/2026', 'PIX recebido', '1.234,56'], 755),
    ...linhaDeTabela(['02/03/2026', 'Pagamento boleto', '-234,56'], 740),
    ...linhaDeTabela(['03/03/2026', 'TED enviada', '-1.000,00'], 725),
    if (comRodape) palavra('Página $numero de 9', 260, 40),
  ];
  return PaginaLida(
    numero: numero,
    palavras: palavras,
  );
}

void main() {
  group('AnalisadorCelula', () {
    test('entende números no jeito brasileiro', () {
      expect(AnalisadorCelula.valorDe('1.234,56'), 1234.56);
      expect(AnalisadorCelula.valorDe('-1.234,56'), -1234.56);
      expect(AnalisadorCelula.valorDe('0,00'), 0.0);
      expect(AnalisadorCelula.valorDe('7.578,84'), 7578.84);
      // Sem separador de milhar, com quatro ou mais dígitos, também é número.
      expect(AnalisadorCelula.valorDe('1234,56'), 1234.56);
      expect(AnalisadorCelula.valorDe('1000,00'), 1000.0);
      expect(AnalisadorCelula.valorDe('50000,00'), 50000.0);
      expect(AnalisadorCelula.valorDe('1.234'), 1234);
      expect(AnalisadorCelula.valorDe('1234.56'), 1234.56);
      expect(AnalisadorCelula.valorDe('-42'), -42);
    });

    test('não transforma código nem documento', () {
      expect(AnalisadorCelula.valorDe('01'), isNull);
      expect(AnalisadorCelula.valorDe('007'), isNull);
      expect(AnalisadorCelula.valorDe('041.665.209-38'), isNull);
      expect(AnalisadorCelula.valorDe('12,5%'), isNull);
      expect(AnalisadorCelula.valorDe(''), isNull);
    });

    test('dinheiro vira número, com a marca de dinheiro guardada', () {
      final real = AnalisadorCelula.analisar('R\$ 10,00');
      expect(real.valor, 10.0);
      expect(real.moeda, isTrue);

      expect(AnalisadorCelula.valorDe('R\$1.144,01'), 1144.01);
      expect(AnalisadorCelula.analisar('R\$1.144,01').moeda, isTrue);
      expect(AnalisadorCelula.valorDe('-R\$ 1.234,56'), -1234.56);
      expect(AnalisadorCelula.valorDe('R\$ -1.234,56'), -1234.56);
      expect(AnalisadorCelula.valorDe('US\$ 99,90'), 99.90);
      // Sem símbolo, não é dinheiro.
      expect(AnalisadorCelula.analisar('1.234,56').moeda, isFalse);
    });

    test('entende datas e recusa data que não existe', () {
      expect(
        AnalisadorCelula.valorDe('31/12/2024'),
        DateTime.utc(2024, 12, 31),
      );
      expect(AnalisadorCelula.valorDe('01/03/2026'), DateTime.utc(2026, 3, 1));
      expect(AnalisadorCelula.valorDe('31/02/2026'), isNull);
      expect(AnalisadorCelula.valorDe('13/13/2026'), isNull);
    });
  });

  group('DetectorTabela', () {
    test('reconstrói uma tabela de três colunas', () {
      final pagina = paginaComTabela();
      final tabelas = DetectorTabela.detectar(pagina.palavras);

      expect(tabelas, hasLength(1));
      final tabela = tabelas.first;
      expect(tabela.colunas, 3);
      expect(tabela.pareceTabela, isTrue);
      expect(tabela.linhas.first, ['Data', 'Histórico', 'Valor']);
      expect(tabela.linhas[1], ['01/03/2026', 'PIX recebido', '1.234,56']);
      expect(tabela.linhas[3], ['03/03/2026', 'TED enviada', '-1.000,00']);
    });

    test('cada palavra fica na coluna certa, mesmo com texto longo', () {
      // Uma tabela de verdade: várias linhas, com o texto da coluna do meio
      // quebrando em palavras em posições diferentes a cada linha.
      List<PalavraTexto> meio(List<String> palavras, double base) {
        var x = 250.0;
        final saida = <PalavraTexto>[];
        for (final texto in palavras) {
          saida.add(palavra(texto, x, base));
          x += texto.length * 5 + 5;
        }
        return saida;
      }

      final palavras = <PalavraTexto>[
        ...linhaDeTabela(['Data', 'Histórico', 'Valor'], 770),
        ...linhaDeTabela(['01/03/2026', '', '1.234,56'], 755),
        ...meio(['PIX', 'recebido', 'de', 'João'], 755),
        ...linhaDeTabela(['02/03/2026', '', '-234,56'], 740),
        ...meio(['Pagamento', 'de', 'boleto', 'bancário'], 740),
        ...linhaDeTabela(['03/03/2026', '', '-1.000,00'], 725),
        ...meio(['TED', 'para', 'Mariana'], 725),
        ...linhaDeTabela(['04/03/2026', '', '20,00'], 710),
        ...meio(['DOC', 'enviado', 'ao', 'cliente'], 710),
        ...linhaDeTabela(['05/03/2026', '', '30,00'], 695),
        ...meio(['Boleto', 'pago', 'hoje'], 695),
        ...linhaDeTabela(['06/03/2026', '', '40,00'], 680),
        ...meio(['Saque', 'no', 'caixa'], 680),
      ];

      final tabela = DetectorTabela.detectar(palavras).first;
      expect(tabela.colunas, 3);
      expect(tabela.linhas[1][1], 'PIX recebido de João');
      expect(tabela.linhas[2][1], 'Pagamento de boleto bancário');
      expect(tabela.linhas[6][1], 'Saque no caixa');
    });

    test('junta na linha de cima o texto que é continuação de uma célula', () {
      final palavras = <PalavraTexto>[
        ...linhaDeTabela(['Data', 'Histórico', 'Valor'], 770),
        ...linhaDeTabela(['01/03/2026', 'PIX recebido de', '1.234,56'], 755),
        palavra('João da Silva', 250, 741),
        ...linhaDeTabela(['02/03/2026', 'Pagamento', '-234,56'], 720),
        ...linhaDeTabela(['03/03/2026', 'TED enviada', '-1.000,00'], 705),
      ];
      final tabela = DetectorTabela.detectar(palavras).first;
      expect(tabela.linhas[1][1], contains('João da Silva'));
      // A continuação não virou uma linha solta.
      expect(
        tabela.linhas.where((linha) => linha[0].isEmpty && linha[2].isEmpty),
        isEmpty,
      );
    });

    test('junta número partido entre fragmentos', () {
      final palavras = <PalavraTexto>[
        ...linhaDeTabela(['Data', 'Histórico', 'Valor'], 770),
        palavra('01/03/2026', 50, 755),
        palavra('PIX', 250, 755),
        palavra('1.234', 420, 755),
        palavra(',56', 445, 755),
        ...linhaDeTabela(['02/03/2026', 'TED', '20,00'], 740),
        ...linhaDeTabela(['03/03/2026', 'DOC', '30,00'], 725),
      ];
      final tabela = DetectorTabela.detectar(palavras).first;
      expect(tabela.linhas[1][2], '1.234,56');
    });

    test('separa duas tabelas diferentes na mesma página', () {
      final palavras = <PalavraTexto>[
        ...linhaDeTabela(['Data', 'Histórico', 'Valor'], 770),
        ...linhaDeTabela(['01/03/2026', 'PIX', '10,00'], 755),
        ...linhaDeTabela(['02/03/2026', 'TED', '20,00'], 740),
        // Bloco de texto corrido no meio, longe das colunas da tabela.
        palavra(
          'Este parágrafo explica o extrato acima em uma linha larga',
          50,
          600,
        ),
        palavra(
          'e continua aqui, sem nenhuma coluna alinhada com o resto.',
          50,
          585,
        ),
        ...linhaDeTabela(['Data', 'Histórico', 'Valor'], 550),
        ...linhaDeTabela(['03/03/2026', 'DOC', '30,00'], 535),
        ...linhaDeTabela(['04/03/2026', 'PIX', '40,00'], 520),
      ];
      final tabelas = DetectorTabela.detectar(palavras);
      expect(tabelas.length, 2);
      expect(tabelas.first.linhas.first.first, 'Data');
      expect(tabelas.last.linhas.last.last, '40,00');
    });

    test('reaproveita as linhas já agrupadas sem mudar o resultado', () {
      final pagina = paginaComTabela();
      final linhas = DetectorTabela.linhasDe(pagina.palavras);
      final comLinhas = DetectorTabela.detectar(
        pagina.palavras,
        linhas: linhas,
      ).first;
      final semLinhas = DetectorTabela.detectar(pagina.palavras).first;
      expect(comLinhas.linhas, semLinhas.linhas);
      expect(comLinhas.colunas, semLinhas.colunas);
    });

    test('modo texto devolve uma coluna por linha', () {
      final pagina = paginaComTabela();
      final tabelas = DetectorTabela.detectar(
        pagina.palavras,
        modo: ModoPlanilha.texto,
      );
      expect(tabelas, hasLength(1));
      expect(tabelas.first.colunas, 1);
      expect(tabelas.first.linhas.length, 6);
      expect(tabelas.first.linhas[1].first, contains('Data Histórico Valor'));
    });

    test('página sem tabela nenhuma vira texto em uma coluna', () {
      final palavras = <PalavraTexto>[
        palavra('Contrato de prestação de serviços', 50, 700),
        palavra('As partes acima identificadas acordam o seguinte.', 50, 680),
      ];
      final tabelas = DetectorTabela.detectar(palavras);
      expect(tabelas, hasLength(1));
      expect(tabelas.first.pareceTabela, isFalse);
      expect(tabelas.first.colunas, 1);
    });

    test('página vazia não quebra nada', () {
      expect(DetectorTabela.detectar(const []), isEmpty);
      expect(DetectorTabela.linhasDe(const []), isEmpty);
    });

    test('a sensibilidade muda a quantidade de colunas', () {
      final palavras = <PalavraTexto>[
        ...linhaDeTabela(['Descrição', 'Débito', 'Crédito'], 770),
        ...linhaDeTabela(['Saldo do dia', '1.000,00', '2.000,00'], 755),
        ...linhaDeTabela(['Saldo anterior', '3.000,00', '4.000,00'], 740),
      ];
      final menos = DetectorTabela.detectar(
        palavras,
        sensibilidade: SensibilidadeColunas.menos,
      ).first;
      final mais = DetectorTabela.detectar(
        palavras,
        sensibilidade: SensibilidadeColunas.mais,
      ).first;
      expect(menos.colunas, lessThanOrEqualTo(mais.colunas));
    });
  });

  group('RemovedorRepetido', () {
    test('tira o cabeçalho e o rodapé que se repetem', () {
      final paginas = [for (var i = 1; i <= 4; i++) paginaComTabela(numero: i)];
      final ignorados = <String>[];
      final limpas = RemovedorRepetido.remover(paginas, ignorados);

      expect(limpas, hasLength(4));
      for (final pagina in limpas) {
        final textos = pagina.palavras.map((p) => p.texto).toList();
        expect(textos, isNot(contains('RELATÓRIO MENSAL')));
        expect(textos, isNot(contains('Página ${pagina.numero} de 9')));
        // O conteúdo da tabela fica.
        expect(textos, contains('PIX recebido'));
      }
      expect(ignorados, contains('relatório mensal'));
    });

    test('não mexe em poucas páginas (não dá para saber o que se repete)', () {
      final paginas = [paginaComTabela(numero: 1), paginaComTabela(numero: 2)];
      final limpas = RemovedorRepetido.remover(paginas, <String>[]);
      expect(limpas.first.palavras.length, paginas.first.palavras.length);
    });

    test('deixa as linhas prontas quando nada é removido', () {
      const nomes = ['Alpha', 'Beta', 'Gamma'];
      final paginas = [
        for (var i = 0; i < nomes.length; i++)
          PaginaLida(
            numero: i + 1,
            palavras: [
              palavra('Título ${nomes[i]}', 50, 800),
              ...linhaDeTabela([
                '${nomes[i]} A',
                '${nomes[i]} B',
                '${nomes[i]} C',
              ], 770),
              ...linhaDeTabela([
                '${nomes[i]} D',
                '${nomes[i]} E',
                '${nomes[i]} F',
              ], 755),
            ],
          ),
      ];
      final limpas = RemovedorRepetido.remover(paginas, <String>[]);
      expect(limpas.every((pagina) => pagina.linhasVisuais != null), isTrue);
    });
  });

  group('ServicoPlanilha.montarAbas', () {
    List<PaginaLida> paginas(int quantidade) => [
      for (var i = 1; i <= quantidade; i++) paginaComTabela(numero: i),
    ];

    test('uma aba por tabela', () {
      final abas = ServicoPlanilha.montarAbas(
        paginas(2),
        const OpcoesPlanilha(escopo: EscopoPlanilha.porTabela),
      );
      expect(abas, hasLength(2));
      expect(abas.first.nome, 'p1');
      expect(abas[1].nome, 'p2');
      expect(abas.first.linhas.first.first, 'Data');
    });

    test('uma aba por página', () {
      final abas = ServicoPlanilha.montarAbas(
        paginas(3),
        const OpcoesPlanilha(escopo: EscopoPlanilha.porPagina),
      );
      expect(abas, hasLength(3));
      expect(abas.map((a) => a.nome), ['p1', 'p2', 'p3']);
    });

    test('tudo junto com marcação de página', () {
      final abas = ServicoPlanilha.montarAbas(
        paginas(2),
        const OpcoesPlanilha(escopo: EscopoPlanilha.porArquivo),
      );
      expect(abas, hasLength(1));
      final linhas = abas.first.linhas;
      expect(linhas.first.first, 'página 1');
      expect(
        linhas.any((linha) => linha.isNotEmpty && linha.first == 'página 2'),
        isTrue,
      );
    });

    test('modo texto gera uma coluna só', () {
      final abas = ServicoPlanilha.montarAbas(
        paginas(1),
        const OpcoesPlanilha(modo: ModoPlanilha.texto),
      );
      expect(abas, hasLength(1));
      expect(abas.first.colunas, 1);
    });

    test('página sem texto não gera aba', () {
      final abas = ServicoPlanilha.montarAbas([
        const PaginaLida(
          numero: 1,
          palavras: [],
        ),
      ], const OpcoesPlanilha());
      expect(abas, isEmpty);
    });

    test('respeita o limite de abas por arquivo', () {
      final muitas = <PaginaLida>[
        for (var i = 1; i <= OpcoesPlanilha.maxAbas + 20; i++)
          paginaComTabela(numero: i),
      ];
      final abas = ServicoPlanilha.montarAbas(
        muitas,
        const OpcoesPlanilha(escopo: EscopoPlanilha.porPagina),
      );
      expect(abas.length, OpcoesPlanilha.maxAbas);
    });
  });

  group('EscritorCsv', () {
    const aba = AbaPlanilha(
      nome: 'p1',
      linhas: [
        ['Data', 'Histórico', 'Valor'],
        ['01/03/2026', 'PIX; recebido "hoje"', '1.234,56'],
        ['02/03/2026', '=SOMA(A1:A2)', '-1.234,56'],
        ['03/03/2026', '+55 21 99999-0000', '@inicio'],
      ],
    );

    test('usa ponto e vírgula e protege fórmulas', () {
      final csv = EscritorCsv.gerar(aba);
      final linhas = csv.split('\r\n');
      expect(linhas.first, 'Data;Histórico;Valor');
      expect(linhas[1], '01/03/2026;"PIX; recebido ""hoje""";1.234,56');
      // Fórmula vira texto, mas número negativo continua número.
      expect(linhas[2], '02/03/2026;\'=SOMA(A1:A2);-1.234,56');
      expect(linhas[3], '03/03/2026;\'+55 21 99999-0000;\'@inicio');
    });

    test('respeita a vírgula como separador', () {
      final csv = EscritorCsv.gerar(aba, separador: ',');
      expect(csv.split('\r\n').first, 'Data,Histórico,Valor');
      expect(
        csv.split('\r\n')[1],
        '01/03/2026,"PIX; recebido ""hoje""","1.234,56"',
      );
    });

    test('a proteção pode ser desligada', () {
      final csv = EscritorCsv.gerar(aba, protegerFormulas: false);
      expect(csv.contains("'=SOMA"), isFalse);
      expect(csv.contains('=SOMA(A1:A2)'), isTrue);
    });

  });

  group('EscritorXlsx', () {
    const aba = AbaPlanilha(
      nome: 'Extrato & <saldo>',
      linhas: [
        ['Data', 'Histórico', 'Valor', 'Vencimento'],
        [
          '01/03/2026',
          'PIX recebido de João & Cia <matriz>',
          '1.234,56',
          '31/12/2026',
        ],
        ['02/03/2026', 'Pagamento "boleto"', '-1.234,56', '31/02/2026'],
        ['', 'linha com ; e \t tabulação', '0,00', '01/01/2026'],
      ],
    );

    Uint8List gerar([List<AbaPlanilha> abas = const [aba]]) =>
        EscritorXlsx.gerar(abas);

    Map<String, String> abrir(Uint8List bytes) {
      final arquivo = ZipDecoder().decodeBytes(bytes);
      return {
        for (final f in arquivo.files)
          f.name: utf8.decode(f.content as List<int>),
      };
    }

    test('gera um zip com as partes obrigatórias do XLSX', () {
      final partes = abrir(gerar());
      expect(partes.keys, contains('[Content_Types].xml'));
      expect(partes.keys, contains('_rels/.rels'));
      expect(partes.keys, contains('xl/workbook.xml'));
      expect(partes.keys, contains('xl/_rels/workbook.xml.rels'));
      expect(partes.keys, contains('xl/worksheets/sheet1.xml'));
      expect(partes.keys, contains('xl/styles.xml'));
      expect(partes.keys, contains('xl/sharedStrings.xml'));
    });

    test('as partes começam com a declaração XML e têm as tags fechadas', () {
      final partes = abrir(gerar());
      for (final entrada in partes.entries) {
        expect(
          entrada.value.startsWith('<?xml version="1.0" encoding="UTF-8"'),
          isTrue,
          reason: '${entrada.key} deveria começar com a declaração XML',
        );
      }
      expect(partes['xl/workbook.xml'], contains('</workbook>'));
      expect(partes['xl/worksheets/sheet1.xml'], contains('</worksheet>'));
    });

    test('escapa o texto e corta caracteres que o XML não aceita', () {
      final partes = abrir(
        gerar(const [
          AbaPlanilha(
            nome: 'x',
            linhas: [
              ['Histórico & saldo <R\$> "aspas" \u0007', 'ok'],
            ],
          ),
        ]),
      );
      final textos = partes['xl/sharedStrings.xml']!;
      expect(textos, contains('Histórico &amp; saldo &lt;R\$&gt;'));
      expect(textos, contains('"aspas"'));
      expect(textos.contains('\u0007'), isFalse);
    });

    test('número e data viram valores tipados, texto vira sharedString', () {
      final planilha = abrir(gerar())['xl/worksheets/sheet1.xml']!;
      expect(planilha, contains('<v>1234.56</v>'));
      expect(planilha, contains('<v>-1234.56</v>'));
      // Data do Excel para 31/12/2026.
      expect(planilha, contains('<v>46387</v>'));
      // 31/02 não existe: fica como texto.
      expect(planilha, contains('t="s"'));
      // A primeira linha sai em negrito e congelada.
      expect(planilha, contains('s="1"'));
      expect(planilha, contains('state="frozen"'));
    });

    test('dinheiro sai como número com formato de dinheiro', () {
      final partes = abrir(
        gerar(const [
          AbaPlanilha(
            nome: 'x',
            linhas: [
              ['Histórico', 'Valor'],
              ['PIX recebido', 'R\$ 1.144,01'],
            ],
          ),
        ]),
      );
      // Valor numérico (somável) com o estilo 3, que mostra R$.
      expect(
        partes['xl/worksheets/sheet1.xml'],
        contains('s="3"><v>1144.01</v>'),
      );
      expect(partes['xl/styles.xml'], contains('formatCode="R\$ #,##0.00"'));
    });

    test('dá para desligar o cabeçalho congelado', () {
      final planilha = abrir(
        EscritorXlsx.gerar(const [aba], congelarCabecalho: false),
      )['xl/worksheets/sheet1.xml']!;
      expect(planilha.contains('state="frozen"'), isFalse);
      expect(planilha.contains('s="1"'), isFalse);
    });

    test(
      'cria uma aba por tabela, com nome único e sem caractere proibido',
      () {
        final partes = abrir(
          gerar(const [
            AbaPlanilha(
              nome: 'p1',
              linhas: [
                ['a'],
              ],
            ),
            AbaPlanilha(
              nome: 'p1',
              linhas: [
                ['b'],
              ],
            ),
            AbaPlanilha(
              nome: 'nome/com:dois*[ruim]?',
              linhas: [
                ['c'],
              ],
            ),
          ]),
        );
        expect(partes.keys, contains('xl/worksheets/sheet3.xml'));
        final workbook = partes['xl/workbook.xml']!;
        expect(workbook, contains('name="p1"'));
        expect(workbook, contains('name="p1 (2)"'));
        final nomes = RegExp(
          r'name="([^"]*)"',
        ).allMatches(workbook).map((m) => m.group(1)!).toList();
        expect(nomes, ['p1', 'p1 (2)', 'nome com dois ruim']);
      },
    );

    test('aguenta muitas abas sem travar (e sem nome repetido)', () {
      final abas = [
        for (var i = 1; i <= 300; i++)
          AbaPlanilha(
            nome: 'p$i',
            linhas: [
              ['coluna a', 'coluna b'],
              ['valor $i', '$i'],
            ],
          ),
      ];
      final cronometro = Stopwatch()..start();
      final bytes = EscritorXlsx.gerar(abas);
      cronometro.stop();
      expect(bytes.length, greaterThan(1000));
      expect(
        cronometro.elapsed,
        lessThan(const Duration(seconds: 10)),
        reason: 'montar 300 abas deveria ser rápido',
      );
    });

    test('planilha vazia ainda gera um arquivo válido', () {
      final partes = abrir(EscritorXlsx.gerar(const []));
      expect(partes.keys, contains('xl/worksheets/sheet1.xml'));
    });
  });

  group('OpcoesPlanilha', () {
    test('vai e volta do JSON sem perder nada', () {
      const opcoes = OpcoesPlanilha(
        formato: FormatoPlanilha.csv,
        modo: ModoPlanilha.texto,
        sensibilidade: SensibilidadeColunas.mais,
        escopo: EscopoPlanilha.porArquivo,
        primeiraLinhaCabecalho: false,
        ignorarCabecalhoRodape: false,
        protegerFormulas: false,
        separadorPontoVirgula: false,
      );
      final voltou = OpcoesPlanilha.fromJson(
        jsonDecode(jsonEncode(opcoes.toJson())) as Map<String, dynamic>,
      );
      expect(voltou.formato, opcoes.formato);
      expect(voltou.modo, opcoes.modo);
      expect(voltou.sensibilidade, opcoes.sensibilidade);
      expect(voltou.escopo, opcoes.escopo);
      expect(voltou.primeiraLinhaCabecalho, isFalse);
      expect(voltou.ignorarCabecalhoRodape, isFalse);
      expect(voltou.protegerFormulas, isFalse);
      expect(voltou.separadorCsv, ',');
    });

    test('JSON vazio cai no padrão', () {
      final padrao = OpcoesPlanilha.fromJson(const {});
      expect(padrao.formato, FormatoPlanilha.xlsx);
      expect(padrao.modo, ModoPlanilha.tabelas);
      expect(padrao.sensibilidade, SensibilidadeColunas.equilibrada);
      expect(padrao.escopo, EscopoPlanilha.porTabela);
      expect(padrao.separadorCsv, ';');
    });

    test('descreve as opções para o histórico', () {
      expect(
        ServicoPlanilha.descrever(const OpcoesPlanilha()),
        'Planilha (XLSX) • colunas equilibrado • uma aba por tabela',
      );
      expect(
        ServicoPlanilha.descrever(
          const OpcoesPlanilha(
            formato: FormatoPlanilha.csv,
            modo: ModoPlanilha.texto,
          ),
        ),
        'CSV • texto em uma coluna • uma aba por tabela',
      );
    });
  });
}
