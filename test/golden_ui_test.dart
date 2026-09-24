@Tags(['golden'])
// Gera as capturas de tela usadas no README e serve de teste de regressão
// visual do layout.
//
//   flutter test --update-goldens test/golden_ui_test.dart   (regrava os PNGs)
//   flutter test test/golden_ui_test.dart                    (confere o layout)
//
// A fila e o histórico são montados em memória: o teste não abre nem grava PDFs
// de verdade, então roda rápido e sempre dá o mesmo resultado.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_enxuto/app.dart';
import 'package:pdf_enxuto/models/app_settings.dart';
import 'package:pdf_enxuto/models/pdf_file_info.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/screens/tela_principal.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';

/// As capturas ficam em assets/screenshot/ (um nível acima da pasta test/).
const String _pastaCapturas = '../assets/screenshot';

/// Carrega uma fonte de verdade: sem isso o Flutter de teste desenha
/// retângulos no lugar das letras.
Future<void> _carregarFontes() async {
  const normais = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
  ];
  const negritos = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
    '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf',
  ];

  final normal = _primeiroExistente(normais);
  final negrito = _primeiroExistente(negritos);
  if (normal == null) return;

  for (final familia in ['Roboto', 'FlutterTest']) {
    final carregador = FontLoader(familia);
    carregador.addFont(_fonte(normal));
    if (negrito != null) carregador.addFont(_fonte(negrito));
    await carregador.load();
  }
}

