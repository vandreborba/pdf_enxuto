import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:pdf_enxuto/core/cancelamento.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/services/pdf/paginas_imagem.dart';

/// O que o Tesseract leu de uma página.
class PaginaReconhecida {
  const PaginaReconhecida({
    required this.palavras,
    required this.texto,
    required this.confianca,
  });

  /// Palavras com posição, em pixels da imagem lida.
  final List<PalavraPagina> palavras;

  /// Texto corrido da página, com parágrafos separados por linha em branco.
  final String texto;

  /// Confiança média (0 a 100); `null` quando nada foi reconhecido.
  final double? confianca;

  bool get vazia => palavras.isEmpty;
}

/// Estado do motor de OCR: onde está e o que sabe ler.
class EstadoOcr {
  const EstadoOcr({
    required this.disponivel,
    this.caminho,
    this.versao,
    this.embutido = false,
    this.idiomas = const [],
    this.erro,
  });

  const EstadoOcr.indisponivel([this.erro])
    : disponivel = false,
      caminho = null,
      versao = null,
      embutido = false,
      idiomas = const [];

  final bool disponivel;
  final String? caminho;
  final String? versao;

  /// `true` quando é o Tesseract que vem dentro do pacote do app.
  final bool embutido;

  /// Códigos dos idiomas instalados (sem o `osd`).
  final List<String> idiomas;
  final String? erro;
}

/// Motor de reconhecimento de texto (Tesseract).
///
/// Procura primeiro o que vem dentro do pacote do app (pasta `ocr` ao lado do
/// executável) e só depois o que estiver instalado no sistema — o app funciona
/// sem instalar nada, mas aproveita um Tesseract que o usuário já tenha.
class MotorTesseract {
  MotorTesseract();

  EstadoOcr _estado = const EstadoOcr.indisponivel('ainda não procurado');
  String? _pastaDados;
  Map<String, String> _ambiente = const {};

  EstadoOcr get estado => _estado;

  /// Injeta um estado pronto — usado pelas capturas de tela dos testes, que
  /// não procuram o Tesseract de verdade.
  @visibleForTesting
  void definirEstado(EstadoOcr estado) => _estado = estado;
  bool get disponivel => _estado.disponivel;

  String get nome => 'Tesseract';

  String get comoInstalar => Sistema.ehWindows
      ? 'Baixe o instalador do Tesseract em github.com/UB-Mannheim/tesseract/wiki '
            'e marque o idioma Português durante a instalação.'
      : 'Debian/Ubuntu: sudo apt install tesseract-ocr tesseract-ocr-por\n'
            'Fedora: sudo dnf install tesseract tesseract-langpack-por\n'
            'Arch: sudo pacman -S tesseract tesseract-data-por';

  static const String siteOficial = 'https://github.com/tesseract-ocr/tesseract';

  /// Pasta `ocr` que acompanha o executável do app.
  static Directory get pastaEmbutida {
    final executavel = File(Platform.resolvedExecutable);
    return Directory(
      '${executavel.parent.path}${Platform.pathSeparator}ocr',
    );
  }

  Future<EstadoOcr> detectar({bool forcar = false}) async {
    if (_estado.disponivel && !forcar) return _estado;

    final embutido = _procurarEmbutido();
    if (embutido != null) {
      final estado = await _sondar(
        embutido.$1,
        embutido: true,
        pastaDados: embutido.$2,
        ambiente: embutido.$3,
      );
      if (estado.disponivel) return _estado = estado;
    }

    final caminho = await Sistema.procurarPrograma(['tesseract']);
    if (caminho == null) {
      return _estado = const EstadoOcr.indisponivel(
        'o Tesseract não foi encontrado',
      );
    }
    return _estado = await _sondar(
      caminho,
      embutido: false,
      pastaDados: null,
      ambiente: const {},
    );
  }

  /// (executável, pasta de idiomas, variáveis de ambiente) do pacote do app.
  (String, String, Map<String, String>)? _procurarEmbutido() {
    final pasta = pastaEmbutida;
    final binario = File(
      '${pasta.path}${Platform.pathSeparator}'
      '${Sistema.ehWindows ? 'tesseract.exe' : 'tesseract'}',
    );
    if (!binario.existsSync()) return null;
    final dados = '${pasta.path}${Platform.pathSeparator}tessdata';
    final bibliotecas = '${pasta.path}${Platform.pathSeparator}lib';
    return (
      binario.path,
      dados,
      {
        if (Sistema.ehLinux && Directory(bibliotecas).existsSync())
          'LD_LIBRARY_PATH': [
            bibliotecas,
            if (Platform.environment['LD_LIBRARY_PATH'] case final atual?)
              if (atual.isNotEmpty) atual,
          ].join(':'),
      },
    );
  }

