import 'package:flutter/material.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/inspecao_pdf.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/animacoes.dart';
import 'package:pdf_enxuto/widgets/base.dart';

/// Área pontilhada que convida a soltar arquivos (ou clicar para escolher).
class ZonaSoltar extends StatefulWidget {
  const ZonaSoltar({
    super.key,
    required this.onEscolher,
    this.compacta = false,
    this.destacada = false,
  });

  final VoidCallback onEscolher;
  final bool compacta;

  /// Muda de cor quando o usuário está arrastando arquivos por cima.
  final bool destacada;

  @override
  State<ZonaSoltar> createState() => _ZonaSoltarState();
}

class _ZonaSoltarState extends State<ZonaSoltar> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final ativo = widget.destacada || _sobre;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: GestureDetector(
        onTap: widget.onEscolher,
        child: AnimatedContainer(
          duration: Motion.escolher(context, Motion.media),
          curve: Motion.entrada,
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: widget.compacta ? 18 : 34,
          ),
          decoration: BoxDecoration(
            color: ativo
                ? cores.accent.withValues(alpha: 0.07)
                : esquema.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ativo
                  ? cores.accent
                  : esquema.outlineVariant.withValues(alpha: 0.7),
              width: ativo ? 2 : 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: ativo ? 1.12 : 1),
                duration: Motion.escolher(context, Motion.media),
                curve: Motion.elastica,
                builder: (context, escala, filho) =>
                    Transform.scale(scale: escala, child: filho),
                child: Icon(
                  ativo
                      ? Icons.file_download_rounded
                      : Icons.upload_file_rounded,
                  size: widget.compacta ? 26 : 38,
                  color: ativo ? cores.accent : esquema.onSurfaceVariant,
                ),
              ),
              SizedBox(height: widget.compacta ? 8 : 14),
              Text(
                ativo ? S.arrasteAqui : S.solteArquivos,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: widget.compacta ? 14 : 17,
                  color: ativo ? cores.accent : esquema.onSurface,
                ),
              ),
              if (!widget.compacta) ...[
                const SizedBox(height: 6),
                Text(
                  S.solteArquivosDica,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
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

/// Sobreposição que aparece na janela inteira durante o arrasto.
class SobreposicaoSolta extends StatelessWidget {
  const SobreposicaoSolta({
    super.key,
    required this.visivel,
    required this.quantidade,
  });

  final bool visivel;
  final int quantidade;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visivel ? 1 : 0,
        duration: Motion.escolher(context, Motion.media),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: visivel ? 1 : 0.9),
            duration: Motion.escolher(context, Motion.media),
            curve: Motion.entrada,
            builder: (context, escala, filho) =>
                Transform.scale(scale: escala, child: filho),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 38),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cores.accent, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_download_rounded,
                    size: 54,
                    color: cores.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.arrasteAqui,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    quantidade == 1
                        ? '1 arquivo será adicionado'
                        : '$quantidade arquivos serão adicionados',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card de um arquivo na fila.
class ItemDaFila extends StatelessWidget {
  const ItemDaFila({
    super.key,
    required this.item,
    required this.onRemover,
    required this.onAbrirPasta,
    required this.onAbrirArquivo,
    this.indice = 0,
  });

  final ItemFila item;
  final VoidCallback onRemover;
  final VoidCallback onAbrirPasta;
  final VoidCallback onAbrirArquivo;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final arquivo = item.arquivo;

    return FadeSlideIn(
      atraso: Duration(milliseconds: 40 * (indice.clamp(0, 8))),
      child: AnimatedContainer(
        duration: Motion.escolher(context, Motion.media),
        curve: Motion.entrada,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cores.fundoCartao,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: switch (item.status) {
              JobStatus.concluido => cores.sucesso.withValues(alpha: 0.5),
              JobStatus.falhou => cores.perigo.withValues(alpha: 0.5),
              JobStatus.processando => cores.accent.withValues(alpha: 0.6),
              _ => esquema.outlineVariant.withValues(alpha: 0.5),
            },
            width: item.status == JobStatus.processando ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Miniatura(caminho: arquivo.caminho, valido: arquivo.ok),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          arquivo.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      _Acoes(
                        item: item,
                        onRemover: onRemover,
                        onAbrirPasta: onAbrirPasta,
                        onAbrirArquivo: onAbrirArquivo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Etiqueta(
                        texto: Fmt.bytes(arquivo.bytes),
                        icone: Icons.description_outlined,
                        compacta: true,
                      ),
                      if (arquivo.paginas > 0)
                        Etiqueta(
                          texto: Fmt.paginas(arquivo.paginas),
                          icone: Icons.layers_outlined,
                          compacta: true,
                        ),
                      if (arquivo.marcadores.isNotEmpty)
                        Etiqueta(
                          texto: '${arquivo.marcadores.length} marcadores',
                          icone: Icons.bookmarks_outlined,
                          compacta: true,
                        ),
                      if (item.alvoBytes != null)
                        Etiqueta(
                          texto: 'alvo ${Fmt.bytes(item.alvoBytes!)}',
                          icone: Icons.flag_outlined,
                          cor: cores.accent,
                          compacta: true,
                        ),
                    ],
                  ),
                  if (!arquivo.ok) ...[
                    const SizedBox(height: 10),
                    _Mensagem(
                      texto: arquivo.criptografado
                          ? S.arquivoProtegido
                          : (arquivo.erro ?? S.arquivoCorrompido),
                      cor: cores.perigo,
                      icone: Icons.error_outline_rounded,
                    ),
                  ] else if (item.status == JobStatus.processando) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: BarraProgresso(
                            valor: item.progresso,
                            altura: 7,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (item.progresso >= 0)
                          Text(
                            '${(item.progresso * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: cores.accent,
                            ),
                          )
                        else
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cores.accent,
                            ),
                          ),
                      ],
                    ),
                    if (item.etapa.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.etapa,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ] else if (item.resultado != null) ...[
                    const SizedBox(height: 12),
                    ComparadorTamanho(resultado: item.resultado!),
                    if (item.resultado!.aviso != null) ...[
                      const SizedBox(height: 10),
                      _Mensagem(
                        texto: item.resultado!.aviso!,
                        cor: cores.alerta,
                        icone: Icons.info_outline_rounded,
                      ),
                    ],
                    if (item.resultado!.erro != null) ...[
                      const SizedBox(height: 10),
                      _Mensagem(
                        texto: item.resultado!.erro!,
                        cor: cores.perigo,
                        icone: Icons.error_outline_rounded,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Acoes extends StatelessWidget {
  const _Acoes({
    required this.item,
    required this.onRemover,
    required this.onAbrirPasta,
    required this.onAbrirArquivo,
  });

  final ItemFila item;
  final VoidCallback onRemover;
  final VoidCallback onAbrirPasta;
  final VoidCallback onAbrirArquivo;

  @override
  Widget build(BuildContext context) {
    final temSaida =
        item.resultado != null && item.resultado!.saidas.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (temSaida) ...[
          IconButton(
            tooltip: S.abrirPasta,
            onPressed: onAbrirPasta,
            icon: const Icon(Icons.folder_open_rounded, size: 19),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: S.abrirArquivo,
            onPressed: onAbrirArquivo,
            icon: const Icon(Icons.open_in_new_rounded, size: 19),
            visualDensity: VisualDensity.compact,
          ),
        ],
        IconButton(
          tooltip: S.remover,
          onPressed: onRemover,
          icon: const Icon(Icons.close_rounded, size: 19),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({
    required this.texto,
    required this.cor,
    required this.icone,
  });

  final String texto;
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12.5, color: cor, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Antes → depois, com barras proporcionais animadas.
class ComparadorTamanho extends StatelessWidget {
  const ComparadorTamanho({super.key, required this.resultado});

  final ItemResult resultado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final antes = resultado.bytesAntes;
    final depois = resultado.bytesDepois;
    final maior = antes > depois ? antes : depois;
    final fatorAntes = maior == 0 ? 0.0 : antes / maior;
    final fatorDepois = maior == 0 ? 0.0 : depois / maior;
    final reduziu = depois < antes && resultado.sucesso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinhaBarra(
          rotulo: 'Antes',
          valor: Fmt.bytes(antes),
          fator: fatorAntes,
          cor: esquema.onSurfaceVariant,
        ),
        const SizedBox(height: 6),
        _LinhaBarra(
          rotulo: 'Depois',
          valor: resultado.saidas.isEmpty ? 'sem alteração' : Fmt.bytes(depois),
          fator: resultado.saidas.isEmpty ? fatorAntes : fatorDepois,
          cor: reduziu ? cores.sucesso : cores.alerta,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (reduziu)
              Etiqueta(
                texto: '${Fmt.reducao(antes, depois)} menor',
                icone: Icons.trending_down_rounded,
                cor: cores.sucesso,
              ),
            if (reduziu) const SizedBox(width: 8),
            Etiqueta(
              texto: Fmt.duracao(resultado.duracao),
              icone: Icons.timer_outlined,
              compacta: true,
            ),
            if (resultado.motor != null) ...[
              const SizedBox(width: 8),
              Etiqueta(
                texto: resultado.motor!,
                icone: Icons.memory_rounded,
                compacta: true,
              ),
            ],
            if (resultado.saidas.length > 1) ...[
              const SizedBox(width: 8),
              Etiqueta(
                texto: '${resultado.saidas.length} arquivos',
                icone: Icons.call_split_rounded,
                compacta: true,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LinhaBarra extends StatelessWidget {
  const _LinhaBarra({
    required this.rotulo,
    required this.valor,
    required this.fator,
    required this.cor,
  });

  final String rotulo;
  final String valor;
  final double fator;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fator.clamp(0, 1)),
            duration: Motion.escolher(context, Motion.lenta),
            curve: Motion.saida,
            builder: (context, animado, _) => Stack(
              children: [
                Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: animado,
                  child: Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.caminho, required this.valido});

  final String caminho;
  final bool valido;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Container(
      width: 52,
      height: 70,
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esquema.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: !valido
          ? Icon(
              Icons.broken_image_outlined,
              size: 22,
              color: esquema.onSurfaceVariant,
            )
          : FutureBuilder(
              future: InspecaoPdf.miniatura(caminho, largura: 104),
              builder: (context, instantaneo) {
                final png = instantaneo.data;
                if (png == null) {
                  return AnimatedOpacity(
                    opacity:
                        instantaneo.connectionState == ConnectionState.waiting
                        ? 1
                        : 0.6,
                    duration: Motion.escolher(context, Motion.media),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 24,
                      color: cores.accent,
                    ),
                  );
                }
                return Image.memory(
                  png,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
    );
  }
}
