import 'dart:async';

import 'package:flutter/material.dart';

const _graphite = Color(0xFF141519);
const _card = Color(0xFF202126);
const _blue = Color(0xFF4DC6E8);
const _violet = Color(0xFFC0A1DC);

ThemeData veloAzulTheme() {
  final colors =
      ColorScheme.fromSeed(
        seedColor: _blue,
        brightness: Brightness.dark,
      ).copyWith(
        primary: _blue,
        secondary: _violet,
        surface: _graphite,
        surfaceContainer: _card,
        surfaceContainerLow: _card,
      );

  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: _graphite,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: _graphite,
      indicatorColor: Color(0xFF243B46),
    ),
  );
}

class VeloAzul extends StatefulWidget {
  const VeloAzul({super.key, required this.child});

  final Widget child;

  @override
  State<VeloAzul> createState() => _VeloAzulState();
}

class _VeloAzulState extends State<VeloAzul>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pass;
  Timer? _nextPass;
  bool _reduceMotion = false;
  bool _foreground = true;

  bool get _canAnimate => _foreground && !_reduceMotion;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    _pass = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener(_onPassStatus);
    binding.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!_canAnimate) {
      _nextPass?.cancel();
      _nextPass = null;
      _pass.reset();
      return;
    }
    _schedulePass();
  }

  void _onPassStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _schedulePass();
  }

  void _schedulePass() {
    if (!_canAnimate || _nextPass != null || _pass.isAnimating) return;
    _nextPass = Timer(const Duration(seconds: 2), () {
      _nextPass = null;
      if (mounted && _canAnimate) _pass.forward(from: 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextPass?.cancel();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _graphite),
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _VeloPainter(_pass)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _VeloPainter extends CustomPainter {
  _VeloPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1 || size.isEmpty) return;

    // Move one broad, flattened reflection through the graphite background.
    final band = Rect.fromLTWH(
      0,
      size.height * .08,
      size.width,
      size.height * .75,
    );

    // Match the easing and keyframes of the approved preview.
    final phase = const Cubic(.42, 0, .58, 1).transform(t);
    final (start, end, fromY, toY, fromAlpha, toAlpha) = switch (phase) {
      < .27 => (0.0, .27, .45, .24, 0.0, .17325),
      < .64 => (.27, .64, .24, -.16, .17325, .2205),
      _ => (.64, 1.0, -.16, -.45, .2205, 0.0),
    };
    final fraction = (phase - start) / (end - start);
    final y = size.height * (.50 + fromY + (toY - fromY) * fraction);
    final opacity = fromAlpha + (toAlpha - fromAlpha) * fraction;

    const unit = Rect.fromLTRB(-1, -1, 1, 1);
    final paint = Paint()
      ..shader = RadialGradient(
        radius: .5,
        colors: [
          const Color(0xFFADCCE3).withValues(alpha: opacity),
          const Color(0xFF8DA2C8).withValues(alpha: opacity * 85 / 255),
          const Color(0x008DA2C8),
        ],
        stops: const [0, .53, .94],
      ).createShader(unit);

    canvas.save();
    canvas.clipRect(band);
    canvas.translate(size.width * .71, y);
    canvas.scale(size.width * .92, size.height * .11);
    canvas.drawOval(unit, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VeloPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