  Future<EstadoOcr> _sondar(
    String caminho, {
    required bool embutido,
    required String? pastaDados,
    required Map<String, String> ambiente,
  }) async {
    try {
      final versao = await Process.run(
        caminho,
        ['--version'],
        environment: ambiente,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      // Algumas versões escrevem a versão na saída de erro.
      final texto = '${versao.stdout}\n${versao.stderr}'.trim();
      if (versao.exitCode != 0 || !texto.toLowerCase().contains('tesseract')) {
        return EstadoOcr(
          disponivel: false,
          caminho: caminho,
          erro: 'encontrado, mas não respondeu',
        );
      }

      final lista = await Process.run(
        caminho,
        [
          if (pastaDados != null) ...['--tessdata-dir', pastaDados],
          '--list-langs',
        ],
        environment: ambiente,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final idiomas = <String>[
        for (final linha in '${lista.stdout}'.split(RegExp(r'\r?\n')))
          if (RegExp(r'^[A-Za-z_]+$').hasMatch(linha.trim()) &&
              linha.trim() != 'osd')
            linha.trim(),
      ];

      _pastaDados = pastaDados;
      _ambiente = ambiente;
      final primeira = texto.split(RegExp(r'\r?\n')).first;
      return EstadoOcr(
        disponivel: idiomas.isNotEmpty,
        caminho: caminho,
        versao: RegExp(r'\d+(\.\d+)+').firstMatch(primeira)?.group(0),
        embutido: embutido,
        idiomas: idiomas,
        erro: idiomas.isEmpty
            ? 'nenhum idioma instalado (falta o pacote de idiomas)'
            : null,
      );
    } catch (erro) {
      return EstadoOcr(disponivel: false, caminho: caminho, erro: '$erro');
    }
  }

  /// Lê o texto de uma imagem (PGM, PNG…) e devolve palavras com posição.
  ///
  /// Um processo por página: o Tesseract é mais estável assim, e dá para
  /// rodar várias páginas ao mesmo tempo (uma thread por processo).
  Future<PaginaReconhecida> reconhecer({
    required String imagem,
    required String idiomas,
    required int psm,
    required int dpi,
    required Cancelamento cancelamento,
  }) async {
    cancelamento.verificar();
    final binario = _estado.caminho;
    if (!_estado.disponivel || binario == null) {
      throw StateError('Tesseract indisponível');
    }

    final processo = await Process.start(
      binario,
      [
        imagem,
        'stdout',
        '-l',
        idiomas,
        '--psm',
        '$psm',
        '--dpi',
        '$dpi',
        if (_pastaDados != null) ...['--tessdata-dir', _pastaDados!],
        'tsv',
      ],
      environment: {..._ambiente, 'OMP_THREAD_LIMIT': '1'},
    );

    final inscricao = cancelamento.quandoCancelar.listen(
      (_) => processo.kill(),
    );
    try {
      final saida = processo.stdout.transform(utf8.decoder).join();
      final erro = processo.stderr.transform(utf8.decoder).join();
      final codigo = await processo.exitCode;
      cancelamento.verificar();
      final tsv = await saida;
      if (codigo != 0) {
        final detalhe = (await erro).trim();
        throw ProcessException(
          binario,
          const [],
          detalhe.isEmpty ? 'código $codigo' : detalhe,
          codigo,
        );
      }
      return interpretarTsv(tsv);
    } finally {
      await inscricao.cancel();
    }
  }

  /// Transforma a saída `tsv` do Tesseract em palavras e texto corrido.
  ///
  /// Fica estático e sem E/S para ser testável sem o Tesseract instalado.
  static PaginaReconhecida interpretarTsv(String tsv) {
    // Colunas: level page block par line word left top width height conf text
    final palavras = <PalavraPagina>[];
    final texto = StringBuffer();
    var somaConfianca = 0.0;
    var contagem = 0;

    // Altura e base da linha corrente (nível 4), aplicadas às palavras dela.
    var alturaLinha = 0.0;
    var baseLinha = 0.0;
    String? linhaAtual;
    String? paragrafoAtual;

    for (final bruta in tsv.split(RegExp(r'\r?\n')).skip(1)) {
      final campos = bruta.split('\t');
      if (campos.length < 12) continue;

      final nivel = int.tryParse(campos[0]);
      if (nivel != 4 && nivel != 5) continue;
      final esquerda = double.tryParse(campos[6]) ?? 0;
      final topo = double.tryParse(campos[7]) ?? 0;
      final largura = double.tryParse(campos[8]) ?? 0;
      final altura = double.tryParse(campos[9]) ?? 0;
      final linha = '${campos[2]}.${campos[3]}.${campos[4]}';

      // A caixa da linha inclui as caudas (g, p, q): a base fica um pouco
      // acima do fundo da caixa.
      if (nivel == 4) {
        alturaLinha = altura;
        baseLinha = topo + altura * 0.82;
        continue;
      }

      final conteudo = campos.sublist(11).join('\t').trim();
      if (conteudo.isEmpty) continue;
      final confianca = double.tryParse(campos[10]) ?? -1;
      if (confianca >= 0) {
        somaConfianca += confianca;
        contagem++;
      }

      final paragrafo = '${campos[2]}.${campos[3]}';
      if (texto.isNotEmpty) {
        if (paragrafo != paragrafoAtual) {
          texto.write('\n\n');
        } else if (linha != linhaAtual) {
          texto.write('\n');
        } else {
          texto.write(' ');
        }
      }
      texto.write(conteudo);
      linhaAtual = linha;
      paragrafoAtual = paragrafo;

      palavras.add(
        PalavraPagina(
          texto: conteudo,
          x: esquerda,
          largura: largura,
          baseY: alturaLinha > 0 ? baseLinha : topo + altura * 0.82,
          alturaLinha: alturaLinha > 0 ? alturaLinha : altura,
        ),
      );
    }

    return PaginaReconhecida(
      palavras: palavras,
      texto: texto.toString().trim(),
      confianca: contagem == 0 ? null : somaConfianca / contagem,
    );
  }
}
