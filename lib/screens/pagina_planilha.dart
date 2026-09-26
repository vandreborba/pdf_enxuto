import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/planilha_options.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/fila.dart';
import 'package:pdf_enxuto/widgets/seletores.dart';

/// Tela de conversão de PDF em planilha (XLSX) ou CSV.
class PaginaPlanilha extends StatelessWidget {
  const PaginaPlanilha({super.key, required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    // Ao abrir a tela, garante que a prévia esteja atualizada (o usuário pode
    // ter adicionado arquivos estando em outra aba).
    if (estado.itensValidos.isNotEmpty &&
        estado.previaPlanilha == null &&
        estado.previaPlanilhaErro == null &&
        !estado.previaPlanilhaCarregando) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        estado.atualizarPreviaPlanilha();
      });
    }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CartaoSecao(
          titulo: S.planilhaArquivos,
          subtitulo: itens.isEmpty
              ? 'Nenhum arquivo na fila'
              : '${itens.length} ${itens.length == 1 ? 'arquivo' : 'arquivos'}',
          icone: Icons.table_chart_outlined,
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
                        rotuloAntes: 'PDF',
                        rotuloDepois: 'Planilha',
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
          titulo: S.planilhaPrevia,
          icone: Icons.preview_outlined,
          ajuda: Ajuda.planilhaModo,
          subtitulo: estado.itensValidos.isEmpty
              ? S.planilhaPreviaVazio
              : 'Baseado em "${estado.itensValidos.first.nome}"',
          child: _Previa(estado: estado),
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
                        ? S.planilhaConvertendo
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
        if (esquema.brightness == Brightness.dark) const SizedBox(height: 2),
      ],
    );
  }
}

