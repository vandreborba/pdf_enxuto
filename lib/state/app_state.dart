import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/app_settings.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/pdf_file_info.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/inspecao_pdf.dart';
import 'package:pdf_enxuto/services/motores.dart';
import 'package:pdf_enxuto/services/servico_arquivos.dart';
import 'package:pdf_enxuto/services/servico_atualizacao.dart';
import 'package:pdf_enxuto/services/servico_compressao.dart';
import 'package:pdf_enxuto/services/servico_config.dart';
import 'package:pdf_enxuto/services/servico_divisao.dart';
import 'package:pdf_enxuto/services/servico_historico.dart';

/// Um arquivo dentro da fila de trabalho.
class ItemFila {
  ItemFila(this.arquivo);

  PdfFileInfo arquivo;

  JobStatus status = JobStatus.aguardando;
  double progresso = 0;
  String etapa = '';
  ItemResult? resultado;
  Cancelamento? cancelamento;

  /// Alvo específico deste item (quando o alvo é dividido entre os arquivos).
  int? alvoBytes;

  String get chave => arquivo.caminho;

  bool get selecionado => status == JobStatus.aguardando;

  bool get processavel => arquivo.ok;

  String get nome => arquivo.nome;

  double get reducao => resultado?.reducao ?? 0;
}

/// Estado central do aplicativo.
///
/// Guarda a fila, as preferências, o histórico e o resultado da verificação de
/// atualização. As telas apenas observam e chamam ações daqui.
class AppState extends ChangeNotifier {
  AppState();

  final ServicoConfig configuracao = ServicoConfig();
  final ServicoHistorico historico = ServicoHistorico();
  final Motores motores = Motores();
  final ServicoAtualizacao atualizacoes = ServicoAtualizacao();
  late final ServicoCompressao compressao = ServicoCompressao(motores);
  late final ServicoDivisao divisao = ServicoDivisao(motores);

  final List<ItemFila> fila = [];

  bool carregando = true;
  bool processando = false;
  String etapaGeral = '';

  /// Versão do aplicativo (lida do pacote na inicialização).
  String versaoApp = '1.0.0';

  ResultadoAtualizacao? resultadoAtualizacao;
  bool verificandoAtualizacao = false;
  bool novidadesAbertas = false;

  int? previsaoSimulada;
  bool simulando = false;

  Timer? _avisoDeTempo;

  AppSettings get config => configuracao.config;

  CompressionOptions get opcoesCompressao => config.compressao;

  SplitOptions get opcoesDivisao => config.divisao;

  List<ItemFila> get itensValidos =>
      fila.where((item) => item.arquivo.ok).toList();

  int get totalBytesFila =>
      fila.fold(0, (soma, item) => soma + item.arquivo.bytes);

  int get totalPaginasFila =>
      fila.fold(0, (soma, item) => soma + item.arquivo.paginas);

  bool get temAlgoParaProcessar => itensValidos.isNotEmpty && !processando;

  // ------------------------------------------------------------------- setup
  Future<void> iniciar() async {
    versaoApp = await ServicoAtualizacao.versaoAtual();
    // Se o app foi fechado no meio de uma tarefa, sobrou pasta temporária.
    unawaited(Sistema.limparTemporariosAntigos());
    await Future.wait([configuracao.carregar(), historico.carregar()]);
    await motores.detectar();
    carregando = false;
    notifyListeners();

    if (config.verificarAtualizacoes) {
      unawaited(verificarAtualizacao(silencioso: true));
    }
  }

  void _avisar() => notifyListeners();

  // -------------------------------------------------------------------- fila
  /// Adiciona arquivos à fila: aceita PDFs, ignora o resto e avisa o usuário.
  Future<({int adicionados, int ignorados, int duplicados, int comProblema})>
  adicionarCaminhos(Iterable<String> caminhos) async {
    final existentes = fila.map((item) => item.chave).toSet();
    var ignorados = 0;
    var duplicados = 0;
    var comProblema = 0;
    var adicionados = 0;

    // Pastas viram a lista de PDFs dentro delas.
    final arquivos = <String>[];
    for (final caminho in caminhos) {
      final tipo = FileSystemEntity.typeSync(caminho);
      if (tipo == FileSystemEntityType.directory) {
        final encontrados =
            Directory(caminho)
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()
                .where((arquivo) => arquivo.path.toLowerCase().endsWith('.pdf'))
                .map((arquivo) => arquivo.path)
                .toList()
              ..sort();
        arquivos.addAll(encontrados);
      } else if (tipo == FileSystemEntityType.file &&
          caminho.toLowerCase().endsWith('.pdf')) {
        arquivos.add(caminho);
      } else {
        ignorados++;
      }
    }

    for (final caminho in arquivos) {
      if (existentes.contains(caminho)) {
        duplicados++;
        continue;
      }
      existentes.add(caminho);

      final info = await InspecaoPdf.inspecionar(caminho);
      final item = ItemFila(info.copyWith(caminho: caminho));
      if (!info.ok) comProblema++;
      fila.add(item);
      adicionados++;
      _avisar();
    }

    _recalcularAlvos();
    _avisar();
    return (
      adicionados: adicionados,
      ignorados: ignorados,
      duplicados: duplicados,
      comProblema: comProblema,
    );
  }

