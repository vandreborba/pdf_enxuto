import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Cuida da janela: tamanho inicial, tamanho mínimo, ícone e lembrar da
/// posição/tamanho entre sessões.
class ServicoJanela {
  ServicoJanela._();

  static const String _chave = 'pdf_enxuto.janela.v1';
  static const Size tamanhoPadrao = Size(1180, 820);
  static const Size tamanhoMinimo = Size(940, 660);

  static Future<void> preparar() async {
    await windowManager.ensureInitialized();

    final salvo = await _ler();
    final opcoes = WindowOptions(
      size: salvo?.tamanho ?? tamanhoPadrao,
      minimumSize: tamanhoMinimo,
      center: salvo == null,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'PDF Enxuto',
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );

    // O fechamento passa pelo app (para salvar a janela e confirmar).
    await windowManager.setPreventClose(true);

    await windowManager.waitUntilReadyToShow(opcoes, () async {
      if (salvo != null) {
        if (_estaVisivel(salvo.posicao, salvo.tamanho)) {
          await windowManager.setPosition(salvo.posicao);
        } else {
          await windowManager.center();
        }
      }
      await windowManager.show();
      await windowManager.focus();
      await _aplicarIcone();
    });
  }

  static Future<void> _aplicarIcone() async {
    try {
      await windowManager.setIcon('assets/icons/icon.png');
    } catch (_) {
      // Ícone da janela é enfeite: se falhar, o app segue normalmente.
    }
  }

  static bool _estaVisivel(Offset posicao, Size tamanho) {
    // Evita reabrir fora da tela quando um monitor foi desconectado.
    if (posicao.dx < -tamanho.width + 80 || posicao.dy < -40) return false;
    return true;
  }

  /// Grava tamanho e posição (chamado ao fechar a janela).
  static Future<void> salvar() async {
    try {
      final tamanho = await windowManager.getSize();
      final posicao = await windowManager.getPosition();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chave,
        jsonEncode({
          'w': tamanho.width,
          'h': tamanho.height,
          'x': posicao.dx,
          'y': posicao.dy,
        }),
      );
    } catch (_) {
      // Sem problema: só perdemos a memória de posição.
    }
  }

  static Future<_EstadoJanela?> _ler() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto == null) return null;
      final json = jsonDecode(texto) as Map<String, dynamic>;
      final largura = (json['w'] as num?)?.toDouble();
      final altura = (json['h'] as num?)?.toDouble();
      if (largura == null || altura == null) return null;
      return _EstadoJanela(
        tamanho: Size(
          largura < tamanhoMinimo.width ? tamanhoMinimo.width : largura,
          altura < tamanhoMinimo.height ? tamanhoMinimo.height : altura,
        ),
        posicao: Offset(
          (json['x'] as num?)?.toDouble() ?? 0,
          (json['y'] as num?)?.toDouble() ?? 0,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Diálogo de confirmação antes de fechar (se o usuário pediu).
  static Future<bool> confirmarFechamento(BuildContext context) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fechar o PDF Enxuto?'),
        content: const Text(
          'Não há tarefas em andamento. Até logo!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar aqui'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    return resposta ?? false;
  }

  static Future<void> definirTitulo(String titulo) async {
    try {
      await windowManager.setTitle(titulo);
    } catch (_) {}
  }

  static bool get suportaIcone => !Platform.isLinux || Platform.environment.containsKey('DISPLAY');
}

class _EstadoJanela {
  const _EstadoJanela({required this.tamanho, required this.posicao});

  final Size tamanho;
  final Offset posicao;
}
