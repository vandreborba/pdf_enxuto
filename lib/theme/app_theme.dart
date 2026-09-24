import 'package:flutter/material.dart';

/// Durações e curvas usadas em todo o app, para que as animações tenham o
/// mesmo "tempero" e possam ser desligadas em um só lugar.
class Motion {
  Motion._();

  static const Duration rapida = Duration(milliseconds: 160);
  static const Duration media = Duration(milliseconds: 260);
  static const Duration lenta = Duration(milliseconds: 420);
  static const Duration muitoLenta = Duration(milliseconds: 720);

  static const Curve entrada = Curves.easeOutCubic;
  static const Curve saida = Curves.easeInCubic;
  static const Curve suave = Curves.easeInOutCubic;
  static const Curve elastica = Curves.easeOutBack;

  /// Respeita a preferência "reduzir animações".
  static Duration escolher(BuildContext context, Duration duracao) {
    final desligado = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return desligado ? Duration.zero : duracao;
  }
}

/// Cores extras que não cabem no [ColorScheme] do Material.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accentSecundaria,
    required this.gradienteMarca,
    required this.gradienteSuperficie,
    required this.sucesso,
    required this.alerta,
    required this.perigo,
    required this.brilho,
  });

  final Color accent;
  final Color accentSecundaria;

  /// Gradiente da identidade visual (usado no logo, botões e destaques).
  final List<Color> gradienteMarca;

  /// Gradiente sutil usado no fundo das telas.
  final List<Color> gradienteSuperficie;

  final Color sucesso;
  final Color alerta;
  final Color perigo;
  final Color brilho;

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentSecundaria,
    List<Color>? gradienteMarca,
    List<Color>? gradienteSuperficie,
    Color? sucesso,
    Color? alerta,
    Color? perigo,
    Color? brilho,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accentSecundaria: accentSecundaria ?? this.accentSecundaria,
      gradienteMarca: gradienteMarca ?? this.gradienteMarca,
      gradienteSuperficie: gradienteSuperficie ?? this.gradienteSuperficie,
      sucesso: sucesso ?? this.sucesso,
      alerta: alerta ?? this.alerta,
      perigo: perigo ?? this.perigo,
      brilho: brilho ?? this.brilho,
    );
  }

  @override
  AppColors lerp(covariant AppColors? outro, double t) {
    if (outro == null) return this;
    return AppColors(
      accent: Color.lerp(accent, outro.accent, t)!,
      accentSecundaria: Color.lerp(accentSecundaria, outro.accentSecundaria, t)!,
      gradienteMarca: [
        for (var i = 0; i < gradienteMarca.length; i++)
          Color.lerp(gradienteMarca[i], outro.gradienteMarca[i], t)!,
      ],
      gradienteSuperficie: [
        for (var i = 0; i < gradienteSuperficie.length; i++)
          Color.lerp(gradienteSuperficie[i], outro.gradienteSuperficie[i], t)!,
      ],
      sucesso: Color.lerp(sucesso, outro.sucesso, t)!,
      alerta: Color.lerp(alerta, outro.alerta, t)!,
      perigo: Color.lerp(perigo, outro.perigo, t)!,
      brilho: Color.lerp(brilho, outro.brilho, t)!,
    );
  }
}

/// Paletas de destaque oferecidas nas configurações.
class AccentPalette {
  const AccentPalette(this.nome, this.primaria, this.terciaria, this.secundaria);

  final String nome;
  final Color primaria;

  /// Cor do meio do gradiente (dá personalidade ao conjunto).
  final Color terciaria;
  final Color secundaria;

  List<Color> get gradiente => [primaria, terciaria, secundaria];

  static const List<AccentPalette> todas = [
    AccentPalette('Aurora', Color(0xFF7C3AED), Color(0xFFC026D3), Color(0xFF22D3EE)),
    AccentPalette('Papel & Ouro', Color(0xFF92400E), Color(0xFFB45309), Color(0xFFEAB308)),
    AccentPalette('Esmeralda', Color(0xFF047857), Color(0xFF10B981), Color(0xFF84CC16)),
    AccentPalette('Cereja', Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFFB923C)),
    AccentPalette('Petróleo', Color(0xFF0F766E), Color(0xFF0891B2), Color(0xFF38BDF8)),
    AccentPalette('Magenta', Color(0xFFA21CAF), Color(0xFFDB2777), Color(0xFF8B5CF6)),
    AccentPalette('Grafite & Âmbar', Color(0xFF334155), Color(0xFF475569), Color(0xFFF59E0B)),
    AccentPalette('Uva', Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFEC4899)),
  ];

  static AccentPalette porIndice(int indice) =>
      todas[indice.clamp(0, todas.length - 1)];
}

