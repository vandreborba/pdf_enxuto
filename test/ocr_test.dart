import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/models/ocr_options.dart';
import 'package:pdf_enxuto/services/ocr/motor_tesseract.dart';
import 'package:pdf_enxuto/services/pdf/paginas_imagem.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';
import 'package:pdf_enxuto/services/servico_ocr.dart';

const String _tsv =
    'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
    '1\t1\t0\t0\t0\t0\t0\t0\t1000\t800\t-1\t\n'
    '2\t1\t1\t0\t0\t0\t80\t80\t600\t100\t-1\t\n'
    '4\t1\t1\t1\t1\t0\t80\t80\t600\t40\t-1\t\n'
    '5\t1\t1\t1\t1\t1\t80\t80\t200\t40\t96.5\tContrato\n'
    '5\t1\t1\t1\t1\t2\t300\t80\t80\t40\t90.0\tde\n'
    '4\t1\t1\t1\t2\t0\t80\t140\t300\t40\t-1\t\n'
    '5\t1\t1\t1\t2\t1\t80\t140\t300\t40\t88.0\tserviços\n'
    '4\t1\t2\t1\t1\t0\t80\t300\t100\t40\t-1\t\n'
    '5\t1\t2\t1\t1\t1\t80\t300\t100\t40\t70.0\tFim\n'
    '5\t1\t2\t1\t1\t2\t200\t300\t50\t40\t-1\t   \n';

