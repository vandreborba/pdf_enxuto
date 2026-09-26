import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/models/planilha_options.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/servico_arquivos.dart';
import 'package:pdf_enxuto/services/tabela/detector_tabela.dart';
import 'package:pdf_enxuto/services/tabela/escritor_planilha.dart';
import 'package:pdf_enxuto/services/tabela/extrator_texto.dart';

/// O que a pré-visualização mostra antes de converter.
class PreviaPlanilha {
  const PreviaPlanilha({
    required this.paginasLidas,
    required this.tabelas,
    required this.totalPaginas,
    required this.soImagem,
  });

  final int paginasLidas;
  final int totalPaginas;

  /// Tabelas encontradas nas páginas lidas (só as que parecem tabela).
  final List<TabelaDetectada> tabelas;

  final bool soImagem;

  bool get temTabela => tabelas.isNotEmpty;

  int get totalLinhas =>
      tabelas.fold(0, (soma, tabela) => soma + tabela.linhasUteis);
}

/// Converte PDF em planilha: lê o texto com posição, reconstrói as tabelas e
/// grava XLSX ou CSV. Tudo local, sem enviar nada para lugar nenhum.
class ServicoPlanilha {
  const ServicoPlanilha();

  /// Nome do motor mostrado no resultado (o mesmo vocabulário da compressão).
  static const String motor = 'Nativo (embutido)';

  /// Lê algumas páginas e mostra o que seria gerado, sem gravar nada.
  ///
  /// É o mesmo caminho da conversão de verdade: o que aparece aqui é o que
  /// sai lá — a diferença é que a prévia para na leitura.
  Future<PreviaPlanilha?> previa({
    required String caminho,
    required OpcoesPlanilha opcoes,
    int paginas = 3,
    Cancelamento? cancelamento,
  }) async {
    if (!File(caminho).existsSync()) return null;
    try {
      final leitura = await ExtratorTexto.ler(
        caminho,
        paginas: [for (var i = 1; i <= paginas; i++) i],
        cancelamento: cancelamento,
        ignorarCabecalhoRodape: opcoes.ignorarCabecalhoRodape,
      );
      if (cancelamento?.cancelado ?? false) return null;

      final tabelas = <TabelaDetectada>[];
      for (final pagina in leitura.paginas) {
        tabelas.addAll(
          DetectorTabela.detectar(
            pagina.palavras,
            sensibilidade: opcoes.sensibilidade,
            modo: opcoes.modo,
            pagina: pagina.numero,
          ),
        );
      }

      return PreviaPlanilha(
        paginasLidas: leitura.paginas.length,
        totalPaginas: leitura.totalPaginas,
        tabelas: [
          for (final t in tabelas)
            if (t.pareceTabela) t,
        ],
        soImagem: leitura.soImagem,
      );
    } catch (_) {
      return null;
    }
  }

