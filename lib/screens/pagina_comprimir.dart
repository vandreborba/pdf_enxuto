import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/services/engines/motor_pdf.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/animacoes.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/dialogos.dart';
import 'package:pdf_enxuto/widgets/fila.dart';
import 'package:pdf_enxuto/widgets/seletores.dart';

/// Tela de compressão: fila à esquerda, opções à direita.
class PaginaComprimir extends StatelessWidget {
  const PaginaComprimir({super.key, required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final largo = restricoes.maxWidth > 1080;
        final fila = _ColunaFila(estado: estado);
        final opcoes = _ColunaOpcoes(estado: estado);

        if (largo) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: fila),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: opcoes),
            ],
          );
        }
        return Column(children: [fila, const SizedBox(height: 20), opcoes]);
      },
    );
  }
}

class _ColunaFila extends StatelessWidget {
  const _ColunaFila({required this.estado});

  final AppState estado;

  Future<void> _escolher() async {
    const grupo = XTypeGroup(label: 'PDF', extensions: ['pdf']);
    final arquivos = await openFiles(acceptedTypeGroups: [grupo]);
    if (arquivos.isEmpty) return;
    await estado.adicionarCaminhos(arquivos.map((a) => a.path));
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final itens = estado.fila;
    final comSaida = estado.fila
        .where((item) => item.resultado?.saidas.isNotEmpty ?? false)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CartaoSecao(
          titulo: 'Arquivos',
          subtitulo: itens.isEmpty
              ? 'Nenhum arquivo na fila'
              : '${Fmt.arquivos(itens.length)} • '
                    '${Fmt.bytes(estado.totalBytesFila)} • '
                    '${Fmt.paginas(estado.totalPaginasFila)}',
          icone: Icons.folder_copy_outlined,
          acao: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (itens.isNotEmpty)
                TextButton.icon(
                  onPressed: estado.processando ? null : estado.limparFila,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text(S.limpar),
                ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: estado.processando ? null : _escolher,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(S.escolherArquivos),
              ),
            ],
          ),
          child: Column(
            children: [
              if (itens.isEmpty)
                ZonaSoltar(onEscolher: _escolher)
              else ...[
                ZonaSoltar(
                  onEscolher: _escolher,
                  compacta: true,
                  destacada: false,
                ),
                const SizedBox(height: 16),
                for (var indice = 0; indice < itens.length; indice++)
                  ItemDaFila(
                    item: itens[indice],
                    indice: indice,
                    onRemover: () => estado.removerItem(itens[indice].chave),
                    onAbrirPasta: () {
                      final saidas =
                          itens[indice].resultado?.saidas ?? const [];
                      if (saidas.isNotEmpty) {
                        abrirPastaDoArquivo(saidas.first);
                      }
                    },
                    onAbrirArquivo: () {
                      final saidas =
                          itens[indice].resultado?.saidas ?? const [];
                      if (saidas.isNotEmpty) {
                        abrirArquivoDoResultado(saidas.first);
                      }
                    },
                  ),
              ],
            ],
          ),
        ),
        if (comSaida.isNotEmpty) ...[
          const SizedBox(height: 16),
          CartaoSecao(
            titulo: 'Resultado',
            icone: Icons.insights_rounded,
            destaque: true,
            child: _ResumoDaTarefa(itens: comSaida),
          ),
        ],
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: 'Onde salvar',
          icone: Icons.save_outlined,
          subtitulo: estado.config.pastaSaida ?? S.pastaSaidaPadrao,
          acao: TextButton.icon(
            onPressed: () async {
              final pasta = await getDirectoryPath();
              if (pasta == null) return;
              await estado.atualizarConfig(
                estado.config.copyWith(pastaSaida: pasta),
              );
            },
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text(S.escolherPastaSaida),
          ),
          ajuda:
              'Por padrão, o PDF comprimido é gravado na mesma pasta do '
              'original, com o sufixo "$_sufixo". Você pode escolher uma pasta '
              'fixa — útil quando os originais vêm de um pendrive ou de uma '
              'pasta somente leitura.',
          child: Row(
            children: [
              if (estado.config.pastaSaida != null)
                TextButton.icon(
                  onPressed: () => estado.atualizarConfig(
                    estado.config.copyWith(limparPastaSaida: true),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text(S.usarPastaPadrao),
                ),
              const Spacer(),
              Text(
                'Nome: ${_exemploNome()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (estado.processando) ...[
          const SizedBox(height: 16),
          CartaoSecao(
            destaque: true,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: cores.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    estado.etapaGeral.isEmpty
                        ? S.comprimindo
                        : estado.etapaGeral,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: estado.cancelarTudo,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text(S.parar),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static const String _sufixo = '_enxuto';

  String _exemploNome() => 'relatorio$_sufixo.pdf';
}

/// Cartão com o resumo do que foi economizado na tarefa atual.
class _ResumoDaTarefa extends StatelessWidget {
  const _ResumoDaTarefa({required this.itens});

  final List<ItemFila> itens;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    var antes = 0;
    var depois = 0;
    var tempo = Duration.zero;
    for (final item in itens) {
      final resultado = item.resultado!;
      antes += resultado.bytesAntes;
      depois += resultado.bytesDepois;
      tempo += resultado.duracao;
    }
    final economizado = (antes - depois).clamp(0, antes);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Economia total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              ContadorAnimado(
                valor: economizado,
                formatador: Fmt.bytes,
                estilo: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: cores.sucesso,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Fmt.bytes(antes)} → ${Fmt.bytes(depois)}  •  '
                '${Fmt.reducao(antes, depois)} menor  •  '
                '${Fmt.duracao(tempo)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        AnelProgresso(
          valor: antes == 0 ? 0 : economizado / antes,
          tamanho: 66,
          cor: cores.sucesso,
        ),
      ],
    );
  }
}

