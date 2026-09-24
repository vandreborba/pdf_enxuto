// Coleta PDFs que o motor nativo não conseguiu processar, copiando-os de forma
// anônima para /tmp/pdf_enxuto_falhas (sem nomes originais) e imprimindo uma
// ficha técnica de cada um para depuração.
//
//   dart run tool/coletar_falhas.dart [quantidade]
import 'dart:io';
import 'dart:math';

import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';

const destinoFalhas = '/tmp/pdf_enxuto_falhas';

void main(List<String> argumentos) {
  final limite = argumentos.isNotEmpty ? int.tryParse(argumentos.first) ?? 400 : 400;
  final raiz = Platform.environment['HOME'] ?? '/home';

  Directory(destinoFalhas).createSync(recursive: true);
  for (final entidade in Directory(destinoFalhas).listSync()) {
    entidade.deleteSync(recursive: true);
  }

  final arquivos = <File>[];
  for (final entidade in Directory(raiz)
      .listSync(recursive: true, followLinks: false)) {
    if (entidade is File && entidade.path.toLowerCase().endsWith('.pdf')) {
      arquivos.add(entidade);
    }
  }

  arquivos.shuffle(Random(7));
  final amostra = arquivos.take(limite).toList();

  var indiceFalha = 0;
  for (final arquivo in amostra) {
    try {
      final bytes = arquivo.readAsBytesSync();
      final leitor = PdfReader.abrir(bytes);
      if (leitor.criptografado) continue;

      final paginas = leitor.paginas();
      final contagem = leitor.contarPaginas();
      if (paginas.isEmpty || contagem != paginas.length) {
        _registrar(++indiceFalha, arquivo, bytes, leitor,
            'leitura: páginas=${paginas.length} count=$contagem');
        continue;
      }

      final primeiro = PdfOperations.extrairPaginas(leitor, [1]);
      if (PdfReader.abrir(primeiro.bytes).paginas().isEmpty) {
        _registrar(++indiceFalha, arquivo, bytes, leitor,
            'extração: resultado sem páginas');
        continue;
      }

      final reescrito = PdfOperations.reescrever(leitor);
      final conferencia = PdfReader.abrir(reescrito.bytes);
      if (conferencia.paginas().length != paginas.length) {
        _registrar(
          ++indiceFalha,
          arquivo,
          bytes,
          leitor,
          'reescrita: ${conferencia.paginas().length} de ${paginas.length} '
              'páginas (lido=${conferencia.erroLeitura})',
        );
      }
    } catch (erro) {
      try {
        final bytes = arquivo.readAsBytesSync();
        _registrar(indiceFalha + 1, arquivo, bytes, PdfReader.abrir(bytes),
            'exceção: $erro');
        indiceFalha++;
      } catch (_) {
        // Ignora arquivos ilegíveis até para copiar.
      }
    }
  }

  stdout.writeln('amostra=$limite falhas=$indiceFalha em $destinoFalhas');
}

void _registrar(int indice, File arquivo, List<int> bytes, PdfReader leitor,
    String motivo) {
  final copia = File('$destinoFalhas/$indice.pdf');
  copia.writeAsBytesSync(bytes);
  final texto = String.fromCharCodes(bytes.take(4096));
  stdout.writeln(
    '#$indice ${(bytes.length / 1024).round()}KB motivo="$motivo" '
    'versão=${leitor.versao} objetos=${leitor.objetosConhecidos} '
    'reconstruido=${leitor.indiceReconstruido} '
    'objstm=${texto.contains('ObjStm')} xrefstm=${texto.contains('/XRef')} '
    'assinatura=${texto.substring(0, min(8, texto.length)).replaceAll(RegExp(r"\s"), ".")}',
  );
}