  /// Converte o PDF e grava os arquivos. Devolve o resultado da tarefa.
  Future<ItemResult> converter({
    required String entrada,
    required OpcoesPlanilha opcoes,
    required Cancelamento cancelamento,
    required void Function(double fracao, String etapa) progresso,
    required bool sobrescrever,
    String? pastaSaida,
  }) async {
    final cronometro = Stopwatch()..start();
    final bytesEntrada = ServicoArquivos.tamanho(entrada);

    ItemResult falha(String mensagem) => ItemResult(
      entrada: entrada,
      saidas: const [],
      bytesAntes: bytesEntrada,
      bytesDepois: bytesEntrada,
      duracao: cronometro.elapsed,
      motor: motor,
      erro: mensagem,
    );

    try {
      progresso(0, 'Lendo o texto do PDF…');
      // Para "uma aba por tabela/página", cada página com texto já garante ao
      // menos uma aba: não faz sentido ler o PDF inteiro depois do teto.
      bool Function(int, int)? parar =
          opcoes.escopo == EscopoPlanilha.porArquivo
          ? null
          : (lidas, comTexto) => comTexto >= OpcoesPlanilha.maxAbas;
      final leitura = await ExtratorTexto.ler(
        entrada,
        cancelamento: cancelamento,
        ignorarCabecalhoRodape: opcoes.ignorarCabecalhoRodape,
        parar: parar,
        progresso: (atual, total) {
          if (total > 0) {
            progresso(
              0.75 * (atual / total),
              'Lendo página ${atual.clamp(1, total)} de $total…',
            );
          }
        },
      );
      cancelamento.verificar();

      if (leitura.paginas.isEmpty) {
        return falha(S.planilhaSemPaginas);
      }
      if (leitura.soImagem) {
        return falha(S.planilhaDigitalizada);
      }

      progresso(0.78, 'Montando as tabelas…');
      final gravado = await _gravar(
        entrada: entrada,
        pastaSaida: pastaSaida,
        opcoes: opcoes,
        paginas: leitura.paginas,
        sobrescrever: sobrescrever,
        cancelamento: cancelamento,
      );
      if (gravado.abas == 0) {
        return falha(S.planilhaSemTabela);
      }
      cancelamento.verificar();

      final saidas = gravado.saidas;
      var bytesSaida = 0;
      for (final saida in saidas) {
        bytesSaida += ServicoArquivos.tamanho(saida);
      }

      progresso(1, '');
      return ItemResult(
        entrada: entrada,
        saidas: saidas,
        bytesAntes: bytesEntrada,
        bytesDepois: bytesSaida,
        duracao: cronometro.elapsed,
        motor: motor,
        aviso: _montarAviso(leitura, gravado.nomesAbas, opcoes),
        detalhe: opcoes.formato == FormatoPlanilha.xlsx
            ? '${gravado.abas} ${gravado.abas == 1 ? 'aba' : 'abas'}'
            : null,
      );
    } on OperacaoCancelada {
      return falha(S.erroCancelado);
    } catch (erro) {
      // O leitor de PDF é nativo: quando ele não carrega, mais nada no app
      // funciona. Vale uma mensagem que o usuário entenda.
      final texto = '$erro';
      if (texto.contains('PDFium') ||
          texto.contains('pdfium') ||
          texto.contains('Native assets')) {
        return falha(S.planilhaMotorIndisponivel);
      }
      return falha('${S.planilhaFalhou}: $erro');
    }
  }

  // ------------------------------------------------------------------- abas
  /// Transforma as páginas lidas nas abas que serão gravadas.
  ///
  /// É a parte "pensante" da conversão e por isso vive separada: dá para
  /// testar sem abrir PDF nenhum.
  static List<AbaPlanilha> montarAbas(
    List<PaginaLida> paginas,
    OpcoesPlanilha opcoes,
  ) {
    if (opcoes.escopo == EscopoPlanilha.porArquivo) {
      return _porArquivo(paginas, opcoes);
    }

    final abas = <AbaPlanilha>[];
    for (final pagina in paginas) {
      final (tabelas, texto) = _detectar(pagina, opcoes);
      if (opcoes.escopo == EscopoPlanilha.porTabela) {
        _acrescentarPorTabela(abas, pagina.numero, tabelas, texto);
      } else {
        _acrescentarPorPagina(abas, pagina.numero, tabelas, texto);
      }
      // Para no limite: detectar o resto do PDF seria trabalho jogado fora.
      if (abas.length >= OpcoesPlanilha.maxAbas) break;
    }
    return [
      for (final aba in abas.take(OpcoesPlanilha.maxAbas))
        if (!aba.semConteudo) aba,
    ];
  }

  /// Detecta as tabelas de uma página e separa o que não é tabela.
  static (List<TabelaDetectada>, List<String>) _detectar(
    PaginaLida pagina,
    OpcoesPlanilha opcoes,
  ) {
    final tabelas = DetectorTabela.detectar(
      pagina.palavras,
      sensibilidade: opcoes.sensibilidade,
      modo: opcoes.modo,
      pagina: pagina.numero,
      linhas: pagina.linhasVisuais,
    );
    final parece = <TabelaDetectada>[];
    final texto = <String>[];
    for (final tabela in tabelas) {
      if (tabela.pareceTabela) {
        parece.add(tabela);
      } else {
        for (final linha in tabela.linhas) {
          if (linha.isNotEmpty) texto.add(linha.first);
        }
      }
    }
    return (parece, texto);
  }