  void removerItem(String chave) {
    fila.removeWhere((item) => item.chave == chave);
    _recalcularAlvos();
    _avisar();
  }

  void limparFila() {
    for (final item in fila) {
      item.cancelamento?.cancelar();
    }
    fila.clear();
    previsaoSimulada = null;
    _avisar();
  }

  /// Refaz a leitura de um arquivo (usado quando a leitura falhou).
  Future<void> reinspecionar(String chave) async {
    final indice = fila.indexWhere((item) => item.chave == chave);
    if (indice < 0) return;
    fila[indice].arquivo = await InspecaoPdf.inspecionar(chave);
    _avisar();
  }

  /// Distribui o alvo total entre os arquivos, proporcionalmente ao tamanho.
  void _recalcularAlvos() {
    final opcoes = opcoesCompressao;
    final validos = itensValidos;
    for (final item in fila) {
      item.alvoBytes = null;
    }
    if (!opcoes.targetEnabled || validos.isEmpty) return;

    if (opcoes.targetScope == TargetScope.porArquivo) {
      for (final item in validos) {
        item.alvoBytes = opcoes.targetBytes;
      }
      return;
    }

    // Alvo para o conjunto: cada arquivo recebe uma cota proporcional.
    final total = totalBytesFila;
    if (total <= 0) return;
    for (final item in validos) {
      final cota = opcoes.targetBytes * (item.arquivo.bytes / total);
      final minimo = math.min(24 * 1024, opcoes.targetBytes);
      item.alvoBytes = cota.round().clamp(minimo, opcoes.targetBytes);
    }
  }

  Future<void> atualizarCompressao(CompressionOptions opcoes) async {
    await configuracao.definirCompressao(opcoes);
    _recalcularAlvos();
    _avisar();
  }

  Future<void> atualizarDivisao(SplitOptions opcoes) async {
    await configuracao.atualizar(config.copyWith(divisao: opcoes));
    _avisar();
  }

  Future<void> atualizarConfig(AppSettings novo) async {
    await configuracao.atualizar(novo);
    _recalcularAlvos();
    _avisar();
  }