/// Carrega os ícones do Material (no teste eles não vêm prontos).
Future<void> _carregarIcones() async {
  final raiz = Platform.environment['FLUTTER_ROOT'] ??
      '/home/vandre/flutter';
  final candidatos = [
    '$raiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/vandre/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  final caminho = _primeiroExistente(candidatos);
  if (caminho == null) return;
  final carregador = FontLoader('MaterialIcons')..addFont(_fonte(caminho));
  await carregador.load();
}

String? _primeiroExistente(List<String> caminhos) {
  for (final caminho in caminhos) {
    if (File(caminho).existsSync()) return caminho;
  }
  return null;
}

Future<ByteData> _fonte(String caminho) async {
  final bytes = File(caminho).readAsBytesSync();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

/// Fila fictícia, só para a captura ficar parecida com o uso real.
void _popularFila(AppState estado) {
  const relatorio = PdfFileInfo(
    caminho: '/home/vandre/Documentos/relatorio-anual.pdf',
    bytes: 8 * 1024 * 1024,
    paginas: 42,
    titulo: 'Relatório anual',
    marcadores: [
      PdfBookmark(titulo: 'Introdução', pagina: 1),
      PdfBookmark(titulo: 'Resultados', pagina: 12),
      PdfBookmark(titulo: 'Anexos', pagina: 30),
    ],
  );
  const digitalizados = PdfFileInfo(
    caminho: '/home/vandre/Documentos/documentos-digitalizados.pdf',
    bytes: 24 * 1024 * 1024,
    paginas: 18,
  );
  const contrato = PdfFileInfo(
    caminho: '/home/vandre/Downloads/contrato-assinado.pdf',
    bytes: 2 * 1024 * 1024,
    paginas: 6,
  );

  final itens = [
    ItemFila(relatorio),
    ItemFila(digitalizados),
    ItemFila(contrato),
  ];
  estado.fila
    ..clear()
    ..addAll(itens);

  itens[0].status = JobStatus.concluido;
  itens[0].resultado = ItemResult(
    entrada: relatorio.caminho,
    saidas: ['/home/vandre/Documentos/relatorio-anual_enxuto.pdf'],
    bytesAntes: 8 * 1024 * 1024,
    bytesDepois: 2 * 1024 * 1024 + 300 * 1024,
    duracao: Duration(seconds: 4, milliseconds: 300),
    motor: 'Ghostscript',
  );
  itens[1].status = JobStatus.concluido;
  itens[1].resultado = ItemResult(
    entrada: digitalizados.caminho,
    saidas: ['/home/vandre/Documentos/documentos-digitalizados_enxuto.pdf'],
    bytesAntes: 24 * 1024 * 1024,
    bytesDepois: 5 * 1024 * 1024 + 700 * 1024,
    duracao: Duration(seconds: 11),
    motor: 'Nativo (embutido)',
  );
}

void _popularHistorico(AppState estado) {
  final agora = DateTime.now();
  estado.historico.registrarVarias([
    HistoryEntry(
      id: '1',
      quando: agora.subtract(const Duration(minutes: 7)),
      kind: TaskKind.comprimir,
      resumo: 'Equilibrado • texto preservado • 150dpi • motor: Ghostscript',
      resultado: const ItemResult(
        entrada: '/home/vandre/Documentos/relatorio-anual.pdf',
        saidas: ['/home/vandre/Documentos/relatorio-anual_enxuto.pdf'],
        bytesAntes: 8 * 1024 * 1024,
        bytesDepois: 2 * 1024 * 1024 + 300 * 1024,
        duracao: Duration(seconds: 4, milliseconds: 300),
        motor: 'Ghostscript',
      ),
    ),
    HistoryEntry(
      id: '2',
      quando: agora.subtract(const Duration(hours: 3)),
      kind: TaskKind.dividir,
      resumo: 'Por intervalos • 3 partes',
      resultado: const ItemResult(
        entrada: '/home/vandre/Downloads/contrato-assinado.pdf',
        saidas: ['/tmp/parte-1.pdf', '/tmp/parte-2.pdf', '/tmp/parte-3.pdf'],
        bytesAntes: 2 * 1024 * 1024,
        bytesDepois: 2 * 1024 * 1024,
        duracao: Duration(seconds: 2),
        motor: 'Nativo (embutido)',
      ),
    ),
    HistoryEntry(
      id: '3',
      quando: agora.subtract(const Duration(days: 2)),
      kind: TaskKind.comprimir,
      resumo: 'Forte • vira imagem • 120dpi • motor: Nativo (embutido)',
      resultado: const ItemResult(
        entrada: '/home/vandre/Documentos/documentos-digitalizados.pdf',
        saidas: ['/home/vandre/Documentos/documentos-digitalizados_enxuto.pdf'],
        bytesAntes: 24 * 1024 * 1024,
        bytesDepois: 5 * 1024 * 1024 + 700 * 1024,
        duracao: Duration(seconds: 11),
        motor: 'Nativo (embutido)',
        aviso: 'As páginas viraram imagens: o texto não é mais selecionável.',
      ),
    ),
  ]);
}

void main() {
  setUpAll(() async {
    await _carregarFontes();
    await _carregarIcones();
  });

  Future<AppState> prepararEstado(
    WidgetTester tester, {
    bool comFila = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final estado = AppState();

    // Só a detecção de motores precisa do mundo real (roda `which gs`).
    await tester.runAsync(() async {
      await estado.configuracao.carregar();
      await estado.motores.detectar();
    });

    await estado.atualizarConfig(
      const AppSettings(
        tema: ThemeMode.light,
        reduzirAnimacoes: true,
        onboardingVisto: true,
      ),
    );
    estado.carregando = false;

    if (comFila) _popularFila(estado);
    _popularHistorico(estado);
    return estado;
  }

  Future<void> capturar(
    WidgetTester tester,
    AppState estado,
    String nome, {
    SecaoApp secao = SecaoApp.comprimir,
    Size tamanho = const Size(1460, 950),
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PdfEnxutoApp(estado: estado));
    // Alguns quadros para as animações de entrada e a barra de rolagem
    // assentarem antes da captura.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    if (secao != SecaoApp.comprimir) {
      final item = find.text(secao.rotulo);
      if (item.evaluate().isNotEmpty) {
        await tester.tap(item.first);
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_pastaCapturas/$nome.png'),
    );
  }

  testWidgets('capturas das telas principais', (tester) async {
    final estado = await prepararEstado(tester);
    await capturar(tester, estado, 'tela-comprimir');
    await capturar(tester, estado, 'tela-dividir', secao: SecaoApp.dividir);
    await capturar(tester, estado, 'tela-historico', secao: SecaoApp.historico);
    await capturar(
      tester,
      estado,
      'tela-configuracoes',
      secao: SecaoApp.configuracoes,
    );
  });

  testWidgets('capturas das paletas de cor', (tester) async {
    final estado = await prepararEstado(tester, comFila: false);

    for (var i = 0; i < AccentPalette.todas.length; i++) {
      await estado.atualizarConfig(estado.config.copyWith(corDestaque: i));
      await capturar(
        tester,
        estado,
        'paleta-$i',
        tamanho: const Size(1200, 820),
      );
    }
  });
}
