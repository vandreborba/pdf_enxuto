import 'dart:io';
import 'dart:math' as math;

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/models/pdf_file_info.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/services/motores.dart';
import 'package:pdf_enxuto/services/servico_arquivos.dart';

/// Plano de divisão pronto para ser mostrado e executado.
class PlanoDivisao {
  const PlanoDivisao({
    required this.partes,
    this.erros = const [],
    this.avisos = const [],
  });

  final List<SplitPart> partes;
  final List<String> erros;
  final List<String> avisos;

  bool get valido => erros.isEmpty && partes.isNotEmpty;

  int get totalBytes =>
      partes.fold(0, (soma, parte) => soma + parte.bytesEstimados);
}

/// Divide um PDF em partes.
///
/// A conta dos cortes é sempre feita em páginas inteiras (é o que o formato
/// permite), e o método "por tamanho" confere o resultado de verdade: se
/// alguma parte passar do limite, ela é dividida de novo automaticamente.
class ServicoDivisao {
  ServicoDivisao(this.motores);

  final Motores motores;

  /// Monta o plano a partir das opções escolhidas.
  static PlanoDivisao montarPlano({
    required PdfFileInfo arquivo,
    required SplitOptions opcoes,
    String? pastaSaida,
  }) {
    final total = arquivo.paginas;
    if (total <= 0) {
      return const PlanoDivisao(
        partes: [],
        erros: ['Este PDF não tem páginas para dividir.'],
      );
    }

    final erros = <String>[];
    final avisos = <String>[];
    var grupos = <List<PageRange>>[];

    switch (opcoes.metodo) {
      case SplitMethod.intervalos:
        final leitura = PageRangeParser.parse(
          opcoes.intervalosTexto,
          totalPaginas: total,
        );
        erros.addAll(leitura.erros);
        if (leitura.aviso != null) avisos.add(leitura.aviso!);
        if (leitura.intervalos.isEmpty && erros.isEmpty) {
          erros.add('Escreva pelo menos um intervalo (ex.: 1-3, 7, 10-12)');
        }
        grupos = [
          for (final intervalo in leitura.intervalos)
            if (opcoes.umaPaginaPorArquivo)
              for (var p = intervalo.inicio; p <= intervalo.fim; p++)
                [PageRange(p, p)]
            else
              [intervalo],
        ];
        if (opcoes.umArquivoSo && grupos.isNotEmpty) {
          grupos = [
            PageRangeParser.normalizar(grupos.expand((g) => g).toList()),
          ];
        }

        final cobertas = <int>{
          for (final grupo in grupos)
            for (final intervalo in grupo) ...intervalo.paginas,
        };
        if (cobertas.length < total) {
          avisos.add(S.paginasNaoUsadas);
        }

      case SplitMethod.cadaN:
        final porParte = opcoes.umaPaginaPorArquivo
            ? 1
            : opcoes.paginasPorParte;
        if (porParte < 1) {
          erros.add('Informe quantas páginas cada parte deve ter');
        } else {
          grupos = [
            for (final intervalo in PageRangeParser.cadaNPaginas(
              total,
              porParte,
            ))
              [intervalo],
          ];
        }

      case SplitMethod.extrair:
        final leitura = PageRangeParser.parse(
          opcoes.extrairTexto,
          totalPaginas: total,
        );
        erros.addAll(leitura.erros);
        if (leitura.aviso != null) avisos.add(leitura.aviso!);
        if (leitura.intervalos.isEmpty && erros.isEmpty) {
          erros.add('Diga quais páginas devem ser extraídas (ex.: 1, 4, 9-12)');
        } else {
          grupos = [PageRangeParser.normalizar(leitura.intervalos)];
        }

      case SplitMethod.porTamanho:
        if (opcoes.maxBytes < 50 * 1024) {
          erros.add('O limite precisa ser de pelo menos 50 KB');
        } else {
          grupos = _porTamanho(arquivo, opcoes.maxBytes);
        }

      case SplitMethod.marcadores:
        final marcadores = arquivo.marcadores
            .where((marcador) => marcador.pagina > 0)
            .toList();
        if (marcadores.isEmpty) {
          erros.add(S.marcadoresVazio);
        } else {
          // Só os marcadores de primeiro nível viram cortes.
          final capitulos =
              marcadores.where((marcador) => marcador.nivel == 0).toList()
                ..sort((a, b) => a.pagina.compareTo(b.pagina));
          final usados = capitulos.isEmpty ? marcadores : capitulos;

          for (var i = 0; i < usados.length; i++) {
            final inicio = math.max(1, usados[i].pagina);
            final fim = i + 1 < usados.length
                ? math.max(inicio, usados[i + 1].pagina - 1)
                : total;
            if (inicio > total) continue;
            grupos.add([PageRange(inicio, fim)]);
          }
          if (grupos.isEmpty) erros.add(S.marcadoresVazio);
        }
    }

    final partes = <SplitPart>[];
    final contexto = _ContextoNomes(
      nomeBase: arquivo.nomeSemExtensao,
      pasta: pastaSaida ?? arquivo.pasta,
      padrao: _padraoEfetivo(opcoes),
      bytesPorPagina: arquivo.bytesPorPagina,
    );

    for (var i = 0; i < grupos.length; i++) {
      final grupo = grupos[i];
      if (grupo.isEmpty) continue;
      final paginas = PageRangeParser.normalizar(grupo);
      final quantidade = paginas.fold(
        0,
        (soma, intervalo) => soma + intervalo.quantidade,
      );
      if (quantidade == 0) continue;
      partes.add(contexto.montar(i + 1, paginas));
    }

    return PlanoDivisao(partes: partes, erros: erros, avisos: avisos);
  }

