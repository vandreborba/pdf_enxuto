import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_enxuto/models/task_models.dart';

/// Histórico das tarefas: alimenta a tela de histórico e o total economizado.
///
/// Só guarda o resultado (caminhos, tamanhos, opções). Nenhum conteúdo de PDF.
class ServicoHistorico extends ChangeNotifier {
  static const String _chave = 'pdf_enxuto.historico.v1';
  static const int _limite = 300;

  List<HistoryEntry> _entradas = const [];

  List<HistoryEntry> get entradas => _entradas;

  bool get vazio => _entradas.isEmpty;

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto == null || texto.isEmpty) return;
      final lista = (jsonDecode(texto) as List)
          .map(
            (item) =>
                HistoryEntry.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
      _entradas = lista;
      notifyListeners();
    } catch (erro) {
      debugPrint('Falha ao ler o histórico: $erro');
    }
  }

  Future<void> registrar(HistoryEntry entrada) async {
    _entradas = [entrada, ..._entradas];
    if (_entradas.length > _limite) {
      _entradas = _entradas.sublist(0, _limite);
    }
    notifyListeners();
    await _salvar();
  }

  Future<void> registrarVarias(Iterable<HistoryEntry> novas) async {
    if (novas.isEmpty) return;
    _entradas = [...novas, ..._entradas];
    if (_entradas.length > _limite) {
      _entradas = _entradas.sublist(0, _limite);
    }
    notifyListeners();
    await _salvar();
  }

  Future<void> limpar() async {
    _entradas = const [];
    notifyListeners();
    await _salvar();
  }

  // ------------------------------------------------------------- estatísticas
  /// Só a compressão economiza espaço: dividir mantém o tamanho e converter
  /// em planilha costuma gerar um arquivo maior que o PDF.
  int get totalEconomizado {
    var total = 0;
    for (final entrada in _entradas) {
      if (entrada.kind != TaskKind.comprimir) continue;
      final diferenca =
          entrada.resultado.bytesAntes - entrada.resultado.bytesDepois;
      if (diferenca > 0 && entrada.resultado.sucesso) total += diferenca;
    }
    return total;
  }

  int get totalProcessado => _entradas.length;

  int get totalBytesEntrada {
    var total = 0;
    for (final entrada in _entradas) {
      if (entrada.kind == TaskKind.planilha) continue;
      total += entrada.resultado.bytesAntes;
    }
    return total;
  }

  double get reducaoMedia {
    final total = totalBytesEntrada;
    if (total <= 0) return 0;
    return totalEconomizado / total;
  }

  /// Arquivos que o app criou a partir de um PDF: partes da divisão e
  /// planilhas da conversão.
  int get arquivosGerados {
    var total = 0;
    for (final entrada in _entradas) {
      if (entrada.kind == TaskKind.dividir ||
          entrada.kind == TaskKind.planilha) {
        total += entrada.resultado.saidas.length;
      }
    }
    return total;
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chave,
        jsonEncode([for (final entrada in _entradas) entrada.toJson()]),
      );
    } catch (erro) {
      debugPrint('Falha ao gravar o histórico: $erro');
    }
  }
}
