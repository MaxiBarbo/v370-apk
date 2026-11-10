import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v370_apk/main.dart';

void main() {
  testWidgets('Navega por las secciones de v370', (tester) async {
    await tester.pumpWidget(const V370App());

    expect(find.text('v370 · Inicio'), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda de hoy'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    for (final section in ['Órdenes', 'Clientes', 'Gestión']) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(find.text('v370 · $section'), findsOneWidget);
    }

    for (final section in ['Presupuestos', 'Stock', 'Proveedores']) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(
        find.text(section == 'Presupuestos' ? 'Presupuestos' : section),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });
}
