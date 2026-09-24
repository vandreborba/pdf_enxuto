import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/models/compression_options.dart';
import 'package:pdf_enxuto/models/page_range.dart';
import 'package:pdf_enxuto/models/pdf_file_info.dart';
import 'package:pdf_enxuto/models/task_models.dart';
import 'package:pdf_enxuto/services/servico_arquivos.dart';
import 'package:pdf_enxuto/services/servico_atualizacao.dart';
import 'package:pdf_enxuto/services/servico_divisao.dart';

void main() {
  group('Leitura de intervalos', () {
    test('entende listas simples', () {
      final resultado = PageRangeParser.parse('1-3, 7, 10-12', totalPaginas: 20);

      expect(resultado.valido, isTrue);
      expect(resultado.intervalos.length, 3);
      expect(resultado.intervalos.first.rotulo, '1-3');
      expect(resultado.intervalos[1].rotulo, '7');
      expect(resultado.totalPaginas, 3 + 1 + 3);
    });

    test('aceita intervalo aberto no fim e no começo', () {
      expect(
        PageRangeParser.parse('5-', totalPaginas: 12).intervalos.single.rotulo,
        '5-12',
      );
      expect(
        PageRangeParser.parse('-4', totalPaginas: 12).intervalos.single.rotulo,
        '1-4',
      );
    });

    test('aceita ponto e vírgula e espaços extras', () {
      final resultado = PageRangeParser.parse(' 1-2 ; 4 ,, 6 ', totalPaginas: 10);
      expect(resultado.intervalos.length, 3);
      expect(resultado.erros, isEmpty);
    });

    test('limita ao total de páginas e avisa', () {
      final resultado = PageRangeParser.parse('1-999', totalPaginas: 8);
      expect(resultado.intervalos.single.fim, 8);
      expect(resultado.aviso, isNotNull);
    });

    test('reclama de coisas inválidas', () {
      expect(PageRangeParser.parse('abc').erros, isNotEmpty);
      expect(PageRangeParser.parse('5-2').erros, isNotEmpty);
      expect(PageRangeParser.parse('0').erros, isNotEmpty);
      expect(
        PageRangeParser.parse('99', totalPaginas: 10).erros,
        isNotEmpty,
      );
    });

    test('divide em partes iguais', () {
      final partes = PageRangeParser.cadaNPaginas(10, 4);
      expect(partes.length, 3);
      expect(partes.last.rotulo, '9-10');
    });

    test('normaliza intervalos sobrepostos', () {
      final unidos = PageRangeParser.normalizar(const [
        PageRange(5, 8),
        PageRange(1, 3),
        PageRange(4, 5),
      ]);
      expect(unidos.length, 1);
      expect(unidos.single.rotulo, '1-8');
    });
  });

  group('Plano de divisão', () {
    PdfFileInfo arquivo({int paginas = 20, int bytes = 20 * 1024 * 1024}) =>
        PdfFileInfo(caminho: '/tmp/relatorio.pdf', bytes: bytes, paginas: paginas);

    test('por intervalos gera uma parte por intervalo', () {
      final plano = ServicoDivisao.montarPlano(
        arquivo: arquivo(),
        opcoes: const SplitOptions(
          metodo: SplitMethod.intervalos,
          intervalosTexto: '1-3, 7, 10-12',
        ),
      );

      expect(plano.valido, isTrue);
      expect(plano.partes.length, 3);
      expect(plano.partes.first.nomeSugerido, contains('parte 1'));
      expect(plano.partes.first.paginas, 3);
    });

    test('uma página por arquivo', () {
      final plano = ServicoDivisao.montarPlano(
        arquivo: arquivo(paginas: 4),
        opcoes: const SplitOptions(
          metodo: SplitMethod.cadaN,
          paginasPorParte: 1,
        ),
      );
      expect(plano.partes.length, 4);
      expect(plano.partes.every((parte) => parte.paginas == 1), isTrue);
    });

    test('por tamanho respeita o limite estimado', () {
      final plano = ServicoDivisao.montarPlano(
        arquivo: arquivo(paginas: 20, bytes: 20 * 1024 * 1024),
        opcoes: const SplitOptions(
          metodo: SplitMethod.porTamanho,
          maxBytes: 5 * 1024 * 1024,
        ),
      );
      // 1 MB por página e limite de 5 MB → 5 páginas por parte.
      expect(plano.partes.length, 4);
      expect(plano.partes.first.paginas, 5);
    });

    test('extrair junta as páginas em um arquivo', () {
      final plano = ServicoDivisao.montarPlano(
        arquivo: arquivo(),
        opcoes: const SplitOptions(
          metodo: SplitMethod.extrair,
          extrairTexto: '1, 4, 9-12',
          umArquivoSo: true,
        ),
      );
      expect(plano.valido, isTrue);
      expect(plano.partes.length, 1);
      expect(plano.partes.first.paginas, 6);
    });

    test('por marcadores usa o sumário do PDF', () {
      final comMarcadores = PdfFileInfo(
        caminho: '/tmp/livro.pdf',
        bytes: 1024,
        paginas: 10,
        marcadores: const [
          PdfBookmark(titulo: 'Capítulo 1', pagina: 1),
          PdfBookmark(titulo: 'Capítulo 2', pagina: 6),
        ],
      );

      final plano = ServicoDivisao.montarPlano(
        arquivo: comMarcadores,
        opcoes: const SplitOptions(metodo: SplitMethod.marcadores),
      );

      expect(plano.partes.length, 2);
      expect(plano.partes.first.rotuloPaginas, '1-5');
      expect(plano.partes.last.rotuloPaginas, '6-10');
    });

    test('sem marcadores, avisa que não dá', () {
      final plano = ServicoDivisao.montarPlano(
        arquivo: arquivo(),
        opcoes: const SplitOptions(metodo: SplitMethod.marcadores),
      );
      expect(plano.valido, isFalse);
      expect(plano.erros, isNotEmpty);
    });
  });

  group('Nomes de arquivo', () {
    test('aplica as variáveis do padrão', () {
      final nome = ServicoArquivos.nomeDaParte(
        padrao: '{nome} - parte {parte} ({inicio}-{fim}) com {paginas}p',
        nomeBase: 'contrato',
        parte: 2,
        inicio: 11,
        fim: 20,
        paginas: 10,
      );
      expect(nome, 'contrato - parte 2 (11-20) com 10p');
    });

    test('limpa caracteres proibidos', () {
      final nome = ServicoArquivos.nomeDaParte(
        padrao: 'a/b:c*?"<>|{parte}',
        nomeBase: 'x',
        parte: 1,
        inicio: 1,
        fim: 1,
        paginas: 1,
      );
      expect(nome.contains('/'), isFalse);
      expect(nome.contains(':'), isFalse);
      expect(nome.contains('*'), isFalse);
    });
  });

  group('Comparação de versões', () {
    test('reconhece versões maiores', () {
      expect(ServicoAtualizacao.versaoMaior('1.2.0', '1.1.9'), isTrue);
      expect(ServicoAtualizacao.versaoMaior('1.0.1', '1.0.10'), isFalse);
      expect(ServicoAtualizacao.versaoMaior('2.0.0', '1.9.9'), isTrue);
      expect(ServicoAtualizacao.versaoMaior('1.0.0', '1.0.0'), isFalse);
      expect(ServicoAtualizacao.versaoMaior('1.1.0-beta', '1.0.5'), isTrue);
    });
  });

  group('Formatação', () {
    test('tamanhos em português', () {
      expect(Fmt.bytes(0), '0 B');
      expect(Fmt.bytes(512), '512 B');
      expect(Fmt.bytes(1536), '1,5 KB');
      expect(Fmt.bytes(5 * 1024 * 1024), '5 MB');
      expect(Fmt.bytes(12884901888), '12 GB');
    });

    test('redução percentual', () {
      expect(Fmt.reducao(1000, 250), '75%');
      expect(Fmt.reducao(1000, 1000), '0%');
      expect(Fmt.reducao(1000, 999), '0,1%');
      expect(Fmt.reducao(100000, 99999), '<0,1%');
    });

    test('lê tamanho digitado pelo usuário', () {
      expect(Fmt.parseTamanho('5'), 5 * 1024 * 1024);
      expect(Fmt.parseTamanho('5mb'), 5 * 1024 * 1024);
      expect(Fmt.parseTamanho('1,5 GB'), (1.5 * 1024 * 1024 * 1024).round());
      expect(Fmt.parseTamanho('500 KB'), 500 * 1024);
      expect(Fmt.parseTamanho(''), isNull);
      expect(Fmt.parseTamanho('abc'), isNull);
      expect(Fmt.parseTamanho('-3'), isNull);
    });

    test('plural em português', () {
      expect(Fmt.paginas(1), '1 página');
      expect(Fmt.paginas(2), '2 páginas');
      expect(Fmt.arquivos(1), '1 arquivo');
      expect(Fmt.partes(3), '3 partes');
    });

    test('durações legíveis', () {
      expect(Fmt.duracao(const Duration(milliseconds: 350)), '350 ms');
      expect(Fmt.duracao(const Duration(seconds: 5)), '5 s');
      expect(Fmt.duracao(const Duration(seconds: 125)), '2 min 5 s');
    });
  });

  group('Preferências', () {
    test('vai e volta do JSON sem perder nada', () {
      const original = CompressionOptions(
        preset: CompressionPreset.forte,
        textMode: TextMode.rasterizar,
        engine: EngineKind.ghostscript,
        modo: CompressionMode.porTamanho,
        targetBytes: 3 * 1024 * 1024,
        targetScope: TargetScope.total,
        dpi: 120,
        jpegQuality: 70,
        colorMode: ColorMode.cinza,
        removeAnnotations: false,
      );
      final json = original.toJson();

      expect(json['preset'], 'forte');
      expect(json['textMode'], 'rasterizar');
      expect(json['engine'], 'ghostscript');
      expect(json['targetBytes'], 3 * 1024 * 1024);
      expect(json['cor'], 'cinza');
    });

    test('os dois modos são separados: perfil ou tamanho alvo', () {
      const base = CompressionOptions();
      expect(base.modo, CompressionMode.porPerfil);
      expect(base.targetEnabled, isFalse);

      final comAlvo = base.copyWith(
        modo: CompressionMode.porTamanho,
        targetBytes: 4 * 1024 * 1024,
      );
      expect(comAlvo.targetEnabled, isTrue);
      // O modo alvo não usa o perfil como ponto de partida: a busca começa
      // sempre na melhor qualidade.
      final partida = comAlvo.partidaDaBusca(rasterizando: false);
      expect(partida.dpi, 300);
      expect(partida.jpegQuality, 92);
      final partidaImagem = comAlvo.partidaDaBusca(rasterizando: true);
      expect(partidaImagem.dpi, 200);
    });

    test('a faixa da busca respeita o piso de qualidade', () {
      const comAlvo = CompressionOptions(
        modo: CompressionMode.porTamanho,
        dpi: 300,
        jpegQuality: 92,
        qualidadeMinima: 0.5,
      );
      final faixa = comAlvo.faixaDoAlvo;
      expect(faixa.dpiInicial, 300);
      expect(faixa.jpegInicial, 92);
      // Piso de 50%: 72 + (300-72)*0.5 = 186 dpi e 30 + (92-30)*0.5 = 61
      expect(faixa.dpiFinal, 186);
      expect(faixa.jpegFinal, 61);

      const semPiso = CompressionOptions(
        modo: CompressionMode.porTamanho,
        dpi: 300,
        qualidadeMinima: 0,
      );
      expect(semPiso.faixaDoAlvo.dpiFinal, 84); // 300 * 0.28
    });

    test('o modo é gravado e o formato antigo continua sendo lido', () {
      final json = const CompressionOptions(
        modo: CompressionMode.porTamanho,
        targetBytes: 2 * 1024 * 1024,
      ).toJson();
      expect(json['modo'], 'porTamanho');
      expect(
        CompressionOptions.fromJson(json).modo,
        CompressionMode.porTamanho,
      );

      // Configuração antiga, gravada antes do seletor de modo.
      final antigo = CompressionOptions.fromJson(const {
        'preset': 'forte',
        'target': true,
        'targetBytes': 3145728,
      });
      expect(antigo.modo, CompressionMode.porTamanho);
      expect(antigo.targetBytes, 3145728);
    });

    test('aplicar um perfil mantém as escolhas fora do perfil', () {
      const base = CompressionOptions(
        textMode: TextMode.rasterizar,
        modo: CompressionMode.porTamanho,
        targetBytes: 2 * 1024 * 1024,
        removeAnnotations: true,
      );

      final forte = base.comPreset(CompressionPreset.forte);

      expect(forte.preset, CompressionPreset.forte);
      expect(forte.dpi, 120);
      expect(forte.jpegQuality, 68);
      expect(forte.textMode, TextMode.rasterizar);
      expect(forte.targetEnabled, isTrue);
      expect(forte.targetBytes, 2 * 1024 * 1024);
      expect(forte.removeAnnotations, isTrue);
    });
  });
}
