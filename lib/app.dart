import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/screens/tela_principal.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';

/// Raiz do aplicativo: tema, idioma e a tela principal.
class PdfEnxutoApp extends StatefulWidget {
  const PdfEnxutoApp({
    super.key,
    required this.estado,
    this.arquivosIniciais = const [],
  });

  final AppState estado;

  /// PDFs passados na linha de comando (ex.: abrir com o app).
  final List<String> arquivosIniciais;

  @override
  State<PdfEnxutoApp> createState() => _PdfEnxutoAppState();
}

class _PdfEnxutoAppState extends State<PdfEnxutoApp> {
  @override
  void initState() {
    super.initState();
    if (widget.arquivosIniciais.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.estado.adicionarCaminhos(widget.arquivosIniciais);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final config = widget.estado.config;
        final paleta = AccentPalette.porIndice(config.corDestaque);

        return MaterialApp(
          title: '${S.appName} — ${S.tagline}',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.claro(paleta: paleta),
          darkTheme: AppTheme.escuro(paleta: paleta),
          themeMode: config.tema,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR'), Locale('pt')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, filho) {
            // Respeita a preferência "reduzir animações" das configurações.
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: config.reduzirAnimacoes
                  ? media.copyWith(disableAnimations: true)
                  : media,
              child: filho ?? const SizedBox.shrink(),
            );
          },
          home: TelaPrincipal(estado: widget.estado),
        );
      },
    );
  }
}
