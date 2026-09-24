import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pdf_enxuto/theme/app_theme.dart';

/// Cartão de seção: a "caixa" padrão do app.
///
/// Traz título, subtítulo opcional, botão de ajuda "?" e um conteúdo. Entra na
/// tela com uma animação suave de baixo para cima.
class CartaoSecao extends StatelessWidget {
  const CartaoSecao({
    super.key,
    required this.child,
    this.titulo,
    this.subtitulo,
    this.ajuda,
    this.icone,
    this.acao,
    this.padding = const EdgeInsets.all(20),
    this.destaque = false,
    this.corFundo,
    this.atraso = Duration.zero,
  });

  final Widget child;
  final String? titulo;
  final String? subtitulo;
  final String? ajuda;
  final IconData? icone;
  final Widget? acao;
  final EdgeInsets padding;
  final bool destaque;
  final Color? corFundo;
  final Duration atraso;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final escuro = esquema.brightness == Brightness.dark;
    final cores = context.cores;

    return FadeSlideIn(
      atraso: atraso,
      child: Container(
        decoration: BoxDecoration(
          color:
              corFundo ??
              (escuro
                  ? esquema.surfaceContainerHigh.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.82)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: destaque
                ? cores.accent.withValues(alpha: 0.55)
                : esquema.outlineVariant.withValues(alpha: escuro ? 0.28 : 0.6),
            width: destaque ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (escuro ? Colors.black : cores.accent).withValues(
                alpha: escuro ? 0.28 : 0.06,
              ),
              blurRadius: destaque ? 26 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  if (icone != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: cores.gradienteMarca),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icone, size: 19, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                titulo!,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (ajuda != null) ...[
                              const SizedBox(width: 6),
                              BotaoAjuda(titulo: titulo!, texto: ajuda!),
                            ],
                          ],
                        ),
                        if (subtitulo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitulo!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: esquema.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (acao != null) ...[const SizedBox(width: 8), acao!],
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// O botão "?" que explica cada método com calma.
class BotaoAjuda extends StatelessWidget {
  const BotaoAjuda({
    super.key,
    required this.titulo,
    required this.texto,
    this.tamanho = 20,
  });

  final String titulo;
  final String texto;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return Tooltip(
      message: 'Clique para entender',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => mostrarAjuda(context, titulo, texto),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: tamanho,
            height: tamanho,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cores.accent.withValues(alpha: 0.12),
              border: Border.all(color: cores.accent.withValues(alpha: 0.5)),
            ),
            child: Icon(
              Icons.question_mark_rounded,
              size: tamanho * 0.62,
              color: cores.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre o diálogo de ajuda com o texto do método.
Future<void> mostrarAjuda(BuildContext context, String titulo, String texto) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _DialogoAjuda(titulo: titulo, texto: texto),
  );
}

class _DialogoAjuda extends StatelessWidget {
  const _DialogoAjuda({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cores.gradienteMarca,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  texto,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendi'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada animada: aparece deslizando de baixo para cima e sumindo em fade.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.atraso = Duration.zero,
    this.deslocamento = 14,
    this.duracao = Motion.lenta,
  });

  final Widget child;
  final Duration atraso;
  final double deslocamento;
  final Duration duracao;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visivel = false;
  bool _decidido = false;
  Timer? _temporizador;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decidido) return;
    _decidido = true;

    // Com animações desligadas (ou sem atraso) nada é agendado: o conteúdo
    // aparece na hora e não ficam temporizadores soltos.
    final semAnimacao = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (semAnimacao || widget.atraso == Duration.zero) {
      _visivel = true;
      return;
    }

    _temporizador = Timer(widget.atraso, () {
      if (mounted) setState(() => _visivel = true);
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duracao = Motion.escolher(context, widget.duracao);
    return AnimatedOpacity(
      opacity: _visivel ? 1 : 0,
      duration: duracao,
      curve: Motion.entrada,
      child: AnimatedSlide(
        offset: _visivel ? Offset.zero : Offset(0, widget.deslocamento / 100),
        duration: duracao,
        curve: Motion.entrada,
        child: widget.child,
      ),
    );
  }
}

/// Cresce um pouco quando o mouse passa por cima.
class HoverScale extends StatefulWidget {
  const HoverScale({
    super.key,
    required this.child,
    this.escala = 1.02,
    this.onTap,
    this.raio = 16,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget child;
  final double escala;
  final VoidCallback? onTap;
  final double raio;
  final MouseCursor cursor;

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final duracao = Motion.escolher(context, Motion.rapida);

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : widget.cursor,
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: AnimatedScale(
        scale: _sobre && widget.onTap != null ? widget.escala : 1,
        duration: duracao,
        curve: Motion.entrada,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.raio),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.raio),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Botão principal com gradiente e animação de pressão.
class BotaoGradiente extends StatefulWidget {
  const BotaoGradiente({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.icone,
    this.carregando = false,
    this.expandido = false,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool carregando;
  final bool expandido;

  @override
  State<BotaoGradiente> createState() => _BotaoGradienteState();
}

class _BotaoGradienteState extends State<BotaoGradiente> {
  bool _pressionado = false;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final ativo = widget.onPressed != null && !widget.carregando;
    final duracao = Motion.escolher(context, Motion.rapida);

    return Semantics(
      button: true,
      label: widget.rotulo,
      child: MouseRegion(
        cursor: ativo ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTapDown: ativo ? (_) => setState(() => _pressionado = true) : null,
          onTapUp: ativo ? (_) => setState(() => _pressionado = false) : null,
          onTapCancel: ativo
              ? () => setState(() => _pressionado = false)
              : null,
          onTap: ativo ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressionado ? 0.97 : 1,
            duration: duracao,
            child: AnimatedOpacity(
              opacity: ativo ? 1 : 0.5,
              duration: duracao,
              child: Container(
                width: widget.expandido ? double.infinity : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: cores.gradienteMarca,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: cores.accent.withValues(alpha: ativo ? 0.34 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: widget.expandido
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.carregando)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    else if (widget.icone != null)
                      Icon(widget.icone, size: 20, color: Colors.white),
                    if (widget.carregando || widget.icone != null)
                      const SizedBox(width: 10),
                    Text(
                      widget.rotulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Número que "conta" até o valor final, com animação.
class ContadorAnimado extends StatelessWidget {
  const ContadorAnimado({
    super.key,
    required this.valor,
    required this.formatador,
    this.duracao = Motion.muitoLenta,
    this.estilo,
  });

  final int valor;
  final String Function(int) formatador;
  final Duration duracao;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.toDouble()),
      duration: Motion.escolher(context, duracao),
      curve: Motion.suave,
      builder: (context, animado, _) =>
          Text(formatador(animado.round()), style: estilo),
    );
  }
}

/// Etiqueta pequena e arredondada (usada para "instalado", "150 dpi", etc.).
class Etiqueta extends StatelessWidget {
  const Etiqueta({
    super.key,
    required this.texto,
    this.icone,
    this.cor,
    this.compacta = false,
  });

  final String texto;
  final IconData? icone;
  final Color? cor;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final corBase = cor ?? esquema.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacta ? 8 : 10,
        vertical: compacta ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: corBase.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corBase.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: compacta ? 11 : 13, color: corBase),
            const SizedBox(width: 5),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: compacta ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: corBase,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vazio com desenho suave e uma dica.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: Motion.escolher(context, Motion.muitoLenta),
              curve: Motion.elastica,
              builder: (context, escala, filho) =>
                  Transform.scale(scale: escala, child: filho),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      cores.accent.withValues(alpha: 0.18),
                      cores.accentSecundaria.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: Icon(icone, size: 42, color: cores.accent),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                descricao,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            if (acao != null) ...[const SizedBox(height: 22), acao!],
          ],
        ),
      ),
    );
  }
}

/// Área com rolagem vertical e barra sempre visível.
///
/// Todas as telas usam esta área, para que nenhuma opção fique escondida
/// quando a janela é pequena.
class AreaRolavel extends StatefulWidget {
  const AreaRolavel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.espacoFinal = 40,
  });

  final Widget child;
  final EdgeInsets padding;
  final double espacoFinal;

  @override
  State<AreaRolavel> createState() => _AreaRolavelState();
}

class _AreaRolavelState extends State<AreaRolavel> {
  final ScrollController _controlador = ScrollController();
  bool _precisaRolar = false;

  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro já sabemos se o conteúdo passa da tela.
    WidgetsBinding.instance.addPostFrameCallback((_) => _medir());
    _controlador.addListener(_medir);
  }

  void _medir() {
    if (!mounted || !_controlador.hasClients) return;
    final precisa = _controlador.position.maxScrollExtent > 8;
    if (precisa != _precisaRolar) {
      setState(() => _precisaRolar = precisa);
    }
  }

  @override
  void dispose() {
    _controlador.removeListener(_medir);
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scrollbar(
      controller: _controlador,
      thumbVisibility: true,
      thickness: 9,
      radius: const Radius.circular(6),
      trackVisibility: false,
      child: SingleChildScrollView(
        controller: _controlador,
        padding: widget.padding.copyWith(
          bottom: widget.padding.bottom + widget.espacoFinal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.child,
            if (_precisaRolar) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Role para ver todas as opções',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: esquema.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Revela ou esconde o conteúdo com fade e deslize.
///
/// Diferente de AnimatedSize, não mexe no layout durante a própria passagem de
/// medição — o que evita o erro "RenderAnimatedSize was mutated".
class Aparecer extends StatelessWidget {
  const Aparecer({super.key, required this.visivel, required this.child});

  final bool visivel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duracao = Motion.escolher(context, Motion.media);

    return AnimatedSwitcher(
      duration: duracao,
      switchInCurve: Motion.entrada,
      switchOutCurve: Motion.saida,
      transitionBuilder: (filho, animacao) => SizeTransition(
        sizeFactor: animacao,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animacao, child: filho),
      ),
      child: visivel
          ? KeyedSubtree(key: const ValueKey('conteudo'), child: child)
          : const SizedBox.shrink(key: ValueKey('vazio')),
    );
  }
}
