import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pdf_enxuto/core/app_info.dart';
import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/services/servico_atualizacao.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/animacoes.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/seletores.dart';

/// Abre um endereço no navegador do sistema.
Future<void> abrirLink(String url) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Sem navegador disponível: não há o que fazer.
  }
}

/// Diálogo de "novidades" com o resultado da verificação de atualização.
class DialogoNovidades extends StatelessWidget {
  const DialogoNovidades({
    super.key,
    required this.resultado,
    required this.onBaixar,
    required this.onIgnorarVersao,
    required this.onFechar,
  });

  final ResultadoAtualizacao resultado;
  final Future<void> Function() onBaixar;
  final VoidCallback onIgnorarVersao;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final versao = resultado.ultimaVersao ?? '';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cores.gradienteMarca,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${S.appName} $versao',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Você está na ${resultado.versaoAtual}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.atualizacaoNotas,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _NotasMarkdown(texto: resultado.notas ?? ''),
                    if (resultado.tamanhoBytes != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Pacote: ${resultado.nomeArquivo ?? ''} '
                        '(${Fmt.bytes(resultado.tamanhoBytes!)})',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: BotaoGradiente(
                          rotulo: S.atualizacaoBaixar,
                          icone: Icons.download_rounded,
                          expandido: true,
                          onPressed: () => onBaixar(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: onFechar,
                        child: const Text(S.atualizacaoDepois),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: onIgnorarVersao,
                        child: const Text(S.atualizacaoIgnorar),
                      ),
                      TextButton(
                        onPressed: () => abrirLink(AppInfo.releasesListUrl),
                        child: const Text(S.verNovidades),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renderizador simples de markdown para as notas da versão.
class _NotasMarkdown extends StatelessWidget {
  const _NotasMarkdown({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final linhas = texto.split(RegExp(r'\r?\n'));
    final widgets = <Widget>[];

    for (final linha in linhas) {
      final limpa = linha.trimRight();
      if (limpa.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (limpa.startsWith('#')) {
        final titulo = limpa.replaceAll(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              titulo,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        );
        continue;
      }

      final ehItem = RegExp(r'^\s*[-*•]\s+').hasMatch(limpa);
      final conteudo = limpa.replaceFirst(RegExp(r'^\s*[-*•]\s+'), '');

      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: ehItem ? 6 : 0, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ehItem)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.cores.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Expanded(child: _linhaFormatada(context, conteudo, esquema)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _linhaFormatada(
    BuildContext context,
    String texto,
    ColorScheme esquema,
  ) {
    final partes = texto.split(RegExp(r'\*\*|`'));
    final spans = <TextSpan>[];
    for (var i = 0; i < partes.length; i++) {
      if (partes[i].isEmpty) continue;
      final negrito = i.isOdd;
      spans.add(
        TextSpan(
          text: partes[i],
          style: TextStyle(
            fontWeight: negrito ? FontWeight.w700 : FontWeight.w400,
            fontFamily: negrito ? null : null,
            color: esquema.onSurface,
          ),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// Faixa de aviso de nova versão, exibida no topo das telas.
class BannerAtualizacao extends StatelessWidget {
  const BannerAtualizacao({
    super.key,
    required this.versao,
    required this.onVerNovidades,
    required this.onFechar,
  });

  final String versao;
  final VoidCallback onVerNovidades;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cores.accent.withValues(alpha: 0.16),
              cores.accentSecundaria.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cores.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            BrilhoCarregando(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: cores.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                S.atualizacaoBannerTitulo.replaceAll('%s', versao),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: onVerNovidades,
              child: const Text(S.atualizacaoBannerAcao),
            ),
            IconButton(
              onPressed: onFechar,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: S.fechar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo "Sobre", com os links do projeto.
class DialogoSobre extends StatelessWidget {
  const DialogoSobre({
    super.key,
    required this.versao,
    required this.onRelatarProblema,
    required this.onSolicitarRecurso,
  });

  final String versao;
  final VoidCallback onRelatarProblema;
  final VoidCallback onSolicitarRecurso;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: cores.gradienteMarca),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(9),
                    child: Image.asset('assets/icons/icon.png'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.appName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          'Versão $versao',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                AppInfo.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _LinkTiles(
                itens: [
                  (
                    Icons.bug_report_outlined,
                    S.relatarBug,
                    onRelatarProblema,
                    'Conte o que deu errado — vai direto para o desenvolvedor',
                  ),
                  (
                    Icons.lightbulb_outline_rounded,
                    S.solicitarRecurso,
                    onSolicitarRecurso,
                    'Tem uma ideia? Mande que a gente conversa',
                  ),
                  (
                    Icons.code_rounded,
                    S.codigoFonte,
                    () => abrirLink(AppInfo.sourceUrl),
                    'Todo o código está disponível no GitHub',
                  ),
                  (
                    Icons.new_releases_outlined,
                    S.verNovidades,
                    () => abrirLink(AppInfo.releasesListUrl),
                    'Histórico de versões',
                  ),
                  (
                    Icons.gavel_rounded,
                    S.licenca,
                    () => abrirLink(AppInfo.licenseUrl),
                    'GPL-3.0 — livre para usar, estudar e melhorar',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cores.sucesso.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cores.sucesso.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: cores.sucesso,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.privacidade,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: cores.sucesso,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            S.privacidadeTexto,
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.feitoCom,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(S.fechar),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkTiles extends StatelessWidget {
  const _LinkTiles({required this.itens});

  final List<(IconData, String, VoidCallback, String)> itens;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Column(
      children: [
        for (final item in itens)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: item.$3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: esquema.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.$1, size: 19, color: cores.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            item.$4,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: esquema.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: esquema.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Boas-vindas da primeira execução.
class DialogoBoasVindas extends StatelessWidget {
  const DialogoBoasVindas({super.key, required this.onFechar});

  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cores.gradienteMarca,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset('assets/icons/icon.png'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bem-vindo ao ${S.appName}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    S.tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                children: const [
                  _PassoBoasVindas(
                    icone: Icons.compress_rounded,
                    titulo: 'Comprima sem perder o que importa',
                    texto:
                        'Escolha um perfil pronto ou diga o tamanho que precisa. '
                        'O app testa as combinações até caber — mantendo o texto '
                        'selecionável.',
                  ),
                  _PassoBoasVindas(
                    icone: Icons.call_split_rounded,
                    titulo: 'Divida do seu jeito',
                    texto:
                        'Por intervalos, a cada N páginas, por tamanho máximo, '
                        'extraindo páginas ou usando os marcadores do PDF.',
                  ),
                  _PassoBoasVindas(
                    icone: Icons.lock_outline_rounded,
                    titulo: 'Nada sai do seu computador',
                    texto:
                        'Sem conta, sem nuvem, sem anúncios. Seus arquivos são '
                        'lidos e gravados apenas aqui.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              child: BotaoGradiente(
                rotulo: 'Começar a usar',
                icone: Icons.arrow_forward_rounded,
                expandido: true,
                onPressed: onFechar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassoBoasVindas extends StatelessWidget {
  const _PassoBoasVindas({
    required this.icone,
    required this.titulo,
    required this.texto,
  });

  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cores.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, size: 20, color: cores.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: esquema.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso rápido no rodapé da janela.
void mostrarAviso(
  BuildContext context,
  String mensagem, {
  IconData icone = Icons.info_outline_rounded,
  Color? cor,
  SnackBarAction? acao,
  Duration duracao = const Duration(seconds: 4),
}) {
  final cores = context.cores;
  final corFinal = cor ?? cores.accent;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duracao,
        action: acao,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        content: Row(
          children: [
            Icon(icone, color: corFinal, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Monta o bloco de informações técnicas anexado nos e-mails de contato.
String informacoesDoSistema({
  required String versao,
  required String sistema,
  required List<String> motores,
}) {
  return 'PDF Enxuto $versao\n'
      'Sistema: $sistema\n'
      'Motores: ${motores.isEmpty ? 'nenhum externo' : motores.join(', ')}';
}

/// Abre o cliente de e-mail com a mensagem pronta.
///
/// Devolve `false` quando o sistema não tem programa de e-mail configurado —
/// nesse caso a mensagem é copiada para a área de transferência.
Future<bool> abrirEmail({
  required String assunto,
  required String corpo,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppInfo.email,
    query: 'subject=${Uri.encodeComponent(assunto)}'
        '&body=${Uri.encodeComponent(corpo)}',
  );
  try {
    if (await canLaunchUrl(uri)) {
      final abriu = await launchUrl(uri);
      if (abriu) return true;
    }
  } catch (_) {
    // Cai no plano B: copiar a mensagem.
  }
  await Clipboard.setData(ClipboardData(text: '$assunto\n\n$corpo'));
  return false;
}

/// Diálogo para relatar um problema ou pedir um recurso novo.
///
/// A mensagem sai pelo e-mail do desenvolvedor (vandreapps@gmail.com) e já vai
/// com a versão do app e do sistema, o que economiza uma ida e volta.
class DialogoRelato extends StatefulWidget {
  const DialogoRelato({
    super.key,
    required this.informacoesTecnicas,
    this.recurso = false,
  });

  final String informacoesTecnicas;
  final bool recurso;

  @override
  State<DialogoRelato> createState() => _DialogoRelatoState();
}

class _DialogoRelatoState extends State<DialogoRelato> {
  late final TextEditingController _controlador = TextEditingController();
  late bool _recurso = widget.recurso;
  bool _anexarInfo = true;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  String get _assunto => _recurso ? AppInfo.assuntoRecurso : AppInfo.assuntoProblema;

  String _corpo() {
    final buffer = StringBuffer()
      ..writeln(_controlador.text.trim())
      ..writeln()
      ..writeln('---');
    if (_anexarInfo) buffer.writeln(widget.informacoesTecnicas);
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cores.gradienteMarca,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _recurso
                        ? Icons.lightbulb_outline_rounded
                        : Icons.bug_report_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          S.relatarTitulo,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Enviado para ${AppInfo.email}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SeletorSegmentado<bool>(
                      valor: _recurso,
                      onMudar: (valor) => setState(() => _recurso = valor),
                      opcoes: const [
                        OpcaoSegmento(
                          valor: false,
                          rotulo: S.relatarProblemaAba,
                          icone: Icons.bug_report_outlined,
                        ),
                        OpcaoSegmento(
                          valor: true,
                          rotulo: S.relatarRecursoAba,
                          icone: Icons.lightbulb_outline_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _recurso
                          ? S.relatarDicaRecurso
                          : S.relatarDicaProblema,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controlador,
                      minLines: 7,
                      maxLines: 12,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _recurso
                            ? S.relatarDescricaoRecurso
                            : S.relatarDescricaoProblema,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _anexarInfo,
                      onChanged: (valor) =>
                          setState(() => _anexarInfo = valor ?? true),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        S.relatarAnexarInfo,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      subtitle: Text(
                        widget.informacoesTecnicas.replaceAll('\n', ' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: BotaoGradiente(
                          rotulo: S.relatarEnviar,
                          icone: Icons.mail_outline_rounded,
                          expandido: true,
                          onPressed: _enviar,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _copiar,
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text(S.relatarCopiar),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => abrirLink(AppInfo.issuesUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(S.relatarViaGitHub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: '${_assunto}\n\n${_corpo()}'));
    if (!mounted) return;
    mostrarAviso(context, S.relatarCopiado, icone: Icons.copy_rounded);
  }

  Future<void> _enviar() async {
    if (_controlador.text.trim().isEmpty) {
      mostrarAviso(
        context,
        S.relatarVazio,
        icone: Icons.error_outline_rounded,
        cor: context.cores.perigo,
      );
      return;
    }

    final abriu = await abrirEmail(assunto: _assunto, corpo: _corpo());
    if (!mounted) return;

    Navigator.of(context).pop();
    mostrarAviso(
      context,
      abriu ? S.relatarObrigado : S.relatarSemCliente,
      icone: abriu ? Icons.mark_email_read_outlined : Icons.copy_rounded,
      duracao: const Duration(seconds: 6),
    );
  }
}

/// Mostra como instalar um motor opcional (Ghostscript, qpdf).
class DialogoInstalarMotor extends StatelessWidget {
  const DialogoInstalarMotor({
    super.key,
    required this.nome,
    required this.descricao,
    required this.comandos,
    required this.siteOficial,
    required this.onProcurarNovamente,
    this.disponivel = false,
    this.versao,
  });

  final String nome;
  final String descricao;
  final String comandos;
  final String siteOficial;
  final Future<void> Function() onProcurarNovamente;
  final bool disponivel;
  final String? versao;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 660),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: cores.gradienteMarca),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.memory_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.instalacaoTitulo.replaceAll('%s', nome),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Etiqueta(
                          texto: disponivel
                              ? 'Instalado${versao != null ? ' • $versao' : ''}'
                              : S.motorIndisponivelAviso,
                          cor: disponivel ? cores.sucesso : null,
                          compacta: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(descricao, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cores.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cores.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 17, color: cores.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        S.instalacaoExplicacao,
                        style: const TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                S.comoInstalar,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  comandos,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.instalacaoSemPermissao,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: comandos));
                      if (!context.mounted) return;
                      mostrarAviso(
                        context,
                        S.comandoCopiado,
                        icone: Icons.copy_rounded,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text(S.copiarComando),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => abrirLink(siteOficial),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text(S.paginaSiteOficial),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await onProcurarNovamente();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.search_rounded, size: 17),
                    label: const Text(S.revalidarMotores),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(S.fechar),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
