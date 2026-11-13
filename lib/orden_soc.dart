import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Piloto C3: encabezado en dos filas, chip centrado y reflejos blanco/púrpura.
class OrdenSocBackdrop extends StatefulWidget {
  const OrdenSocBackdrop({super.key, required this.child});
  final Widget child;

  @override
  State<OrdenSocBackdrop> createState() => _OrdenSocBackdropState();
}

class _OrdenSocBackdropState extends State<OrdenSocBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cycle.stop();
      _cycle.value = 0;
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Transparencia local a la orden para dejar pasar las pistas del fondo.
    final card = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    return ColoredBox(
      color: const Color(0xff11151d),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SocPainter(
                    _cycle,
                    MediaQuery.paddingOf(context).top,
                  ),
                ),
              ),
            ),
          ),
          Theme(
            data: theme.copyWith(
              cardTheme: theme.cardTheme.copyWith(
                color: card.withValues(alpha: .68),
              ),
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Sustituye el AppBar del detalle. Conserva título y acciones existentes.
class OrdenSocHeader extends AppBar {
  OrdenSocHeader({
    super.key,
    Widget? title,
    List<Widget>? actions,
    bool showBackButton = true,
    Color? backgroundColor,
    Color? surfaceTintColor,
    double? elevation,
    double? scrolledUnderElevation,
    List<Widget>? headerActions,
    bool showSectionMenu = true,
    VoidCallback? onSearch,
    VoidCallback? onNotifications,
  }) : super(
         automaticallyImplyLeading: false,
         centerTitle: true,
         toolbarHeight: 72,
         titleSpacing: 0,
         backgroundColor: backgroundColor ?? Colors.transparent,
         surfaceTintColor: surfaceTintColor ?? Colors.transparent,
         elevation: elevation ?? 0,
         scrolledUnderElevation: scrolledUnderElevation ?? 0,
         systemOverlayStyle: const SystemUiOverlayStyle(
           statusBarColor: Colors.transparent,
           statusBarIconBrightness: Brightness.light,
           statusBarBrightness: Brightness.dark,
         ),
         title: const Padding(
           padding: EdgeInsets.only(top: 14),
           child: _SocBrand(),
         ),
         actions: [
           Padding(
             padding: const EdgeInsets.only(top: 14, right: 4),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children:
                   headerActions ??
                   [
                     IconButton(
                       tooltip: onSearch == null
                           ? 'Búsqueda global · pendiente de conectar'
                           : 'Buscar',
                       onPressed: onSearch,
                       disabledColor: const Color(0xffaeb8c5),
                       icon: const Icon(Icons.search, size: 21),
                     ),
                     IconButton(
                       tooltip: onNotifications == null
                           ? 'Notificaciones · pendiente de conectar'
                           : 'Notificaciones',
                       onPressed: onNotifications,
                       disabledColor: const Color(0xffaeb8c5),
                       icon: const Icon(Icons.notifications_none, size: 21),
                     ),
                   ],
             ),
           ),
         ],
         bottom: PreferredSize(
           preferredSize: const Size.fromHeight(54),
           child: _OrderSectionRow(
             title: title,
             actions: actions ?? const [],
             showBackButton: showBackButton,
             showSectionMenu: showSectionMenu,
           ),
         ),
       );
}

class SocHomeScope extends InheritedWidget {
  const SocHomeScope({super.key, required this.onHome, required super.child});

  final VoidCallback onHome;

  static SocHomeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SocHomeScope>();

  @override
  bool updateShouldNotify(SocHomeScope oldWidget) => onHome != oldWidget.onHome;
}

class _SocBrand extends StatelessWidget {
  const _SocBrand();

  static final _logo = base64Decode(
    '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',
  );

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / 360;
    final onHome = SocHomeScope.maybeOf(context)?.onHome;
    return Tooltip(
      message: 'Ir a Inicio',
      child: Semantics(
        button: true,
        label: 'Ir a Inicio',
        child: InkWell(
          onTap: onHome,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 78 * scale,
            height: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Image.memory(
                _logo,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderSectionRow extends StatelessWidget {
  const _OrderSectionRow({
    required this.title,
    required this.actions,
    this.showBackButton = true,
    required this.showSectionMenu,
  });
  final Widget? title;
  final List<Widget> actions;
  final bool showBackButton;
  final bool showSectionMenu;

  @override
  Widget build(BuildContext context) {
    final buttons = actions.whereType<IconButton>().toList();
    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xff28313c))),
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Color(0xffd9e0eb)),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xffedf1f6),
                  ),
                  child: title ?? const SizedBox.shrink(),
                ),
                const SizedBox(height: 6),
                Container(width: 28, height: 2, color: const Color(0xff4acbe4)),
              ],
            ),
          ),
          // No descarta acciones personalizadas que pudiera tener el proyecto.
          for (final action in actions)
            if (action is! IconButton && action is! SizedBox) action,
          if (showSectionMenu && buttons.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert, size: 21),
              onSelected: (index) => buttons[index].onPressed?.call(),
              itemBuilder: (_) => [
                for (var i = 0; i < buttons.length; i++)
                  PopupMenuItem<int>(
                    value: i,
                    enabled: buttons[i].onPressed != null,
                    child: Row(
                      children: [
                        buttons[i].icon,
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(buttons[i].tooltip ?? 'Acción ${i + 1}'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SocPainter extends CustomPainter {
  _SocPainter(this.cycle, this.topInset) : super(repaint: cycle);
  final Animation<double> cycle;
  final double topInset;

  static const _chipScale = 1.21;
  static const _chipCenterX = 180.0;
  static const _chipCenterY = 43.0;
  static const _chipWidth = 78 * _chipScale;
  static const _chipHeight = 38 * _chipScale;
  static const _chipLeft = _chipCenterX - _chipWidth / 2;
  static const _chipTop = _chipCenterY - _chipHeight / 2;
  static const _chipRight = _chipCenterX + _chipWidth / 2;
  static const _chipBottom = _chipCenterY + _chipHeight / 2;
  static const _white = Color(0xffececec);
  static const _purple = Color(0xffebaaff);
  static const _edgePurple = Color(0xffd197e3);
  static const _lightGain = .43 * 1.07 * 1.10 * 1.10;
  static const _purpleGain = 1.14979890;

  static Path _route(int side, int pin) {
    final x = _chipCenterX + (-34 + 68 * pin / 13) * _chipScale;
    final y = _chipCenterY + (-15 + 30 * pin / 13) * _chipScale;
    switch (side) {
      case 0:
        return Path()
          ..moveTo(x, _chipTop)
          ..lineTo(x, 0);
      case 1:
        return Path()
          ..moveTo(_chipRight, y)
          ..lineTo(360, y);
      case 2:
        final first = 250 + 1.5 * (13 - pin);
        final second = 418 + 1.5 * pin;
        return Path()
          ..moveTo(x, _chipBottom)
          ..lineTo(x, first)
          ..lineTo(x + 90, first)
          ..lineTo(x + 90, second)
          ..lineTo(x - 73, second)
          ..lineTo(x - 73, 644);
      default:
        return Path()
          ..moveTo(_chipLeft, y)
          ..lineTo(0, y);
    }
  }

  static final _rays = [
    for (var side = 0; side < 4; side++)
      for (var pin = 0; pin < 14; pin++)
        (
          metric: _route(side, pin).computeMetrics().single,
          purple: (side + pin).isOdd,
          bottom: side == 2,
        ),
  ];
  // 835 unidades de camino inferior; llegada como la previsualización aprobada.
  static const _bottomArrival = 1.6235294118;
  static final _speed =
      (_rays.where((r) => r.bottom).first.metric.length - 5) / _bottomArrival;

  double _pulse(double elapsed) => elapsed < 0
      ? 0
      : (elapsed / .075).clamp(0.0, 1.0).toDouble() *
            ((.70 - elapsed) / .45).clamp(0.0, 1.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.height <= topInset + 126) {
      return;
    }
    final t = cycle.value * 4;
    final fadeIn = (t / .15).clamp(0.0, 1.0).toDouble();
    final fadeOut = ((2 - t) / .40).clamp(0.0, 1.0).toDouble();
    final level = fadeIn < fadeOut ? fadeIn : fadeOut;
    final sx = size.width / 360;
    final bodyTop = topInset + _chipBottom;
    final bands = [
      (
        start: 0.0,
        end: _chipTop,
        top: 0.0,
        height: topInset + _chipTop,
        dim: .70,
      ),
      (
        start: _chipTop,
        end: _chipBottom,
        top: topInset + _chipTop,
        height: _chipHeight,
        dim: .62,
      ),
      (
        start: _chipBottom,
        end: 644.0,
        top: bodyTop,
        height: size.height - bodyTop,
        dim: .53,
      ),
    ];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;
    final tip = Paint();
    for (final band in bands) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, band.top, size.width, band.height));
      canvas.translate(0, band.top);
      canvas.scale(sx, band.height / (band.end - band.start));
      canvas.translate(0, -band.start);
      for (final ray in _rays) {
        final metric = ray.metric;
        if (level > 0) {
          final color = ray.purple ? _purple : _white;
          final gain = !ray.purple && ray.bottom ? 1.155 : 1.0;
          final alpha =
              (ray.purple ? .58 : .50) *
              _lightGain *
              gain *
              level *
              band.dim *
              (ray.purple ? _purpleGain : 1.0);
          final reach = (5 + _speed * t).clamp(0.0, metric.length).toDouble();
          canvas.drawPath(
            metric.extractPath(0, reach),
            stroke
              ..strokeWidth = .75
              ..color = color.withValues(alpha: alpha),
          );
          final center = metric.getTangentForOffset(reach)?.position;
          if (center != null &&
              center.dy >= band.start &&
              center.dy <= band.end) {
            tip.shader = ui.Gradient.radial(center, 11, [
              color.withValues(alpha: alpha * .20),
              color.withValues(alpha: 0),
            ]);
            canvas.drawCircle(center, 11, tip);
          }
        }
        canvas.drawPath(
          metric.extractPath(0, 5 * _chipScale),
          stroke
            ..strokeWidth = .8
            ..color = const Color(0xff5c6878),
        );
      }
      canvas.restore();
    }

    // Remate alto, con el corte desplazado a la izquierda al bajar.
    const remateAlto = 40.5;
    final remateArriba = 174 * sx;
    final remateAbajo = 141 * sx;
    final remate = Path()
      ..moveTo(0, 0)
      ..lineTo(remateArriba, 0)
      ..lineTo(remateAbajo, remateAlto)
      ..lineTo(0, remateAlto)
      ..close();
    canvas.drawPath(remate, Paint()..color = const Color(0xff222832));
    canvas.drawPath(
      Path()
        ..moveTo(0, remateAlto)
        ..lineTo(remateAbajo, remateAlto)
        ..lineTo(remateArriba, 0),
      stroke
        ..strokeWidth = .7
        ..color = const Color(0xff333c49),
    );
    final rect = Rect.fromLTWH(
      _chipLeft * sx,
      topInset + _chipTop,
      _chipWidth * sx,
      _chipHeight,
    );
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(body, Paint()..color = const Color(0xff262e39));
    canvas.drawRRect(
      body,
      stroke
        ..strokeWidth = .8
        ..color = const Color(0xff8997a9),
    );
    final inner = RRect.fromRectAndRadius(
      rect.deflate(4),
      const Radius.circular(3),
    );
    canvas.drawRRect(inner, Paint()..color = const Color(0xff1a222c));
    canvas.drawRRect(
      inner,
      stroke
        ..strokeWidth = .6
        ..color = const Color(0xff445064),
    );

    final upper = _pulse(t - (_chipTop - 5) / _speed);
    final lower = _pulse(t - _bottomArrival) * ((2 - t) / .15).clamp(0.0, 1.0);
    _edge(canvas, size, upper, false);
    _edge(canvas, size, lower, true);
  }

  void _edge(Canvas canvas, Size size, double intensity, bool bottom) {
    if (intensity <= 0) {
      return;
    }
    final start = bottom ? Offset(0, size.height) : Offset.zero;
    final end = bottom ? Offset(0, size.height - 14) : const Offset(0, 14);
    final bounds = bottom
        ? Rect.fromLTWH(0, size.height - 14, size.width, 14)
        : Rect.fromLTWH(0, 0, size.width, 14);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          start,
          end,
          [
            _edgePurple.withValues(alpha: .32 * intensity),
            _edgePurple.withValues(alpha: .08 * intensity),
            _edgePurple.withValues(alpha: 0),
          ],
          [0, .25, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _SocPainter oldDelegate) =>
      oldDelegate.cycle != cycle || oldDelegate.topInset != topInset;
}
