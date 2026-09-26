import 'dart:async';

/// Permite cancelar uma tarefa longa (compressão, divisão, simulação).
///
/// Os motores consultam [verificar] nos pontos seguros: entre páginas, entre
/// partes e antes de gravar o arquivo. Processos externos são encerrados.
class Cancelamento {
  bool _cancelado = false;
  bool _descartado = false;
  final _controlador = StreamController<void>.broadcast();

  bool get cancelado => _cancelado;

  Stream<void> get quandoCancelar => _controlador.stream;

  void cancelar() {
    if (_cancelado || _descartado) return;
    _cancelado = true;
    _controlador.add(null);
  }

  /// Lança [OperacaoCancelada] se o usuário pediu para parar.
  void verificar() {
    if (_cancelado) throw const OperacaoCancelada();
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _controlador.close();
  }
}

class OperacaoCancelada implements Exception {
  const OperacaoCancelada();

  @override
  String toString() => 'Operação cancelada';
}