void main() {
  group('MotorTesseract.interpretarTsv', () {
    final pagina = MotorTesseract.interpretarTsv(_tsv);

    test('monta linhas e parágrafos', () {
      expect(pagina.texto, 'Contrato de\nserviços\n\nFim');
    });

    test('guarda posição e altura da linha de cada palavra', () {
      expect(pagina.palavras, hasLength(4));
      final contrato = pagina.palavras.first;
      expect(contrato.texto, 'Contrato');
      expect(contrato.x, 80);
      expect(contrato.largura, 200);
      expect(contrato.alturaLinha, 40);
      expect(contrato.baseY, closeTo(80 + 40 * 0.82, 0.001));
    });

    test('média ignora palavras sem confiança', () {
      expect(pagina.confianca, closeTo((96.5 + 90 + 88 + 70) / 4, 0.001));
    });

    test('saída vazia não quebra', () {
      final vazia = MotorTesseract.interpretarTsv('');
      expect(vazia.vazia, isTrue);
      expect(vazia.texto, isEmpty);
      expect(vazia.confianca, isNull);
    });
  });

  group('TextoWinAnsi', () {
    test('a tabela de larguras cobre o ASCII imprimível', () {
      // "i" e "W" em Helvetica: 222 e 944.
      expect(TextoWinAnsi.larguraHelvetica('i'), closeTo(0.222, 1e-9));
      expect(TextoWinAnsi.larguraHelvetica('W'), closeTo(0.944, 1e-9));
      expect(TextoWinAnsi.larguraHelvetica('~'), closeTo(0.584, 1e-9));
      expect(TextoWinAnsi.larguraHelvetica(' '), closeTo(0.278, 1e-9));
    });

    test('acentos têm a largura da letra base', () {
      expect(
        TextoWinAnsi.larguraHelvetica('ção'),
        TextoWinAnsi.larguraHelvetica('cao'),
      );
    });

    test('codifica Latin-1, aspas e ligaduras', () {
      expect(TextoWinAnsi.codificar('ação'), [0x61, 0xE7, 0xE3, 0x6F]);
      expect(TextoWinAnsi.codificar('“x”'), [0x93, 0x78, 0x94]);
      expect(TextoWinAnsi.codificar('ﬁm'), 'fim'.codeUnits);
      expect(TextoWinAnsi.codificar('日'), [0x3F]);
    });
  });

  group('PDF pesquisável', () {
    Uint8List montar() {
      final imagem = ImagemPagina(
        dados: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
        largura: 1000,
        altura: 800,
        filtro: 'DCTDecode',
        espacoCor: 'DeviceGray',
        bits: 8,
      );
      return montarPdfDePaginas(
        [imagem],
        [const TamanhoPagina(largura: 500, altura: 400)],
        texto: [
          [
            const PalavraPagina(
              texto: 'Olá (mundo)',
              x: 100,
              largura: 300,
              baseY: 200,
              alturaLinha: 40,
            ),
          ],
        ],
      );
    }

    test('abre no leitor do app com uma página', () {
      expect(PdfReader.abrir(montar()).paginas(), hasLength(1));
    });

    test('sem texto, o PDF é o mesmo de antes (sem fonte)', () {
      final imagem = ImagemPagina(
        dados: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
        largura: 10,
        altura: 10,
        filtro: 'DCTDecode',
        espacoCor: 'DeviceGray',
        bits: 8,
      );
      final bytes = montarPdfDePaginas(
        [imagem],
        [const TamanhoPagina(largura: 100, altura: 100)],
      );
      expect(String.fromCharCodes(bytes), isNot(contains('Helvetica')));
    });
  });

  group('OpcoesOcr', () {
    test('ida e volta pelo JSON', () {
      const original = OpcoesOcr(
        idiomas: ['spa'],
        qualidade: QualidadeOcr.preciso,
        tipoPagina: TipoPaginaOcr.esparso,
        gerarPdf: false,
        gerarTxt: true,
        paginas: '1-3',
      );
      final lido = OpcoesOcr.fromJson(original.toJson());
      expect(lido.idiomas, ['spa']);
      expect(lido.qualidade, QualidadeOcr.preciso);
      expect(lido.tipoPagina, TipoPaginaOcr.esparso);
      expect(lido.gerarPdf, isFalse);
      expect(lido.gerarTxt, isTrue);
      expect(lido.paginas, '1-3');
      expect(lido.idiomasTesseract, 'spa');
    });

    test('JSON antigo ou estragado cai nos padrões', () {
      final lido = OpcoesOcr.fromJson({
        'idiomas': ['xx', 3],
        'gerarPdf': false,
        'gerarTxt': false,
      });
      expect(lido.idiomas, ['por', 'eng']);
      expect(lido.temSaida, isTrue);
    });
  });

  group('ServicoOcr.montarAviso', () {
    test('sem problemas, sem aviso', () {
      expect(
        ServicoOcr.montarAviso(
          paginasLidas: 3,
          paginasSemTexto: 0,
          confianca: 92,
          jaTinhamTexto: 0,
          gerouPdf: true,
        ),
        isNull,
      );
    });

    test('avisa confiança baixa e páginas vazias', () {
      final aviso = ServicoOcr.montarAviso(
        paginasLidas: 3,
        paginasSemTexto: 1,
        confianca: 55,
        jaTinhamTexto: 0,
        gerouPdf: true,
      );
      expect(aviso, contains('1 página não teve texto'));
      expect(aviso, contains('confiança'));
    });
  });

  // Roda só onde há Tesseract (o app embutido ou o do sistema).
  group('Tesseract de verdade', () {
    final amostra = Platform.environment['OCR_AMOSTRA'];

    test(
      'lê a amostra e gera PDF com texto extraível',
      () async {
        final motor = MotorTesseract();
        final estado = await motor.detectar();
        expect(estado.disponivel, isTrue, reason: estado.erro);

        final cancelamento = Cancelamento();
        final pagina = await motor.reconhecer(
          imagem: amostra!,
          idiomas: 'por',
          psm: 3,
          dpi: 150,
          cancelamento: cancelamento,
        );
        cancelamento.dispose();
        expect(pagina.texto, contains('Contrato de prestação de serviços'));
        expect(pagina.texto, contains('R\$ 1.250,00'));
        expect(pagina.texto, contains('ação e coração'));
        expect(pagina.confianca, greaterThan(80));

        final saida = Platform.environment['OCR_SAIDA'];
        if (saida != null) {
          // Fundo branco 1240x500 em JPEG de verdade para conferir no leitor.
          final jpeg = File('$amostra.jpg').readAsBytesSync();
          final bytes = montarPdfDePaginas(
            [
              ImagemPagina(
                dados: jpeg,
                largura: 1240,
                altura: 500,
                filtro: 'DCTDecode',
                espacoCor: 'DeviceGray',
                bits: 8,
              ),
            ],
            [const TamanhoPagina(largura: 595, altura: 240)],
            texto: [pagina.palavras],
          );
          File(saida).writeAsBytesSync(bytes);
        }
      },
      skip: amostra == null ? 'defina OCR_AMOSTRA com uma imagem PGM' : false,
    );
  });
}
