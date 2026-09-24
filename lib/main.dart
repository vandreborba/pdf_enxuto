import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_enxuto/app.dart';
import 'package:pdf_enxuto/services/servico_janela.dart';
import 'package:pdf_enxuto/state/app_state.dart';

Future<void> main(List<String> argumentos) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Janela: tamanho, ícone e memória de posição entre sessões.
  await ServicoJanela.preparar();

  // Motor de renderização (pdfium) usado nas miniaturas e no modo
  // "máxima redução". Vem junto com o app — nada é baixado.
  try {
    await pdfrxFlutterInitialize();
  } catch (erro) {
    debugPrint('Aviso: não foi possível inicializar o pdfium ($erro)');
  }

  final estado = AppState();
  await estado.iniciar();

  // Aceita arquivos passados na linha de comando (ou abertos "com" o app).
  final arquivos = argumentos
      .where((argumento) => argumento.toLowerCase().endsWith('.pdf'))
      .where((argumento) => File(argumento).existsSync())
      .toList();

  runApp(PdfEnxutoApp(estado: estado, arquivosIniciais: arquivos));
}
