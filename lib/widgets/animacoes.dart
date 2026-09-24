import 'package:flutter/material.dart';

import 'package:pdf_enxuto/theme/app_theme.dart';

/// Fundo do app: cor lisa, sem degradê e sem enfeites.
///
/// A personalidade vem da cor de destaque escolhida nas configurações, usada
/// com parcimônia — nada de manchas coloridas atrás do conteúdo.
class FundoAnimado extends StatelessWidget {
  const FundoAnimado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.cores.fundo, child: child);
  }
}

/// Barra de progresso com brilho deslizante quando indeterminada.
class BarraProgresso extends StatelessWidget {
  const BarraProgresso({
    super.key,
    required this.valor,
    this.altura = 8,
    this.cor,
    this.animada = true,
  });

  /// 0 a 1. Valor negativo = indeterminado.
  final double valor;
  final double altura;
  final Color? cor;
  final bool animada;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final corFinal = cor ?? cores.accent;

    if (valor < 0 || !animada) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(altura),
        child: SizedBox(
          height: altura,
          child: LinearProgressIndicator(
            value: valor < 0 ? null : valor.clamp(0, 1),
            backgroundColor: esquema.outlineVariant.withValues(alpha: 0.35),
            valueColor: AlwaysStoppedAnimation<Color>(corFinal),
            minHeight: altura,
          ),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.clamp(0, 1)),
      duration: Motion.escolher(context, Motion.media),
      curve: Motion.saida,
      builder: (context, animado, _) => ClipRRect(
        borderRadius: BorderRadius.circular(altura),
        child: Stack(
          children: [
            Container(
              height: altura,
              color: esquema.outlineVariant.withValues(alpha: 0.35),
            ),
            FractionallySizedBox(
              widthFactor: animado.clamp(0.0, 1.0),
              child: Container(height: altura, color: corFinal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anel de progresso com porcentagem no centro.
class AnelProgresso extends StatelessWidget {
  const AnelProgresso({
    super.key,
    required this.valor,
    this.tamanho = 56,
    this.espessura = 5,
    this.cor,
    this.rotulo,
  });

  final double valor;
  final double tamanho;
  final double espessura;
  final Color? cor;
  final String? rotulo;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final corFinal = cor ?? cores.accent;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.clamp(0, 1)),
      duration: Motion.escolher(context, Motion.media),
      curve: Motion.saida,
      builder: (context, animado, _) => SizedBox(
        width: tamanho,
        height: tamanho,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: animado,
              strokeWidth: espessura,
              backgroundColor: esquema.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(corFinal),
              strokeCap: StrokeCap.round,
            ),
            if (rotulo case final texto?)
              Text(
                texto,
                style: TextStyle(
                  fontSize: tamanho * 0.26,
                  fontWeight: FontWeight.w700,
                  color: corFinal,
                ),
              )
            else
              Text(
                '${(animado * 100).round()}%',
                style: TextStyle(
                  fontSize: tamanho * 0.26,
                  fontWeight: FontWeight.w700,
                  color: corFinal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Realce que passa por cima de um conteúdo enquanto algo carrega.
class BrilhoCarregando extends StatefulWidget {
  const BrilhoCarregando({super.key, required this.child, this.ativo = true});

  final Widget child;
  final bool ativo;

  @override
  State<BrilhoCarregando> createState() => _BrilhoCarregandoState();
}

class _BrilhoCarregandoState extends State<BrilhoCarregando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ativo) _controle.repeat();
  }

  @override
  void didUpdateWidget(covariant BrilhoCarregando antigo) {
    super.didUpdateWidget(antigo);
    if (widget.ativo && !_controle.isAnimating) {
      _controle.repeat();
    } else if (!widget.ativo && _controle.isAnimating) {
      _controle.stop();
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ativo) return widget.child;

    // Pulsa a opacidade em vez de passar um brilho: discreto e suficiente
    // para indicar que algo está acontecendo.
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1,
      ).animate(CurvedAnimation(parent: _controle, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Transição padrão entre páginas do app.
class TransicaoSuave extends StatelessWidget {
  const TransicaoSuave({super.key, required this.child, required this.chave});

  final Widget child;
  final String chave;

  @override
  Widget build(BuildContext context) {
    final duracao = Motion.escolher(context, Motion.media);

    return AnimatedSwitcher(
      duration: duracao,
      switchInCurve: Motion.entrada,
      switchOutCurve: Motion.saida,
      // Sem isto o conteúdo fica centralizado na vertical quando é menor que
      // a janela — o que desalinha as colunas.
      layoutBuilder: (atual, anteriores) => Stack(
        alignment: Alignment.topCenter,
        children: [...anteriores, ?atual],
      ),
      transitionBuilder: (filho, animacao) {
        final deslizamento = Tween<Offset>(
          begin: const Offset(0.02, 0.03),
          end: Offset.zero,
        ).animate(animacao);
        return FadeTransition(
          opacity: animacao,
          child: SlideTransition(position: deslizamento, child: filho),
        );
      },
      child: KeyedSubtree(key: ValueKey(chave), child: child),
    );
  }
}
