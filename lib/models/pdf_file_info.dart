import 'dart:io';

import 'package:pdf_enxuto/models/page_range.dart';

/// Um marcador (bookmark) do PDF, usado para dividir por capítulos.
class PdfBookmark {
  const PdfBookmark({required this.titulo, required this.pagina, this.nivel = 0});

  final String titulo;

  /// Página onde o marcador começa (1 = primeira).
  final int pagina;
  final int nivel;

  @override
  String toString() => '$titulo (pág. $pagina)';
}

/// O que sabemos sobre um PDF depois de abri-lo.
class PdfFileInfo {
  const PdfFileInfo({
    required this.caminho,
    required this.bytes,
    required this.paginas,
    this.criptografado = false,
    this.erro,
    this.marcadores = const [],
    this.titulo,
    this.autor,
    this.produtor,
    this.aviso,
  });

  final String caminho;
  final int bytes;
  final int paginas;
  final bool criptografado;
  final String? erro;
  final List<PdfBookmark> marcadores;
  final String? titulo;
  final String? autor;
  final String? produtor;

  /// Observação para o usuário (ex.: "o arquivo estava em base64").
  final String? aviso;

  bool get ok => erro == null && !criptografado && paginas > 0;

  String get nome => caminho.split(Platform.pathSeparator).last;

  String get nomeSemExtensao {
    final n = nome;
    final ponto = n.lastIndexOf('.');
    return ponto > 0 ? n.substring(0, ponto) : n;
  }

  String get pasta {
    final indice = caminho.lastIndexOf(Platform.pathSeparator);
    return indice > 0 ? caminho.substring(0, indice) : caminho;
  }

  /// Tamanho médio de cada página — base para prever a divisão por tamanho.
  double get bytesPorPagina => paginas > 0 ? bytes / paginas : bytes.toDouble();

  List<PageRange> get intervaloCompleto =>
      paginas > 0 ? [PageRange(1, paginas)] : const [];

  PdfFileInfo copyWith({
    String? caminho,
    int? bytes,
    int? paginas,
    bool? criptografado,
    String? erro,
    List<PdfBookmark>? marcadores,
    String? aviso,
  }) {
    return PdfFileInfo(
      caminho: caminho ?? this.caminho,
      bytes: bytes ?? this.bytes,
      paginas: paginas ?? this.paginas,
      criptografado: criptografado ?? this.criptografado,
      erro: erro ?? this.erro,
      marcadores: marcadores ?? this.marcadores,
      titulo: titulo,
      autor: autor,
      produtor: produtor,
      aviso: aviso ?? this.aviso,
    );
  }

  static PdfFileInfo comErro(String caminho, String mensagem) => PdfFileInfo(
        caminho: caminho,
        bytes: 0,
        paginas: 0,
        erro: mensagem,
      );
}
