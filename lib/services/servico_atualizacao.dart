import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:pdf_enxuto/core/app_info.dart';
import 'package:pdf_enxuto/core/sistema.dart';

/// O que a verificação de atualização descobriu.
class ResultadoAtualizacao {
  const ResultadoAtualizacao({
    required this.versaoAtual,
    this.ultimaVersao,
    this.notas,
    this.paginaHtml,
    this.urlDownload,
    this.nomeArquivo,
    this.publicadoEm,
    this.tamanhoBytes,
    this.erroRede = false,
  });

  final String versaoAtual;
  final String? ultimaVersao;
  final String? notas;
  final String? paginaHtml;
  final String? urlDownload;
  final String? nomeArquivo;
  final DateTime? publicadoEm;
  final int? tamanhoBytes;
  final bool erroRede;

  bool get temAtualizacao =>
      ultimaVersao != null &&
      ServicoAtualizacao.versaoMaior(ultimaVersao!, versaoAtual);

  bool get verificou => ultimaVersao != null || erroRede;
}

/// Consulta a última release no GitHub.
///
/// É a única conexão de rede do app, e pode ser desligada nas configurações.
/// Nenhum documento é enviado — só a pergunta "qual é a última versão?".
class ServicoAtualizacao {
  ServicoAtualizacao();

  static String? _versaoCache;

  static Future<String> versaoAtual() async {
    if (_versaoCache != null) return _versaoCache!;
    try {
      final info = await PackageInfo.fromPlatform();
      _versaoCache = info.version.isEmpty ? '0.0.0' : info.version;
    } catch (_) {
      _versaoCache = '0.0.0';
    }
    return _versaoCache!;
  }

  Future<ResultadoAtualizacao> verificar() async {
    final atual = await versaoAtual();

    try {
      final resposta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/${AppInfo.repo}/releases/latest',
            ),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'pdf-enxuto',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (resposta.statusCode != 200) {
        return ResultadoAtualizacao(versaoAtual: atual, erroRede: true);
      }

      final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
      final tag = (dados['tag_name'] as String? ?? '').trim();
      final versao = tag.startsWith('v') ? tag.substring(1) : tag;
      if (versao.isEmpty) {
        return ResultadoAtualizacao(versaoAtual: atual, erroRede: true);
      }

      final ativos = (dados['assets'] as List?) ?? const [];
      String? urlDownload;
      String? nomeArquivo;
      int? tamanho;

      final desejado = Sistema.ehWindows ? '.zip' : '.appimage';
      for (final ativo in ativos) {
        if (ativo is! Map) continue;
        final nome = ativo['name'] as String? ?? '';
        if (!nome.toLowerCase().endsWith(desejado)) continue;
        urlDownload = ativo['browser_download_url'] as String?;
        nomeArquivo = nome;
        tamanho = (ativo['size'] as num?)?.toInt();
        break;
      }

      return ResultadoAtualizacao(
        versaoAtual: atual,
        ultimaVersao: versao,
        notas: (dados['body'] as String?)?.trim(),
        paginaHtml: dados['html_url'] as String? ?? AppInfo.releasesUrl,
        urlDownload: urlDownload,
        nomeArquivo: nomeArquivo,
        publicadoEm: DateTime.tryParse(dados['published_at'] as String? ?? ''),
        tamanhoBytes: tamanho,
      );
    } catch (_) {
      return ResultadoAtualizacao(versaoAtual: atual, erroRede: true);
    }
  }

  /// Compara versões no formato X.Y.Z (aceita sufixos como "-beta").
  static bool versaoMaior(String candidata, String atual) {
    final a = _partes(candidata);
    final b = _partes(atual);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x > y) return true;
      if (x < y) return false;
    }
    return false;
  }

  static List<int> _partes(String versao) => versao.split('.').map((parte) {
    final match = RegExp(r'^\d+').firstMatch(parte.trim());
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }).toList();

  /// Baixa o pacote da nova versão para a pasta de downloads.
  ///
  /// Devolve o caminho do arquivo salvo, ou `null` em caso de falha.
  Future<String?> baixar(ResultadoAtualizacao resultado) async {
    final url = resultado.urlDownload;
    final nome = resultado.nomeArquivo;
    if (url == null || nome == null) return null;

    try {
      final resposta = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'pdf-enxuto'})
          .timeout(const Duration(minutes: 5));
      if (resposta.statusCode != 200) return null;

      final pasta = await _pastaDownloads();
      final destino = File('$pasta${Platform.pathSeparator}$nome');
      await destino.writeAsBytes(resposta.bodyBytes, flush: true);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _pastaDownloads() async {
    final casa =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final candidata = Directory('$casa${Platform.pathSeparator}Downloads');
    if (await candidata.exists()) return candidata.path;
    final pasta = Directory('$casa${Platform.pathSeparator}pdf_enxuto');
    await pasta.create(recursive: true);
    return pasta.path;
  }
}