  static void _acrescentarPorTabela(
    List<AbaPlanilha> abas,
    int pagina,
    List<TabelaDetectada> tabelas,
    List<String> texto,
  ) {
    if (tabelas.isEmpty) {
      if (texto.isEmpty) return;
      abas.add(
        AbaPlanilha(
          nome: 'p$pagina (texto)',
          linhas: [
            for (final linha in texto) [linha],
          ],
        ),
      );
      return;
    }
    for (final tabela in tabelas) {
      abas.add(
        AbaPlanilha(
          nome: tabelas.length == 1
              ? 'p$pagina'
              : 'p$pagina - t${tabela.indiceNaPagina}',
          linhas: tabela.linhas,
        ),
      );
    }
  }

  static void _acrescentarPorPagina(
    List<AbaPlanilha> abas,
    int pagina,
    List<TabelaDetectada> tabelas,
    List<String> texto,
  ) {
    final linhas = <List<String>>[];
    for (final tabela in tabelas) {
      if (linhas.isNotEmpty) linhas.add(const []);
      linhas.addAll(tabela.linhas);
    }
    if (tabelas.isEmpty) {
      for (final linha in texto) {
        linhas.add([linha]);
      }
    }
    if (linhas.isEmpty) return;
    abas.add(AbaPlanilha(nome: 'p$pagina', linhas: linhas));
  }

  static List<AbaPlanilha> _porArquivo(
    List<PaginaLida> paginas,
    OpcoesPlanilha opcoes,
  ) {
    final linhas = <List<String>>[];
    final variasPaginas = paginas.length > 1;

    for (final pagina in paginas) {
      if (linhas.length >= EscritorXlsx.limiteLinhas) break;
      final (tabelas, soltas) = _detectar(pagina, opcoes);
      if (tabelas.isEmpty) {
        if (soltas.isEmpty) continue;
        if (linhas.isNotEmpty) linhas.add(const []);
        if (variasPaginas) linhas.add(['página ${pagina.numero}']);
        for (final linha in soltas) {
          linhas.add([linha]);
        }
        continue;
      }
      for (final tabela in tabelas) {
        if (linhas.isNotEmpty) linhas.add(const []);
        if (variasPaginas) linhas.add(['página ${pagina.numero}']);
        linhas.addAll(tabela.linhas);
      }
    }

    if (linhas.isEmpty) return const [];
    return [AbaPlanilha(nome: 'Planilha', linhas: linhas)];
  }

