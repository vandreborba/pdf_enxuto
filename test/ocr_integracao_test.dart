import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/models/ocr_options.dart';
import 'package:pdf_enxuto/services/servico_ocr.dart';
import 'package:pdf_enxuto/services/tabela/extrator_texto.dart';

/// Fluxo completo (pdfium + Tesseract) sobre um PDF digitalizado de verdade.
///
///   OCR_PDF=/caminho/scan.pdf flutter test test/ocr_integracao_test.dart
///
/// Só roda quando OCR_PDF aponta para um PDF sem texto.
void main() {
  final entrada = Platform.environment['OCR_PDF'];

  test(
    'reconhece um PDF digitalizado e devolve PDF pesquisável + txt',
    () async {
      ExtratorTexto.inicializadorAlternativo = pdfrxInitialize;
      final servico = ServicoOcr();
      await servico.motor.detectar();
      expect(servico.motor.disponivel, isTrue);

      final pasta = Directory.systemTemp.createTempSync('ocr_int_');
      addTearDown(() => pasta.deleteSync(recursive: true));
      final cancelamento = Cancelamento();
      final etapas = <String>[];

      final previa = await servico.previa(
        caminho: entrada!,
        opcoes: const OpcoesOcr(idiomas: ['por']),
        cancelamento: cancelamento,
      );
      expect(previa.leuAlgo, isTrue);
      expect(previa.jaTinhaTexto, isFalse);
      expect(previa.texto, contains('Contrato'));

      final resultado = await servico.reconhecer(
        entrada: entrada,
        opcoes: const OpcoesOcr(idiomas: ['por'], gerarTxt: true),
        cancelamento: cancelamento,
        progresso: (fracao, etapa) => etapas.add(etapa),
        sobrescrever: true,
        pastaSaida: pasta.path,
      );
      cancelamento.dispose();

      expect(resultado.erro, isNull);
      expect(resultado.saidas, hasLength(2));
      expect(resultado.saidas.first, endsWith('_ocr.pdf'));
      final texto = File(resultado.saidas.last).readAsStringSync();
      expect(texto, contains('Contrato de prestação de serviços'));
      expect(etapas, isNotEmpty);

      final destino = Platform.environment['OCR_COPIA'];
      if (destino != null) {
        File(resultado.saidas.first).copySync(destino);
      }

      // Já tem texto agora: sem "refazer", o app recusa com um aviso claro.
      final denovo = await servico.reconhecer(
        entrada: resultado.saidas.first,
        opcoes: const OpcoesOcr(idiomas: ['por']),
        cancelamento: Cancelamento(),
        progresso: (_, _) {},
        sobrescrever: true,
        pastaSaida: pasta.path,
      );
      expect(denovo.erro, contains('já tem texto'));
    },
    skip: entrada == null ? 'defina OCR_PDF com um PDF digitalizado' : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
