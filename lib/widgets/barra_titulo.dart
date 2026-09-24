import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';

/// Barra de título própria do app.
///
/// Substitui a moldura do sistema: arraste por qualquer ponto vazio para mover
/// a janela, clique duas vezes para maximizar e use os botões da direita para
/// minimizar, maximizar e fechar.
class BarraTitulo extends StatelessWidget {
  const BarraTitulo({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.maximizada,
    this.altura = 46,
  });

  final String titulo;
  final String subtitulo;
  final bool maximizada;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Container(
      height: altura,
      decoration: BoxDecoration(
        color: esquema.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.30)
            : Colors.white.withValues(alpha: 0.60),
        border: Border(
          bottom: BorderSide(
            color: esquema.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset('assets/icons/icon_24.png', width: 22, height: 22),
          ),
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _alternarMaximizar(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitulo.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                esquema.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          _BotaoJanela(
            icone: Icons.remove_rounded,
            dica: 'Minimizar',
            onTap: () => windowManager.minimize(),
          ),
          _BotaoJanela(
            icone: maximizada
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            dica: maximizada ? 'Restaurar' : 'Maximizar',
            onTap: () => _alternarMaximizar(context),
          ),
          _BotaoJanela(
            icone: Icons.close_rounded,
            dica: S.fechar,
            corHover: const Color(0xFFE11D48),
            onTap: () => windowManager.close(),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 10),
            child: IconButton(
              tooltip: 'Como usar o app',
              onPressed: () => mostrarAjuda(context, 'Barra da janela', Ajuda.tituloJanela),
              icon: Icon(
                Icons.question_mark_rounded,
                size: 15,
                color: cores.accent,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _alternarMaximizar(BuildContext context) async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

class _BotaoJanela extends StatefulWidget {
  const _BotaoJanela({
    required this.icone,
    required this.dica,
    required this.onTap,
    this.corHover,
  });

  final IconData icone;
  final String dica;
  final VoidCallback onTap;
  final Color? corHover;

  @override
  State<_BotaoJanela> createState() => _BotaoJanelaState();
}

class _BotaoJanelaState extends State<_BotaoJanela> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cor = widget.corHover ?? esquema.primary;

    return Tooltip(
      message: widget.dica,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _sobre = true),
        onExit: (_) => setState(() => _sobre = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 42,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _sobre ? cor.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              widget.icone,
              size: 17,
              color: _sobre ? cor : esquema.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