  // ---------------------------------------------------------------- gravação
  /// Monta as abas, gera os arquivos e devolve o que foi gravado.
  ///
  /// A detecção e a geração são trabalho de CPU: rodam fora da thread da UI.
  /// Para o XLSX, montar e gerar acontecem no mesmo isolate, para os dados das
  /// abas não atravessarem a fronteira do isolate duas vezes.
  static Future<
    ({List<String> saidas, int abas, List<String> nomesAbas})
  >
  _gravar({
    required String entrada,
    required String? pastaSaida,
    required OpcoesPlanilha opcoes,
    required List<PaginaLida> paginas,
    required bool sobrescrever,
    required Cancelamento cancelamento,
  }) async {
    if (opcoes.formato == FormatoPlanilha.xlsx) {
      final preparado = await Isolate.run(() {
        final abas = montarAbas(paginas, opcoes);
        if (abas.isEmpty) {
          return (bytes: Uint8List(0), abas: 0, nomes: <String>[]);
        }
        return (
          bytes: EscritorXlsx.gerar(
            abas,
            congelarCabecalho: opcoes.primeiraLinhaCabecalho,
          ),
          abas: abas.length,
          nomes: [for (final aba in abas) aba.nome],
        );
      });
      if (preparado.abas == 0) {
        return (saidas: <String>[], abas: 0, nomesAbas: <String>[]);
      }
      final caminho = ServicoArquivos.caminhoFinal(
        ServicoArquivos.caminhoSaida(entrada, pastaSaida, opcoes.extensao),
        sobrescrever: sobrescrever,
      );
      cancelamento.verificar();
      await File(caminho).writeAsBytes(preparado.bytes, flush: true);
      return (
        saidas: [caminho],
        abas: preparado.abas,
        nomesAbas: preparado.nomes,
      );
    }

    // Uma única spawn para montar e gerar todas as abas: o CSV grava um
    // arquivo por aba, e gerar sheet a sheet multiplicaria as cópias.
    final preparado = await Isolate.run(() {
      final abas = montarAbas(paginas, opcoes);
      return (
        bytes: [
          for (final aba in abas)
            Uint8List.fromList([
              0xEF,
              0xBB,
              0xBF,
              ...utf8.encode(
                EscritorCsv.gerar(
                  aba,
                  separador: opcoes.separadorCsv,
                  protegerFormulas: opcoes.protegerFormulas,
                ),
              ),
            ]),
        ],
        abas: abas.length,
        nomes: [for (final aba in abas) aba.nome],
      );
    });
    final saidas = <String>[];
    for (var i = 0; i < preparado.abas; i++) {
      final caminho = ServicoArquivos.caminhoFinal(
        ServicoArquivos.caminhoSaida(
          entrada,
          pastaSaida,
          opcoes.extensao,
          acrescimo: preparado.abas == 1 ? null : preparado.nomes[i],
        ),
        sobrescrever: sobrescrever,
      );
      cancelamento.verificar();
      await File(caminho).writeAsBytes(preparado.bytes[i], flush: true);
      saidas.add(caminho);
    }
    return (
      saidas: saidas,
      abas: preparado.abas,
      nomesAbas: preparado.nomes,
    );
  }

  static String? _montarAviso(
    LeituraPdf leitura,
    List<String> nomesAbas,
    OpcoesPlanilha opcoes,
  ) {
    final avisos = <String>[];

    if (leitura.paginasSemTexto > 0) {
      avisos.add(
        '${leitura.paginasSemTexto} '
        '${leitura.paginasSemTexto == 1 ? 'página é uma imagem' : 'páginas são imagens'} '
        '(digitalização) e ficou de fora: sem texto não há o que converter.',
      );
    }
    if (opcoes.modo != ModoPlanilha.texto &&
        nomesAbas.any((nome) => nome.contains('(texto)'))) {
      avisos.add(S.planilhaPaginasSemTabela);
    }
    if (leitura.cabecalhosIgnorados.isNotEmpty) {
      avisos.add(
        '${leitura.cabecalhosIgnorados.length} '
        '${leitura.cabecalhosIgnorados.length == 1 ? 'linha repetida de cabeçalho ou rodapé foi ignorada' : 'linhas repetidas de cabeçalho ou rodapé foram ignoradas'}.',
      );
    }
    if (nomesAbas.length >= OpcoesPlanilha.maxAbas) {
      avisos.add(
        'O PDF tem mais conteúdo do que cabe em um arquivo: paramos em '
        '${OpcoesPlanilha.maxAbas} abas.',
      );
    }

    return avisos.isEmpty ? null : avisos.join(' ');
  }

  /// Resumo curto das opções, usado no histórico.
  static String descrever(OpcoesPlanilha opcoes) {
    final partes = <String>[opcoes.formato.rotulo];
    if (opcoes.modo == ModoPlanilha.texto) {
      partes.add('texto em uma coluna');
    } else {
      partes.add('colunas ${opcoes.sensibilidade.rotulo.toLowerCase()}');
    }
    partes.add(opcoes.escopo.rotulo.toLowerCase());
    return partes.join(' • ');
  }
}
