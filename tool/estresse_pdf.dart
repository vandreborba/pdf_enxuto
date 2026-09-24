// Teste de robustez do motor nativo com PDFs reais.
//
//   dart run tool/estresse_pdf.dart [quantidade]
//
// Percorre PDFs encontrados em ~ (sem imprimir nomes nem conteúdo), mede a
// taxa de sucesso do parser e da extração de páginas, e resume os erros por
// tipo. Nada é enviado para fora da máquina.
import 'dart:io';
import 'dart:math';

import 'package:pdf_enxuto/services/pdf/pdf_operations.dart';
import 'package:pdf_enxuto/services/pdf/pdf_reader.dart';

void main(List<String> argumentos) {
  final limite = argumentos.isNotEmpty ? int.tryParse(argumentos.first) ?? 60 : 60;
  final raiz = Platform.environment['HOME'] ?? '/home';

  final arquivos = <File>[];
  for (final entidade in Directory(raiz).listSync(recursive: true, followLinks: false)) {
    if (entidade is File && entidade.path.toLowerCase().endsWith('.pdf')) {
      arquivos.add(entidade);
      if (arquivos.length > 4000) break;
    }
  }

  stdout.writeln('${arquivos.length} PDFs encontrados em $raiz');

  // Amostra espalhada (não só os primeiros) e ordenada por tamanho crescente.
  arquivos.shuffle(Random(20260924));
  final amostra = arquivos.take(limite).toList()
    ..sort((a, b) => a.lengthSync().compareTo(b.lengthSync()));

  var ok = 0;
  var falhasParse = 0;
  var falhasExtracao = 0;
  var criptografados = 0;
  var reconstruidos = 0;
  final erros = <String, int>{};

  for (var i = 0; i < amostra.length; i++) {
    final arquivo = amostra[i];
    final tamanho = arquivo.lengthSync();
    try {
      final bytes = arquivo.readAsBytesSync();
      final leitor = PdfReader.abrir(bytes);

      if (leitor.criptografado) {
        criptografados++;
        continue;
      }
      if (leitor.indiceReconstruido) reconstruidos++;

      final paginas = leitor.paginas();
      final contagem = leitor.contarPaginas();
      if (paginas.isEmpty) {
        falhasParse++;
        _contar(erros, 'sem páginas (count=$contagem)');
        continue;
      }

      // Extrai a primeira e a última página e confere o resultado.
      final escolhidas = <int>[1, if (paginas.length > 1) paginas.length];
      final resultado = PdfOperations.extrairPaginas(leitor, escolhidas);
      final conferencia = PdfReader.abrir(resultado.bytes);
      final lidas = conferencia.paginas().length;
      if (lidas != escolhidas.length) {
        falhasExtracao++;
        _contar(erros, 'extração devolveu $lidas de ${escolhidas.length} páginas');
        continue;
      }

      // Reescrita completa também precisa continuar legível.
      final reescrito = PdfOperations.reescrever(leitor);
      final conferencia2 = PdfReader.abrir(reescrito.bytes);
      if (conferencia2.contarPaginas() != contagem) {
        falhasExtracao++;
        _contar(erros, 'reescrita perdeu páginas '
            '(${conferencia2.contarPaginas()} de $contagem)');
        continue;
      }

      ok++;
      if (i < 12) {
        stdout.writeln(
          '  #$i ${(tamanho / 1024).round()}KB páginas=$contagem '
          'extraido=${resultado.bytes.length}B otimizado=${reescrito.bytes.length}B '
          'fluxos=${resultado.fluxosRecomprimidos}',
        );
      }
    } on PdfCriptografadoException {
      criptografados++;
    } catch (erro) {
      falhasParse++;
      _contar(erros, erro.runtimeType.toString());
    }
  }

  stdout.writeln('');
  stdout.writeln('amostra:            ${amostra.length}');
  stdout.writeln('ok:                 $ok');
  stdout.writeln('criptografados:     $criptografados');
  stdout.writeln('índice remontado:   $reconstruidos');
  stdout.writeln('falhas de leitura:  $falhasParse');
  stdout.writeln('falhas de escrita:  $falhasExtracao');
  if (erros.isNotEmpty) {
    stdout.writeln('motivos:');
    for (final entrada in erros.entries) {
      stdout.writeln('  ${entrada.value}x ${entrada.key}');
    }
  }
}

void _contar(Map<String, int> mapa, String chave) {
  final texto = chave.length > 90 ? chave.substring(0, 90) : chave;
  mapa[texto] = (mapa[texto] ?? 0) + 1;
}
