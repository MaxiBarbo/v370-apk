import 'package:flutter/material.dart';

import 'velo_azul.dart';
import 'orden_soc.dart';

import 'workshop_sample.dart';
import 'v370_informacion_frp.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const V370App());
}

class V370App extends StatefulWidget {
  const V370App({super.key});

  @override
  State<V370App> createState() => _V370AppState();
}

class _V370AppState extends State<V370App> {
  final _shellKey = GlobalKey<_WorkshopShellState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'v370',
      debugShowCheckedModeBanner: false,
      theme: veloAzulTheme(),
      builder: (context, child) => SocHomeScope(
        onHome: () => _shellKey.currentState?._goHome(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: WorkshopShell(key: _shellKey),
    );
  }
}

class WorkshopShell extends StatefulWidget {
  const WorkshopShell({super.key});

  @override
  State<WorkshopShell> createState() => _WorkshopShellState();
}

class _WorkshopShellState extends State<WorkshopShell> {
  Widget _sectionNavigation(int selectedIndex, ValueChanged<int> onSelected) =>
      NavigationBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in _sections)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      );

  void _leaveSuppliersFor(int index) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _selectedIndex = index);
  }

  int _selectedIndex = 0;

  void _goHome() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static const _sections = [
    (label: 'Inicio', icon: Icons.home_outlined, links: <String>[]),
    (label: 'Órdenes', icon: Icons.receipt_long_outlined, links: <String>[]),
    (label: 'Clientes', icon: Icons.people_outline, links: <String>[]),
    (
      label: 'Gestión',
      icon: Icons.grid_view_outlined,
      links: [
        'Presupuestos',
        'Ingresos',
        'Stock',
        'Proveedores',
        'Información FRP',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final section = _sections[_selectedIndex];
    final isHome = _selectedIndex == 0;

    return OrdenSocBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: OrdenSocHeader(
          title: Text(section.label),
          actions: [if (section.label == 'Gestión') const _V370AnimatedGear()],
          showBackButton: false,
          showSectionMenu: !isHome && section.label != 'Gestión',
          headerActions: isHome
              ? [
                  IconButton(
                    tooltip: 'Cuenta',
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cuenta'),
                        content: const Text(
                          'El inicio de sesión está pendiente de conectar.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
              : null,
        ),
        body: isHome
            ? const WorkshopInicio()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (section.label != "Gestión")
                    WorkshopSampleLink(section: section.label),
                  // Accesos previstos para el MVP 2.
                  for (final (label, icon) in switch (section.label) {
                    'Órdenes' => const [
                      (
                        'Reingresos y garantías',
                        Icons.assignment_return_outlined,
                      ),
                      ('Órdenes demoradas', Icons.schedule_outlined),
                    ],
                    'Clientes' => const [
                      ('Historial por equipo', Icons.history),
                      ('Consultas recibidas', Icons.mail_outline),
                    ],
                    _ => const <(String, IconData)>[],
                  })
                    Card(
                      child: ListTile(
                        leading: CustomPaint(
                          size: const Size.square(24),
                          painter: _Mvp2IconPainter(icon),
                        ),

                        title: Text(label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Previsto en el próximo MVP'),
                            ),
                          ),
                      ),
                    ),

                  for (final label in section.links)
                    if (label == 'Presupuestos')
                      const WorkshopBudgetsLink()
                    else if (label == 'Ingresos')
                      const WorkshopIncomeLink()
                    else if (label == 'Información FRP')
                      const Card(child: InformacionFrpExtra())
                    else if (label == 'Stock' || label == 'Proveedores')
                      WorkshopCatalogLink(
                        suppliers: label == 'Proveedores',
                        supplierNavigation: label == 'Proveedores'
                            ? _sectionNavigation(
                                _selectedIndex,
                                _leaveSuppliersFor,
                              )
                            : null,
                      )
                    else
                      Card(
                        child: ListTile(
                          title: Text(label),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => Scaffold(
                                appBar: AppBar(title: Text(label)),
                                body: const Center(
                                  child: Text('Pantalla inicial'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
        bottomNavigationBar: _sectionNavigation(_selectedIndex, (index) {
          setState(() => _selectedIndex = index);
        }),
      ),
    );
  }
}

class _Mvp2IconPainter extends CustomPainter {
  const _Mvp2IconPainter(this.icon);

  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    switch (icon) {
      case Icons.assignment_return_outlined:
        stroke.color = const Color(0xffad73e0);
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 5)
            ..lineTo(2, 9.5)
            ..lineTo(6.5, 14)
            ..moveTo(2, 9.5)
            ..lineTo(16, 9.5)
            ..arcToPoint(
              const Offset(16, 20),
              radius: const Radius.circular(5.25),
            )
            ..lineTo(8, 20),
          stroke,
        );
        break;
      case Icons.schedule_outlined:
        stroke.color = const Color(0xffffaa00);
        canvas.drawCircle(const Offset(12, 12), 10, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..lineTo(12, 12)
            ..lineTo(16.5, 14),
          stroke,
        );
        break;
      case Icons.history:
        stroke.color = const Color(0xffba6bea);
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 22)
            ..lineTo(3.5, 22)
            ..quadraticBezierTo(2, 22, 2, 20.5)
            ..lineTo(2, 3.5)
            ..quadraticBezierTo(2, 2, 3.5, 2)
            ..lineTo(14.5, 2)
            ..quadraticBezierTo(16, 2, 16, 3.5)
            ..lineTo(16, 7.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9, 15.5)
            ..arcToPoint(
              const Offset(10.5, 20.5),
              radius: const Radius.circular(6.5),
              largeArc: true,
            )
            ..moveTo(7, 14.5)
            ..lineTo(9, 16.5)
            ..lineTo(11, 14.5)
            ..moveTo(15.5, 12)
            ..lineTo(15.5, 16)
            ..lineTo(18.5, 17.5),
          stroke,
        );
        break;
      case Icons.mail_outline:
        stroke.color = const Color(0xff00e4f6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(2, 5, 22, 19),
            const Radius.circular(1),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 6)
            ..lineTo(12, 13.5)
            ..lineTo(21.5, 6),
          stroke,
        );
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Mvp2IconPainter oldDelegate) =>
      oldDelegate.icon != icon;
}

class _V370AnimatedGear extends StatefulWidget {
  const _V370AnimatedGear();

  @override
  State<_V370AnimatedGear> createState() => _V370AnimatedGearState();
}

class _V370AnimatedGearState extends State<_V370AnimatedGear>
    with SingleTickerProviderStateMixin {
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    upperBound: 0.125,
  );
  bool _opening = false;

  Future<void> _openSettings() async {
    if (_opening) return;
    _opening = true;
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _rotation.forward().orCancel;
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const _V370Ajustes()),
      );
    } on TickerCanceled {
      // Gestión se cerró durante el giro.
    } finally {
      if (mounted) _rotation.reset();
      _opening = false;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajustes',
      onPressed: _openSettings,
      icon: RotationTransition(
        turns: _rotation,
        child: const Icon(Icons.settings_outlined, color: Colors.white),
      ),
    );
  }
}