  // ------------------------------------------------------------- compressão
  Future<void> comprimirTudo() async {
    if (processando || itensValidos.isEmpty) return;

    _recalcularAlvos();
    processando = true;
    etapaGeral = 'Comprimindo…';
    _avisar();

    final paraProcessar = itensValidos;
    final paralelismo = config.paralelismo;
    final novidades = <HistoryEntry>[];

    for (final item in paraProcessar) {
      item.status = JobStatus.aguardando;
      item.progresso = 0;
      item.resultado = null;
    }
    _avisar();

    var proximo = 0;
    final total = paraProcessar.length;
    var concluidos = 0;

    Future<void> trabalhador() async {
      while (true) {
        final indice = proximo;
        proximo++;
        if (indice >= total) return;

        final item = paraProcessar[indice];
        final cancelamento = Cancelamento();
        item.cancelamento = cancelamento;
        item.status = JobStatus.processando;
        item.etapa = 'Preparando…';
        _avisar();

        final destino = ServicoArquivos.caminhoComprimido(
          item.chave,
          config.pastaSaida,
        );

        final resultado = await compressao.comprimir(
          entrada: item.chave,
          destino: destino,
          opcoes: opcoesCompressao,
          alvoBytes: item.alvoBytes,
          cancelamento: cancelamento,
          progresso: (fracao, etapa) {
            item.progresso = fracao < 0 ? -1 : fracao.clamp(0, 1);
            item.etapa = etapa;
            _avisar();
          },
          sobrescrever: config.sobrescrever,
          paginas: item.arquivo.paginas,
        );

        item.resultado = resultado;
        item.status = resultado.sucesso
            ? JobStatus.concluido
            : (resultado.erro == S.erroCancelado
                  ? JobStatus.cancelado
                  : JobStatus.falhou);
        item.progresso = 1;
        item.etapa = '';
        concluidos++;
        etapaGeral = 'Comprimindo… $concluidos de $total';

        novidades.add(
          HistoryEntry(
            id: '${DateTime.now().microsecondsSinceEpoch}-${item.chave.hashCode}',
            quando: DateTime.now(),
            kind: TaskKind.comprimir,
            resultado: resultado,
            resumo: compressao.descrever(opcoesCompressao),
          ),
        );

        cancelamento.dispose();
        _avisar();
      }
    }

    await Future.wait([
      for (var i = 0; i < paralelismo.clamp(1, 8); i++) trabalhador(),
    ]);

    await historico.registrarVarias(novidades);

    processando = false;
    etapaGeral = '';
    _recalcularAlvos();

    var economizado = 0;
    for (final entrada in novidades) {
      final diferenca =
          entrada.resultado.bytesAntes - entrada.resultado.bytesDepois;
      if (diferenca > 0) economizado += diferenca;
    }

    if (config.abrirPastaAoTerminar) {
      for (final entrada in novidades) {
        if (entrada.resultado.saidas.isEmpty) continue;
        await Sistema.mostrarNaPasta(entrada.resultado.saidas.first);
        break;
      }
    }

    if (config.notificarAoTerminar && novidades.isNotEmpty) {
      await Sistema.notificar(
        S.appName,
        'Compressão concluída: ${novidades.length} arquivo(s), '
        'economia de ${_formatarBytes(economizado)}.',
      );
    }

    _avisar();
  }

  // ------------------------------------------------------------------ dividir
  Future<void> dividirTudo() async {
    if (processando || itensValidos.isEmpty) return;

    processando = true;
    etapaGeral = 'Dividindo…';
    _avisar();

    final paraProcessar = itensValidos;
    final novidades = <HistoryEntry>[];

    for (final item in paraProcessar) {
      item.status = JobStatus.aguardando;
      item.progresso = 0;
      item.resultado = null;
    }
    _avisar();

    for (var i = 0; i < paraProcessar.length; i++) {
      final item = paraProcessar[i];
      final cancelamento = Cancelamento();
      item.cancelamento = cancelamento;
      item.status = JobStatus.processando;
      etapaGeral = 'Dividindo ${i + 1} de ${paraProcessar.length}…';
      _avisar();

      final plano = ServicoDivisao.montarPlano(
        arquivo: item.arquivo,
        opcoes: opcoesDivisao,
        pastaSaida: config.pastaSaida,
      );

      if (!plano.valido) {
        item.status = JobStatus.falhou;
        item.resultado = ItemResult(
          entrada: item.chave,
          saidas: const [],
          bytesAntes: item.arquivo.bytes,
          bytesDepois: item.arquivo.bytes,
          duracao: Duration.zero,
          erro: plano.erros.isEmpty
              ? 'Não foi possível montar a divisão'
              : plano.erros.first,
        );
        _avisar();
        continue;
      }

      final resultado = await divisao.dividir(
        arquivo: item.arquivo,
        opcoes: opcoesDivisao,
        plano: plano,
        cancelamento: cancelamento,
        progresso: (fracao, etapa) {
          item.progresso = fracao < 0 ? -1 : fracao.clamp(0, 1);
          item.etapa = etapa;
          _avisar();
        },
        sobrescrever: config.sobrescrever,
      );

      item.resultado = resultado;
      item.status = resultado.sucesso
          ? JobStatus.concluido
          : (resultado.erro == S.erroCancelado
                ? JobStatus.cancelado
                : JobStatus.falhou);
      item.progresso = 1;
      item.etapa = '';

      novidades.add(
        HistoryEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-${item.chave.hashCode}',
          quando: DateTime.now(),
          kind: TaskKind.dividir,
          resultado: resultado,
          resumo:
              '${opcoesDivisao.metodo.rotulo} • '
              '${plano.partes.length} ${S.partesPrevistas}',
        ),
      );

      cancelamento.dispose();
      _avisar();
    }

    await historico.registrarVarias(novidades);

    processando = false;
    etapaGeral = '';

    if (config.abrirPastaAoTerminar) {
      for (final entrada in novidades) {
        if (entrada.resultado.saidas.isEmpty) continue;
        await Sistema.mostrarNaPasta(entrada.resultado.saidas.first);
        break;
      }
    }