/// Pré-visualização do que o app encontrou nas primeiras páginas.
class _Previa extends StatelessWidget {
  const _Previa({required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    if (estado.itensValidos.isEmpty) {
      return Text(
        S.planilhaPreviaDica,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (estado.previaPlanilhaCarregando) {
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
          Text(
            S.planilhaPreviaLendo,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    final erro = estado.previaPlanilhaErro;
    if (erro != null) {
      return _Recado(
        texto: erro,
        cor: cores.perigo,
        icone: Icons.error_outline_rounded,
      );
    }

    final previa = estado.previaPlanilha;
    if (previa == null) {
      return Text(
        S.planilhaPreviaDica,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    if (previa.soImagem) {
      return _Recado(
        texto: S.planilhaPreviaDigitalizada,
        cor: cores.alerta,
        icone: Icons.image_outlined,
        ajuda: Ajuda.planilhaDigitalizada,
      );
    }

    if (!previa.temTabela) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Recado(
            texto: S.planilhaPreviaNada,
            cor: cores.alerta,
            icone: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 10),
          Text(
            '${previa.paginasLidas} de ${previa.totalPaginas} '
            '${previa.totalPaginas == 1 ? 'página lida' : 'páginas lidas'} '
            'para a prévia.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    final primeira = previa.tabelas.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cores.sucesso.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  '${previa.tabelas.length}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: cores.sucesso,
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
                    '${previa.tabelas.length} ${S.planilhaPreviaResumo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${previa.totalLinhas} ${S.planilhaPreviaLinhas} • '
                    'primeira: ${primeira.colunas} '
                    '${S.planilhaPreviaColunas} × ${primeira.linhasUteis} '
                    '${S.planilhaPreviaLinhas} • '
                    '${S.planilhaPreviaPagina.replaceFirst('%d', '${primeira.pagina}')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Grade(linhas: primeira.linhas),
        const SizedBox(height: 10),
        Text(
          'Prévia das ${previa.paginasLidas} primeiras '
          '${previa.paginasLidas == 1 ? 'página' : 'páginas'} de '
          '${previa.totalPaginas}. O arquivo completo pode ter mais tabelas.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Desenho da tabela detectada, com o mesmo alinhamento que sai na planilha.
class _Grade extends StatelessWidget {
  const _Grade({required this.linhas});

  final List<List<String>> linhas;

  static const int maxLinhas = 6;
  static const int maxColunas = 5;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final linhasVisiveis = linhas.take(maxLinhas).toList();
    if (linhasVisiveis.isEmpty) return const SizedBox.shrink();

    final colunas = linhasVisiveis
        .map((linha) => linha.length)
        .reduce((a, b) => a > b ? a : b);
    final visiveis = colunas > maxColunas ? maxColunas : colunas;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esquema.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < linhasVisiveis.length; i++)
            Container(
              decoration: BoxDecoration(
                color: i == 0
                    ? cores.accent.withValues(alpha: 0.07)
                    : Colors.transparent,
                border: i == 0
                    ? null
                    : Border(
                        top: BorderSide(
                          color: esquema.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  for (var c = 0; c < visiveis; c++)
                    Expanded(
                      child: Text(
                        c < linhasVisiveis[i].length
                            ? linhasVisiveis[i][c]
                            : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: i == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == 0 ? cores.accent : esquema.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (linhas.length > maxLinhas || colunas > maxColunas)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                [
                  if (linhas.length > maxLinhas)
                    'mais ${linhas.length - maxLinhas} linhas',
                  if (colunas > maxColunas)
                    'mais ${colunas - maxColunas} colunas',
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _Recado extends StatelessWidget {
  const _Recado({
    required this.texto,
    required this.cor,
    required this.icone,
    this.ajuda,
  });

  final String texto;
  final Color cor;
  final IconData icone;
  final String? ajuda;

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
        if (ajuda != null) ...[
          const SizedBox(width: 6),
          BotaoAjuda(titulo: S.planilhaPrevia, texto: ajuda!, tamanho: 18),
        ],
      ],
    );
  }
}

class _ColunaOpcoes extends StatelessWidget {
  const _ColunaOpcoes({required this.estado});

  final AppState estado;

  OpcoesPlanilha get opcoes => estado.opcoesPlanilha;

  Future<void> _mudar(OpcoesPlanilha novas) => estado.atualizarPlanilha(novas);

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CartaoSecao(
          titulo: S.planilhaFormato,
          icone: Icons.grid_on_rounded,
          ajuda: Ajuda.planilhaFormato,
          subtitulo: opcoes.formato.descricao,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SeletorSegmentado<FormatoPlanilha>(
                valor: opcoes.formato,
                onMudar: (valor) => _mudar(opcoes.copyWith(formato: valor)),
                opcoes: [
                  for (final formato in FormatoPlanilha.values)
                    OpcaoSegmento(
                      valor: formato,
                      rotulo: formato.rotuloCurto,
                      icone: formato == FormatoPlanilha.xlsx
                          ? Icons.table_chart_outlined
                          : Icons.text_snippet_outlined,
                      descricao: formato.descricao,
                    ),
                ],
              ),
              Aparecer(
                visivel: opcoes.formato == FormatoPlanilha.csv,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Rotulo(
                        texto: S.planilhaSeparador,
                        ajuda: Ajuda.planilhaSeparador,
                      ),
                      const SizedBox(height: 8),
                      SeletorSegmentado<bool>(
                        valor: opcoes.separadorPontoVirgula,
                        onMudar: (valor) => _mudar(
                          opcoes.copyWith(separadorPontoVirgula: valor),
                        ),
                        opcoes: const [
                          OpcaoSegmento(
                            valor: true,
                            rotulo: S.planilhaSeparadorPontoVirgula,
                            descricao: 'Padrão do Excel em português',
                          ),
                          OpcaoSegmento(
                            valor: false,
                            rotulo: S.planilhaSeparadorVirgula,
                            descricao: 'Padrão internacional',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.planilhaModoLeitura,
          icone: Icons.find_in_page_outlined,
          ajuda: Ajuda.planilhaModo,
          child: SeletorSegmentado<ModoPlanilha>(
            valor: opcoes.modo,
            onMudar: (valor) => _mudar(opcoes.copyWith(modo: valor)),
            opcoes: [
              for (final modo in ModoPlanilha.values)
                OpcaoSegmento(
                  valor: modo,
                  rotulo: modo.rotulo,
                  descricao: modo.descricao,
                  icone: modo == ModoPlanilha.tabelas
                      ? Icons.table_rows_outlined
                      : Icons.notes_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Aparecer(
          visivel: opcoes.modo == ModoPlanilha.tabelas,
          child: CartaoSecao(
            titulo: S.planilhaSeparacao,
            icone: Icons.vertical_split_outlined,
            ajuda: Ajuda.planilhaColunas,
            subtitulo: opcoes.sensibilidade.rotulo,
            child: SeletorSegmentado<SensibilidadeColunas>(
              valor: opcoes.sensibilidade,
              onMudar: (valor) => _mudar(opcoes.copyWith(sensibilidade: valor)),
              opcoes: [
                for (final sensibilidade in SensibilidadeColunas.values)
                  OpcaoSegmento(
                    valor: sensibilidade,
                    rotulo: sensibilidade.rotuloCurto,
                    descricao: sensibilidade.rotulo,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.planilhaOrganizacao,
          icone: Icons.layers_outlined,
          ajuda: Ajuda.planilhaEscopo,
          child: SeletorSegmentado<EscopoPlanilha>(
            valor: opcoes.escopo,
            onMudar: (valor) => _mudar(opcoes.copyWith(escopo: valor)),
            opcoes: [
              for (final escopo in EscopoPlanilha.values)
                OpcaoSegmento(
                  valor: escopo,
                  rotulo: escopo.rotuloCurto,
                  descricao: escopo.descricao,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.planilhaOpcoes,
          icone: Icons.tune_rounded,
          child: Column(
            children: [
              LinhaOpcao(
                titulo: S.planilhaCabecalho,
                descricao: 'Negrito e presa no topo da planilha',
                valor: opcoes.primeiraLinhaCabecalho,
                ajuda: Ajuda.planilhaCabecalho,
                onMudar: (valor) =>
                    _mudar(opcoes.copyWith(primeiraLinhaCabecalho: valor)),
              ),
              LinhaOpcao(
                titulo: S.planilhaIgnorarCabecalho,
                descricao: '"Página 3 de 23" e o nome da empresa, por exemplo',
                valor: opcoes.ignorarCabecalhoRodape,
                ajuda: Ajuda.planilhaIgnorarCabecalho,
                onMudar: (valor) =>
                    _mudar(opcoes.copyWith(ignorarCabecalhoRodape: valor)),
              ),
              LinhaOpcao(
                titulo: S.planilhaProteger,
                descricao: 'Só afeta o CSV',
                valor: opcoes.protegerFormulas,
                ajuda: Ajuda.planilhaProteger,
                desabilitado: opcoes.formato != FormatoPlanilha.csv,
                onMudar: (valor) =>
                    _mudar(opcoes.copyWith(protegerFormulas: valor)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoSecao(
          titulo: S.planilhaOndeSalvar,
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
                  S.planilhaAvisoXlsx,
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

class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.texto, this.ajuda});

  final String texto;
  final String? ajuda;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        if (ajuda != null) ...[
          const SizedBox(width: 4),
          BotaoAjuda(titulo: texto, texto: ajuda!, tamanho: 17),
        ],
      ],
    );
  }
}
