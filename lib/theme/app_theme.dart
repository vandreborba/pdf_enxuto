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
    required this.accentEscuro,
    required this.accentSuave,
    required this.fundo,
    required this.fundoCartao,
    required this.sucesso,
    required this.alerta,
    required this.perigo,
  });

  /// Cor de destaque única do aplicativo.
  final Color accent;

  /// Mesma cor, mais escura (hover, pressionado, texto sobre fundo claro).
  final Color accentEscuro;

  /// Mesma cor, bem clara — para fundos discretos de realce.
  final Color accentSuave;

  /// Cor de fundo da janela (lisa, sem degradê).
  final Color fundo;

  /// Cor dos cartões e barras.
  final Color fundoCartao;

  final Color sucesso;
  final Color alerta;
  final Color perigo;

  /// Cor do texto/ícone quando ele fica em cima da cor de destaque.
  /// Escolhida pelo contraste, para funcionar em qualquer paleta e tema.
  Color get sobreAccent => accent.computeLuminance() > 0.45
      ? const Color(0xFF11151C)
      : const Color(0xFFFFFFFF);

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentEscuro,
    Color? accentSuave,
    Color? fundo,
    Color? fundoCartao,
    Color? sucesso,
    Color? alerta,
    Color? perigo,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accentEscuro: accentEscuro ?? this.accentEscuro,
      accentSuave: accentSuave ?? this.accentSuave,
      fundo: fundo ?? this.fundo,
      fundoCartao: fundoCartao ?? this.fundoCartao,
      sucesso: sucesso ?? this.sucesso,
      alerta: alerta ?? this.alerta,
      perigo: perigo ?? this.perigo,
    );
  }

  @override
  AppColors lerp(covariant AppColors? outro, double t) {
    if (outro == null) return this;
    return AppColors(
      accent: Color.lerp(accent, outro.accent, t)!,
      accentEscuro: Color.lerp(accentEscuro, outro.accentEscuro, t)!,
      accentSuave: Color.lerp(accentSuave, outro.accentSuave, t)!,
      fundo: Color.lerp(fundo, outro.fundo, t)!,
      fundoCartao: Color.lerp(fundoCartao, outro.fundoCartao, t)!,
      sucesso: Color.lerp(sucesso, outro.sucesso, t)!,
      alerta: Color.lerp(alerta, outro.alerta, t)!,
      perigo: Color.lerp(perigo, outro.perigo, t)!,
    );
  }
}

/// Paletas de destaque oferecidas nas configurações.
class AccentPalette {
  const AccentPalette(this.nome, this.cor);

  final String nome;

  /// Cor de destaque do app. Uma só, discreta, usada com parcimônia:
  /// no botão principal, no item selecionado e em pequenos realces.
  final Color cor;

  /// Versão mais escura, para passar o mouse e estados pressionados.
  Color get escura => Color.lerp(cor, const Color(0xFF000000), 0.18)!;

  /// Versão clara, para fundos suaves (nunca como degradê).
  Color get suave => Color.lerp(cor, const Color(0xFFFFFFFF), 0.88)!;

  static const List<AccentPalette> todas = [
    // A primeira é a padrão do aplicativo.
    AccentPalette('Petróleo', Color(0xFF2F5D62)),
    AccentPalette('Ardósia', Color(0xFF44546A)),
    AccentPalette('Aço', Color(0xFF4B5563)),
    AccentPalette('Oliva', Color(0xFF56613F)),
    AccentPalette('Tijolo', Color(0xFF7A4A3A)),
    AccentPalette('Ameixa', Color(0xFF5B4356)),
    AccentPalette('Bronze', Color(0xFF7A6535)),
    AccentPalette('Índigo', Color(0xFF3B4C7A)),
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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: paleta.cor,
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1F2430),
        );

    return _base(
      scheme: scheme,
      cores: AppColors(
        accent: paleta.cor,
        accentEscuro: paleta.escura,
        accentSuave: paleta.suave,
        fundo: const Color(0xFFF2F3F5),
        fundoCartao: const Color(0xFFFFFFFF),
        sucesso: _sucessoClaro,
        alerta: _alertaClaro,
        perigo: _perigoClaro,
      ),
    );
  }

  static ThemeData escuro({required AccentPalette paleta}) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: paleta.cor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF1B1E23),
          onSurface: const Color(0xFFE6E8EC),
        );

    return _base(
      scheme: scheme,
      cores: AppColors(
        accent: Color.lerp(paleta.cor, Colors.white, 0.42)!,
        accentEscuro: Color.lerp(paleta.cor, Colors.white, 0.24)!,
        accentSuave: Color.lerp(paleta.cor, const Color(0xFF1B1E23), 0.78)!,
        fundo: const Color(0xFF141618),
        fundoCartao: const Color(0xFF1B1E23),
        sucesso: _sucessoEscuro,
        alerta: _alertaEscuro,
        perigo: _perigoEscuro,
      ),
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required AppColors cores,
  }) {
    final escuro = scheme.brightness == Brightness.dark;
    final raio = BorderRadius.circular(12);
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
        color: scheme.outlineVariant.withValues(alpha: escuro ? 0.30 : 0.55),
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
        color: cores.fundoCartao,
        shape: RoundedRectangleBorder(borderRadius: raio),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: escuro
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
          backgroundColor: cores.accent,
          foregroundColor: cores.sobreAccent,
          disabledBackgroundColor: cores.accent.withValues(alpha: 0.35),
          disabledForegroundColor: cores.sobreAccent.withValues(alpha: 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
          foregroundColor: cores.accent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textos.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cores.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textos.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: cores.fundoCartao,
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
    // A tipografia certa para cada brilho: usar a "clara" no tema escuro é o
    // que mantém o texto legível sobre o fundo escuro.
    final tipografia = Typography.material2021(colorScheme: scheme);
    final base = scheme.brightness == Brightness.dark
        ? tipografia.white
        : tipografia.black;
    return base
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
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
