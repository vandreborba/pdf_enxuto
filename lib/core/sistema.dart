import 'dart:io';

/// Ajudantes de sistema operacional: abrir arquivos, procurar programas,
/// notificar o usuário. Tudo o que é específico de Linux ou Windows fica aqui.
class Sistema {
  Sistema._();

  static bool get ehLinux => Platform.isLinux;
  static bool get ehWindows => Platform.isWindows;

  static const String _criarSemJanela = 'CREATE_NO_WINDOW';

  /// Abre um arquivo com o programa padrão do sistema.
  static Future<bool> abrir(String caminho) async {
    try {
      if (ehWindows) {
        await Process.run('cmd', ['/c', 'start', '', caminho]);
        return true;
      }
      await Process.run('xdg-open', [caminho]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Abre a pasta que contém o arquivo, com o arquivo selecionado quando
  /// o gerenciador de arquivos permitir.
  static Future<bool> mostrarNaPasta(String caminho) async {
    try {
      final arquivo = File(caminho);
      final pasta = arquivo.parent.path;
      if (!Directory(pasta).existsSync()) return false;

      if (ehWindows) {
        if (arquivo.existsSync()) {
          await Process.run('explorer', [
            '/select,',
            caminho.replaceAll('/', r'\'),
          ]);
        } else {
          await Process.run('explorer', [pasta.replaceAll('/', r'\')]);
        }
        return true;
      }

      // Tenta os gerenciadores mais comuns antes de cair no xdg-open.
      for (final comando in [
        [
          'dbus-send',
          '--session',
          '--dest=org.freedesktop.FileManager1',
          '--type=method_call',
          '/org/freedesktop/FileManager1',
          'org.freedesktop.FileManager1.ShowItems',
          'array:string:file://$caminho',
          'string:',
        ],
        ['nautilus', '--select', caminho],
        ['dolphin', '--select', caminho],
        ['nemo', caminho],
        ['thunar', caminho],
        ['xdg-open', pasta],
      ]) {
        try {
          final resultado = await Process.run(
            comando.first,
            comando.sublist(1),
          );
          if (resultado.exitCode == 0) return true;
        } catch (_) {
          continue;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Procura um executável no PATH. Aceita vários nomes (ex.: gs e gswin64c).
  static Future<String?> procurarPrograma(List<String> nomes) async {
    for (final nome in nomes) {
      try {
        final resultado = ehWindows
            ? await Process.run('where', [nome])
            : await Process.run('which', [nome]);
        if (resultado.exitCode == 0) {
          final saida = (resultado.stdout as String).trim();
          if (saida.isNotEmpty) {
            return saida.split(RegExp(r'\r?\n')).first.trim();
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Roda um programa e devolve a saída padrão (ou `null` em caso de erro).
  static Future<String?> executar(
    String programa,
    List<String> argumentos, {
    Duration? tempoLimite,
  }) async {
    try {
      final processo = await Process.run(
        programa,
        argumentos,
        runInShell: ehWindows,
      );
      if (processo.exitCode != 0) return null;
      return (processo.stdout as String).trim();
    } catch (_) {
      return null;
    }
  }

  /// Notificação nativa (Linux: notify-send; Windows: sem suporte direto).
  static Future<void> notificar(String titulo, String corpo) async {
    if (!ehLinux) return;
    try {
      final existe = await procurarPrograma(['notify-send']);
      if (existe == null) return;
      await Process.run('notify-send', ['-a', 'PDF Enxuto', titulo, corpo]);
    } catch (_) {
      // Notificação é opcional: se falhar, ninguém perde nada.
    }
  }

  /// Cria uma pasta de trabalho temporária, sempre dentro de uma pasta
  /// própria do app (facilita a limpeza depois).
  static Directory criarPastaTemporaria([String prefixo = 'job_']) {
    final base = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}pdf_enxuto',
    );
    if (!base.existsSync()) base.createSync(recursive: true);
    return base.createTempSync(prefixo);
  }

  /// Apaga pastas temporárias que sobraram de execuções interrompidas
  /// (por exemplo, quando o app foi fechado no meio de uma compressão).
  static Future<void> limparTemporariosAntigos({
    Duration maisVelhosQue = const Duration(hours: 6),
  }) async {
    try {
      final base = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}pdf_enxuto',
      );
      if (!base.existsSync()) return;

      final agora = DateTime.now();
      for (final entidade in base.listSync()) {
        if (entidade is! Directory) continue;
        final modificado = entidade.statSync().modified;
        if (agora.difference(modificado) < maisVelhosQue) continue;
        entidade.deleteSync(recursive: true);
      }
    } catch (_) {
      // Limpeza é cortesia: se falhar, nada quebra.
    }
  }

  /// Número de núcleos, usado para sugerir o paralelismo.
  static int get nucleos => Platform.numberOfProcessors;

  /// Esconde a janela de console dos processos auxiliares no Windows.
  static bool get esconderConsole => ehWindows;

  /// Nome interno usado em depuração.
  static String get nomeSistema =>
      ehLinux ? 'linux' : (ehWindows ? 'windows' : Platform.operatingSystem);

  static const String marcaJanelaSemConsole = _criarSemJanela;
}
