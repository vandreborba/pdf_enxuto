import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/servico_divisao.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/fila.dart';
import 'package:pdf_enxuto/widgets/seletores.dart';

/// Tela de divisão de PDF.
class PaginaDividir extends StatelessWidget {
  const PaginaDividir({super.key, required this.estado});

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
    final plano = estado.planoDivisaoPreview();

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
          child: itens.isEmpty
              ? ZonaSoltar(onEscolher: _escolher)
              : Column(
                  children: [
                    ZonaSoltar(onEscolher: _escolher, compacta: true),
                    const SizedBox(height: 16),
                    for (var indice = 0; indice < itens.length; indice++)
                      ItemDaFila(
                        item: itens[indice],
                        indice: indice,
                        onRemover: () =>
                            estado.removerItem(itens[indice].chave),
                        onAbrirPasta: () {
                          final saidas =
                              itens[indice].resultado?.saidas ?? const [];
                          if (saidas.isNotEmpty) {
                            Sistema.mostrarNaPasta(saidas.first);
                          }
                        },
                        onAbrirArquivo: () {
                          final saidas =
                              itens[indice].resultado?.saidas ?? const [];
                          if (saidas.isNotEmpty) {
                            Sistema.abrir(saidas.first);
                          }
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.previsaoPartes,
          icone: Icons.preview_outlined,
          ajuda: Ajuda.previsao,
          subtitulo: estado.itensValidos.isEmpty
              ? 'Adicione um PDF para ver como ficaria a divisão'
              : 'Baseado em "${estado.itensValidos.first.nome}"',
          child: estado.itensValidos.isEmpty
              ? Text(
                  'A prévia mostra quantas partes serão criadas e quais '
                  'páginas entram em cada uma.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : _PreviaPlano(plano: plano),
        ),
        if (plano != null && plano.partes.isNotEmpty) ...[
          const SizedBox(height: 16),
          CartaoSecao(
            titulo: 'Partes que serão geradas',
            icone: Icons.call_split_rounded,
            child: Column(
              children: [
                for (var indice = 0; indice < plano.partes.length; indice++)
                  _LinhaParte(parte: plano.partes[indice], indice: indice),
              ],
            ),
          ),
        ],
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
                    estado.etapaGeral.isEmpty ? S.dividindo : estado.etapaGeral,
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
        if (esquema.brightness == Brightness.dark) const SizedBox(height: 2),
      ],
    );
  }
}

class _PreviaPlano extends StatelessWidget {
  const _PreviaPlano({required this.plano});

  final PlanoDivisao? plano;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    if (plano == null) {
      return const SizedBox.shrink();
    }

    final valido = plano!.valido;
    final cor = valido ? cores.sucesso : cores.alerta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  '${plano!.partes.length}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: cor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plano!.partes.length} ${S.partesPrevistas}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valido
                        ? 'Total aproximado: ${Fmt.bytes(plano!.totalBytes)}'
                        : 'Ajuste as opções para continuar',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        for (final erro in plano!.erros)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Aviso(
              texto: erro,
              cor: cores.perigo,
              icone: Icons.error_outline_rounded,
            ),
          ),
        for (final aviso in plano!.avisos)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Aviso(
              texto: aviso,
              cor: cores.alerta,
              icone: Icons.info_outline_rounded,
            ),
          ),
      ],
    );
  }
}

class _LinhaParte extends StatelessWidget {
  const _LinhaParte({required this.parte, required this.indice});

