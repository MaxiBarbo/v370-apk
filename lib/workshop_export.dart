part of 'workshop_sample.dart';

Future<Uint8List> _exportWorkshopReport() async {
  final db = await _openWorkshop();
  final sheets = await db.transaction((txn) async {
    final clients = await txn.query(
      'customers',
      orderBy: 'name COLLATE NOCASE, id',
    );
    final orders = await txn.rawQuery('''
      SELECT o.*, c.id AS client_id, c.name AS client_name,
             TRIM(COALESCE(d.brand || ' ', '') || d.model) AS equipment,
             b.id AS budget_id, b.validity_days, b.warranty, b.notes,
             (SELECT SUM(amount_cents) FROM budget_items WHERE budget_id = b.id) AS quoted,
             COALESCE((SELECT SUM(amount_cents) FROM order_payments WHERE order_id = o.id), 0) AS received
      FROM work_orders o
      JOIN devices d ON d.id = o.device_id
      JOIN customers c ON c.id = d.customer_id
      LEFT JOIN budgets b ON b.order_id = o.id
      ORDER BY o.id
    ''');
    return <String, List<List<Object?>>>{
      'Resumen de trabajos': [
        [
          'Orden',
          'Ingreso',
          'Cliente',
          'Equipo',
          'Estado',
          'Presupuesto',
          'Total acordado',
          'Saldo',
          'Trabajo realizado',
        ],
        for (final row in orders)
          [
            row['code'],
            _reportDate(row['received_at']),
            row['client_name'],
            row['equipment'],
            row['status'],
            _reportBudgetCode(row),
            _reportAmount(row['agreed_cents']),
            row['agreed_cents'] == null
                ? null
                : ((row['agreed_cents'] as int) - (row['received'] as int)) /
                      100,
            row['work_performed'],
          ],
      ],
      'Clientes': [
        ['ID cliente', 'Nombre', 'Teléfono', 'Correo', 'Dirección'],
        for (final row in clients)
          [row['id'], row['name'], row['phone'], row['email'], row['address']],
      ],
      'Órdenes': [
        [
          'Orden',
          'ID cliente',
          'Cliente',
          'Equipo',
          'Ingreso',
          'Retiro pactado',
          'Estado',
          'Falla informada',
          'Observaciones de seguimiento',
          'Trabajo realizado',
        ],
        for (final row in orders)
          [
            row['code'],
            row['client_id'],
            row['client_name'],
            row['equipment'],
            _reportDate(row['received_at']),
            row['pickup_date'],
            row['status'],
            row['issue'],
            row['follow_up_notes'],
            row['work_performed'],
          ],
      ],
      'Presupuestos': [
        [
          'Presupuesto',
          'Orden',
          'ID cliente',
          'Cliente',
          'Equipo',
          'Estado de la orden',
          'Total presupuestado',
          'Validez (días)',
          'Garantía',
          'Notas',
        ],
        for (final row in orders)
          if (row['budget_id'] != null)
            [
              _reportBudgetCode(row),
              row['code'],
              row['client_id'],
              row['client_name'],
              row['equipment'],
              row['status'],
              _reportAmount(row['quoted']),
              row['validity_days'],
              row['warranty'],
              row['notes'],
            ],
      ],
    };
  });

  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const types = 'http://schemas.openxmlformats.org/package/2006/content-types';
  const pkg = 'http://schemas.openxmlformats.org/package/2006/relationships';
  final archive = Archive();
  void add(String path, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  final entries = sheets.entries.toList();
  final ids = List.generate(entries.length, (index) => index + 1);
  add(
    '[Content_Types].xml',
    '<Types xmlns="$types'
        '"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '${ids.map((i) => '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}</Types>',
  );
  add(
    '_rels/.rels',
    '<Relationships xmlns="$pkg"><Relationship Id="rId1" Type="$rel/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  add(
    'xl/workbook.xml',
    '<workbook xmlns="$ns" xmlns:r="$rel"><bookViews><workbookView/></bookViews><sheets>'
        '${ids.map((i) => '<sheet name="${_reportXml(entries[i - 1].key)}" sheetId="$i" r:id="rId$i"/>').join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="$pkg">'
        '${ids.map((i) => '<Relationship Id="rId$i" Type="$rel/worksheet" Target="worksheets/sheet$i.xml"/>').join()}'
        '</Relationships>',
  );

  for (final i in ids) {
    final rows = entries[i - 1].value;
    final xml = StringBuffer(
      '<worksheet xmlns="$ns"><sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews><cols><col min="1" max="${rows.first.length}" '
      'width="24" customWidth="1"/></cols><sheetData>',
    );
    for (var row = 0; row < rows.length; row++) {
      xml.write('<row r="${row + 1}">');
      for (var column = 0; column < rows[row].length; column++) {
        final value = rows[row][column];
        final ref = '${String.fromCharCode(65 + column)}${row + 1}';
        if (value is num) {
          xml.write('<c r="$ref"><v>$value</v></c>');
        } else if (value != null) {
          xml.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_reportXml(value.toString())}</t></is></c>',
          );
        }
      }
      xml.write('</row>');
    }
    xml.write(
      '</sheetData><autoFilter ref="A1:${String.fromCharCode(64 + rows.first.length)}${rows.length}"/></worksheet>',
    );
    add('xl/worksheets/sheet$i.xml', xml.toString());
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _reportXml(String value) => const HtmlEscape(HtmlEscapeMode.attribute)
    .convert(
      value.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]'), ''),
    );

String? _reportDate(Object? value) => value is int
    ? DateTime.fromMillisecondsSinceEpoch(value)
          .toIso8601String()
          .split('T')
          .first
    : null;

double? _reportAmount(Object? cents) => cents is int ? cents / 100 : null;

String? _reportBudgetCode(Map<String, Object?> row) => row['budget_id'] == null
    ? null
    : "PR-${row['budget_id'].toString().padLeft(6, '0')}";

class _WorkshopExportPage extends StatefulWidget {
  const _WorkshopExportPage();

  @override
  State<_WorkshopExportPage> createState() => _WorkshopExportPageState();
}

class _WorkshopExportPageState extends State<_WorkshopExportPage> {
  bool _busy = false;
  String? _message;

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await _exportWorkshopReport();
      if (!mounted) return;
      final result = await _backupFile.invokeMethod<bool>('saveReport', bytes);
      if (mounted && result == true) {
        _message = 'Planilla guardada. Podés abrirla en Google Sheets.';
      }
    } catch (_) {
      if (mounted) _message = 'No se pudo guardar la planilla.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff11151d),
    appBar: OrdenSocHeader(
      title: const Text('Exportar a Google Sheets'),
      headerActions: const [],
      showSectionMenu: false,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Una planilla nueva · 4 pestañas'),
        for (final title in const [
          'Resumen de trabajos',
          'Clientes',
          'Órdenes',
          'Presupuestos',
        ])
          Card(child: ListTile(title: Text(title))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Crear planilla'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message case final String message) Text(message),
      ],
    ),
  );
}

// v370: cierre de copias y exportacion
