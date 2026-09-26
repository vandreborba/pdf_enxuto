import 'package:flutter/material.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/fila.dart';

/// Tela de histórico: o que já passou pelo app e quanto espaço foi economizado.
class PaginaHistorico extends StatelessWidget {
  const PaginaHistorico({super.key, required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final historico = estado.historico;

    if (historico.vazio) {
      return CartaoSecao(
        child: EstadoVazio(
          icone: Icons.history_rounded,
          titulo: S.historicoVazio,
          descricao: S.historicoVazioDica,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, restricoes) {
            final porLinha = restricoes.maxWidth > 900 ? 4 : 2;
            final espaco = 14.0;
            final largura =
                (restricoes.maxWidth - espaco * (porLinha - 1)) / porLinha;
            final cartoes = [
              _CartaoEstatistica(
                titulo: S.totalEconomizado,
                valor: historico.totalEconomizado,
                formatador: Fmt.bytes,
                icone: Icons.savings_outlined,
                cor: context.cores.sucesso,
              ),
              _CartaoEstatistica(
                titulo: S.totalProcessado,
                valor: historico.totalProcessado,
                formatador: (valor) => '$valor',
                icone: Icons.inventory_2_outlined,
                cor: context.cores.accent,
              ),
              _CartaoEstatistica(
                titulo: S.taxaMedia,
                valor: (historico.reducaoMedia * 1000).round(),
                formatador: (valor) =>
                    '${(valor / 10).toStringAsFixed(1).replaceAll('.', ',')}%',
                icone: Icons.trending_down_rounded,
                cor: context.cores.accentEscuro,
              ),
              _CartaoEstatistica(
                titulo: 'Arquivos gerados',
                valor: historico.arquivosGerados,
                formatador: (valor) => '$valor',
                icone: Icons.call_split_rounded,
                cor: context.cores.alerta,
              ),
            ];

            return Wrap(
              spacing: espaco,
              runSpacing: espaco,
              children: [
                for (var i = 0; i < cartoes.length; i++)
                  SizedBox(
                    width: largura,
                    child: FadeSlideIn(
                      atraso: Duration(milliseconds: 60 * i),
                      child: cartoes[i],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        CartaoSecao(
          titulo: S.historicoTitulo,
          subtitulo: S.historicoSubtitulo,
          icone: Icons.history_rounded,
          acao: TextButton.icon(
            onPressed: () => _confirmarLimpeza(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text(S.limparHistorico),
          ),
          child: Column(
            children: [
              for (var i = 0; i < historico.entradas.length; i++)
                _LinhaHistorico(entrada: historico.entradas[i], indice: i),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            S.privacidadeTexto,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _confirmarLimpeza(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.limparHistorico),
        content: const Text(S.limparHistoricoConfirmar),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.limpar),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await estado.historico.limpar();
    }
  }
}

class _CartaoEstatistica extends StatelessWidget {
  const _CartaoEstatistica({
    required this.titulo,
    required this.valor,
    required this.formatador,
    required this.icone,
    required this.cor,
  });

  final String titulo;
  final int valor;
  final String Function(int) formatador;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: esquema.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 17, color: cor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ContadorAnimado(
            valor: valor,
            formatador: formatador,
            estilo: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: cor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  const _LinhaHistorico({required this.entrada, required this.indice});

  final HistoryEntry entrada;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final resultado = entrada.resultado;
    final nome = resultado.entrada.split(RegExp(r'[/\\]')).last;
    final icone = switch (entrada.kind) {
      TaskKind.comprimir => Icons.compress_rounded,
      TaskKind.dividir => Icons.call_split_rounded,
      TaskKind.planilha => Icons.table_chart_outlined,
    };

    return FadeSlideIn(
      atraso: Duration(milliseconds: 18 * indice.clamp(0, 14)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icone,
              size: 20,
              color: resultado.sucesso ? cores.accent : cores.perigo,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_quando(entrada.quando)} • ${entrada.resumo}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (resultado.sucesso && resultado.saidas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ComparadorTamanho(
                      resultado: resultado,
                      mostrarReducao: entrada.kind != TaskKind.planilha,
                    ),
                  ] else if (resultado.erro != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      resultado.erro!,
                      style: TextStyle(fontSize: 12.5, color: cores.perigo),
                    ),
                  ],
                ],
              ),
            ),
            if (resultado.saidas.isNotEmpty)
              IconButton(
                tooltip: S.mostrarNoGerenciador,
                onPressed: () => Sistema.mostrarNaPasta(resultado.saidas.first),
                icon: const Icon(Icons.folder_open_rounded, size: 19),
              ),
          ],
        ),
      ),
    );
  }

  String _quando(DateTime data) {
    final diferenca = DateTime.now().difference(data);
    if (diferenca.inMinutes < 1) return 'agora mesmo';
    if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
    if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
    if (diferenca.inDays < 30) return 'há ${diferenca.inDays} dias';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }
}