  final SplitPart parte;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return FadeSlideIn(
      atraso: Duration(milliseconds: 25 * indice.clamp(0, 10)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cores.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${parte.indice}',
                  style: TextStyle(
                    color: cores.sobreAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parte.intervalos.length == 1
                        ? 'Páginas ${parte.rotuloPaginas}'
                        : '${parte.paginas} páginas',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    parte.nomeSugerido.split(RegExp(r'[/\\]')).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Etiqueta(
              texto: '≈ ${Fmt.bytes(parte.bytesEstimados)}',
              compacta: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.cor, required this.icone});

  final String texto;
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12.5, color: cor, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _ColunaOpcoes extends StatelessWidget {
  const _ColunaOpcoes({required this.estado});

  final AppState estado;

  SplitOptions get opcoes => estado.opcoesDivisao;

  Future<void> _mudar(SplitOptions novas) => estado.atualizarDivisao(novas);

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final totalPaginas = estado.itensValidos.isEmpty
        ? null
        : estado.itensValidos.first.arquivo.paginas;

    final leitura = opcoes.metodo == SplitMethod.extrair
        ? PageRangeParser.parse(opcoes.extrairTexto, totalPaginas: totalPaginas)
        : PageRangeParser.parse(
            opcoes.intervalosTexto,
            totalPaginas: totalPaginas,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CartaoSecao(
          titulo: S.metodoDivisao,
          icone: Icons.content_cut_rounded,
          ajuda: Ajuda.divisaoMetodo,
          child: Column(
            children: [
              for (final metodo in SplitMethod.values)
                _OpcaoMetodo(
                  metodo: metodo,
                  selecionado: opcoes.metodo == metodo,
                  onTap: () => _mudar(opcoes.copyWith(metodo: metodo)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetalhesDoMetodo(
          child: CartaoSecao(
            titulo: 'Detalhes do método',
            icone: Icons.tune_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (opcoes.metodo == SplitMethod.intervalos) ...[
                  CampoIntervalos(
                    valor: opcoes.intervalosTexto,
                    onMudar: (texto) =>
                        _mudar(opcoes.copyWith(intervalosTexto: texto)),
                    rotulo: S.intervalosLabel,
                    dica: S.intervalosDica,
                    ajuda: Ajuda.intervalos,
                    totalPaginas: totalPaginas,
                    erro: leitura.erros.isEmpty ? null : leitura.erros.first,
                    aviso: leitura.aviso,
                  ),
                  const SizedBox(height: 12),
                  LinhaOpcao(
                    titulo: 'Juntar tudo em um arquivo',
                    descricao: 'Os intervalos viram um único PDF',
                    valor: opcoes.umArquivoSo,
                    onMudar: (valor) =>
                        _mudar(opcoes.copyWith(umArquivoSo: valor)),
                  ),
                ],
                if (opcoes.metodo == SplitMethod.cadaN) ...[
                  LinhaSlider(
                    titulo: S.cadaNLabel,
                    valor: opcoes.paginasPorParte.toDouble(),
                    minimo: 1,
                    maximo: 100,
                    formatar: (valor) => '${valor.round()}',
                    ajuda:
                        'Cada parte terá exatamente esta quantidade de páginas '
                        '(a última pode ter menos).',
                    onMudar: (valor) =>
                        _mudar(opcoes.copyWith(paginasPorParte: valor.round())),
                  ),
                  const SizedBox(height: 8),
                  LinhaOpcao(
                    titulo: S.separarCadaPagina,
                    descricao: 'Um arquivo para cada página',
                    valor: opcoes.umaPaginaPorArquivo,
                    onMudar: (valor) =>
                        _mudar(opcoes.copyWith(umaPaginaPorArquivo: valor)),
                  ),
                ],
                if (opcoes.metodo == SplitMethod.porTamanho) ...[
                  CampoTamanho(
                    bytes: opcoes.maxBytes,
                    rotulo: S.tamanhoMaximoLabel,
                    ajuda: Ajuda.tamanhoMaximo,
                    onMudar: (bytes) =>
                        _mudar(opcoes.copyWith(maxBytes: bytes)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'O app confere o tamanho real de cada parte e divide de novo '
                    'o que passar do limite.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (opcoes.metodo == SplitMethod.extrair) ...[
                  CampoIntervalos(
                    valor: opcoes.extrairTexto,
                    onMudar: (texto) =>
                        _mudar(opcoes.copyWith(extrairTexto: texto)),
                    rotulo: S.extrairLabel,
                    dica: S.extrairDica,
                    ajuda: Ajuda.intervalos,
                    totalPaginas: totalPaginas,
                    erro: leitura.erros.isEmpty ? null : leitura.erros.first,
                  ),
                  const SizedBox(height: 8),
                  LinhaOpcao(
                    titulo: 'Gerar um arquivo por intervalo',
                    descricao: 'Desligado: tudo vira um único PDF novo',
                    valor: !opcoes.umArquivoSo,
                    onMudar: (valor) =>
                        _mudar(opcoes.copyWith(umArquivoSo: !valor)),
                  ),
                ],
                if (opcoes.metodo == SplitMethod.marcadores) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.bookmarks_outlined,
                        size: 18,
                        color: cores.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          estado.itensValidos.isEmpty
                              ? 'Adicione um PDF que tenha sumário'
                              : '${estado.itensValidos.first.arquivo.marcadores.length} '
                                    '${S.marcadoresEncontrados}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cada capítulo do sumário vira um arquivo. Os marcadores de '
                    'primeiro nível definem os cortes.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.nomeDosArquivos,
          icone: Icons.drive_file_rename_outline_rounded,
          ajuda: Ajuda.nomePadrao,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CampoNomePadrao(
                valor: opcoes.padraoNome,
                onMudar: (texto) => _mudar(opcoes.copyWith(padraoNome: texto)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variavel in const [
                    '{nome}',
                    '{parte}',
                    '{inicio}',
                    '{fim}',
                    '{paginas}',
                  ])
                    Etiqueta(
                      texto: variavel,
                      icone: Icons.data_object_rounded,
                      compacta: true,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${S.exemploNome}: ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Text(
                      _exemplo(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: cores.accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinhaOpcao(
                titulo: S.marcarPartes,
                valor: opcoes.incluirNumeroParte,
                onMudar: (valor) =>
                    _mudar(opcoes.copyWith(incluirNumeroParte: valor)),
              ),
            ],
          ),
        ),
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
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: esquema.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'A divisão não altera a qualidade: as páginas são copiadas '
                  'como estão.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _exemplo() {
    final plano = estado.planoDivisaoPreview();
    if (plano != null && plano.partes.isNotEmpty) {
      final parte = plano.partes.length > 1 ? plano.partes[1] : plano.partes[0];
      return parte.nomeSugerido.split(RegExp(r'[/\\]')).last;
    }
    return 'relatorio - parte 2.pdf';
  }
}

class _OpcaoMetodo extends StatelessWidget {
  const _OpcaoMetodo({
    required this.metodo,
    required this.selecionado,
    required this.onTap,
  });

  final SplitMethod metodo;
  final bool selecionado;
  final VoidCallback onTap;

  static const Map<SplitMethod, (IconData, String)> _detalhes = {
    SplitMethod.intervalos: (
      Icons.tag_rounded,
      'Você escreve os pedaços: "1-3, 7, 10-12"',
    ),
    SplitMethod.cadaN: (
      Icons.view_module_outlined,
      'Partes iguais e automáticas',
    ),
    SplitMethod.porTamanho: (
      Icons.straighten_rounded,
      'Nenhuma parte passa do limite',
    ),
    SplitMethod.extrair: (
      Icons.filter_alt_outlined,
      'Junta páginas escolhidas em um PDF novo',
    ),
    SplitMethod.marcadores: (
      Icons.bookmarks_outlined,
      'Um arquivo por capítulo do sumário',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final detalhe = _detalhes[metodo]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.escolher(context, Motion.media),
          curve: Motion.entrada,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selecionado
                ? cores.accent.withValues(alpha: 0.11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionado
                  ? cores.accent.withValues(alpha: 0.7)
                  : esquema.outlineVariant.withValues(alpha: 0.4),
              width: selecionado ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.escolher(context, Motion.media),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selecionado
                      ? cores.accent
                      : esquema.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  detalhe.$1,
                  size: 18,
                  color: selecionado
                      ? cores.sobreAccent
                      : esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metodo.rotulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: selecionado ? cores.accent : esquema.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalhe.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: selecionado ? 1 : 0,
                duration: Motion.escolher(context, Motion.media),
                curve: Motion.elastica,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: cores.accent,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo do padrão de nome — mantém o cursor no lugar enquanto se digita.
class _CampoNomePadrao extends StatefulWidget {
  const _CampoNomePadrao({required this.valor, required this.onMudar});

  final String valor;
  final ValueChanged<String> onMudar;

  @override
  State<_CampoNomePadrao> createState() => _CampoNomePadraoState();
}

class _CampoNomePadraoState extends State<_CampoNomePadrao> {
  late final TextEditingController _controlador = TextEditingController(
    text: widget.valor,
  );

  @override
  void didUpdateWidget(covariant _CampoNomePadrao antigo) {
    super.didUpdateWidget(antigo);
    if (widget.valor != _controlador.text) {
      _controlador.value = TextEditingValue(
        text: widget.valor,
        selection: TextSelection.collapsed(offset: widget.valor.length),
      );
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controlador,
      onChanged: widget.onMudar,
      decoration: const InputDecoration(
        labelText: S.padraoNome,
        hintText: '{nome} - parte {parte}',
      ),
    );
  }
}

/// Envolve o cartão de detalhes do método.
///
/// É de propósito um wrapper simples: animar o tamanho aqui dispara o erro
/// "RenderAnimatedSize was mutated" quando o conteúdo troca de método.
class _DetalhesDoMetodo extends StatelessWidget {
  const _DetalhesDoMetodo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