  /// Ajusta o padrão escolhido: garante o número da parte quando pedido e
  /// remove o número quando tudo vai para um arquivo só.
  static String _padraoEfetivo(SplitOptions opcoes) {
    var padrao = opcoes.padraoNome;
    if (opcoes.incluirNumeroParte && !padrao.contains('{parte}')) {
      padrao = '$padrao - parte {parte}';
    }
    if (opcoes.metodo == SplitMethod.extrair && opcoes.umArquivoSo) {
      padrao = padrao.replaceAll(' - parte {parte}', '');
    }
    if (opcoes.metodo == SplitMethod.extrair) {
      padrao = padrao.replaceAll(' - parte {parte}', '');
    }
    return padrao;
  }

  /// Agrupa páginas em partes que caibam no limite, pela média de bytes/página.
  static List<List<PageRange>> _porTamanho(PdfFileInfo arquivo, int limite) {
    final media = arquivo.bytesPorPagina;
    if (media <= 0 || arquivo.paginas <= 0) return const [];

    // Uma página por parte quando nem uma sozinha cabe no limite.
    final porParte = math.max(1, (limite / media).floor());
    final grupos = <List<PageRange>>[];
    for (var inicio = 1; inicio <= arquivo.paginas; inicio += porParte) {
      grupos.add([
        PageRange(inicio, math.min(inicio + porParte - 1, arquivo.paginas)),
      ]);
    }
    return grupos;
  }

  /// Executa a divisão e devolve o resultado.
  Future<ItemResult> dividir({
    required PdfFileInfo arquivo,
    required SplitOptions opcoes,
    required PlanoDivisao plano,
    required Cancelamento cancelamento,
    required ProgressoCallback progresso,
    required bool sobrescrever,
  }) async {
    final inicio = DateTime.now();
    final temporaria = await Future.value(
      Sistema.criarPastaTemporaria('divisao_'),
    );

    try {
      final motor = _motorParaDividir();
      var partes = plano.partes;
      final contexto = _ContextoNomes(
        nomeBase: arquivo.nomeSemExtensao,
        pasta: ServicoArquivos.pastaDe(plano.partes.first.nomeSugerido),
        padrao: _padraoEfetivo(opcoes),
        bytesPorPagina: arquivo.bytesPorPagina,
      );
      final limite = opcoes.metodo == SplitMethod.porTamanho
          ? opcoes.maxBytes
          : null;
      final avisos = <String>[...plano.avisos];

      List<String>? destinosFinais;
      var bytesTotal = 0;

      if (motor == null) {
        return ItemResult(
          entrada: arquivo.caminho,
          saidas: const [],
          bytesAntes: arquivo.bytes,
          bytesDepois: arquivo.bytes,
          duracao: DateTime.now().difference(inicio),
          erro: 'Nenhum motor de divisão disponível',
        );
      }

      // Até três passadas: só o método "por tamanho" costuma precisar de mais
      // de uma, quando a média de bytes por página engana.
      for (var passada = 0; passada < 3; passada++) {
        cancelamento.verificar();

        final destinos = <String>[
          for (final parte in partes)
            '${temporaria.path}${Platform.pathSeparator}'
                'parte_${passada}_${parte.indice}.pdf',
        ];

        final resultado = await motor.dividir(
          entrada: arquivo.caminho,
          partes: [for (final parte in partes) parte.intervalos],
          destinos: destinos,
          cancelamento: cancelamento,
          progresso: progresso,
        );

        if (!resultado.sucesso) {
          return ItemResult(
            entrada: arquivo.caminho,
            saidas: const [],
            bytesAntes: arquivo.bytes,
            bytesDepois: arquivo.bytes,
            duracao: DateTime.now().difference(inicio),
            erro: resultado.erro,
            motor: motor.nome,
          );
        }

        final tamanhos = [
          for (final destino in destinos) ServicoArquivos.tamanho(destino),
        ];
        bytesTotal = tamanhos.fold(0, (soma, valor) => soma + valor);

        if (limite == null) {
          destinosFinais = destinos;
          break;
        }

        // Confere o limite de verdade e reparte o que passou.
        final excedentes = <int>[
          for (var i = 0; i < partes.length; i++)
            if (tamanhos[i] > limite && partes[i].paginas > 1) i,
        ];

        if (excedentes.isEmpty) {
          if (tamanhos.any((t) => t > limite)) {
            avisos.add(
              'Uma página sozinha já passa do limite informado e virou uma '
              'parte maior que o pedido.',
            );
          }
          destinosFinais = destinos;
          break;
        }

        final novoPlano = <SplitPart>[];
        for (var i = 0; i < partes.length; i++) {
          final parte = partes[i];
          if (!excedentes.contains(i)) {
            novoPlano.add(parte);
            continue;
          }
          final paginas = [
            for (final intervalo in parte.intervalos) ...intervalo.paginas,
          ];
          final meio = (paginas.length / 2).ceil();
          final primeira = paginas.sublist(0, meio);
          final segunda = paginas.sublist(meio);
          novoPlano.add(_repartir(parte, primeira, parte.indice, 0));
          if (segunda.isNotEmpty) {
            novoPlano.add(_repartir(parte, segunda, parte.indice, 1));
          }
        }

        // Renumera e refaz os nomes com o mesmo padrão do plano original.
        partes = [
          for (var i = 0; i < novoPlano.length; i++)
            contexto.montar(i + 1, novoPlano[i].intervalos),
        ];
      }

      if (destinosFinais == null) {
        return ItemResult(
          entrada: arquivo.caminho,
          saidas: const [],
          bytesAntes: arquivo.bytes,
          bytesDepois: arquivo.bytes,
          duracao: DateTime.now().difference(inicio),
          erro: 'Não foi possível respeitar o limite de tamanho',
        );
      }

      // Move tudo para o destino final, sem sobrescrever nada por acidente.
      final saidas = <String>[];
      for (var i = 0; i < partes.length && i < destinosFinais.length; i++) {
        final destino = ServicoArquivos.caminhoFinal(
          partes[i].nomeSugerido,
          sobrescrever: sobrescrever,
        );
        await File(destinosFinais[i]).copy(destino);
        saidas.add(destino);
      }

      progresso(1, 'Concluído');

      return ItemResult(
        entrada: arquivo.caminho,
        saidas: saidas,
        bytesAntes: arquivo.bytes,
        bytesDepois: bytesTotal,
        duracao: DateTime.now().difference(inicio),
        motor: motor.nome,
        aviso: avisos.isEmpty ? null : avisos.join('\n\n'),
      );
    } on OperacaoCancelada {
      return ItemResult(
        entrada: arquivo.caminho,
        saidas: const [],
        bytesAntes: arquivo.bytes,
        bytesDepois: arquivo.bytes,
        duracao: DateTime.now().difference(inicio),
        erro: S.erroCancelado,
      );
    } finally {
      try {
        if (temporaria.existsSync()) await temporaria.delete(recursive: true);
      } catch (_) {}
    }
  }

