import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pdf_enxuto/core/formatting.dart';
import 'package:pdf_enxuto/theme/app_theme.dart';
import 'package:pdf_enxuto/widgets/base.dart';

/// Uma opção do seletor segmentado.
class OpcaoSegmento<T> {
  const OpcaoSegmento({
    required this.valor,
    required this.rotulo,
    this.icone,
    this.descricao,
  });

  final T valor;
  final String rotulo;
  final IconData? icone;
  final String? descricao;
}

/// Seletor com "pílula" animada deslizando até a opção escolhida.
class SeletorSegmentado<T> extends StatelessWidget {
  const SeletorSegmentado({
    super.key,
    required this.opcoes,
    required this.valor,
    required this.onMudar,
    this.expandido = true,
  });

  final List<OpcaoSegmento<T>> opcoes;
  final T valor;
  final ValueChanged<T> onMudar;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final escuro = esquema.brightness == Brightness.dark;
    final indice = opcoes.indexWhere((opcao) => opcao.valor == valor);
    final duracao = Motion.escolher(context, Motion.media);

    return LayoutBuilder(
      builder: (context, restricoes) {
        final larguraTotal = restricoes.maxWidth;
        final larguraItem = larguraTotal / opcoes.length;

        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: escuro
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: esquema.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: duracao,
                curve: Motion.elastica,
                left: (indice < 0 ? 0 : indice) * larguraItem + 3,
                top: 3,
                bottom: 3,
                width: larguraItem - 6,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: cores.gradienteMarca),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: cores.accent.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final opcao in opcoes)
                    Expanded(
                      child: _ItemSegmento<T>(
                        opcao: opcao,
                        selecionado: opcao.valor == valor,
                        onTap: () => onMudar(opcao.valor),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemSegmento<T> extends StatelessWidget {
  const _ItemSegmento({
    required this.opcao,
    required this.selecionado,
    required this.onTap,
  });

  final OpcaoSegmento<T> opcao;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Semantics(
      selected: selecionado,
      button: true,
      label: opcao.rotulo,
      child: Tooltip(
        message: opcao.descricao ?? opcao.rotulo,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: AnimatedDefaultTextStyle(
            duration: Motion.escolher(context, Motion.rapida),
            style: (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
                .copyWith(
                  fontSize: 13.5,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                  color: selecionado ? Colors.white : esquema.onSurfaceVariant,
                ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (opcao.icone != null) ...[
                  Icon(
                    opcao.icone,
                    size: 16,
                    color: selecionado
                        ? Colors.white
                        : esquema.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    opcao.rotulo,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartões grandes para escolher o perfil de compressão.
class CartoesPerfil<T> extends StatelessWidget {
  const CartoesPerfil({
    super.key,
    required this.opcoes,
    required this.valor,
    required this.onMudar,
  });

  final List<OpcaoSegmento<T>> opcoes;
  final T valor;
  final ValueChanged<T> onMudar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final porLinha = restricoes.maxWidth > 720 ? 4 : 2;
        final espaco = 12.0;
        final largura =
            (restricoes.maxWidth - espaco * (porLinha - 1)) / porLinha;

        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final opcao in opcoes)
              SizedBox(
                width: largura,
                child: _CartaoPerfil<T>(
                  opcao: opcao,
                  selecionado: opcao.valor == valor,
                  onTap: () => onMudar(opcao.valor),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CartaoPerfil<T> extends StatelessWidget {
  const _CartaoPerfil({
    required this.opcao,
    required this.selecionado,
    required this.onTap,
  });

  final OpcaoSegmento<T> opcao;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    final escuro = esquema.brightness == Brightness.dark;

    return HoverScale(
      onTap: onTap,
      escala: 1.03,
      raio: 18,
      child: AnimatedContainer(
        duration: Motion.escolher(context, Motion.media),
        curve: Motion.entrada,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: selecionado
              ? LinearGradient(
                  colors: [
                    cores.accent.withValues(alpha: 0.20),
                    cores.accentSecundaria.withValues(alpha: 0.12),
                  ],
                )
              : null,
          color: selecionado
              ? null
              : (escuro
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selecionado
                ? cores.accent
                : esquema.outlineVariant.withValues(alpha: 0.5),
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (opcao.icone != null) ...[
                  Icon(
                    opcao.icone,
                    size: 19,
                    color: selecionado ? cores.accent : esquema.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    opcao.rotulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: selecionado ? cores.accent : esquema.onSurface,
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: selecionado ? 1 : 0,
                  duration: Motion.escolher(context, Motion.media),
                  curve: Motion.elastica,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: cores.accent,
                  ),
                ),
              ],
            ),
            if (opcao.descricao != null) ...[
              const SizedBox(height: 6),
              Text(
                opcao.descricao!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                      height: 1.3,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Campo de tamanho (número + unidade) com atalhos rápidos.
class CampoTamanho extends StatefulWidget {
  const CampoTamanho({
    super.key,
    required this.bytes,
    required this.onMudar,
    this.rotulo = 'Tamanho alvo',
    this.ajuda,
  });

  final int bytes;
  final ValueChanged<int> onMudar;
  final String rotulo;
  final String? ajuda;

  @override
  State<CampoTamanho> createState() => _CampoTamanhoState();
}

class _CampoTamanhoState extends State<CampoTamanho> {
  late final TextEditingController _controlador;
  String _unidade = 'MB';
  String? _erro;

  @override
  void initState() {
    super.initState();
    final (valor, unidade) = _decompor(widget.bytes);
    _controlador = TextEditingController(text: valor);
    _unidade = unidade;
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  (String, String) _decompor(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return ((bytes / (1024 * 1024 * 1024)).toStringAsFixed(1), 'GB');
    }
    if (bytes >= 1024 * 1024) {
      final valor = bytes / (1024 * 1024);
      return (valor >= 10 ? valor.round().toString() : valor.toStringAsFixed(1), 'MB');
    }
    return ((bytes / 1024).round().toString(), 'KB');
  }

  void _aplicar() {
    final numero = double.tryParse(_controlador.text.replaceAll(',', '.'));
    if (numero == null || numero <= 0) {
      setState(() => _erro = 'Digite um número válido');
      return;
    }
    final bytes = Fmt.parseTamanho('${_controlador.text}$_unidade');
    if (bytes == null) {
      setState(() => _erro = 'Valor fora do intervalo');
      return;
    }
    setState(() => _erro = null);
    widget.onMudar(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controlador,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => _aplicar(),
                decoration: InputDecoration(
                  labelText: widget.rotulo,
                  errorText: _erro,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _unidade,
                        borderRadius: BorderRadius.circular(12),
                        items: const [
                          DropdownMenuItem(value: 'KB', child: Text('KB')),
                          DropdownMenuItem(value: 'MB', child: Text('MB')),
                          DropdownMenuItem(value: 'GB', child: Text('GB')),
                        ],
                        onChanged: (valor) {
                          if (valor == null) return;
                          setState(() => _unidade = valor);
                          _aplicar();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.ajuda != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: BotaoAjuda(
                  titulo: widget.rotulo,
                  texto: widget.ajuda!,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final atalho in const [
              (1, '1 MB'),
              (2, '2 MB'),
              (5, '5 MB'),
              (10, '10 MB'),
              (25, '25 MB'),
            ])
              AtalhoTexto(
                rotulo: atalho.$2,
                selecionado: widget.bytes == atalho.$1 * 1024 * 1024,
                onTap: () {
                  final (valor, unidade) = _decompor(atalho.$1 * 1024 * 1024);
                  setState(() {
                    _controlador.text = valor;
                    _unidade = unidade;
                    _erro = null;
                  });
                  widget.onMudar(atalho.$1 * 1024 * 1024);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Valor atual: ${Fmt.bytes(widget.bytes)}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

class AtalhoTexto extends StatelessWidget {
  const AtalhoTexto({
    super.key,
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.escolher(context, Motion.rapida),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? cores.accent.withValues(alpha: 0.16)
              : esquema.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selecionado
                ? cores.accent
                : esquema.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
            color: selecionado ? cores.accent : esquema.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Campo de intervalos de páginas, com validação em tempo real.
class CampoIntervalos extends StatefulWidget {
  const CampoIntervalos({
    super.key,
    required this.valor,
    required this.onMudar,
    required this.rotulo,
    this.dica,
    this.erro,
    this.aviso,
    this.ajuda,
    this.totalPaginas,
  });

  final String valor;
  final ValueChanged<String> onMudar;
  final String rotulo;
  final String? dica;
  final String? erro;
  final String? aviso;
  final String? ajuda;
  final int? totalPaginas;

  @override
  State<CampoIntervalos> createState() => _CampoIntervalosState();
}

class _CampoIntervalosState extends State<CampoIntervalos> {
  late final TextEditingController _controlador =
      TextEditingController(text: widget.valor);

  @override
  void didUpdateWidget(covariant CampoIntervalos antigo) {
    super.didUpdateWidget(antigo);
    // Mantém o texto sincronizado quando a mudança vem de fora (atalhos).
    if (widget.valor != _controlador.text) {
      _controlador.value = TextEditingValue(
        text: widget.valor,
        selection: TextSelection.collapsed(offset: widget.valor.length),
      );
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controlador,
                onChanged: widget.onMudar,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  letterSpacing: 0.4,
                ),
                decoration: InputDecoration(
                  labelText: widget.rotulo,
                  hintText: widget.dica,
                  errorText: widget.erro,
                  helperText: widget.totalPaginas != null
                      ? 'Este PDF tem ${widget.totalPaginas} páginas'
                      : null,
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                ),
              ),
            ),
            if (widget.ajuda != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: BotaoAjuda(titulo: widget.rotulo, texto: widget.ajuda!),
              ),
            ],
          ],
        ),
        if (widget.aviso != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: cores.alerta),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.aviso!,
                  style: TextStyle(fontSize: 12, color: cores.alerta),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final exemplo in const ['1-3, 7, 10-12', '1-', '-5', '2, 4, 6'])
              AtalhoTexto(
                rotulo: exemplo,
                selecionado: widget.valor.trim() == exemplo,
                onTap: () => widget.onMudar(exemplo),
              ),
            if (widget.totalPaginas != null && widget.totalPaginas! > 0)
              AtalhoTexto(
                rotulo: '1-${widget.totalPaginas}',
                selecionado: widget.valor.trim() == '1-${widget.totalPaginas}',
                onTap: () => widget.onMudar('1-${widget.totalPaginas}'),
              ),
          ],
        ),
        if (widget.valor.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Digite os intervalos ou use um exemplo acima.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Linha com título, explicação e um Switch.
class LinhaOpcao extends StatelessWidget {
  const LinhaOpcao({
    super.key,
    required this.titulo,
    required this.valor,
    required this.onMudar,
    this.ajuda,
    this.descricao,
    this.desabilitado = false,
  });

  final String titulo;
  final bool valor;
  final ValueChanged<bool> onMudar;
  final String? ajuda;
  final String? descricao;
  final bool desabilitado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Opacity(
      opacity: desabilitado ? 0.5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: desabilitado ? null : () => onMudar(!valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (ajuda != null) ...[
                          const SizedBox(width: 4),
                          BotaoAjuda(
                            titulo: titulo,
                            texto: ajuda!,
                            tamanho: 17,
                          ),
                        ],
                      ],
                    ),
                    if (descricao != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          descricao!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: esquema.onSurfaceVariant,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: valor,
                onChanged: desabilitado ? null : onMudar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha com um Slider e o valor em destaque.
class LinhaSlider extends StatelessWidget {
  const LinhaSlider({
    super.key,
    required this.titulo,
    required this.valor,
    required this.minimo,
    required this.maximo,
    required this.onMudar,
    required this.formatar,
    this.ajuda,
    this.descricao,
    this.sufixo,
  });

  final String titulo;
  final double valor;
  final double minimo;
  final double maximo;
  final ValueChanged<double> onMudar;
  final String Function(double) formatar;
  final String? ajuda;
  final String? descricao;
  final String? sufixo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (ajuda != null) ...[
              const SizedBox(width: 4),
              BotaoAjuda(titulo: titulo, texto: ajuda!, tamanho: 17),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cores.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formatar(valor),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cores.accent,
                ),
              ),
            ),
          ],
        ),
        if (descricao != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              descricao!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ),
        Slider(
          value: valor.clamp(minimo, maximo),
          min: minimo,
          max: maximo,
          divisions: (maximo - minimo).round().clamp(1, 200),
          label: formatar(valor),
          onChanged: onMudar,
        ),
      ],
    );
  }
}
