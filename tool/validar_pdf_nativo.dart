// Validação manual do motor nativo (parser + escritor em Dart puro).
//
//   dart run tool/validar_pdf_nativo.dart
//
// Gera PDFs de teste, exercita extração de páginas e reescrita, e grava os
// resultados em /tmp/pdf_enxuto_teste para conferência com o Ghostscript.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';

const saida = '/tmp/pdf_enxuto_teste';

Future<void> main() async {
  Directory(saida).createSync(recursive: true);

  final simples = await _gerarPdfSimples(6);
  final comMarcadores = await _gerarPdfComMarcadores();

  _analisar('simples.pdf', simples);
  _analisar('gs.pdf', File('$saida/gs.pdf').existsSync()
      ? File('$saida/gs.pdf').readAsBytesSync()
      : simples);

  _extrair('simples.pdf', simples, [2, 3]);
  _extrair('simples.pdf', simples, [1, 4, 5, 6]);
  _reescrever('simples.pdf', simples);

  if (comMarcadores.isNotEmpty) {
    _extrair('marcadores.pdf', comMarcadores, [1, 2]);
    _reescrever('marcadores.pdf', comMarcadores);
  }

  stdout.writeln('\nArquivos em $saida');
}

Future<List<int>> _gerarPdfSimples(int paginas) async {
  final doc = pw.Document();
  for (var i = 1; i <= paginas; i++) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Página $i de $paginas',
                style: const pw.TextStyle(fontSize: 32)),
            pw.SizedBox(height: 20),
            pw.Text('Texto de teste com acentuação: ção, ã, é, ü.'),
            pw.SizedBox(height: 20),
            pw.Container(height: 120, color: PdfColors.blue200),
          ],
        ),
      ),
    );
  }
  final bytes = await doc.save();
  final caminho = '$saida/simples.pdf';
  File(caminho).writeAsBytesSync(bytes);
  stdout.writeln('gerado: $caminho (${bytes.length} bytes, $paginas páginas)');
  return bytes;
}

Future<List<int>> _gerarPdfComMarcadores() async {
  try {
    final doc = pw.Document();
    for (var i = 1; i <= 4; i++) {
      doc.addPage(
        pw.Page(
          build: (context) => pw.Outline(
            name: 'capitulo-$i',
            title: 'Capítulo $i',
            child: pw.Center(child: pw.Text('Capítulo $i')),
          ),
        ),
      );
    }
    final bytes = await doc.save();
    final caminho = '$saida/marcadores.pdf';
    File(caminho).writeAsBytesSync(bytes);
    stdout.writeln('gerado: $caminho (${bytes.length} bytes, 4 páginas)');
    return bytes;
  } catch (erro) {
    stdout.writeln('aviso: não foi possível gerar PDF com marcadores ($erro)');
    return const [];
  }
}

void _analisar(String rotulo, List<int> bytes) {
  try {
    final leitor = PdfReader.abrirBytes(bytes);
    final paginas = leitor.paginas();
    stdout.writeln(
      '[$rotulo] versão=${leitor.versao} páginas=${paginas.length} '
      '(count=${leitor.contarPaginas()}) objetos=${leitor.objetosConhecidos} '
      'cripto=${leitor.criptografado} '
      'reconstruido=${leitor.indiceReconstruido} '
      'marcadores=${leitor.marcadores().length} '
      'info=${leitor.titulo ?? "-"}',
    );
    if (paginas.isNotEmpty) {
      final primeira = paginas.first;
      stdout.writeln(
        '  1ª página: obj=${primeira.numeroObjeto} '
        'herdados=${primeira.herdados.keys.toList()} '
        'conteudo=${primeira.dict.tem('Contents')}',
      );
    }
  } catch (erro) {
    stdout.writeln('[$rotulo] FALHA: $erro');
  }
}

void _extrair(String rotulo, List<int> bytes, List<int> paginas) {
  try {
    final leitor = PdfReader.abrirBytes(bytes);
    final resultado = PdfOperations.extrairPaginas(leitor, paginas);
    final destino = '$saida/${rotulo.replaceAll('.pdf', '')}_extraido.pdf';
    File(destino).writeAsBytesSync(resultado.bytes);

    final conferencia = PdfReader.abrir(resultado.bytes);
    stdout.writeln(
      '[$rotulo] extrair $paginas → ${resultado.bytes.length} bytes, '
      'páginas=${conferencia.contarPaginas()}, '
      'lidas=${conferencia.paginas().length}, '
      'objetos ${resultado.objetosOriginais}→${resultado.objetosMantidos} '
      '→ $destino',
    );
  } catch (erro, pilha) {
    stdout.writeln('[$rotulo] FALHA ao extrair $paginas: $erro\n$pilha');
  }
}

void _reescrever(String rotulo, List<int> bytes) {
  try {
    final leitor = PdfReader.abrirBytes(bytes);
    final resultado = PdfOperations.reescrever(leitor);
    final destino = '$saida/${rotulo.replaceAll('.pdf', '')}_otimizado.pdf';
    File(destino).writeAsBytesSync(resultado.bytes);

    final conferencia = PdfReader.abrir(resultado.bytes);
    stdout.writeln(
      '[$rotulo] reescrever → ${resultado.bytes.length} bytes '
      '(original ${bytes.length}), páginas=${conferencia.contarPaginas()}, '
      'objetos ${resultado.objetosOriginais}→${resultado.objetosMantidos}, '
      'fluxos recomprimidos=${resultado.fluxosRecomprimidos} → $destino',
    );
  } catch (erro, pilha) {
    stdout.writeln('[$rotulo] FALHA ao reescrever: $erro\n$pilha');
  }
}