  SplitPart _repartir(
    SplitPart original,
    List<int> paginas,
    int indiceOriginal,
    int metade,
  ) {
    final normalizado = PageRangeParser.normalizar([
      for (final pagina in paginas) PageRange(pagina, pagina),
    ]);
    return SplitPart(
      indice: indiceOriginal * 10 + metade,
      intervalos: normalizado,
      paginas: paginas.length,
      bytesEstimados: original.bytesEstimados ~/ 2,
      nomeSugerido: original.nomeSugerido,
    );
  }

  /// Dividir é sempre sem perdas: preferimos o motor nativo (cópia exata das
  /// páginas) e só caímos para os externos se ele não estiver disponível.
  MotorPdf? _motorParaDividir() {
    final lista = motores.todos.where((motor) => motor.disponivel).toList();
    if (lista.isEmpty) return null;
    return lista.firstWhere(
      (motor) => motor.tipo == EngineKind.nativo,
      orElse: () => lista.first,
    );
  }
}

/// Contexto reutilizado para montar nomes de forma consistente.
typedef _ContextoNomes = _ContextoNomesImpl;

/// Monta os nomes das partes a partir do padrão escolhido.
class _ContextoNomesImpl {
  const _ContextoNomesImpl({
    required this.nomeBase,
    required this.pasta,
    required this.padrao,
    required this.bytesPorPagina,
  });

  final String nomeBase;
  final String pasta;
  final String padrao;
  final double bytesPorPagina;

  SplitPart montar(int indice, List<PageRange> intervalos) {
    final paginas = intervalos.fold(
      0,
      (soma, intervalo) => soma + intervalo.quantidade,
    );
    final nome = ServicoArquivos.nomeDaParte(
      padrao: padrao,
      nomeBase: nomeBase,
      parte: indice,
      inicio: intervalos.first.inicio,
      fim: intervalos.last.fim,
      paginas: paginas,
    );
    return SplitPart(
      indice: indice,
      intervalos: intervalos,
      paginas: paginas,
      bytesEstimados: (bytesPorPagina * paginas).round(),
      nomeSugerido: '$pasta${Platform.pathSeparator}$nome.pdf',
    );
  }
}