class _V370Ajustes extends StatelessWidget {
  const _V370Ajustes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: const Text('Ajustes'),
        headerActions: const [],
        showSectionMenu: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.animation_outlined),
              title: const Text('Prueba de animación SoC C3'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const _V370SocLab()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema'),
              subtitle: const Text('Claro y oscuro'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const _V370Tema()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Copias de seguridad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkshopBackupPage(),
                ),
              ),
            ),
          ),
          const WorkshopTrackingLink(),
        ],
      ),
    );
  }
}

class _V370SocLab extends StatelessWidget {
  const _V370SocLab();

  @override
  Widget build(BuildContext context) {
    return OrdenSocBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: OrdenSocHeader(
          title: const Text('Prueba SoC C3'),
          headerActions: const [],
          showSectionMenu: false,
        ),
      ),
    );
  }
}

class _V370Tema extends StatelessWidget {
  const _V370Tema();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: const Text('Tema'),
        headerActions: const [],
        showSectionMenu: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              title: Text('Oscuro'),
              trailing: Icon(
                Icons.radio_button_checked,
                color: Color(0xff4acbe4),
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Claro'),
              trailing: Icon(Icons.radio_button_unchecked),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Text('Vista prevista. La selección de tema está pendiente.'),
          ),
        ],
      ),
    );
  }
}