    if (config.notificarAoTerminar && novidades.isNotEmpty) {
      var gerados = 0;
      for (final entrada in novidades) {
        gerados += entrada.resultado.saidas.length;
      }
      await Sistema.notificar(
        S.appName,
        'Divisão concluída: $gerados arquivo(s) gerado(s).',
      );
    }

    _avisar();
  }

  void cancelarTudo() {
    for (final item in fila) {
      item.cancelamento?.cancelar();
    }
    _avisar();
  }

  // ----------------------------------------------------------------- simular
  Future<void> simular() async {
    final validos = itensValidos;
    if (validos.isEmpty || simulando) return;

    simulando = true;
    previsaoSimulada = null;
    _avisar();

    final cancelamento = Cancelamento();
    try {
      final estimativas = <int>[];
      for (final item in validos.take(5)) {
        final estimativa = await compressao.simular(
          entrada: item.chave,
          opcoes: opcoesCompressao,
          paginas: item.arquivo.paginas,
          cancelamento: cancelamento,
        );
        if (estimativa != null) estimativas.add(estimativa);
      }
      if (estimativas.isNotEmpty) {
        final totalOriginal = validos
            .take(5)
            .fold<int>(0, (soma, item) => soma + item.arquivo.bytes);
        final proporcao =
            estimativas.fold<int>(0, (soma, valor) => soma + valor) /
            totalOriginal;
        previsaoSimulada = (totalBytesFila * proporcao).round().clamp(
          1024,
          totalBytesFila,
        );
      }
    } finally {
      simulando = false;
      _avisar();
    }
  }

  // ------------------------------------------------------------ atualizações
  Future<void> verificarAtualizacao({bool silencioso = false}) async {
    if (verificandoAtualizacao) return;
    verificandoAtualizacao = true;
    if (!silencioso) _avisar();

    final resultado = await atualizacoes.verificar();
    resultadoAtualizacao = resultado;
    verificandoAtualizacao = false;

    await configuracao.atualizar(
      config.copyWith(ultimaVerificacao: DateTime.now()),
    );

    if (resultado.temAtualizacao &&
        !config.avisosDesligados &&
        config.versaoIgnorada != resultado.ultimaVersao &&
        !silencioso) {
      novidadesAbertas = true;
    }

    _avisar();
  }

  bool get deveMostrarBannerAtualizacao {
    final resultado = resultadoAtualizacao;
    if (resultado == null || !resultado.temAtualizacao) return false;
    if (config.avisosDesligados) return false;
    return config.versaoIgnorada != resultado.ultimaVersao;
  }

  Future<void> ignorarVersaoAtual() async {
    final versao = resultadoAtualizacao?.ultimaVersao;
    if (versao == null) return;
    await configuracao.atualizar(config.copyWith(versaoIgnorada: versao));
    novidadesAbertas = false;
    _avisar();
  }

  Future<String?> baixarAtualizacao() async {
    final resultado = resultadoAtualizacao;
    if (resultado == null) return null;
    return atualizacoes.baixar(resultado);
  }

  void abrirNovidades() {
    novidadesAbertas = true;
    _avisar();
  }

  void fecharNovidades() {
    novidadesAbertas = false;
    _avisar();
  }

  // --------------------------------------------------------------- utilidades
  static String _formatarBytes(int valor) {
    const unidades = ['B', 'KB', 'MB', 'GB'];
    var tamanho = valor.toDouble();
    var indice = 0;
    while (tamanho >= 1024 && indice < unidades.length - 1) {
      tamanho /= 1024;
      indice++;
    }
    final texto = tamanho.toStringAsFixed(tamanho >= 100 ? 0 : 1);
    return '${texto.replaceAll('.', ',')} ${unidades[indice]}';
  }

  /// Plano de divisão do primeiro arquivo válido (pré-visualização).
  PlanoDivisao? planoDivisaoPreview() {
    final validos = itensValidos;
    if (validos.isEmpty) return null;
    return ServicoDivisao.montarPlano(
      arquivo: validos.first.arquivo,
      opcoes: opcoesDivisao,
      pastaSaida: config.pastaSaida,
    );
  }

  Future<void> procurarMotoresNovamente() async {
    await motores.detectar(forcar: true);
    _avisar();
  }

  @override
  void dispose() {
    _avisoDeTempo?.cancel();
    configuracao.dispose();
    historico.dispose();
    super.dispose();
  }
}
