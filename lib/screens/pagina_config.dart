import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pdf_enxuto/core/app_info.dart';
import 'package:pdf_enxuto/core/app_strings.dart';
import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/core/sistema.dart';
import 'package:pdf_enxuto/state/app_state.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';
import 'package:pdf_enxuto/widgets/dialogos.dart';
import 'package:pdf_enxuto/widgets/seletores.dart';

/// Tela de configurações, organizada em cartões por assunto.
class PaginaConfiguracoes extends StatelessWidget {
  const PaginaConfiguracoes({super.key, required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final config = estado.config;
    final cores = context.cores;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CartaoSecao(
            titulo: S.aparencia,
            icone: Icons.palette_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.tema, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                SeletorSegmentado<ThemeMode>(
                  valor: config.tema,
                  onMudar: (modo) =>
                      estado.atualizarConfig(config.copyWith(tema: modo)),
                  opcoes: const [
                    OpcaoSegmento(
                      valor: ThemeMode.system,
                      rotulo: S.temaSistema,
                      icone: Icons.brightness_auto_rounded,
                    ),
                    OpcaoSegmento(
                      valor: ThemeMode.light,
                      rotulo: S.temaClaro,
                      icone: Icons.light_mode_rounded,
                    ),
                    OpcaoSegmento(
                      valor: ThemeMode.dark,
                      rotulo: S.temaEscuro,
                      icone: Icons.dark_mode_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  S.corDestaque,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < AccentPalette.todas.length; i++)
                      _BolhaCor(
                        paleta: AccentPalette.todas[i],
                        selecionada: config.corDestaque == i,
                        onTap: () => estado.atualizarConfig(
                          config.copyWith(corDestaque: i),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                LinhaOpcao(
                  titulo: S.animacoesReduzidas,
                  descricao: S.animacoesReduzidasDica,
                  valor: config.reduzirAnimacoes,
                  onMudar: (valor) => estado.atualizarConfig(
                    config.copyWith(reduzirAnimacoes: valor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CartaoSecao(
            titulo: 'Arquivos e avisos',
            icone: Icons.folder_special_outlined,
            atraso: const Duration(milliseconds: 40),
            child: Column(
              children: [
                LinhaOpcao(
                  titulo: S.abrirPastaAoTerminar,
                  descricao: 'Abre o gerenciador de arquivos com o resultado',
                  valor: config.abrirPastaAoTerminar,
                  onMudar: (valor) => estado.atualizarConfig(
                    config.copyWith(abrirPastaAoTerminar: valor),
                  ),
                ),
                LinhaOpcao(
                  titulo: S.notificarAoTerminar,
                  descricao: 'Notificação do sistema quando a fila acabar',
                  valor: config.notificarAoTerminar,
                  onMudar: (valor) => estado.atualizarConfig(
                    config.copyWith(notificarAoTerminar: valor),
                  ),
                ),
                LinhaOpcao(
                  titulo: S.sobrescrever,
                  descricao: S.sobrescreverDica,
                  valor: config.sobrescrever,
                  onMudar: (valor) => estado.atualizarConfig(
                    config.copyWith(sobrescrever: valor),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cores.sucesso.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: cores.sucesso,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'O PDF Enxuto nunca altera nem apaga os arquivos '
                          'originais: ele sempre cria um arquivo novo.',
                          style: TextStyle(fontSize: 12.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CartaoSecao(
            titulo: S.desempenho,
            icone: Icons.speed_rounded,
            ajuda: Ajuda.paralelismo,
            atraso: const Duration(milliseconds: 80),
            child: Column(
              children: [
                LinhaOpcao(
                  titulo: S.processarEmParalelo,
                  descricao:
                      'Este computador tem ${Sistema.nucleos} núcleos disponíveis',
                  valor: config.processarEmParalelo,
                  onMudar: (valor) => estado.atualizarConfig(
                    config.copyWith(processarEmParalelo: valor),
                  ),
                ),
                Aparecer(
                  visivel: config.processarEmParalelo,
                  child: LinhaSlider(
                    titulo: S.simultaneos,
                    descricao: S.simultaneosDica,
                    valor: config.simultaneos.toDouble(),
                    minimo: 1,
                    maximo: 8,
                    formatar: (valor) => '${valor.round()}',
                    onMudar: (valor) => estado.atualizarConfig(
                      config.copyWith(simultaneos: valor.round()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CartaoAtualizacoes(estado: estado),
          const SizedBox(height: 16),
          _CartaoMotores(estado: estado),
          const SizedBox(height: 16),
          CartaoSecao(
            titulo: S.sobre,
            icone: Icons.info_outline_rounded,
            atraso: const Duration(milliseconds: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppInfo.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _abrirRelato(context, estado),
                      icon: const Icon(Icons.bug_report_outlined, size: 18),
                      label: const Text(S.relatarBug),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _abrirRelato(context, estado, recurso: true),
                      icon: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(S.solicitarRecurso),
                    ),
                    _BotaoLink(
                      rotulo: S.codigoFonte,
                      icone: Icons.code_rounded,
                      url: AppInfo.sourceUrl,
                    ),
                    _BotaoLink(
                      rotulo: S.licenca,
                      icone: Icons.gavel_rounded,
                      url: AppInfo.licenseUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 15,
                      color: esquema.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Contato direto: ${AppInfo.email}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  S.feitoCom,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

/// Abre o formulário de contato (problema ou sugestão).
Future<void> _abrirRelato(
  BuildContext context,
  AppState estado, {
  bool recurso = false,
}) {
  final motores = estado.motores.todos
      .where((motor) => motor.disponivel)
      .map(
        (motor) =>
            '${motor.nome}${motor.estado.versao != null ? ' ${motor.estado.versao}' : ''}',
      )
      .toList();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => DialogoRelato(
      recurso: recurso,
      informacoesTecnicas: informacoesDoSistema(
        versao: estado.versaoApp,
        sistema: Platform.operatingSystemVersion,
        motores: motores,
      ),
    ),
  );
}

class _BolhaCor extends StatelessWidget {
  const _BolhaCor({
    required this.paleta,
    required this.selecionada,
    required this.onTap,
  });

  final AccentPalette paleta;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: paleta.nome,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.escolher(context, Motion.media),
          curve: Motion.entrada,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: paleta.cor,
            shape: BoxShape.circle,
            border: Border.all(
              color: selecionada
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: AnimatedScale(
            scale: selecionada ? 1 : 0,
            duration: Motion.escolher(context, Motion.media),
            curve: Motion.elastica,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoLink extends StatelessWidget {
  const _BotaoLink({
    required this.rotulo,
    required this.icone,
    required this.url,
  });

  final String rotulo;
  final IconData icone;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => abrirLink(url),
      icon: Icon(icone, size: 18),
      label: Text(rotulo),
    );
  }
}

class _CartaoAtualizacoes extends StatelessWidget {
  const _CartaoAtualizacoes({required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final config = estado.config;
    final ultima = config.ultimaVerificacao;

    return CartaoSecao(
      titulo: S.atualizacoes,
      icone: Icons.system_update_rounded,
      ajuda: Ajuda.autoUpdate,
      atraso: const Duration(milliseconds: 100),
      acao: OutlinedButton.icon(
        onPressed: estado.verificandoAtualizacao
            ? null
            : () => estado.verificarAtualizacao(),
        icon: estado.verificandoAtualizacao
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(
          estado.verificandoAtualizacao ? S.verificando : S.verificarAgora,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinhaOpcao(
            titulo: S.verificarAoAbrir,
            valor: config.verificarAtualizacoes,
            onMudar: (valor) => estado.atualizarConfig(
              config.copyWith(verificarAtualizacoes: valor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 15,
                color: esquema.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${S.ultimaVerificacao}: '
                '${ultima == null ? S.nuncaVerificado : Fmt.duracaoAtras(ultima)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (estado.resultadoAtualizacao?.temAtualizacao == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cores.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: cores.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Versão ${estado.resultadoAtualizacao!.ultimaVersao} '
                      'disponível',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: estado.abrirNovidades,
                    child: const Text(S.verNovidades),
                  ),
                ],
              ),
            ),
          ],
          if (config.avisosDesligados || config.versaoIgnorada != null) ...[
            const SizedBox(height: 8),
            Text(
              S.atualizacoesDesligadas,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => estado.atualizarConfig(
                config.copyWith(
                  avisosDesligados: false,
                  limparVersaoIgnorada: true,
                ),
              ),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text(S.reativarAvisos),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartaoMotores extends StatelessWidget {
  const _CartaoMotores({required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return CartaoSecao(
      titulo: S.motoresInstalados,
      subtitulo: S.motoresDescricao,
      icone: Icons.memory_rounded,
      ajuda: Ajuda.motores,
      atraso: const Duration(milliseconds: 110),
      acao: TextButton.icon(
        onPressed: estado.procurarMotoresNovamente,
        icon: const Icon(Icons.search_rounded, size: 18),
        label: const Text(S.revalidarMotores),
      ),
      child: Column(
        children: [
          for (final motor in estado.motores.todos)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: motor.disponivel
                      ? cores.sucesso.withValues(alpha: 0.35)
                      : esquema.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: motor.disponivel
                              ? cores.sucesso
                              : esquema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        motor.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Etiqueta(
                        texto: motor.disponivel
                            ? '${S.motorInstalado}'
                                  '${motor.estado.versao != null ? ' • ${motor.estado.versao}' : ''}'
                            : S.motorNaoEncontrado,
                        cor: motor.disponivel ? cores.sucesso : null,
                        compacta: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    motor.descricao,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => DialogoInstalarMotor(
                            nome: motor.nome,
                            descricao: motor.descricao,
                            comandos: motor.comoInstalar,
                            siteOficial: motor.siteOficial,
                            disponivel: motor.disponivel,
                            versao: motor.estado.versao,
                            onProcurarNovamente:
                                estado.procurarMotoresNovamente,
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: Text(
                          motor.disponivel ? S.comoInstalar : S.comoInstalar,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: motor.comoInstalar),
                          );
                          if (!context.mounted) return;
                          mostrarAviso(
                            context,
                            S.comandoCopiado,
                            icone: Icons.copy_rounded,
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(S.copiarComando),
                      ),
                      const Spacer(),
                      if (motor.disponivel)
                        Etiqueta(
                          texto: S.motorEmUso,
                          cor: cores.sucesso,
                          compacta: true,
                          icone: Icons.check_circle_outline_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
