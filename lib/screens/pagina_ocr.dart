import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/ocr_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/services/ocr/motor_tesseract.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/fila.dart';
import 'package:pdf_enxuto/widgets/seletores.dart';

/// Tela de reconhecimento de texto (OCR): digitalização → PDF pesquisável.
class PaginaOcr extends StatelessWidget {
  const PaginaOcr({super.key, required this.estado});

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
    final cores = context.cores;
    final itens = estado.fila;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CartaoSecao(
          titulo: S.ocrArquivos,
          subtitulo: itens.isEmpty
              ? 'Nenhum arquivo na fila'
              : '${itens.length} ${itens.length == 1 ? 'arquivo' : 'arquivos'}',
          icone: Icons.document_scanner_outlined,
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
                        rotuloAntes: 'Original',
                        rotuloDepois: 'PDF novo',
                        mostrarReducao: false,
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
          titulo: S.ocrTeste,
          icone: Icons.preview_outlined,
          subtitulo: estado.itensValidos.isEmpty
              ? S.ocrTesteVazio
              : 'Baseado em "${estado.itensValidos.first.nome}"',
          acao: OutlinedButton.icon(
            onPressed:
                estado.itensValidos.isEmpty ||
                    estado.processando ||
                    estado.previaOcrCarregando ||
                    !estado.ocr.motor.disponivel
                ? null
                : estado.testarOcr,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text(S.ocrTestar),
          ),
          child: _Teste(estado: estado),
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
                        ? S.ocrReconhecendo
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
}

/// Resultado do teste na primeira página.
class _Teste extends StatelessWidget {
  const _Teste({required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final fraco = Theme.of(context).textTheme.bodySmall;

    if (estado.itensValidos.isEmpty) {
      return Text(S.ocrTesteDica, style: fraco);
    }
    if (estado.previaOcrCarregando) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cores.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(S.ocrTestando, style: fraco),
        ],
      );
    }
    if (estado.previaOcrErro != null) {
      return _Recado(
        texto: estado.previaOcrErro!,
        cor: cores.perigo,
        icone: Icons.error_outline_rounded,
      );
    }
    final previa = estado.previaOcr;
    if (previa == null) return Text(S.ocrTesteDica, style: fraco);

    if (!previa.leuAlgo) {
      return _Recado(
        texto: S.ocrTesteNada,
        cor: cores.alerta,
        icone: Icons.info_outline_rounded,
      );
    }

