import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pdf_enxuto/core/app_info.dart';
import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/services/servico_atualizacao.dart';
import 'package:pdf_enxuto/services/servico_janela.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/animacoes.dart';
import 'package:pdf_enxuto/widgets/barra_titulo.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/dialogos.dart';
import 'package:pdf_enxuto/widgets/fila.dart';
import 'package:pdf_enxuto/screens/pagina_comprimir.dart';
import 'package:pdf_enxuto/screens/pagina_config.dart';
import 'package:pdf_enxuto/screens/pagina_dividir.dart';
import 'package:pdf_enxuto/screens/pagina_historico.dart';

/// As telas do app.
enum SecaoApp {
  comprimir(S.navComprimir, Icons.compress_rounded),
  dividir(S.navDividir, Icons.call_split_rounded),
  historico(S.navHistorico, Icons.history_rounded),
  configuracoes(S.navConfiguracoes, Icons.settings_rounded);

  const SecaoApp(this.rotulo, this.icone);

  final String rotulo;
  final IconData icone;
}

/// Janela principal: navegação lateral, conteúdo e o alvo global de soltar
/// arquivos.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key, required this.estado});

  final AppState estado;

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> with WindowListener {
  SecaoApp _secao = SecaoApp.comprimir;
  bool _maximizada = false;
  bool _arrastando = false;
  bool _boasVindasMostradas = false;
  bool _novidadesMostradas = false;
  bool _sobreAberto = false;

  AppState get estado => widget.estado;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Pergunta o estado da janela sem depender do plugin (em testes, por
    // exemplo, ele não existe).
    unawaited(_lerEstadoDaJanela());
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximizada = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximizada = false);
  }

  Future<void> _lerEstadoDaJanela() async {
    try {
      final valor = await windowManager.isMaximized();
      if (mounted) setState(() => _maximizada = valor);
    } catch (_) {
      // Sem plugin de janela: seguimos com o estado padrão.
    }
  }

  /// Informações anexadas nos e-mails de contato.
  String get informacoesTecnicas {
    final versao = estado.versaoApp;
    final motores = estado.motores.todos
        .where((motor) => motor.disponivel)
        .map(
          (motor) =>
              '${motor.nome}${motor.estado.versao != null ? ' ${motor.estado.versao}' : ''}',
        )
        .join(', ');
    return 'PDF Enxuto $versao\n'
        'Sistema: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
        'Motores: $motores';
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Fecha direto, sem janela de confirmação: guarda a posição/tamanho da
    // janela e sai. Tarefas em andamento são interrompidas — os motores só
    // renomeiam o arquivo final no fim, então nada fica pela metade.
    if (estado.processando) estado.cancelarTudo();
    await ServicoJanela.salvar();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _abrir,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _processar,
        const SingleActivator(LogicalKeyboardKey.escape): _cancelar,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            setState(() => _secao = SecaoApp.comprimir),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            setState(() => _secao = SecaoApp.dividir),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            setState(() => _secao = SecaoApp.historico),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            setState(() => _secao = SecaoApp.configuracoes),
      },
      child: Focus(
        autofocus: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _arrastando = true),
          onDragExited: (_) => setState(() => _arrastando = false),
          onDragDone: (detalhes) async {
            setState(() => _arrastando = false);
            final caminhos = detalhes.files.map((f) => f.path).toList();
            final resultado = await estado.adicionarCaminhos(caminhos);
            if (!mounted) return;
            _avisarSobreArquivos(resultado);
          },
          // Como a janela não tem moldura do sistema, as bordas precisam ser
          // redimensionáveis pelo próprio app.
          child: DragToResizeArea(
            resizeEdgeSize: 6,
            child: Stack(
              children: [
                FundoAnimado(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Column(
                      children: [
                        BarraTitulo(
                          titulo: S.appName,
                          subtitulo: _secao.rotulo,
                          maximizada: _maximizada,
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BarraLateral(
                                secao: _secao,
                                estado: estado,
                                onMudar: (secao) =>
                                    setState(() => _secao = secao),
                                onSobre: _mostrarSobre,
                                onRelatar: () => _mostrarRelato(),
                                onRecurso: () => _mostrarRelato(recurso: true),
                              ),
                              Expanded(child: _conteudo()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SobreposicaoSolta(visivel: _arrastando, quantidade: 1),
                if (estado.processando)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _BarraDeProgressoGlobal(estado: estado),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cabecalho(
            secao: _secao,
            estado: estado,
            onProcessar: _processar,
            onAbrir: _abrir,
          ),
          if (estado.deveMostrarBannerAtualizacao)
            BannerAtualizacao(
              versao: estado.resultadoAtualizacao?.ultimaVersao ?? '',
              onVerNovidades: estado.abrirNovidades,
              onFechar: estado.ignorarVersaoAtual,
            ),
          Expanded(
            child: TransicaoSuave(
              chave: _secao.name,
              child: AreaRolavel(child: _pagina()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagina() {
    return switch (_secao) {
      SecaoApp.comprimir => PaginaComprimir(estado: estado),
      SecaoApp.dividir => PaginaDividir(estado: estado),
      SecaoApp.historico => PaginaHistorico(estado: estado),
      SecaoApp.configuracoes => PaginaConfiguracoes(estado: estado),
    };
  }

  // ------------------------------------------------------------------ ações
  Future<void> _abrir() async {
    const grupo = XTypeGroup(label: 'PDF', extensions: ['pdf']);
    final arquivos = await openFiles(acceptedTypeGroups: [grupo]);
    if (arquivos.isEmpty) return;
    final resultado = await estado.adicionarCaminhos(
      arquivos.map((arquivo) => arquivo.path),
    );
    if (!mounted) return;
    _avisarSobreArquivos(resultado);
  }

  Future<void> _processar() async {
    if (!estado.temAlgoParaProcessar) return;
    if (_secao == SecaoApp.dividir) {
      await estado.dividirTudo();
    } else {
      await estado.comprimirTudo();
    }
  }

  void _cancelar() {
    if (estado.processando) {
      estado.cancelarTudo();
      return;
    }
    if (_secao != SecaoApp.comprimir) {
      setState(() => _secao = SecaoApp.comprimir);
    }
  }

  void _avisarSobreArquivos(
    ({int adicionados, int ignorados, int duplicados, int comProblema}) r,
  ) {
    final partes = <String>[];
    if (r.adicionados > 0) partes.add('${r.adicionados} adicionado(s)');
    if (r.duplicados > 0) partes.add('${r.duplicados} já estava(m) na fila');
    if (r.ignorados > 0) partes.add('${r.ignorados} ignorado(s)');
    if (r.comProblema > 0) partes.add('${r.comProblema} com problema');

    if (partes.isEmpty) return;
    mostrarAviso(
      context,
      partes.join(' • '),
      icone: r.adicionados > 0
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded,
    );
  }

  Future<void> _mostrarRelato({bool recurso = false}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => DialogoRelato(
        recurso: recurso,
        informacoesTecnicas: informacoesTecnicas,
      ),
    );
  }

  Future<void> _mostrarSobre() async {
    if (_sobreAberto) return;
    _sobreAberto = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogoSobre(
        versao: estado.versaoApp,
        onRelatarProblema: () {
          Navigator.of(dialogContext).pop();
          if (!mounted) return;
          _mostrarRelato();
        },
        onSolicitarRecurso: () {
          Navigator.of(dialogContext).pop();
          if (!mounted) return;
          _mostrarRelato(recurso: true);
        },
      ),
    );
    _sobreAberto = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mostrarDialogosPendentes();
  }

  void _mostrarDialogosPendentes() {
    if (_boasVindasMostradas == false &&
        !estado.carregando &&
        !estado.config.onboardingVisto) {
      _boasVindasMostradas = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => DialogoBoasVindas(
            onFechar: () {
              Navigator.of(context).pop();
              estado.atualizarConfig(
                estado.config.copyWith(onboardingVisto: true),
              );
            },
          ),
        );
      });
    }

    if (_novidadesMostradas == false && estado.novidadesAbertas) {
      _novidadesMostradas = true;
      final resultado = estado.resultadoAtualizacao;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || resultado == null) return;
        _mostrarNovidades(resultado);
      });
    }
  }

  Future<void> _mostrarNovidades(ResultadoAtualizacao resultado) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogoNovidades(
        resultado: resultado,
        onBaixar: () async {
          final caminho = await estado.baixarAtualizacao();
          if (!mounted) return;
          Navigator.of(dialogContext).pop();
          mostrarAviso(
            context,
            caminho == null
                ? 'Não foi possível baixar o pacote agora.'
                : 'Pacote salvo em ${Fmt.nomeCurto(caminho)}',
            icone: caminho == null
                ? Icons.error_outline_rounded
                : Icons.download_done_rounded,
          );
        },
        onIgnorarVersao: () async {
          await estado.ignorarVersaoAtual();
          if (!mounted) return;
          Navigator.of(dialogContext).pop();
        },
        onFechar: () {
          estado.fecharNovidades();
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    estado.fecharNovidades();
    _novidadesMostradas = false;
  }
}

class _BarraDeProgressoGlobal extends StatelessWidget {
  const _BarraDeProgressoGlobal({required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    return BarraProgresso(valor: -1, altura: 3);
  }
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral({
    required this.secao,
    required this.estado,
    required this.onMudar,
    required this.onSobre,
    required this.onRelatar,
    required this.onRecurso,
  });

  final SecaoApp secao;
  final AppState estado;
  final ValueChanged<SecaoApp> onMudar;
  final VoidCallback onSobre;
  final VoidCallback onRelatar;
  final VoidCallback onRecurso;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final escuro = esquema.brightness == Brightness.dark;

    return Container(
      width: 234,
      decoration: BoxDecoration(
        color: escuro
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.55),
        border: Border(
          right: BorderSide(
            color: esquema.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cores.accentSuave,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset('assets/icons/icon.png'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.appName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '100% local',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cores.sucesso,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final item in SecaoApp.values)
            _ItemNavegacao(
              secao: item,
              selecionada: item == secao,
              onTap: () => onMudar(item),
            ),
          const Spacer(),
          if (estado.historico.totalEconomizado > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cores.sucesso.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cores.sucesso.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.savings_outlined,
                          size: 15,
                          color: cores.sucesso,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Já economizou',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: cores.sucesso,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ContadorAnimado(
                      valor: estado.historico.totalEconomizado,
                      formatador: Fmt.bytes,
                      estilo: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cores.sucesso,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  onPressed: onSobre,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text(S.sobre),
                ),
                TextButton.icon(
                  onPressed: () => abrirLink(AppInfo.sourceUrl),
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: const Text(S.codigoFonte),
                ),
                TextButton.icon(
                  onPressed: onRelatar,
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text(S.relatarBug),
                ),
                TextButton.icon(
                  onPressed: onRecurso,
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                  label: const Text(S.solicitarRecurso),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemNavegacao extends StatefulWidget {
  const _ItemNavegacao({
    required this.secao,
    required this.selecionada,
    required this.onTap,
  });

  final SecaoApp secao;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  State<_ItemNavegacao> createState() => _ItemNavegacaoState();
}

class _ItemNavegacaoState extends State<_ItemNavegacao> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final ativo = widget.selecionada || _sobre;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.escolher(context, Motion.media),
          curve: Motion.entrada,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Item selecionado: fundo discreto na cor do app e uma barrinha
            // à esquerda, em vez de um bloco colorido.
            color: widget.selecionada
                ? cores.accent.withValues(alpha: 0.10)
                : (_sobre
                      ? esquema.surfaceContainerHighest.withValues(alpha: 0.35)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: widget.selecionada ? cores.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.secao.icone,
                size: 19,
                color: widget.selecionada
                    ? cores.accent
                    : (ativo ? cores.accent : esquema.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Text(
                widget.secao.rotulo,
                style: TextStyle(
                  fontWeight: widget.selecionada
                      ? FontWeight.w700
                      : FontWeight.w600,
                  fontSize: 14,
                  color: widget.selecionada ? Colors.white : esquema.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.secao,
    required this.estado,
    required this.onProcessar,
    required this.onAbrir,
  });

  final SecaoApp secao;
  final AppState estado;
  final Future<void> Function() onProcessar;
  final Future<void> Function() onAbrir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    final (titulo, subtitulo) = switch (secao) {
      SecaoApp.comprimir => (S.comprimirTitulo, S.comprimirSubtitulo),
      SecaoApp.dividir => (S.dividirTitulo, S.dividirSubtitulo),
      SecaoApp.historico => (S.historicoTitulo, S.historicoSubtitulo),
      SecaoApp.configuracoes => (S.configTitulo, S.configSubtitulo),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (secao == SecaoApp.comprimir || secao == SecaoApp.dividir) ...[
            OutlinedButton.icon(
              onPressed: estado.processando ? null : onAbrir,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar PDFs'),
            ),
            const SizedBox(width: 12),
            if (estado.processando)
              OutlinedButton.icon(
                onPressed: estado.cancelarTudo,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text(S.parar),
              )
            else
              BotaoGradiente(
                rotulo: _rotuloAcao(),
                icone: secao == SecaoApp.dividir
                    ? Icons.call_split_rounded
                    : Icons.compress_rounded,
                onPressed: estado.temAlgoParaProcessar ? onProcessar : null,
              ),
          ],
        ],
      ),
    );
  }

  String _rotuloAcao() {
    final quantidade = estado.itensValidos.length;
    if (quantidade == 0) {
      return secao == SecaoApp.dividir ? S.dividirAgora : S.comprimirAgora;
    }
    final acao = secao == SecaoApp.dividir ? 'Dividir' : 'Comprimir';
    return '$acao $quantidade ${quantidade == 1 ? 'arquivo' : 'arquivos'}';
  }
}
