import 'package:flutter/material.dart';

import 'velo_azul.dart';

import 'workshop_sample.dart';
import 'v370_informacion_frp.dart';

void main() => runApp(const V370App());

class V370App extends StatelessWidget {
  const V370App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'v370',
      debugShowCheckedModeBanner: false,
      theme: veloAzulTheme(),
      builder: (context, child) =>
          VeloAzul(child: child ?? const SizedBox.shrink()),
      home: const WorkshopShell(),
    );
  }
}

class WorkshopShell extends StatefulWidget {
  const WorkshopShell({super.key});

  @override
  State<WorkshopShell> createState() => _WorkshopShellState();
}

class _WorkshopShellState extends State<WorkshopShell> {
  int _selectedIndex = 0;

  static const _sections = [
    (label: 'Inicio', icon: Icons.home_outlined, links: ['Agenda']),
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

    return Scaffold(
      appBar: AppBar(title: Text('v370 · ${section.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (section.label != "Gestión")
            WorkshopSampleLink(section: section.label),
          for (final label in section.links)
            if (label == "Agenda")
              const WorkshopAgendaLink()
            else if (label == 'Presupuestos')
              const WorkshopBudgetsLink()
            else if (label == 'Ingresos')
              const WorkshopIncomeLink()
            else if (label == 'Información FRP')
              const Card(child: InformacionFrpExtra())
            else if (label == 'Stock' || label == 'Proveedores')
              WorkshopCatalogLink(suppliers: label == 'Proveedores')
            else
              Card(
                child: ListTile(
                  title: Text(label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text(label)),
                        body: const Center(child: Text('Pantalla inicial')),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          for (final item in _sections)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}
