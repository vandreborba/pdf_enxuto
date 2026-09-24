import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:pdf_enxuto/theme/app_theme.dart';

/// Fundo do app: gradiente suave com "manchas" coloridas que flutuam devagar.
///
/// Fica atrás de tudo, é barato de desenhar (gradientes radiais, sem blur) e
/// dá a personalidade visual sem atrapalhar a leitura.
class FundoAnimado extends StatefulWidget {
  const FundoAnimado({super.key, required this.child});

  final Widget child;

  @override
  State<FundoAnimado> createState() => _FundoAnimadoState();
}

class _FundoAnimadoState extends State<FundoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void initState() {
    super.initState();
    _controle.repeat();
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final escuro = esquema.brightness == Brightness.dark;
    final animar = !MediaQuery.of(context).disableAnimations;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cores.gradienteSuperficie,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: animar
                  ? AnimatedBuilder(
                      animation: _controle,
                      builder: (context, _) => CustomPaint(
                        painter: _PintorManchas(
                          progresso: _controle.value,
                          corPrimaria: cores.accent,
                          corSecundaria: cores.accentSecundaria,
                          opacidade: escuro ? 0.30 : 0.20,
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: _PintorManchas(
                        progresso: 0.2,
                        corPrimaria: cores.accent,
                        corSecundaria: cores.accentSecundaria,
                        opacidade: escuro ? 0.30 : 0.20,
                      ),
                    ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _PintorManchas extends CustomPainter {
  _PintorManchas({
    required this.progresso,
    required this.corPrimaria,
    required this.corSecundaria,
    required this.opacidade,
  });

  final double progresso;
  final Color corPrimaria;
  final Color corSecundaria;
  final double opacidade;

  @override
  void paint(Canvas canvas, Size size) {
    final raio = math.max(size.width, size.height);

    void mancha(
      double fx,
      double fy,
      double escala,
      Color cor,
      double fase,
      double forca,
    ) {
      final angulo = (progresso + fase) * 2 * math.pi;
      final centro = Offset(
        size.width * fx + math.cos(angulo) * size.width * 0.06,
        size.height * fy + math.sin(angulo * 0.8) * size.height * 0.05,
      );
      final gradiente = RadialGradient(
        colors: [
          cor.withValues(alpha: forca * opacidade),
          cor.withValues(alpha: 0),
        ],
      );
      canvas.drawCircle(
        centro,
        raio * escala,
        Paint()
          ..shader = gradiente.createShader(
            Rect.fromCircle(center: centro, radius: raio * escala),
          ),
      );
    }

    mancha(0.12, 0.08, 0.55, corPrimaria, 0.0, 1.0);
    mancha(0.92, 0.18, 0.48, corSecundaria, 0.35, 0.9);
    mancha(0.78, 0.95, 0.52, corPrimaria, 0.62, 0.7);
  }

  @override
  bool shouldRepaint(covariant _PintorManchas antigo) =>
      antigo.progresso != progresso ||
      antigo.corPrimaria != corPrimaria ||
      antigo.corSecundaria != corSecundaria ||
      antigo.opacidade != opacidade;
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
              child: Container(
                height: altura,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [corFinal, cores.accentSecundaria],
                  ),
                ),
              ),
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
    final cores = context.cores;

    return AnimatedBuilder(
      animation: _controle,
      builder: (context, filho) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (retangulo) {
          final deslocamento = _controle.value * 2 - 1;
          return LinearGradient(
            begin: Alignment(-1 + deslocamento * 2, -0.4),
            end: Alignment(1 + deslocamento * 2, 0.4),
            colors: [
              Colors.transparent,
              cores.brilho.withValues(alpha: 0.28),
              Colors.transparent,
            ],
          ).createShader(retangulo);
        },
        child: filho,
      ),
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
