import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_enxuto/services/pdf/pdf_objects.dart';
import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';
import 'package:pdf_enxuto/services/pdf/pdf_writer.dart';

/// Gera um PDF de teste com [paginas] páginas de texto.
Future<Uint8List> _gerarPdf(int paginas, {bool marcadores = false}) async {
  final documento = pw.Document();
  for (var i = 1; i <= paginas; i++) {
    documento.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: marcadores
              ? pw.Outline(
                  name: 'capitulo-$i',
                  title: 'Capítulo $i',
                  child: pw.Text('Página $i'),
                )
              : pw.Text('Página $i'),
        ),
      ),
    );
  }
  return Uint8List.fromList(await documento.save());
}

void main() {
  group('Leitor de PDF', () {
    test('conta as páginas corretamente', () async {
      final bytes = await _gerarPdf(5);
      final leitor = PdfReader.abrir(bytes);

      expect(leitor.criptografado, isFalse);
      expect(leitor.paginas().length, 5);
      expect(leitor.contarPaginas(), 5);
    });

    test('lê o catálogo e o /Info', () async {
      final bytes = await _gerarPdf(2);
      final leitor = PdfReader.abrir(bytes);

      expect(leitor.catalogo, isNotNull);
      expect(leitor.catalogo!.nome('Type'), 'Catalog');
      expect(leitor.paginas().first.dict.nome('Type'), 'Page');
    });

    test('lê os marcadores (sumário)', () async {
      final bytes = await _gerarPdf(3, marcadores: true);
      final leitor = PdfReader.abrir(bytes);
      final marcadores = leitor.marcadores();

      expect(marcadores.length, 3);
      expect(marcadores.first.titulo, 'Capítulo 1');
      expect(marcadores.first.pagina, 1);
    });

    test('recusa arquivo que não é PDF', () {
      final leitor = PdfReader.abrir(Uint8List.fromList('nada aqui'.codeUnits));
      expect(leitor.paginas(), isEmpty);
    });

    test('reconstrói o índice quando a tabela xref está quebrada', () async {
      final bytes = await _gerarPdf(2);
      // Estraga o startxref (é o que acontece em arquivos mal gerados).
      final texto = String.fromCharCodes(bytes);
      final posicao = texto.lastIndexOf('startxref');
      final estragado = Uint8List.fromList(bytes);
      for (var i = posicao + 10; i < posicao + 16; i++) {
        if (i < estragado.length) estragado[i] = 0x39; // '9'
      }

      final leitor = PdfReader.abrir(estragado);
      expect(leitor.paginas(), isNotEmpty);
      expect(leitor.indiceReconstruido, isTrue);
    });
  });

  group('Escritor de PDF', () {
    test('preserva os valores ao gravar e reler', () {
      final escritor = PdfWriter(versao: '1.7');
      final refPaginas = escritor.reservar();
      final pagina = escritor.adicionar(
        PdfDict({
          'Type': const PdfName('Page'),
          'MediaBox': const PdfArray([
            PdfNumber(0),
            PdfNumber(0),
            PdfNumber(595),
            PdfNumber(842),
          ]),
          'Rotate': const PdfNumber(90),
          'Titulo': PdfString.fromTexto('Acentuação: ção'),
        }),
      );
      escritor.definirRef(
        refPaginas,
        PdfDict({
          'Type': PdfName.pages,
          'Kids': PdfArray([pagina]),
          'Count': const PdfNumber(1),
        }),
      );
      escritor.raiz = escritor.adicionar(
        PdfDict({'Type': PdfName.catalog, 'Pages': refPaginas}),
      );

      final bytes = escritor.escrever(usarFluxosDeObjeto: false);
      final leitor = PdfReader.abrir(bytes);
      final paginas = leitor.paginas();

      expect(paginas.length, 1);
      expect(paginas.first.dict.real('Rotate'), 90);
      expect(paginas.first.dict.lista('MediaBox')!.items.length, 4);
      expect(paginas.first.dict.texto('Titulo')!.texto, 'Acentuação: ção');
    });

    test('grava com fluxos de objeto e continua legível', () {
      final escritor = PdfWriter(versao: '1.7');
      final refPaginas = escritor.reservar();
      final refs = <PdfRef>[];
      for (var i = 0; i < 3; i++) {
        refs.add(
          escritor.adicionar(
            PdfDict({'Type': PdfName('Page'), 'Indice': PdfNumber(i)}),
          ),
        );
      }
      escritor.definirRef(
        refPaginas,
        PdfDict({
          'Type': PdfName.pages,
          'Kids': PdfArray(refs),
          'Count': const PdfNumber(3),
        }),
      );
      escritor.raiz = escritor.adicionar(
        PdfDict({'Type': PdfName.catalog, 'Pages': refPaginas}),
      );

      final bytes = escritor.escrever();
      final leitor = PdfReader.abrir(bytes);

      expect(leitor.paginas().length, 3);
      expect(leitor.paginas()[2].dict.inteiro('Indice'), 2);
    });
  });

  group('Operações nativas', () {
    test('extrai apenas as páginas pedidas, na ordem pedida', () async {
      final bytes = await _gerarPdf(6);
      final leitor = PdfReader.abrir(bytes);

      final resultado = PdfOperations.extrairPaginas(leitor, [3, 1, 5]);
      final conferencia = PdfReader.abrir(resultado.bytes);

      expect(conferencia.paginas().length, 3);
      expect(conferencia.contarPaginas(), 3);
      expect(conferencia.paginas().first.dict.nome('Type'), 'Page');
    });

    test('ignora páginas que não existem', () async {
      final bytes = await _gerarPdf(2);
      final leitor = PdfReader.abrir(bytes);

      final resultado = PdfOperations.extrairPaginas(leitor, [1, 99]);
      expect(PdfReader.abrir(resultado.bytes).paginas().length, 1);
    });

    test('reescrever mantém todas as páginas', () async {
      final bytes = await _gerarPdf(7);
      final leitor = PdfReader.abrir(bytes);

      final resultado = PdfOperations.reescrever(leitor);
      final conferencia = PdfReader.abrir(resultado.bytes);

      expect(conferencia.paginas().length, 7);
      expect(resultado.objetosMantidos, lessThanOrEqualTo(resultado.objetosOriginais));
    });

    test('mantém os marcadores ao reescrever', () async {
      final bytes = await _gerarPdf(3, marcadores: true);
      final leitor = PdfReader.abrir(bytes);

      final mantendo = PdfReader.abrir(
        PdfOperations.reescrever(leitor, manterMarcadores: true).bytes,
      );
      final removendo = PdfReader.abrir(
        PdfOperations.reescrever(leitor, manterMarcadores: false).bytes,
      );

      expect(mantendo.marcadores().length, 3);
      expect(removendo.marcadores(), isEmpty);
    });

    test('remove metadados quando pedido', () async {
      final bytes = await _gerarPdf(2);
      final leitor = PdfReader.abrir(bytes);

      final comInfo = PdfReader.abrir(
        PdfOperations.reescrever(leitor, manterMetadados: true).bytes,
      );
      final semInfo = PdfReader.abrir(
        PdfOperations.reescrever(leitor, manterMetadados: false).bytes,
      );

      expect(comInfo.info, isNotNull);
      expect(semInfo.info, isNull);
    });

    test('o resultado é legível com xref clássico e com fluxos de objeto',
        () async {
      final bytes = await _gerarPdf(4);
      final leitor = PdfReader.abrir(bytes);

      for (final usarFluxos in [true, false]) {
        final resultado = PdfOperations.reescrever(
          leitor,
          usarFluxosDeObjeto: usarFluxos,
        );
        expect(
          PdfReader.abrir(resultado.bytes).paginas().length,
          4,
          reason: 'usarFluxosDeObjeto=$usarFluxos',
        );
      }
    });
  });
}
