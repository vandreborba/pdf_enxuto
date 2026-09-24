import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_enxuto/models/app_settings.dart';
import 'package:pdf_enxuto/models/compression_options.dart';

/// Guarda e recupera as preferências do usuário.
class ServicoConfig extends ChangeNotifier {
  static const String _chave = 'pdf_enxuto.config.v1';

  AppSettings _config = AppSettings.padrao;

  AppSettings get config => _config;

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto == null || texto.isEmpty) return;
      final json = jsonDecode(texto) as Map<String, dynamic>;
      _config = AppSettings.fromJson(json);
      notifyListeners();
    } catch (erro) {
      debugPrint('Falha ao ler as preferências: $erro');
    }
  }

  Future<void> atualizar(AppSettings novo) async {
    _config = novo;
    notifyListeners();
    await _salvar();
  }

  /// Atalhos usados pelas telas e pelos atalhos de teclado.
  Future<void> definirCompressao(CompressionOptions opcoes) =>
      atualizar(_config.copyWith(compressao: opcoes));

  Future<void> definirTema(ThemeMode tema) =>
      atualizar(_config.copyWith(tema: tema));

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode(_config.toJson()));
    } catch (erro) {
      debugPrint('Falha ao gravar as preferências: $erro');
    }
  }
}