class _ColunaOpcoes extends StatelessWidget {
  const _ColunaOpcoes({required this.estado});

  final AppState estado;

  CompressionOptions get opcoes => estado.opcoesCompressao;

  Future<void> _mudar(CompressionOptions novas) =>
      estado.atualizarCompressao(novas);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Um cartão só, com duas abas: ou o perfil, ou o tamanho alvo.
        CartaoSecao(
          titulo: S.comoComprimir,
          icone: Icons.tune_rounded,
          ajuda: Ajuda.modoCompressao,
          atraso: const Duration(milliseconds: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SeletorSegmentado<CompressionMode>(
                valor: opcoes.modo,
                onMudar: (valor) => _mudar(opcoes.copyWith(modo: valor)),
                opcoes: [
                  OpcaoSegmento(
                    valor: CompressionMode.porPerfil,
                    rotulo: S.presets,
                    icone: Icons.tune_rounded,
                    descricao: CompressionMode.porPerfil.descricao,
                  ),
                  OpcaoSegmento(
                    valor: CompressionMode.porTamanho,
                    rotulo: S.tamanhoAlvo,
                    icone: Icons.flag_outlined,
                    descricao: CompressionMode.porTamanho.descricao,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _NotaExplicativa(texto: opcoes.modo.descricao),
              const SizedBox(height: 18),
              if (opcoes.modo == CompressionMode.porPerfil)
                AbaPerfis(opcoes: opcoes, onMudar: _mudar)
              else
                AbaAlvo(opcoes: opcoes, estado: estado, onMudar: _mudar),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.modoTexto,
          icone: Icons.text_fields_rounded,
          ajuda: Ajuda.modoTexto,
          atraso: const Duration(milliseconds: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SeletorSegmentado<TextMode>(
                valor: opcoes.textMode,
                onMudar: (valor) => _mudar(opcoes.copyWith(textMode: valor)),
                opcoes: const [
                  OpcaoSegmento(
                    valor: TextMode.manterTexto,
                    rotulo: S.modoTextoManterCurto,
                    icone: Icons.text_fields_rounded,
                    descricao: S.modoTextoManter,
                  ),
                  OpcaoSegmento(
                    valor: TextMode.rasterizar,
                    rotulo: S.modoTextoRasterizarCurto,
                    icone: Icons.image_rounded,
                    descricao: S.modoTextoRasterizar,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: Motion.escolher(context, Motion.media),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (opcoes.textMode == TextMode.rasterizar
                              ? context.cores.alerta
                              : context.cores.sucesso)
                          .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      opcoes.textMode == TextMode.rasterizar
                          ? Icons.warning_amber_rounded
                          : Icons.verified_outlined,
                      size: 17,
                      color: opcoes.textMode == TextMode.rasterizar
                          ? context.cores.alerta
                          : context.cores.sucesso,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opcoes.textMode.descricaoCurta,
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Avancadas(estado: estado, opcoes: opcoes, onMudar: _mudar),
      ],
    );
  }
}

/// Aba "Perfis prontos": a qualidade escolhida de antemão.
class AbaPerfis extends StatelessWidget {
  const AbaPerfis({super.key, required this.opcoes, required this.onMudar});

  final CompressionOptions opcoes;
  final Future<void> Function(CompressionOptions) onMudar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CartoesPerfil<CompressionPreset>(
          valor: opcoes.preset,
          onMudar: (valor) => onMudar(opcoes.comPreset(valor)),
          opcoes: [
            for (final preset in CompressionPreset.values)
              OpcaoSegmento(
                valor: preset,
                rotulo: preset.rotulo,
                descricao: preset.resumo,
                icone: switch (preset) {
                  CompressionPreset.leve => Icons.spa_outlined,
                  CompressionPreset.equilibrado => Icons.balance_rounded,
                  CompressionPreset.forte => Icons.bolt_rounded,
                  CompressionPreset.extremo => Icons.compress_rounded,
                  CompressionPreset.personalizado => Icons.tune_rounded,
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Etiqueta(
              texto: '${opcoes.dpi} dpi',
              icone: Icons.straighten_rounded,
              compacta: true,
            ),
            Etiqueta(
              texto: 'JPEG ${opcoes.jpegQuality}',
              icone: Icons.photo_size_select_large_rounded,
              compacta: true,
            ),
            if (opcoes.colorMode != ColorMode.manter)
              Etiqueta(
                texto: opcoes.colorMode.rotulo,
                icone: Icons.palette_outlined,
                compacta: true,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(S.perfisAjuda, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Aba "Tamanho alvo": o tamanho desejado e o piso de qualidade.
class AbaAlvo extends StatelessWidget {
  const AbaAlvo({
    super.key,
    required this.opcoes,
    required this.estado,
    required this.onMudar,
  });

  final CompressionOptions opcoes;
  final AppState estado;
  final Future<void> Function(CompressionOptions) onMudar;

  @override
  Widget build(BuildContext context) {
    final motores = estado.motores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.tamanhoAlvoDica, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        CampoTamanho(
          bytes: opcoes.targetBytes,
          rotulo: S.tamanhoAlvo,
          ajuda: Ajuda.tamanhoAlvo,
          onMudar: (bytes) => onMudar(opcoes.copyWith(targetBytes: bytes)),
        ),
        const SizedBox(height: 14),
        if (estado.itensValidos.length > 1) ...[
          SeletorSegmentado<TargetScope>(
            valor: opcoes.targetScope,
            onMudar: (valor) => onMudar(opcoes.copyWith(targetScope: valor)),
            opcoes: const [
              OpcaoSegmento(
                valor: TargetScope.porArquivo,
                rotulo: S.tamanhoAlvoPorArquivo,
                icone: Icons.description_outlined,
              ),
              OpcaoSegmento(
                valor: TargetScope.total,
                rotulo: S.tamanhoAlvoTotal,
                icone: Icons.stacked_bar_chart_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            opcoes.targetScope == TargetScope.total
                ? 'Cada arquivo recebe uma cota proporcional ao tamanho dele.'
                : 'Todos os arquivos tentam caber no mesmo limite.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
        ],
        _FaixaDaBusca(opcoes: opcoes),
        if (!motores.permiteBuscaDeAlvo(opcoes)) ...[
          const SizedBox(height: 10),
          _NotaExplicativa(
            texto: S.alvoSemAjuste,
            cor: context.cores.alerta,
            icone: Icons.warning_amber_rounded,
          ),
        ],
        const SizedBox(height: 12),
        LinhaSlider(
          titulo: S.qualidadeMinima,
          descricao:
              'O quanto a qualidade pode cair na busca para caber no alvo.',
          valor: opcoes.qualidadeMinima,
          minimo: 0,
          maximo: 1,
          ajuda:
              '0% deixa a busca descer bastante (até 72 dpi / JPEG 30); 100% '
              'mantém a qualidade do começo e pode não atingir o alvo.',
          formatar: (valor) => '${(valor * 100).round()}%',
          onMudar: (valor) => onMudar(opcoes.copyWith(qualidadeMinima: valor)),
        ),
      ],
    );
  }
}

class _Avancadas extends StatelessWidget {
  const _Avancadas({
    required this.estado,
    required this.opcoes,
    required this.onMudar,
  });

  final AppState estado;
  final CompressionOptions opcoes;
  final Future<void> Function(CompressionOptions) onMudar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;

    return CartaoSecao(
      titulo: S.opcoesAvancadas,
      icone: Icons.settings_suggest_outlined,
      subtitulo: 'Para quem quer ajustar cada detalhe',
      atraso: const Duration(milliseconds: 160),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        // O Material próprio evita o aviso de tinta escondida pelo cartão.
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: Text(
              opcoes.resumo,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        S.motorCompressao,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      BotaoAjuda(titulo: S.motorCompressao, texto: Ajuda.motor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final motor in estado.motores.todos)
                        _ChipMotor(
                          nome: motor.nome,
                          disponivel: motor.disponivel,
                          versao: motor.estado.versao,
                          selecionado: opcoes.engine == motor.tipo,
                          onTap: () =>
                              onMudar(opcoes.copyWith(engine: motor.tipo)),
                          onVerInstalacao: motor.disponivel
                              ? null
                              : () =>
                                    mostrarComoInstalar(context, motor, estado),
                        ),
                      _ChipMotor(
                        nome: S.motorAutomatico,
                        disponivel: true,
                        versao: 'melhor disponível',
                        selecionado: opcoes.engine == EngineKind.automatico,
                        onTap: () => onMudar(
                          opcoes.copyWith(engine: EngineKind.automatico),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // No modo "por tamanho alvo" quem decide resolução e JPEG é
                  // a busca — os controles manuais só aparecem no modo perfil.
                  if (opcoes.targetEnabled)
                    _NotaExplicativa(texto: S.avancadasNoAlvo)
                  else ...[
                    LinhaSlider(
                      titulo: S.resolucao,
                      valor: opcoes.dpi.toDouble(),
                      minimo: 60,
                      maximo: 400,
                      ajuda: Ajuda.resolucao,
                      formatar: (valor) => '${valor.round()} dpi',
                      onMudar: (valor) => onMudar(
                        opcoes.copyWith(dpi: valor.round()).personalizado(),
                      ),
                    ),
                    LinhaSlider(
                      titulo: S.qualidadeJpeg,
                      valor: opcoes.jpegQuality.toDouble(),
                      minimo: 20,
                      maximo: 100,
                      ajuda: Ajuda.qualidadeJpeg,
                      formatar: (valor) => '${valor.round()}',
                      onMudar: (valor) => onMudar(
                        opcoes
                            .copyWith(jpegQuality: valor.round())
                            .personalizado(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        S.corImagens,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      BotaoAjuda(titulo: S.corImagens, texto: Ajuda.corImagens),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SeletorSegmentado<ColorMode>(
                    valor: opcoes.colorMode,
                    onMudar: (valor) => onMudar(
                      opcoes.copyWith(colorMode: valor).personalizado(),
                    ),
                    opcoes: [
                      for (final modo in ColorMode.values)
                        OpcaoSegmento(
                          valor: modo,
                          rotulo: switch (modo) {
                            ColorMode.manter => 'Original',
                            ColorMode.cinza => 'Cinza',
                            ColorMode.mono => 'P&B',
                          },
                          descricao: modo.rotulo,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: esquema.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 6),
                  LinhaOpcao(
                    titulo: S.otimizarEstrutura,
                    descricao: S.comprimirFluxos,
                    ajuda: Ajuda.otimizarEstrutura,
                    valor: opcoes.optimizeStructure,
                    onMudar: (valor) => onMudar(
                      opcoes.copyWith(optimizeStructure: valor).personalizado(),
                    ),
                  ),
                  LinhaOpcao(
                    titulo: S.removerMetadados,
                    ajuda: Ajuda.removerMetadados,
                    valor: opcoes.removeMetadata,
                    onMudar: (valor) => onMudar(
                      opcoes.copyWith(removeMetadata: valor).personalizado(),
                    ),
                  ),
                  LinhaOpcao(
                    titulo: S.removerMiniaturas,
                    valor: opcoes.removeThumbnails,
                    onMudar: (valor) => onMudar(
                      opcoes.copyWith(removeThumbnails: valor).personalizado(),
                    ),
                  ),
                  LinhaOpcao(
                    titulo: S.removerMarcadores,
                    ajuda: Ajuda.removerMarcadores,
                    valor: opcoes.removeBookmarks,
                    onMudar: (valor) => onMudar(
                      opcoes.copyWith(removeBookmarks: valor).personalizado(),
                    ),
                  ),
                  LinhaOpcao(
                    titulo: S.removerAnotacoes,
                    ajuda: Ajuda.removerAnotacoes,
                    valor: opcoes.removeAnnotations,
                    onMudar: (valor) => onMudar(
                      opcoes.copyWith(removeAnnotations: valor).personalizado(),
                    ),
                  ),
                  LinhaOpcao(
                    titulo: 'Compatibilidade com leitores antigos',
                    descricao: 'Gera um PDF 1.4, sem fluxos de objeto',
                    ajuda:
                        'Alguns programas antigos (e certas impressoras) não '
                        'entendem PDFs modernos. Ative esta opção se o arquivo '
                        'comprimido não abrir em algum lugar — o resultado fica '
                        'um pouco maior.',
                    valor: opcoes.compatibilidadeAntiga,
                    onMudar: (valor) => onMudar(
                      opcoes
                          .copyWith(compatibilidadeAntiga: valor)
                          .personalizado(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            estado.itensValidos.isEmpty || estado.simulando
                            ? null
                            : estado.simular,
                        icon: estado.simulando
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.speed_rounded, size: 18),
                        label: Text(estado.simulando ? S.simulando : S.simular),
                      ),
                      const SizedBox(width: 8),
                      BotaoAjuda(
                        titulo: S.simulacaoTitulo,
                        texto: Ajuda.simulacao,
                      ),
                      const Spacer(),
                      if (estado.previsaoSimulada != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              S.previsaoTamanho,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            ContadorAnimado(
                              valor: estado.previsaoSimulada!,
                              formatador: Fmt.bytes,
                              estilo: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: cores.accent,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          S.previsaoIndisponivel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipMotor extends StatelessWidget {
  const _ChipMotor({
    required this.nome,
    required this.disponivel,
    required this.selecionado,
    required this.onTap,
    this.versao,
    this.onVerInstalacao,
  });

  final String nome;
  final bool disponivel;
  final bool selecionado;
  final VoidCallback onTap;
  final String? versao;

  /// Quando o motor não está instalado, oferece o passo a passo.
  final VoidCallback? onVerInstalacao;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final corEstado = disponivel ? cores.sucesso : esquema.onSurfaceVariant;

    return Tooltip(
      message: disponivel
          ? 'Disponível${versao != null ? ' • $versao' : ''}'
          : 'Não encontrado neste computador',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.escolher(context, Motion.rapida),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selecionado
                ? cores.accent.withValues(alpha: 0.14)
                : esquema.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selecionado
                  ? cores.accent
                  : esquema.outlineVariant.withValues(alpha: 0.5),
              width: selecionado ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: corEstado,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                nome,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                  color: selecionado ? cores.accent : esquema.onSurface,
                ),
              ),
              if (onVerInstalacao != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Como instalar o $nome',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onVerInstalacao,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 15,
                        color: cores.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ações usadas pelos cards de resultado.
Future<void> abrirPastaDoArquivo(String caminho) =>
    Sistema.mostrarNaPasta(caminho);

Future<void> abrirArquivoDoResultado(String caminho) => Sistema.abrir(caminho);

/// Abre o passo a passo de instalação de um motor opcional.
Future<void> mostrarComoInstalar(
  BuildContext context,
  MotorPdf motor,
  AppState estado,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => DialogoInstalarMotor(
      nome: motor.nome,
      descricao: motor.descricao,
      comandos: motor.comoInstalar,
      siteOficial: motor.siteOficial,
      disponivel: motor.disponivel,
      versao: motor.estado.versao,
      onProcurarNovamente: estado.procurarMotoresNovamente,
    ),
  );
}

/// Nota curta dentro de um cartão (explicação ou aviso).
class _NotaExplicativa extends StatelessWidget {
  const _NotaExplicativa({
    required this.texto,
    this.cor,
    this.icone = Icons.info_outline_rounded,
  });

  final String texto;
  final Color? cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final corFinal = cor ?? context.cores.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: corFinal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: corFinal.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: corFinal),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: corFinal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostra de onde até onde a busca pelo tamanho alvo pode ir.
class _FaixaDaBusca extends StatelessWidget {
  const _FaixaDaBusca({required this.opcoes});

  final CompressionOptions opcoes;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    // A faixa começa sempre na melhor qualidade do modo alvo — não no perfil,
    // que nesse modo não é usado.
    final faixa = opcoes
        .partidaDaBusca(rasterizando: opcoes.textMode == TextMode.rasterizar)
        .faixaDoAlvo;
    final comeca = '${faixa.dpiInicial} dpi / JPEG ${faixa.jpegInicial}';
    final termina = '${faixa.dpiFinal} dpi / JPEG ${faixa.jpegFinal}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              S.faixaDoAlvo,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            BotaoAjuda(titulo: S.faixaDoAlvo, texto: Ajuda.tamanhoAlvo),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _EtiquetaFaixa(texto: comeca, cor: cores.accent),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: esquema.onSurfaceVariant,
              ),
            ),
            _EtiquetaFaixa(texto: termina, cor: esquema.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'O app para no primeiro degrau que couber no alvo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EtiquetaFaixa extends StatelessWidget {
  const _EtiquetaFaixa({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }
}