class AppTheme {
  AppTheme._();

  static const Color _sucessoClaro = Color(0xFF15803D);
  static const Color _alertaClaro = Color(0xFFB45309);
  static const Color _perigoClaro = Color(0xFFDC2626);

  static const Color _sucessoEscuro = Color(0xFF4ADE80);
  static const Color _alertaEscuro = Color(0xFFFBBF24);
  static const Color _perigoEscuro = Color(0xFFF87171);

  static ThemeData claro({required AccentPalette paleta}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: paleta.primaria,
      brightness: Brightness.light,
    ).copyWith(surface: const Color(0xFFFBF9FF));

    return _base(
      scheme: scheme,
      cores: AppColors(
        accent: paleta.primaria,
        accentSecundaria: paleta.secundaria,
        gradienteMarca: paleta.gradiente,
        // O fundo também ganha um toque da paleta escolhida.
        gradienteSuperficie: [
          Color.lerp(Colors.white, paleta.secundaria, 0.18)!,
          Color.lerp(Colors.white, paleta.terciaria, 0.10)!,
          Color.lerp(Colors.white, paleta.primaria, 0.05)!,
          Colors.white,
        ],
        sucesso: _sucessoClaro,
        alerta: _alertaClaro,
        perigo: _perigoClaro,
        brilho: Colors.white,
      ),
    );
  }

  static ThemeData escuro({required AccentPalette paleta}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: paleta.primaria,
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF120F1C));

    return _base(
      scheme: scheme,
      cores: AppColors(
        accent: Color.lerp(paleta.primaria, Colors.white, 0.18)!,
        accentSecundaria: paleta.secundaria,
        gradienteMarca: [
          Color.lerp(paleta.primaria, Colors.white, 0.14)!,
          Color.lerp(paleta.terciaria, Colors.white, 0.08)!,
          Color.lerp(paleta.secundaria, Colors.white, 0.04)!,
        ],
        gradienteSuperficie: [
          Color.lerp(const Color(0xFF0D0B14), paleta.primaria, 0.10)!,
          Color.lerp(const Color(0xFF100E19), paleta.terciaria, 0.07)!,
          Color.lerp(const Color(0xFF0A0910), paleta.secundaria, 0.05)!,
        ],
        sucesso: _sucessoEscuro,
        alerta: _alertaEscuro,
        perigo: _perigoEscuro,
        brilho: const Color(0xFF241F38),
      ),
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required AppColors cores,
  }) {
    final escuro = scheme.brightness == Brightness.dark;
    final raio = BorderRadius.circular(16);
    // Os textos dos botões saem da mesma tipografia do app (e não da fonte
    // padrão do sistema, que pode ser outra).
    final textos = _textos(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [cores],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: textos,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: escuro ? 0.35 : 0.6),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textos.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: escuro
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.86),
        shape: RoundedRectangleBorder(borderRadius: raio),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: escuro
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.75),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: escuro ? 0.5 : 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cores.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cores.perigo),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textos.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textos.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textos.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textos.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: cores.accent,
        thumbColor: cores.accent,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        inactiveTrackColor: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Colors.white
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? cores.accent
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          color: escuro ? const Color(0xFF2A2438) : const Color(0xFF2B2733),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textos.bodySmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: textos.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: escuro ? const Color(0xFF1B1728) : Colors.white,
      ),
      scrollbarTheme: ScrollbarThemeData(
        // Barra de rolagem sempre visível e na cor do app: é ela que garante
        // que nenhuma opção fique escondida em janelas pequenas.
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: const WidgetStatePropertyAll(10),
        radius: const Radius.circular(6),
        thumbColor: WidgetStatePropertyAll(
          cores.accent.withValues(alpha: escuro ? 0.65 : 0.55),
        ),
        trackColor: WidgetStatePropertyAll(
          scheme.outlineVariant.withValues(alpha: escuro ? 0.15 : 0.22),
        ),
        trackVisibility: const WidgetStatePropertyAll(false),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.outlineVariant.withValues(alpha: 0.3),
      ),
    );
  }

  static TextTheme _textos(ColorScheme scheme) {
    final base = Typography.material2021(colorScheme: scheme).black;
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(height: 1.4),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Atalho para acessar as cores extras.
extension AppColorsX on BuildContext {
  AppColors get cores => Theme.of(this).extension<AppColors>()!;
}