    final confianca = previa.confianca;
    final corConfianca = confianca == null
        ? esquema.onSurfaceVariant
        : confianca >= 85
        ? cores.sucesso
        : confianca >= 70
        ? cores.alerta
        : cores.perigo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Etiqueta(
              texto: 'Página ${previa.pagina} de ${previa.totalPaginas}',
              icone: Icons.description_outlined,
            ),
            Etiqueta(
              texto: '${previa.palavras} palavras',
              icone: Icons.notes_rounded,
            ),
            if (confianca != null)
              Etiqueta(
                texto: 'Confiança ${confianca.round()}%',
                icone: Icons.verified_outlined,
                cor: corConfianca,
              ),
          ],
        ),
        if (previa.jaTinhaTexto) ...[
          const SizedBox(height: 10),
          _Recado(
            texto: S.ocrTesteJaTinha,
            cor: cores.alerta,
            icone: Icons.info_outline_rounded,
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: esquema.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border.all(
              color: esquema.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              previa.texto,
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColunaOpcoes extends StatelessWidget {
  const _ColunaOpcoes({required this.estado});

  final AppState estado;

  OpcoesOcr get opcoes => estado.opcoesOcr;

  Future<void> _mudar(OpcoesOcr novas) => estado.atualizarOcr(novas);

  /// Liga ou desliga um idioma, sempre deixando pelo menos um marcado.
  void _alternarIdioma(String codigo) {
    final atuais = [...opcoes.idiomas];
    if (atuais.contains(codigo)) {
      if (atuais.length == 1) return;
      atuais.remove(codigo);
    } else {
      atuais.add(codigo);
    }
    // Mantém a ordem da lista oficial: o primeiro idioma pesa mais.
    atuais.sort(
      (a, b) => IdiomaOcr.todos
          .indexWhere((i) => i.codigo == a)
          .compareTo(IdiomaOcr.todos.indexWhere((i) => i.codigo == b)),
    );
    _mudar(opcoes.copyWith(idiomas: atuais));
  }

  /// Marcar PDF e texto: se o usuário desliga o último, liga o outro.
  void _saida({bool? pdf, bool? txt}) {
    var gerarPdf = pdf ?? opcoes.gerarPdf;
    var gerarTxt = txt ?? opcoes.gerarTxt;
    if (!gerarPdf && !gerarTxt) {
      if (pdf == false) gerarTxt = true;
      if (txt == false) gerarPdf = true;
    }
    _mudar(opcoes.copyWith(gerarPdf: gerarPdf, gerarTxt: gerarTxt));
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final motor = estado.ocr.motor;
    final instalados = motor.estado.idiomas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoMotor(estado: estado),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.ocrIdiomas,
          icone: Icons.translate_rounded,
          ajuda: Ajuda.ocrIdiomas,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final idioma in IdiomaOcr.todos)
                Tooltip(
                  message: instalados.contains(idioma.codigo)
                      ? ''
                      : S.ocrIdiomaIndisponivel,
                  child: Opacity(
                    opacity: instalados.contains(idioma.codigo) ? 1 : 0.4,
                    child: AtalhoTexto(
                      rotulo: idioma.nome,
                      selecionado: opcoes.idiomas.contains(idioma.codigo),
                      onTap: instalados.contains(idioma.codigo)
                          ? () => _alternarIdioma(idioma.codigo)
                          : () {},
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.ocrSaida,
          icone: Icons.output_rounded,
          ajuda: Ajuda.ocrSaida,
          child: Column(
            children: [
              LinhaOpcao(
                titulo: 'PDF pesquisável',
                descricao: 'Igual ao original, com texto para buscar e copiar',
                valor: opcoes.gerarPdf,
                onMudar: (valor) => _saida(pdf: valor),
              ),
              LinhaOpcao(
                titulo: 'Texto (.txt)',
                descricao: 'Só o texto reconhecido',
                valor: opcoes.gerarTxt,
                onMudar: (valor) => _saida(txt: valor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.ocrQualidade,
          icone: Icons.speed_rounded,
          ajuda: Ajuda.ocrQualidade,
          subtitulo: opcoes.qualidade.descricao,
          child: SeletorSegmentado<QualidadeOcr>(
            valor: opcoes.qualidade,
            onMudar: (valor) => _mudar(opcoes.copyWith(qualidade: valor)),
            opcoes: [
              for (final qualidade in QualidadeOcr.values)
                OpcaoSegmento(
                  valor: qualidade,
                  rotulo: qualidade.rotulo,
                  descricao: '${qualidade.dpi} dpi',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.ocrTipoPagina,
          icone: Icons.view_agenda_outlined,
          ajuda: Ajuda.ocrTipoPagina,
          subtitulo: opcoes.tipoPagina.descricao,
          child: SeletorSegmentado<TipoPaginaOcr>(
            valor: opcoes.tipoPagina,
            onMudar: (valor) => _mudar(opcoes.copyWith(tipoPagina: valor)),
            opcoes: [
              for (final tipo in TipoPaginaOcr.values)
                OpcaoSegmento(valor: tipo, rotulo: tipo.rotulo),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Aparecer(
          visivel: opcoes.gerarPdf,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CartaoSecao(
              titulo: S.ocrImagem,
              icone: Icons.image_outlined,
              ajuda: Ajuda.ocrImagem,
              subtitulo: opcoes.qualidadeImagem.descricao,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SeletorSegmentado<QualidadeImagemOcr>(
                    valor: opcoes.qualidadeImagem,
                    onMudar: (valor) =>
                        _mudar(opcoes.copyWith(qualidadeImagem: valor)),
                    opcoes: [
                      for (final qualidade in QualidadeImagemOcr.values)
                        OpcaoSegmento(
                          valor: qualidade,
                          rotulo: qualidade.rotulo,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SeletorSegmentado<ColorMode>(
                    valor: opcoes.cor,
                    onMudar: (valor) => _mudar(opcoes.copyWith(cor: valor)),
                    opcoes: [
                      for (final cor in ColorMode.values)
                        OpcaoSegmento(
                          valor: cor,
                          rotulo: switch (cor) {
                            ColorMode.manter => 'Colorido',
                            ColorMode.cinza => 'Tons de cinza',
                            ColorMode.mono => 'Preto e branco',
                          },
                          descricao: cor.rotulo,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        CartaoSecao(
          titulo: S.ocrPaginas,
          icone: Icons.tag_rounded,
          ajuda: Ajuda.ocrPaginas,
          child: _CampoPaginas(
            valor: opcoes.paginas,
            onMudar: (valor) => _mudar(opcoes.copyWith(paginas: valor)),
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.ocrOpcoes,
          icone: Icons.tune_rounded,
          child: LinhaOpcao(
            titulo: S.ocrRefazer,
            descricao: 'Para PDFs cujo texto embutido está errado',
            valor: opcoes.refazerComTexto,
            ajuda: Ajuda.ocrRefazer,
            onMudar: (valor) => _mudar(opcoes.copyWith(refazerComTexto: valor)),
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.ocrOndeSalvar,
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
                  'O PDF novo recebe o final "_ocr"; o original não muda.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mostra de onde vem o Tesseract e, se faltar, como instalar.
class _CartaoMotor extends StatelessWidget {
  const _CartaoMotor({required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final motor = estado.ocr.motor;
    final situacao = motor.estado;

    if (motor.disponivel) {
      return CartaoSecao(
        titulo: S.ocrMotor,
        icone: Icons.memory_rounded,
        ajuda: Ajuda.ocrMotor,
        subtitulo:
            'Tesseract${situacao.versao == null ? '' : ' ${situacao.versao}'}'
            '${situacao.embutido ? ' • embutido no app' : ' • instalado no sistema'}',
        child: Text(
          'Tudo roda no seu computador. ${situacao.idiomas.length} '
          '${situacao.idiomas.length == 1 ? 'idioma disponível' : 'idiomas disponíveis'}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return CartaoSecao(
      titulo: S.ocrMotor,
      icone: Icons.memory_rounded,
      ajuda: Ajuda.ocrMotor,
      destaque: true,
      acao: TextButton.icon(
        onPressed: estado.procurarMotoresNovamente,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Procurar novamente'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Recado(
            texto: S.ocrMotorIndisponivel,
            cor: cores.alerta,
            icone: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 12),
          SelectableText(
            motor.comoInstalar,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
          if (situacao.erro != null) ...[
            const SizedBox(height: 8),
            Text(
              'Detalhe: ${situacao.erro}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => Sistema.abrir(MotorTesseract.siteOficial),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Site do Tesseract'),
          ),
        ],
      ),
    );
  }
}

/// Campo de páginas com validação ao digitar.
class _CampoPaginas extends StatefulWidget {
  const _CampoPaginas({required this.valor, required this.onMudar});

  final String valor;
  final ValueChanged<String> onMudar;

  @override
  State<_CampoPaginas> createState() => _CampoPaginasState();
}

class _CampoPaginasState extends State<_CampoPaginas> {
  late final TextEditingController _controlador = TextEditingController(
    text: widget.valor,
  );

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leitura = PageRangeParser.parse(widget.valor);
    return TextField(
      controller: _controlador,
      onChanged: widget.onMudar,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
      decoration: InputDecoration(
        hintText: S.ocrPaginasDica,
        errorText: leitura.erros.isEmpty ? null : leitura.erros.first,
        prefixIcon: const Icon(Icons.tag_rounded, size: 18),
      ),
    );
  }
}

class _Recado extends StatelessWidget {
  const _Recado({required this.texto, required this.cor, required this.icone});

  final String texto;
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12.5, color: cor, height: 1.4),
          ),
        ),
      ],
    );
  }
}
