import 'dart:async' show Timer;
import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart' show Archive, ArchiveFile, ZipEncoder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, MethodChannel;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart' show PdfColor;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import 'orden_soc.dart';

part 'workshop_finance.dart';
part 'workshop_frp.dart';
part 'workshop_inicio.dart';
part 'workshop_backup.dart';
part 'workshop_export.dart';

Future<void> _addFollowUpNotes(Database db) async {
  await db.execute('ALTER TABLE work_orders ADD COLUMN follow_up_notes TEXT');
}

Future<void> _addContactDetails(Database db) async {
  await db.execute('ALTER TABLE customers ADD COLUMN address TEXT');
  await db.execute(
    'ALTER TABLE suppliers ADD COLUMN active INTEGER NOT NULL DEFAULT 1',
  );
  await db.execute('ALTER TABLE suppliers ADD COLUMN warranty_days INTEGER');
  for (final key in _supplierFields.keys) {
    if (key != 'warranty_days') {
      await db.execute('ALTER TABLE suppliers ADD COLUMN $key TEXT');
    }
  }
}

Future<Database> _openWorkshop() async {
  final directory = await getDatabasesPath();
  return openDatabase(
    '$directory/v370_workshop.db',
    version: 23,
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 19) {
        await _createDeviceFrp(db);
      } else if (oldVersion < 20) {
        await db.execute(
          'ALTER TABLE device_frp ADD COLUMN processor_soc TEXT',
        );
      }
      if (oldVersion < 2) await _createStatusHistory(db);
      if (oldVersion < 3) await _addCustomerNotice(db);
      if (oldVersion < 4) await _addPickupDate(db);
      if (oldVersion < 5) await _addCustomerPhone(db);
      if (oldVersion < 6) await _createOrderSequence(db);
      if (oldVersion < 7) await _createBudgets(db);
      if (oldVersion < 8) await _createCatalog(db);
      if (oldVersion < 9) await _createOrderPhotos(db);
      if (oldVersion < 10) await _addCustomerEmail(db);
      if (oldVersion < 11) await _addBudgetQuantity(db);
      if (oldVersion < 12) await _addDeviceFields(db);
      if (oldVersion < 13) await _addReceptionFields(db);
      if (oldVersion < 14) await _createStockMovements(db);
      if (oldVersion < 15) await _addOrderFinance(db);
      if (oldVersion < 16) await _addPaidOrders(db);
      if (oldVersion < 17) await _addFollowUpNotes(db);
      if (oldVersion < 18) await _addContactDetails(db);
      if (oldVersion < 21) await _addFrpWorkflow(db);
      if (oldVersion < 22) await _addBackupIds(db);
      if (oldVersion < 23) {
        await db.execute(
          'ALTER TABLE work_orders ADD COLUMN work_performed TEXT',
        );
      }
    },
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await _createStatusHistory(db);
      await db.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE devices (
          id INTEGER PRIMARY KEY,
          customer_id INTEGER NOT NULL REFERENCES customers(id),
          model TEXT NOT NULL
        )
      ''');
      await _createDeviceFrp(db);
      await db.execute('''
        CREATE TABLE work_orders (
          id INTEGER PRIMARY KEY,
          device_id INTEGER NOT NULL REFERENCES devices(id),
          code TEXT NOT NULL UNIQUE,
          issue TEXT NOT NULL,
          status TEXT NOT NULL
        )
      ''');
      await _addFrpWorkflow(db);
      await _addCustomerNotice(db);
      await _addPickupDate(db);
      await _addCustomerPhone(db);
      await _createOrderSequence(db);
      await db.insert('customers', {'id': 1, 'name': 'Lucía Torres'});
      await db.insert('devices', {
        'id': 1,
        'customer_id': 1,
        'model': 'Samsung Galaxy S22',
      });
      await db.insert('work_orders', {
        'id': 1,
        'device_id': 1,
        'code': 'V370-001',
        'issue': 'El equipo no carga.',
        'status': 'Diagnóstico',
      });
      await _createBudgets(db);
      await _addBudgetQuantity(db);
      await _addDeviceFields(db);
      await _addReceptionFields(db);
      await _createCatalog(db);
      await _createStockMovements(db);
      await _createOrderPhotos(db);
      await _addCustomerEmail(db);
      await _addOrderFinance(db);
      await _addPaidOrders(db);
      await _addContactDetails(db);
      await _addFollowUpNotes(db);
      await _addBackupIds(db);
      await db.execute(
        'ALTER TABLE work_orders ADD COLUMN work_performed TEXT',
      );
    },
  );
}

Future<List<Map<String, Object?>>> _readOrders({String? code}) async {
  final db = await _openWorkshop();
  return db.rawQuery(
    '''
    SELECT o.code, o.issue, o.status, TRIM(COALESCE(d.brand || ' ', '') || d.model) AS model, c.name AS customer, o.pickup_date, o.customer_notified_at, c.id AS customer_id, c.phone AS customer_phone
    FROM work_orders o
    JOIN devices d ON d.id = o.device_id
    JOIN customers c ON c.id = d.customer_id
    WHERE (? IS NULL OR o.code = ?)
    ORDER BY o.id DESC
  ''',
    [code, code],
  );
}

class WorkshopSampleLink extends StatelessWidget {
  const WorkshopSampleLink({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon) = switch (section) {
      'Clientes' => (
        'Cartera del taller',
        'Consultá el cliente y su equipo',
        Icons.people_outline,
      ),
      'Órdenes' => (
        'Reparaciones registradas',
        'Consultá la orden y su estado',
        Icons.receipt_long_outlined,
      ),
      _ => (
        'Actividad del taller',
        'Consultá las reparaciones recientes',
        Icons.build_outlined,
      ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _WorkshopRecords(title: title, section: section),
          ),
        ),
      ),
    );
  }
}

class _WorkshopRecords extends StatefulWidget {
  const _WorkshopRecords({required this.title, required this.section});

  final String title;
  final String section;

  @override
  State<_WorkshopRecords> createState() => _WorkshopRecordsState();
}

class _WorkshopRecordsState extends State<_WorkshopRecords> {
  late Future<List<Map<String, Object?>>> _orders;
  final _searchController = TextEditingController();
  String _searchText = '';
  String? _statusFilter;
  Future<List<Map<String, Object?>>> _loadRows() =>
      widget.section == 'Clientes' ? _readCustomers() : _readOrders();

  Future<void> _startOrderFromList() async {
    final customer = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(builder: (_) => const _OrderCustomerPicker()),
    );
    if (!mounted || customer == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _CustomerDetails(customer: customer)),
    );
    if (mounted) setState(() => _orders = _loadRows());
  }

  Future<void> _addCustomer() async {
    final saved = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _NewCustomerDialog(),
    );
    if (mounted && saved != null) setState(() => _orders = _loadRows());
  }

  @override
  void initState() {
    super.initState();
    _orders = _loadRows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustomers = widget.section == 'Clientes';

    // Encabezado SoC del listado de ordenes.
    final page = Scaffold(
      backgroundColor: isCustomers ? null : Colors.transparent,
      appBar: !isCustomers
          ? OrdenSocHeader(
              title: const Text('Órdenes'),
              showSectionMenu: false,
              headerActions: const [],
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    tooltip: 'Nueva orden',
                    onPressed: _startOrderFromList,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            )
          : AppBar(
              title: Text(widget.title),
              actions: [
                if (isCustomers)
                  IconButton(
                    tooltip: 'Nuevo cliente',
                    onPressed: _addCustomer,
                    icon: const Icon(Icons.person_add_outlined),
                  ),
              ],
            ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _orders = _loadRows()),
                child: const Text('Error al leer SQLite. Reintentar'),
              ),
            );
          }

          final orders = snapshot.data;
          if (orders == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final visibleOrders = orders.where((row) {
            if (!isCustomers &&
                _statusFilter != null &&
                row['status'] != _statusFilter) {
              return false;
            }
            final fields = isCustomers
                ? [row['customer'], row['customer_phone']]
                : [row['code'], row['customer'], row['model']];
            return fields.any(
              (value) =>
                  value?.toString().toLowerCase().contains(_searchText) ??
                  false,
            );
          }).toList();
          if (orders.isEmpty) {
            return Center(
              child: Text(
                isCustomers
                    ? 'Todavía no hay clientes.'
                    : 'Todavía no hay órdenes.',
              ),
            );
          }

          final search = TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              border: isCustomers ? null : const OutlineInputBorder(),
              isDense: !isCustomers,
              labelText: isCustomers
                  ? 'Buscar por nombre o teléfono'
                  : 'Buscar órdenes',
              hintText: isCustomers ? null : 'Código, cliente o equipo',
            ),
            onChanged: (value) =>
                setState(() => _searchText = value.trim().toLowerCase()),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isCustomers)
                search
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final status = DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _statusFilter ?? 'Todos',
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final value in [
                          'Todos',
                          ..._OrderDetailsState._statuses,
                        ])
                          DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _statusFilter = value == 'Todos' ? null : value,
                      ),
                    );
                    if (constraints.maxWidth < 320 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18) {
                      return Column(
                        children: [search, const SizedBox(height: 8), status],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 3, child: search),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: status),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),
              Text(
                isCustomers
                    ? '${visibleOrders.length} clientes'
                    : '${visibleOrders.length} órdenes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (visibleOrders.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.search_off),
                    title: Text(
                      isCustomers
                          ? 'Sin clientes que coincidan'
                          : 'Sin órdenes que coincidan',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Probá con otra búsqueda o filtro.'),
                        if (!isCustomers && _searchText.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchText = '');
                            },
                            child: const Text('Limpiar búsqueda'),
                          ),
                      ],
                    ),
                  ),
                ),
              for (final order in visibleOrders)
                Card(
                  child: ListTile(
                    leading: Icon(
                      isCustomers ? Icons.person_outline : Icons.phone_android,
                    ),
                    title: Text(
                      (isCustomers ? order['customer'] : order['model'])
                          as String,
                    ),
                    subtitle: Text(
                      isCustomers
                          ? (order['customer_phone'] as String? ??
                                'Sin teléfono registrado')
                          : '${order['code']} · ${order['customer']}',
                    ),
                    trailing: isCustomers
                        ? const Icon(Icons.chevron_right)
                        : _OrderStatusBadge(status: order['status'] as String),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => isCustomers
                              ? _CustomerDetails(customer: order)
                              : _OrderDetails(order: order),
                        ),
                      );
                      if (!mounted) return;
                      setState(() => _orders = _loadRows());
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
    return isCustomers ? page : OrdenSocBackdrop(child: page);
  }
}

class _OrderDetails extends StatefulWidget {
  const _OrderDetails({required this.order});

  final Map<String, Object?> order;

  @override
  State<_OrderDetails> createState() => _OrderDetailsState();
}

class _OrderDetailsState extends State<_OrderDetails> {
  late Future<String?> _workPerformed = _loadOrderText('work_performed');
  late Future<String?> _observation = _loadOrderText('follow_up_notes');

  void _setOrderText(bool work, Future<String?> value) {
    setState(() {
      if (work) {
        _workPerformed = value;
      } else {
        _observation = value;
      }
    });
  }

  Future<String?> _loadOrderText(String column) async {
    final db = await _openWorkshop();
    final rows = await db.query(
      'work_orders',
      columns: [column],
      where: 'code = ?',
      whereArgs: [widget.order['code']],
    );
    return rows.single[column] as String?;
  }

  Future<void> _editObservation(String? previous, bool work) async {
    final form = GlobalKey<FormState>();
    var text = previous ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(
          work
              ? 'Trabajo realizado'
              : (previous == null
                    ? 'Agregar observación'
                    : 'Editar observación'),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: text,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: work
                  ? 'Trabajo realizado'
                  : 'Observaciones de seguimiento',
            ),
            onChanged: (value) => text = value,
            validator: (value) => (value ?? '').trim().isEmpty
                ? work
                      ? 'Ingresá el trabajo realizado.'
                      : 'Ingresá una observación.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(dialog).pop(text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result == previous) return;
    await _saveObservation(previous, result, work);
  }

  Future<void> _deleteObservation(String previous, bool work) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(work ? 'Borrar trabajo realizado' : 'Borrar observación'),
        content: Text(
          work
              ? 'Se borrará el trabajo realizado de esta orden.'
              : 'Se borrará el texto de seguimiento de esta orden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _saveObservation(previous, null, work);
  }

  Future<void> _saveObservation(
    String? previous,
    String? value,
    bool work,
  ) async {
    final column = work ? 'work_performed' : 'follow_up_notes';
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'work_orders',
        {column: value},
        where: 'code = ? AND $column IS ?',
        whereArgs: [widget.order['code'], previous],
      );
      if (!mounted) return;
      if (updated != 1) {
        _setOrderText(
          work,
          _loadOrderText(work ? 'work_performed' : 'follow_up_notes'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La orden cambió. Revisá el texto y reintentá.'),
          ),
        );
        return;
      }
      _setOrderText(work, Future<String?>.value(value));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el texto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _observationCard({bool work = false}) => Card(
    child: FutureBuilder<String?>(
      future: work ? _workPerformed : _observation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return ListTile(
            title: const Text('No se pudo cargar el texto.'),
            subtitle: const Text('Tocá para reintentar.'),
            onTap: () => _setOrderText(
              work,
              _loadOrderText(work ? 'work_performed' : 'follow_up_notes'),
            ),
          );
        }
        final text = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                work ? 'Trabajo realizado' : 'Observaciones de seguimiento',
              ),
              subtitle: Text(
                text ?? (work ? 'Sin trabajo registrado' : 'Sin observaciones'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _editObservation(text, work),
                    child: Text(text == null ? 'Agregar' : 'Editar'),
                  ),
                  if (text != null)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => _deleteObservation(text, work),
                      child: const Text('Borrar'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _editReportedIssue() async {
    final form = GlobalKey<FormState>();
    var input = _reportedIssue;

    final issue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xff22272f),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff454b55)),
        ),
        title: const Text('Editar problema informado'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: _reportedIssue,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => input = value,
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Ingresá una descripción.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(dialogContext).pop(input.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!mounted || issue == null || issue == _reportedIssue || _saving) {
      return;
    }

    setState(() => _saving = true);
    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'work_orders',
        {'issue': issue},
        where: 'code = ?',
        whereArgs: [widget.order['code']],
      );

      if (updated != 1) {
        throw StateError('La orden ya no está disponible.');
      }
      if (mounted) setState(() => _reportedIssue = issue);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la descripción.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _statuses = [
    'Pendiente',
    'Diagnóstico',
    'Presupuestado',
    'Reparación',
    'Entregar',
    'Retirado',
  ];

  late String _status = widget.order['status'] as String;
  late String _reportedIssue = widget.order['issue'] as String;
  bool _saving = false;

  late var _finance = _loadFinance();

  String get _code => widget.order['code'] as String;

  Future<_OrderFinance> _loadFinance() async {
    final db = await _openWorkshop();
    return _readOrderFinance(db, _code);
  }

  Future<void> _acceptBudget(_OrderFinance finance) async {
    final total = finance.quoted!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Aceptar presupuesto'),
        content: Text(
          'El importe acordado quedará fijado en ${_money(total)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _updateFinance((txn, current) async {
      if (current.agreed != null || current.quoted != total) {
        throw StateError('El presupuesto cambió. Revisá el importe.');
      }
      if (total < current.received) {
        throw StateError('El total es menor que los cobros registrados.');
      }
      await txn.update(
        'work_orders',
        {'agreed_cents': total},
        where: 'id = ?',
        whereArgs: [current.id],
      );
    });
  }

  Future<void> _editDeposit(_OrderFinance finance) async {
    if (_saving) return;

    final List<Map<String, Object?>> deposits;
    try {
      final db = await _openWorkshop();
      deposits = await db.query(
        'order_payments',
        columns: ['id', 'amount_cents', 'received_at'],
        where: 'order_id = ? AND is_deposit = 1',
        whereArgs: [finance.id],
        orderBy: 'received_at DESC, id DESC',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron leer las señas.')),
        );
      }
      return;
    }
    if (!mounted || deposits.isEmpty || _saving) return;

    final deposit = deposits.length == 1
        ? deposits.single
        : await showDialog<Map<String, Object?>>(
            context: context,
            builder: (dialog) => SimpleDialog(
              title: const Text('Elegí la seña que querés editar'),
              children: [
                for (final row in deposits)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(dialog).pop(row),
                    child: Text(
                      '${_displayDate(DateTime.fromMillisecondsSinceEpoch(row['received_at'] as int))}'
                      ' · ${_money(row['amount_cents'] as int)}',
                    ),
                  ),
              ],
            ),
          );
    if (!mounted || deposit == null || _saving) return;

    final previous = deposit['amount_cents'] as int;
    final form = GlobalKey<FormState>();
    var input =
        '${previous ~/ 100},'
        '${(previous % 100).toString().padLeft(2, '0')}';

    final corrected = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff22272f),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff454b55)),
        ),
        title: const Text('Editar seña'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Importe en pesos'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => input = value,
            validator: (value) {
              final cents = _parseAmount(value ?? '');
              if (cents == null || cents <= 0) {
                return 'Ingresá un importe válido.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(dialog).pop(_parseAmount(input));
              }
            },
            child: const Text('Guardar corrección'),
          ),
        ],
      ),
    );

    if (!mounted || corrected == null || corrected == previous) return;
    await _updateFinance((txn, current) async {
      if (current.paid) {
        throw StateError('Desmarcá Cobrado antes de editar la seña.');
      }
      final agreed = current.agreed;

      if (agreed != null && current.received - previous + corrected > agreed) {
        throw StateError('La corrección supera el importe acordado.');
      }

      final updated = await txn.update(
        'order_payments',
        {'amount_cents': corrected},
        where:
            'id = ? AND order_id = ? AND is_deposit = 1 AND amount_cents = ?',
        whereArgs: [deposit['id'], current.id, previous],
      );
      if (updated != 1) {
        throw StateError('La seña cambió. Volvé a abrirla para editarla.');
      }
    });
  }

  Future<void> _deleteDeposit(_OrderFinance finance) async {
    if (_saving || finance.paid) return;

    final List<Map<String, Object?>> deposits;
    try {
      final db = await _openWorkshop();
      deposits = await db.query(
        'order_payments',
        columns: ['id', 'amount_cents', 'received_at'],
        where: 'order_id = ? AND is_deposit = 1',
        whereArgs: [finance.id],
        orderBy: 'received_at DESC, id DESC',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron leer las señas.')),
        );
      }
      return;
    }
    if (!mounted || _saving || deposits.isEmpty) return;

    String label(Map<String, Object?> deposit) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        deposit['received_at'] as int,
      );
      return '${_displayDate(date)} · ${_money(deposit['amount_cents'] as int)}';
    }

    final deposit = deposits.length == 1
        ? deposits.single
        : await showDialog<Map<String, Object?>>(
            context: context,
            builder: (dialog) => SimpleDialog(
              title: const Text('Elegí la seña que querés eliminar'),
              children: [
                for (final row in deposits)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(dialog).pop(row),
                    child: Text(label(row)),
                  ),
              ],
            ),
          );
    if (!mounted || _saving || deposit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Eliminar seña'),
        content: Text(
          'Se eliminará la seña del ${label(deposit)}.\n\n'
          'El saldo se recalculará. Podés registrar una nueva seña después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Eliminar seña'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    await _updateFinance((txn, current) async {
      if (current.paid) {
        throw StateError('Desmarcá Cobrado antes de eliminar la seña.');
      }
      final deleted = await txn.delete(
        'order_payments',
        where:
            'id = ? AND order_id = ? AND is_deposit = 1 '
            'AND amount_cents = ? AND received_at = ?',
        whereArgs: [
          deposit['id'],
          current.id,
          deposit['amount_cents'],
          deposit['received_at'],
        ],
      );
      if (deleted != 1) {
        throw StateError('La seña cambió. Revisá el resumen económico.');
      }
    });
  }

  Future<void> _registerPayment(
    _OrderFinance finance, {
    bool forceDeposit = false,
  }) async {
    final form = GlobalKey<FormState>();
    var input = '';
    final deposit = forceDeposit || finance.status != 'Retirado';
    final remaining = finance.agreed == null
        ? null
        : finance.agreed! - finance.received;
    final amount = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff22272f),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff454b55)),
        ),
        title: Text(deposit ? 'Registrar seña' : 'Registrar cobro'),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Importe en pesos'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => input = value,
            validator: (value) {
              final amount = _parseAmount(value ?? '');
              if (amount == null || amount <= 0) {
                return 'Ingresá un importe válido.';
              }
              if (remaining != null && amount > remaining) {
                return 'El importe supera el saldo.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(dialog).pop(_parseAmount(input));
              }
            },
            child: const Text('Confirmar cobro'),
          ),
        ],
      ),
    );
    if (!mounted || amount == null) return;
    await _updateFinance((txn, current) async {
      if (current.status != finance.status ||
          current.agreed != finance.agreed ||
          current.received != finance.received) {
        throw StateError('El resumen cambió. Revisá el saldo.');
      }
      await _insertOrderPayment(
        txn,
        current,
        amount,
        deposit: deposit,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  Future<void> _updateFinance(
    Future<void> Function(Transaction, _OrderFinance) update,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    _OrderFinance? refreshed;
    try {
      final db = await _openWorkshop();
      refreshed = await db.transaction((txn) async {
        await update(txn, await _readOrderFinance(txn, _code));
        return _readOrderFinance(txn, _code);
      });
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el movimiento.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          final saved = refreshed;
          _finance = saved == null ? _loadFinance() : Future.value(saved);
        });
      }
    }
  }

  Widget _financeCard() => FutureBuilder(
    future: _finance,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return OutlinedButton(
          onPressed: _saving
              ? null
              : () => setState(() => _finance = _loadFinance()),
          child: const Text('No se pudo leer el resumen. Reintentar'),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final finance = snapshot.requireData;
      final agreed = finance.agreed;
      final quoted = finance.quoted;
      final total = agreed ?? quoted;
      final balance = total == null ? null : total - finance.received;
      final canRecord = agreed == null || agreed > finance.received;
      return Card(
        child: Column(
          children: [
            ListTile(
              title: Text(agreed == null ? 'Presupuesto' : 'Importe acordado'),
              trailing: Text(
                agreed != null
                    ? _money(agreed)
                    : quoted == null
                    ? 'Sin presupuesto'
                    : '${_money(quoted)} · Pendiente',
              ),
            ),
            ListTile(
              title: const Text('Seña recibida'),
              trailing: Text(_money(finance.deposits)),
            ),
            ListTile(
              title: Text(
                balance != null && balance < 0
                    ? 'Cobrado por encima del presupuesto'
                    : 'Saldo pendiente',
              ),
              trailing: Text(
                balance == null ? 'Por calcular' : _money(balance.abs()),
              ),
            ),
            if (agreed == null && quoted != null)
              TextButton(
                onPressed: _saving ? null : () => _acceptBudget(finance),
                child: const Text('Aceptar presupuesto'),
              ),
            if (finance.deposits > 0 && !finance.paid)
              TextButton(
                onPressed: _saving ? null : () => _editDeposit(finance),
                child: const Text('Editar seña'),
              ),
            CheckboxListTile(
              title: const Text('Cobrado'),
              subtitle: Text(
                agreed == null
                    ? 'Aceptá el presupuesto para confirmar el cobro.'
                    : 'Independiente del estado de entrega.',
              ),
              value: finance.paid,
              onChanged: _saving || agreed == null
                  ? null
                  : (value) => _setPaid(finance, value == true),
            ),
            if (finance.deposits > 0 && !finance.paid)
              TextButton(
                onPressed: _saving ? null : () => _deleteDeposit(finance),
                child: const Text('Eliminar seña'),
              ),
            if (canRecord && !finance.paid && finance.status == 'Retirado')
              TextButton(
                onPressed: _saving
                    ? null
                    : () => _registerPayment(finance, forceDeposit: true),
                child: const Text('Registrar seña'),
              ),
            if (canRecord && !finance.paid)
              TextButton(
                onPressed: _saving ? null : () => _registerPayment(finance),
                child: Text(
                  finance.status == 'Retirado'
                      ? 'Registrar cobro'
                      : 'Registrar seña',
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _setPaid(_OrderFinance finance, bool paid) async {
    final agreed = finance.agreed;
    if (_saving || agreed == null) return;
    final balance = agreed - finance.received;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff22272f),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff454b55)),
        ),
        title: Text(paid ? 'Confirmar cobro' : 'Desmarcar cobrado'),
        content: Text(
          paid
              ? 'Total acordado: ${_money(agreed)}\n'
                    'Cobro a registrar: ${_money(balance)}'
              : 'Se revierte el pago generado por esta casilla, si lo hubo. '
                    'Las señas y los cobros registrados por separado se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(paid ? 'Marcar cobrado' : 'Desmarcar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    await _updateFinance((txn, current) async {
      if (current != finance) {
        throw StateError('La orden cambió. Revisá el resumen económico.');
      }
      await _savePaidOrder(txn, current, paid);
    });
  }

  Future<void> _openOrderDevice() async {
    try {
      final db = await _openWorkshop();
      final rows = await db.rawQuery(
        'SELECT d.* FROM devices d JOIN work_orders o ON o.device_id = d.id '
        'WHERE o.code = ?',
        [_code],
      );
      if (!mounted || rows.isEmpty) return;
      await _showWorkshopDevice(context, rows.single);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la ficha del equipo.'),
          ),
        );
      }
    }
  }

  Future<void> _showHistory() async {
    final code = widget.order['code'] as String;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StatusHistoryPage(
          code: code,
          model: widget.order['model'] as String,
          status: _status,
        ),
      ),
    );
  }

  Future<void> _changeStatus() async {
    final nextStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Cambiar estado'),
        children: [
          for (final status in _statuses)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(status),
              child: Text(status),
            ),
        ],
      ),
    );

    if (!mounted || _saving || nextStatus == null || nextStatus == _status) {
      return;
    }

    setState(() => _saving = true);
    try {
      final db = await _openWorkshop();
      await _saveOrderStatus(db, _code, nextStatus);
      if (mounted) {
        setState(() {
          _status = nextStatus;
          _finance = _loadFinance();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el estado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_saving,
      child: OrdenSocBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: OrdenSocHeader(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text('Orden ${order['code']}'),
            actions: [
              SizedBox(width: MediaQuery.sizeOf(context).width * .22),
              IconButton(
                tooltip: 'Eliminar orden',
                onPressed: _saving
                    ? null
                    : () => _deleteWorkshopRecord(
                        context,
                        _DeleteTarget.order,
                        order['code']!,
                      ),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(label: Text(_status)),
                  OutlinedButton(
                    onPressed: _saving ? null : _changeStatus,
                    child: Text(_saving ? 'Guardando…' : 'Cambiar estado'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _showHistory,
                    child: const Text('Ver historial'),
                  ),
                ],
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Equipo'),
                      subtitle: Text(order['model'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving ? null : _openOrderDevice,
                    ),
                    ListTile(
                      title: const Text('Cliente'),
                      subtitle: Text(order['customer'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving || order['customer_id'] is! int
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    _CustomerDetails(customer: order),
                              ),
                            ),
                    ),
                    _CustomerPhoneTile(order: order),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Reparación', style: theme.textTheme.titleLarge),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Problema informado'),
                      subtitle: Text(_reportedIssue),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Acciones del problema informado',
                        enabled: !_saving,
                        onSelected: (_) => _editReportedIssue(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                        ],
                      ),
                    ),
                    _OrderFrpMethodTile(code: _code),
                  ],
                ),
              ),
              _observationCard(work: true),
              _observationCard(),
              const SizedBox(height: 20),
              Text('Presupuesto y cobro', style: theme.textTheme.titleLarge),
              Card(
                child: _OrderBudgetLink(
                  code: _code,
                  onReturn: () => setState(() => _finance = _loadFinance()),
                ),
              ),
              _financeCard(),
              const SizedBox(height: 20),
              Text('Entrega', style: theme.textTheme.titleLarge),
              Card(child: _PickupDateTile(order: order)),
              const SizedBox(height: 20),
              Text('Recepción', style: theme.textTheme.titleLarge),
              _OrderReceptionCard(code: _code),
              const SizedBox(height: 20),
              Text('Fotos y documentos', style: theme.textTheme.titleLarge),
              _WorkshopPdfButton(code: _code),
              _OrderPhotos(code: _code),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _createStatusHistory(Database db) async {
  await db.execute('''
    CREATE TABLE order_status_history (
      id INTEGER PRIMARY KEY,
      order_id INTEGER NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
      previous_status TEXT NOT NULL,
      new_status TEXT NOT NULL,
      changed_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE INDEX order_status_history_order_idx
    ON order_status_history(order_id, id)
  ''');
}

Future<void> _saveOrderStatus(
  Database db,
  String code,
  String nextStatus,
) async {
  await db.transaction((txn) async {
    final orders = await txn.query(
      'work_orders',
      columns: ['id', 'status'],
      where: 'code = ?',
      whereArgs: [code],
    );
    if (orders.isEmpty) throw StateError('No se encontró la orden.');

    final order = orders.single;
    final previousStatus = order['status'] as String;
    if (previousStatus == nextStatus) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await txn.update(
      'work_orders',
      {'status': nextStatus, 'customer_notified_at': null},
      where: 'id = ?',
      whereArgs: [order['id']],
    );
    await txn.insert('order_status_history', {
      'order_id': order['id'],
      'previous_status': previousStatus,
      'new_status': nextStatus,
      'changed_at': now,
    });
  });
}

Future<List<Map<String, Object?>>> _readStatusHistory(String code) async {
  final db = await _openWorkshop();
  return db.rawQuery(
    '''
    SELECT h.previous_status, h.new_status, h.changed_at
    FROM order_status_history h
    JOIN work_orders o ON o.id = h.order_id
    WHERE o.code = ?
    ORDER BY h.id DESC
  ''',
    [code],
  );
}

class _StatusHistoryPage extends StatefulWidget {
  const _StatusHistoryPage({
    required this.code,
    required this.model,
    required this.status,
  });

  final String code;
  final String model;
  final String status;

  @override
  State<_StatusHistoryPage> createState() => _StatusHistoryPageState();
}

class _StatusHistoryPageState extends State<_StatusHistoryPage> {
  late final _history = _readStatusHistory(widget.code);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: Text('Historial · ${widget.code}'),
        showSectionMenu: false,
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo leer el historial.'));
          }
          final entries = snapshot.data;
          if (entries == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final localizations = MaterialLocalizations.of(context);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.isEmpty ? 2 : entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone_android),
                      title: Text(widget.model),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _OrderStatusBadge(status: widget.status),
                        ),
                      ),
                    ),
                  ),
                );
              }
              if (entries.isEmpty) {
                return const ListTile(
                  title: Text('Todavía no hay cambios registrados.'),
                );
              }
              final entry = entries[index - 1];
              final date = DateTime.fromMillisecondsSinceEpoch(
                entry['changed_at'] as int,
              );
              final day = localizations.formatShortDate(date);
              final time = localizations.formatTimeOfDay(
                TimeOfDay.fromDateTime(date),
                alwaysUse24HourFormat: true,
              );

              final accent = index == 1
                  ? const Color(0xff10d9ef)
                  : const Color(0xffdba8ed);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          if (entries.length > 1)
                            Positioned(
                              top: index == 1 ? 22 : 0,
                              bottom: index == entries.length ? null : 0,
                              height: index == entries.length ? 22 : null,
                              child: const VerticalDivider(width: 1),
                            ),
                          Positioned(
                            top: 15,
                            child: Icon(
                              Icons.radio_button_checked,
                              size: 14,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(Icons.swap_horiz, color: accent),
                            title: Text(
                              '${entry['previous_status']} → ${entry['new_status']}',
                            ),
                            subtitle: Text('$day · $time'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _addCustomerNotice(Database db) async {
  await db.execute(
    'ALTER TABLE work_orders ADD COLUMN customer_notified_at INTEGER',
  );
}

Future<void> _saveCustomerNotice(String code) async {
  final db = await _openWorkshop();
  await db.update(
    'work_orders',
    {'customer_notified_at': DateTime.now().millisecondsSinceEpoch},
    where: 'code = ? AND status = ? AND customer_notified_at IS NULL',
    whereArgs: [code, 'Entregar'],
  );
}

class WorkshopAgendaLink extends StatelessWidget {
  const WorkshopAgendaLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: const Text('Agenda'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const _WorkshopAgendaPage()),
        ),
      ),
    );
  }
}

class _WorkshopAgendaPage extends StatelessWidget {
  const _WorkshopAgendaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: const Text('Agenda'),
        showSectionMenu: false,
      ),
      body: const WorkshopInicio(agendaOnly: true),
    );
  }
}

Future<void> _addPickupDate(Database db) async {
  await db.execute('ALTER TABLE work_orders ADD COLUMN pickup_date TEXT');
}

String _pickupDayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _PickupDateTile extends StatefulWidget {
  const _PickupDateTile({required this.order});

  final Map<String, Object?> order;

  @override
  State<_PickupDateTile> createState() => _PickupDateTileState();
}

class _PickupDateTileState extends State<_PickupDateTile> {
  late String? _date = widget.order['pickup_date'] as String?;
  bool _saving = false;

  Future<void> _choose() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDay = DateTime(today.year + 5, today.month, today.day);
    final current = DateTime.tryParse(_date ?? '');
    final initialDate =
        current != null && !current.isBefore(today) && !current.isAfter(lastDay)
        ? current
        : today;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDay,
    );

    if (mounted && selected != null) {
      await _save(_pickupDayKey(selected));
    }
  }

  Future<void> _save(String? date) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'work_orders',
        {'pickup_date': date},
        where: 'code = ?',
        whereArgs: [widget.order['code']],
      );

      if (updated != 1) throw StateError('Orden no encontrada.');
      if (mounted) setState(() => _date = date);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la fecha de retiro.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(_date ?? '');

    return PopScope(
      canPop: !_saving,
      child: ListTile(
        title: const Text('Retiro pactado'),
        subtitle: Text(
          date == null
              ? 'Sin fecha'
              : MaterialLocalizations.of(context).formatShortDate(date),
        ),
        onTap: _saving ? null : _choose,
        trailing: date == null
            ? const Icon(Icons.event_outlined)
            : IconButton(
                tooltip: 'Quitar fecha',
                onPressed: _saving ? null : () => _save(null),
                icon: const Icon(Icons.event_busy_outlined),
              ),
      ),
    );
  }
}

Future<void> _addCustomerPhone(Database db) async {
  await db.execute('ALTER TABLE customers ADD COLUMN phone TEXT');
}

Future<void> _openDialer(BuildContext context, String phone) async {
  try {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (opened) return;
  } catch (_) {
    // Android puede no tener una aplicación para abrir el marcador.
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No se pudo abrir el marcador.')),
  );
}

class _CustomerPhoneTile extends StatefulWidget {
  const _CustomerPhoneTile({super.key, required this.order});

  final Map<String, Object?> order;

  @override
  State<_CustomerPhoneTile> createState() => _CustomerPhoneTileState();
}

class _CustomerPhoneTileState extends State<_CustomerPhoneTile> {
  late String? _phone = widget.order['customer_phone'] as String?;
  bool _saving = false;

  Future<void> _edit() async {
    var input = _phone ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Teléfono del cliente'),
        content: TextFormField(
          initialValue: input,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Número de teléfono'),
          onChanged: (text) => input = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(input),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;

    final normalized = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (normalized.isNotEmpty &&
        !RegExp(r'^\+?[0-9]{6,15}$').hasMatch(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un número de teléfono válido.')),
      );
      return;
    }

    final phone = normalized.isEmpty ? null : normalized;
    setState(() => _saving = true);
    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'customers',
        {'phone': phone},
        where: 'id = ?',
        whereArgs: [widget.order['customer_id']],
      );
      if (updated != 1) throw StateError('Cliente no encontrado.');
      if (mounted) setState(() => _phone = phone);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el teléfono.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    try {
      final opened = await launchUrl(
        Uri.https('wa.me', '/${phone.substring(1)}'),
        mode: LaunchMode.externalApplication,
      );
      if (opened) {
        return;
      }
    } catch (_) {
      // Se informa el fallo debajo.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
  }

  @override
  Widget build(BuildContext context) {
    final phone = (_phone ?? '').replaceAll(RegExp(r'[\s().-]'), '');
    final canWhatsApp = RegExp(r'^\+[1-9][0-9]{5,14}$').hasMatch(phone);

    return PopScope(
      canPop: !_saving,
      child: ListTile(
        title: const Text('Teléfono del cliente'),
        subtitle: Text(_phone ?? 'Sin teléfono registrado'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Acciones del teléfono',
          enabled: !_saving,
          onSelected: (action) async {
            switch (action) {
              case 'whatsapp':
                await _openWhatsApp(phone);
              case 'call':
                await _openDialer(context, phone);
              case 'edit':
                await _edit();
            }
          },
          itemBuilder: (_) => [
            if (canWhatsApp)
              const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
            if (phone.isNotEmpty)
              const PopupMenuItem(value: 'call', child: Text('Llamar')),
            const PopupMenuItem(value: 'edit', child: Text('Editar número')),
          ],
        ),
        onTap: _saving
            ? null
            : phone.isEmpty
            ? _edit
            : () async {
                await Clipboard.setData(ClipboardData(text: _phone!.trim()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Teléfono copiado.')),
                );
              },
      ),
    );
  }
}

class _CustomerDetails extends StatefulWidget {
  const _CustomerDetails({required this.customer});

  final Map<String, Object?> customer;

  @override
  State<_CustomerDetails> createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<_CustomerDetails> {
  Future<void> _editDevice(Map<String, Object?> device) => _saveDevice(device);

  late String _customerName = widget.customer['customer'] as String;
  bool _savingName = false;

  Future<void> _editCustomerName() async {
    final name = await _askRequiredText(
      title: 'Editar cliente',
      label: 'Nombre',
      initialValue: _customerName,
    );
    if (!mounted || name == null || name == _customerName || _savingName) {
      return;
    }

    setState(() => _savingName = true);
    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'customers',
        {'name': name},
        where: 'id = ?',
        whereArgs: [widget.customer['customer_id']],
      );
      if (updated != 1) throw StateError('Cliente no encontrado.');
      if (mounted) setState(() => _customerName = name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el nombre.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  late var _records = _load();
  int _revision = 0;

  Future<
    ({List<Map<String, Object?>> devices, List<Map<String, Object?>> orders})
  >
  _load() async {
    final db = await _openWorkshop();
    final customerId = widget.customer['customer_id'];
    final devices = await db.query(
      'devices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'model',
    );
    final orders = await _readOrders();
    return (
      devices: devices,
      orders: orders
          .where((order) => order['customer_id'] == customerId)
          .toList(),
    );
  }

  void _reload() {
    setState(() {
      _revision++;
      _records = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: Text(_customerName),
        actions: [
          IconButton(
            tooltip: 'Editar nombre',
            onPressed: _savingName ? null : _editCustomerName,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar cliente',
            onPressed: () => _deleteWorkshopRecord(
              context,
              _DeleteTarget.customer,
              widget.customer['customer_id']!,
            ),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: _reload,
                child: const Text('No se pudo cargar la ficha. Reintentar'),
              ),
            );
          }

          final records = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: _CustomerPhoneTile(
                  key: ValueKey(_revision),
                  order: records.orders.firstOrNull ?? widget.customer,
                ),
              ),
              const SizedBox(height: 20),
              _CustomerAddressTile(
                customerId: widget.customer['customer_id'] as int,
              ),
              _CustomerEmailTile(
                customerId: widget.customer['customer_id'] as int,
              ),
              const SizedBox(height: 16),
              Text('Equipos', style: heading),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar equipo'),
                ),
              ),
              if (records.devices.isEmpty)
                const ListTile(title: Text('Sin equipos registrados')),
              for (final device in records.devices)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(_deviceLabel(device)),
                    onTap: () => _showDevice(device),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Opciones del equipo',
                      onSelected: (action) async {
                        if (action == 'orden') {
                          await _addOrder(device);
                        } else if (action == 'editar') {
                          await _editDevice(device);
                        } else {
                          await _deleteWorkshopRecord(
                            context,
                            _DeleteTarget.device,
                            device['id']!,
                            onDeleted: _reload,
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'editar',
                          child: Text('Editar equipo'),
                        ),
                        PopupMenuItem(
                          value: 'orden',
                          child: Text('Nueva orden'),
                        ),
                        PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar equipo'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Órdenes', style: heading),
              if (records.orders.isEmpty)
                const ListTile(title: Text('Sin órdenes registradas')),
              for (final order in records.orders)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text('${order['code']} · ${order['model']}'),
                    subtitle: Text(order['status'] as String),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final currentOrders = await _readOrders().catchError(
                        (Object error) => <Map<String, Object?>>[],
                      );
                      if (!context.mounted) return;
                      final current = currentOrders
                          .where((row) => row['code'] == order['code'])
                          .firstOrNull;
                      if (current == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo abrir la orden.'),
                          ),
                        );
                        return;
                      }
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _OrderDetails(order: current),
                        ),
                      );
                      if (mounted) _reload();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<List<Map<String, Object?>>> _readCustomers() async {
  final db = await _openWorkshop();
  return db.rawQuery('''
    SELECT id AS customer_id, name AS customer, phone AS customer_phone
    FROM customers
    ORDER BY name COLLATE NOCASE, id
  ''');
}

class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog();

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _address = '';
  bool _saving = false;
  String? _error;

  String get _normalizedPhone =>
      _phone.text.trim().replaceAll(RegExp(r'[\s().-]'), '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final name = _name.text.trim();
    final phone = _normalizedPhone;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final db = await _openWorkshop();
      final customer = <String, Object?>{
        'name': name,
        'phone': phone.isEmpty ? null : phone,
        'address': _address.isEmpty ? null : _address,
      };
      final id = await db.insert('customers', customer);
      if (!mounted) return;
      Navigator.of(context).pop(<String, Object?>{
        ...customer,
        'customer_id': id,
        'customer': name,
        'customer_phone': customer['phone'],
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el cliente. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xff22272f),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff454b55)),
        ),
        title: const Text('Nuevo cliente'),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Ingresá el nombre.' : null,
              ),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono opcional',
                  border: OutlineInputBorder(),
                ),
                validator: (_) {
                  final phone = _normalizedPhone;
                  if (_phone.text.trim().isEmpty ||
                      RegExp(r'^\+?[0-9]{6,15}$').hasMatch(phone)) {
                    return null;
                  }
                  return 'Ingresá un teléfono válido.';
                },
              ),
              TextFormField(
                enabled: !_saving,
                keyboardType: TextInputType.streetAddress,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _address = value.trim(),
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}

extension on _CustomerDetailsState {
  Future<String?> _askRequiredText({
    required String title,
    required String label,
    int maxLines = 1,
    String initialValue = '',
  }) {
    final form = GlobalKey<FormState>();
    var value = initialValue;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: initialValue,
            autofocus: true,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label),
            onChanged: (text) => value = text.trim(),
            validator: (text) =>
                (text ?? '').trim().isEmpty ? 'Completá este campo.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDevice() => _saveDevice();

  Future<void> _addOrder(Map<String, Object?> device) async {
    final reception = await showDialog<_ReceptionData>(
      context: context,
      builder: (_) => _ReceptionDialog(deviceLabel: _deviceLabel(device)),
    );
    if (!mounted || reception == null) return;

    try {
      final db = await _openWorkshop();
      final code = await db.transaction((txn) async {
        final id = await _reserveOrderNumber(txn);
        final code = 'V370-${id.toString().padLeft(3, '0')}';

        await txn.insert('work_orders', {
          'id': id,
          'device_id': device['id'],
          'code': code,
          'issue': reception.issue,
          'received_accessories': reception.accessories,
          'intake_notes': reception.notes,
          'received_at': DateTime.now().millisecondsSinceEpoch,
          'status': reception.status,
        });
        return code;
      });

      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Orden $code creada.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la orden.')),
      );
    }
  }
}

class _OrderCustomerPicker extends StatefulWidget {
  const _OrderCustomerPicker();

  @override
  State<_OrderCustomerPicker> createState() => _OrderCustomerPickerState();
}

class _OrderCustomerPickerState extends State<_OrderCustomerPicker> {
  late var _customers = _readCustomers();

  Future<void> _createCustomerForOrder() async {
    final customer = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _NewCustomerDialog(),
    );
    if (!mounted || customer == null) return;
    Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    // Encabezado de alta de orden.
    return OrdenSocBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: OrdenSocHeader(
          title: const Text('Nueva orden'),
          headerActions: const [],
          showSectionMenu: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: _createCustomerForOrder,
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'Nuevo cliente',
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _customers,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _customers = _readCustomers()),
                  child: const Text('No se pudo cargar Clientes. Reintentar'),
                ),
              );
            }

            final customers = snapshot.requireData;
            if (customers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Todavía no hay clientes. Tocá Nuevo cliente para continuar.',
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),

              itemCount: customers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Elegir cliente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }
                final customer = customers[index - 1];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(customer['customer'] as String),
                    subtitle: Text(
                      customer['customer_phone'] as String? ??
                          'Sin teléfono registrado',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(customer),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum _DeleteTarget { order, device, customer }

Future<void> _deleteWorkshopRecord(
  BuildContext context,
  _DeleteTarget target,
  Object id, {
  VoidCallback? onDeleted,
}) async {
  final label = switch (target) {
    _DeleteTarget.order => 'orden',
    _DeleteTarget.device => 'equipo',
    _DeleteTarget.customer => 'cliente',
  };

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Eliminar $label'),
      content: Text(switch (target) {
        _DeleteTarget.order => 'Se eliminarán la orden y su historial.',
        _DeleteTarget.device => 'Solo se puede eliminar un equipo sin órdenes.',
        _DeleteTarget.customer =>
          'Solo se puede eliminar un cliente sin equipos.',
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return;

  try {
    final db = await _openWorkshop();
    final deleted = await db.transaction((txn) async {
      return switch (target) {
        _DeleteTarget.order => txn.delete(
          'work_orders',
          where:
              'code = ? AND NOT EXISTS '
              '(SELECT 1 FROM order_payments WHERE order_id = work_orders.id)',
          whereArgs: [id],
        ),
        _DeleteTarget.device => txn.delete(
          'devices',
          where:
              'id = ? AND NOT EXISTS '
              '(SELECT 1 FROM work_orders WHERE device_id = devices.id)',
          whereArgs: [id],
        ),
        _DeleteTarget.customer => txn.delete(
          'customers',
          where:
              'id = ? AND NOT EXISTS '
              '(SELECT 1 FROM devices WHERE customer_id = customers.id)',
          whereArgs: [id],
        ),
      };
    });

    if (!context.mounted) return;
    if (deleted != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (target) {
            _DeleteTarget.order =>
              'La orden tiene cobros registrados o ya no está disponible.',
            _DeleteTarget.device =>
              'El equipo tiene órdenes asociadas o ya no está disponible.',
            _DeleteTarget.customer =>
              'El cliente tiene equipos asociados o ya no está disponible.',
          }),
        ),
      );
      return;
    }

    if (onDeleted != null) {
      onDeleted();
    } else if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo eliminar el registro de $label.')),
    );
  }
}

Future<void> _createOrderSequence(Database db) async {
  await db.execute('''
    CREATE TABLE order_sequence (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      last_number INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    INSERT INTO order_sequence (id, last_number)
    SELECT 1, COALESCE(MAX(id), 0) FROM work_orders
  ''');
}

Future<int> _reserveOrderNumber(Transaction txn) async {
  await txn.rawUpdate('''
    UPDATE order_sequence
    SET last_number = MAX(
      last_number,
      (SELECT COALESCE(MAX(id), 0) FROM work_orders)
    ) + 1
    WHERE id = 1
  ''');
  final rows = await txn.query(
    'order_sequence',
    columns: ['last_number'],
    where: 'id = 1',
  );
  return rows.single['last_number'] as int;
}

String _budgetReference(Object? id) => 'PR-${id.toString().padLeft(6, '0')}';

Future<void> _createBudgets(Database db) async {
  await db.execute('''
    CREATE TABLE budgets (
      id INTEGER PRIMARY KEY,
      order_id INTEGER NOT NULL UNIQUE
        REFERENCES work_orders(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE budget_items (
      id INTEGER PRIMARY KEY,
      budget_id INTEGER NOT NULL
        REFERENCES budgets(id) ON DELETE CASCADE,
      description TEXT NOT NULL,
      amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0)
    )
  ''');

  final orders = await db.query(
    'work_orders',
    columns: ['id'],
    where: 'code = ?',
    whereArgs: ['V370-001'],
  );
  if (orders.isEmpty) return;

  final budgetId = await db.insert('budgets', {
    'order_id': orders.single['id'],
  });
  await db.insert('budget_items', {
    'budget_id': budgetId,
    'description': 'Repuesto de prueba',
    'amount_cents': 2500000,
  });
  await db.insert('budget_items', {
    'budget_id': budgetId,
    'description': 'Mano de obra de prueba',
    'amount_cents': 1500000,
  });
}

Future<List<Map<String, Object?>>> _readBudgets(String? orderCode) async {
  final db = await _openWorkshop();
  return db.rawQuery(
    '''
    SELECT b.id, o.code, TRIM(COALESCE(d.brand || ' ', '') || d.model) AS model, c.name AS customer,
           b.validity_days, b.warranty, b.notes,
           COALESCE(SUM(i.amount_cents), 0) AS total_cents
    FROM budgets b
    JOIN work_orders o ON o.id = b.order_id
    JOIN devices d ON d.id = o.device_id
    JOIN customers c ON c.id = d.customer_id
    LEFT JOIN budget_items i ON i.budget_id = b.id
    WHERE (? IS NULL OR o.code = ?)
    GROUP BY b.id, o.code, d.model, c.name
    ORDER BY b.id DESC
    ''',
    [orderCode, orderCode],
  );
}

String _budgetAmount(int cents) => _money(cents);

class WorkshopBudgetsLink extends StatelessWidget {
  const WorkshopBudgetsLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Presupuestos'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const WorkshopBudgetsPage()),
        ),
      ),
    );
  }
}

class _OrderBudgetLink extends StatelessWidget {
  const _OrderBudgetLink({required this.code, required this.onReturn});

  final String code;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: const Text('Ver presupuesto'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WorkshopBudgetsPage(orderCode: code),
          ),
        );
        if (context.mounted) onReturn();
      },
    );
  }
}

class WorkshopBudgetsPage extends StatefulWidget {
  const WorkshopBudgetsPage({super.key, this.orderCode});

  final String? orderCode;

  @override
  State<WorkshopBudgetsPage> createState() => _WorkshopBudgetsPageState();
}

class _WorkshopBudgetsPageState extends State<WorkshopBudgetsPage> {
  late Future<List<Map<String, Object?>>> _budgets = _readBudgets(
    widget.orderCode,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: const Text('Presupuestos'),
        showSectionMenu: false,
      ),

      floatingActionButton: widget.orderCode == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Crear o editar'),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => _BudgetEditor(code: widget.orderCode!),
                  ),
                );
                if (mounted && saved == true) {
                  setState(() => _budgets = _readBudgets(widget.orderCode));
                }
              },
            ),
      body: FutureBuilder(
        future: _budgets,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => _budgets = _readBudgets(widget.orderCode)),
                child: const Text(
                  'No se pudieron leer los presupuestos. Reintentar',
                ),
              ),
            );
          }

          final budgets = snapshot.requireData;
          if (budgets.isEmpty) {
            return const Center(
              child: Text('No hay presupuestos registrados.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (index, budget) in budgets.indexed)
                _budgetCard(budget, index),
            ],
          );
        },
      ),
    );
  }

  Widget _budgetCard(Map<String, Object?> budget, int index) {
    final theme = Theme.of(context);
    final accent = index.isEven
        ? const Color(0xff10d9ef)
        : const Color(0xffedaafb);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xff454b55)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xff1e2229),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => _BudgetDetails(
                  budget: budget,
                  showOrderLink: widget.orderCode == null,
                ),
              ),
            );
            if (mounted) {
              setState(() => _budgets = _readBudgets(widget.orderCode));
            }
          },
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Ink(color: accent),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      const Icon(Icons.assignment_outlined, size: 23),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              budget['customer'] as String,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              budget['model'] as String,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '${_budgetReference(budget['id'])} · ${budget['code']}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * .40,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xff555d68)),
                          ),
                        ),
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Text(
                          _budgetAmount(budget['total_cents'] as int),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetDetails extends StatefulWidget {
  const _BudgetDetails({required this.budget, required this.showOrderLink});

  final Map<String, Object?> budget;
  final bool showOrderLink;

  @override
  State<_BudgetDetails> createState() => _BudgetDetailsState();
}

class _BudgetDetailsState extends State<_BudgetDetails> {
  late var _items = _loadItems();
  bool _openingOrder = false;

  Future<void> _openRelatedOrder() async {
    if (_openingOrder) return;
    setState(() => _openingOrder = true);

    try {
      final orders = await _readOrders();
      if (!mounted) return;
      final code = widget.budget['code'];
      final order = orders.where((row) => row['code'] == code).firstOrNull;
      if (order == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La orden asociada ya no está disponible.'),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _OrderDetails(order: order)),
      );
      if (mounted) setState(() => _items = _loadItems());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la orden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingOrder = false);
    }
  }

  Future<List<Map<String, Object?>>> _loadItems() async {
    final db = await _openWorkshop();
    return db.query(
      'budget_items',
      where: 'budget_id = ?',
      whereArgs: [widget.budget['id']],
      orderBy: 'id',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: Text('Presupuesto · ${widget.budget['code']}'),
        showSectionMenu: false,
      ),
      body: FutureBuilder(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo leer el detalle.'));
          }

          final items = snapshot.requireData;
          final total = items.fold<int>(
            0,
            (sum, item) => sum + (item['amount_cents'] as int),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(widget.budget['customer'] as String),
                  subtitle: Text(
                    '${widget.budget['model']}\n'
                    '${_budgetReference(widget.budget['id'])} · ${widget.budget['code']}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xff263943),
                child: ListTile(
                  title: Text(
                    'Total cotizado',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: Text(
                    _budgetAmount(total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Conceptos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Card(child: ListTile(title: Text('Sin conceptos'))),
              for (final item in items)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(item['description'] as String),
                    subtitle: Text(
                      '${item['quantity']} × '
                      '${_budgetAmount((item['amount_cents'] as int) ~/ (item['quantity'] as int))}',
                    ),
                    trailing: Text(_budgetAmount(item['amount_cents'] as int)),
                  ),
                ),
              const SizedBox(height: 12),
              if (widget.budget['validity_days'] != null)
                ListTile(
                  title: const Text('Validez'),
                  trailing: Text('${widget.budget['validity_days']} días'),
                ),
              if (widget.budget['warranty'] case final String warranty)
                ListTile(
                  title: const Text('Garantía'),
                  subtitle: Text(warranty),
                ),
              if (widget.budget['notes'] case final String notes)
                ListTile(
                  title: const Text('Observaciones'),
                  subtitle: Text(notes),
                ),
              _WorkshopPdfButton(
                code: widget.budget['code'] as String,
                budget: true,
              ),
              if (widget.showOrderLink)
                OutlinedButton.icon(
                  onPressed: _openingOrder ? null : _openRelatedOrder,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ir a la orden'),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _createCatalog(Database db) async {
  await db.execute('''
    CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      contact TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE stock_items (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      model TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity >= 0),
      supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL
    )
  ''');

  final supplierId = await db.insert('suppliers', {
    'name': 'Proveedor de prueba',
    'contact': 'repuestos@example.com',
  });
  await db.insert('stock_items', {
    'name': 'Módulo de pantalla',
    'model': 'Samsung Galaxy S22',
    'quantity': 2,
    'supplier_id': supplierId,
  });
  await db.insert('stock_items', {
    'name': 'Puerto de carga',
    'model': 'Motorola Moto G54',
    'quantity': 4,
    'supplier_id': supplierId,
  });
}

class WorkshopCatalogLink extends StatelessWidget {
  const WorkshopCatalogLink({
    super.key,
    required this.suppliers,
    this.supplierNavigation,
  });

  final Widget? supplierNavigation;

  final bool suppliers;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          suppliers
              ? Icons.local_shipping_outlined
              : Icons.inventory_2_outlined,
        ),
        title: Text(suppliers ? 'Proveedores' : 'Stock'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _CatalogPage(
              suppliers: suppliers,
              supplierNavigation: supplierNavigation,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogPage extends StatefulWidget {
  const _CatalogPage({
    required this.suppliers,
    this.supplierId,
    this.supplierNavigation,
  });

  final Widget? supplierNavigation;

  final bool suppliers;
  final int? supplierId;

  @override
  State<_CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<_CatalogPage> {
  late Future<List<Map<String, Object?>>> _rows = _load();
  String _search = '';

  Future<List<Map<String, Object?>>> _load() async {
    final db = await _openWorkshop();

    if (widget.supplierId case final supplierId?) {
      return db.rawQuery(
        '''
        SELECT s.*, i.name AS part, i.model, i.quantity
        FROM suppliers s
        LEFT JOIN stock_items i ON i.supplier_id = s.id
        WHERE s.id = ?
        ORDER BY i.name COLLATE NOCASE
        ''',
        [supplierId],
      );
    }

    if (widget.suppliers) {
      return db.query('suppliers', orderBy: 'name COLLATE NOCASE, id');
    }

    return db.rawQuery('''
      SELECT i.id, i.name, i.model, i.quantity, i.supplier_id, s.name AS supplier
      FROM stock_items i
      LEFT JOIN suppliers s ON s.id = i.supplier_id
      ORDER BY i.name COLLATE NOCASE, i.id
    ''');
  }

  Future<void> _openStockMovements(Map<String, Object?> item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _StockMovementsPage(item: item)),
    );
    if (mounted) setState(() => _rows = _load());
  }

  Future<void> _editStockItem([Map<String, Object?>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StockItemEditor(item: item),
    );
    if (mounted && saved == true) setState(() => _rows = _load());
  }

  Future<void> _editSupplier([Map<String, Object?>? supplier]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _SupplierEditor(
          supplier: supplier,
          supplierNavigation: widget.supplierNavigation,
        ),
      ),
    );

    if (mounted && saved == true) setState(() => _rows = _load());
  }

  Widget _supplierAccentCard(Widget child, Color accent) {
    return Card(
      color: const Color(0xff22272f),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff3d4652)),
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            left: 1,
            top: 3,
            bottom: 3,
            width: 4,
            child: IgnorePointer(child: ColoredBox(color: accent)),
          ),
        ],
      ),
    );
  }

  Widget _supplierListTile(Map<String, Object?> supplier) {
    final savedPhone = (supplier['phone'] as String? ?? '').trim();
    final legacyContact = (supplier['contact'] as String? ?? '').trim();
    final legacyNumber = legacyContact.replaceAll(RegExp(r'[\s().-]'), '');
    final phone = savedPhone.isNotEmpty
        ? savedPhone
        : RegExp(r'^\+?[0-9]{6,15}$').hasMatch(legacyNumber)
        ? legacyContact
        : '';
    final number = phone.replaceAll(RegExp(r'[\s().-]'), '');
    final address = (supplier['address'] as String? ?? '').trim();
    final city = (supplier['city'] as String? ?? '').trim();
    final location = [
      if (address.isNotEmpty) address,
      if (city.isNotEmpty) city,
    ].join(', ');

    return ListTile(
      title: Text(
        supplier['name'] as String,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            phone.isNotEmpty
                ? phone
                : (supplier['contact'] as String? ?? 'Sin contacto registrado'),
          ),
          if (location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                location,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (phone.isNotEmpty)
            IconButton(
              tooltip: 'Abrir WhatsApp',
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF66BD88),
                size: 23,
              ),
              onPressed: () async {
                if (!RegExp(r'^\+[1-9][0-9]{5,14}$').hasMatch(number)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Editá el teléfono e incluí + y el código de país.',
                      ),
                    ),
                  );
                  return;
                }
                await _SupplierContactDetails._open(
                  context,
                  Uri.https('wa.me', '/${number.substring(1)}'),
                );
              },
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _openSupplier(supplier['id'] as int),
    );
  }

  bool _deletingSupplier = false;

  Future<void> _deleteSupplier(Map<String, Object?> supplier) async {
    if (_deletingSupplier) return;
    setState(() => _deletingSupplier = true);
    final route = ModalRoute.of(context);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar proveedor'),
          content: Text(
            'Se eliminarán la ficha de ${supplier['name']} y todos sus datos. '
            'Sus repuestos quedarán en Stock sin proveedor asociado. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || route?.isCurrent != true) return;

      final db = await _openWorkshop();
      await db.delete(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplier['id']],
      );

      if (!mounted) return;
      if (route?.isCurrent == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Proveedor eliminado.')));
        Navigator.of(context).pop();
      } else {
        setState(() => _rows = _load());
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el proveedor.')),
      );
    } finally {
      if (mounted) setState(() => _deletingSupplier = false);
    }
  }

  Future<void> _openSupplier(int id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _CatalogPage(
          suppliers: true,
          supplierId: id,
          supplierNavigation: widget.supplierNavigation,
        ),
      ),
    );
    if (mounted) setState(() => _rows = _load());
  }

  @override
  Widget build(BuildContext context) {
    final isDetail = widget.supplierId != null;
    final title = isDetail
        ? 'Ficha del proveedor'
        : (widget.suppliers ? 'Proveedores' : 'Stock');

    // Encabezado compartido de proveedores.
    final page = Scaffold(
      bottomNavigationBar: widget.suppliers ? widget.supplierNavigation : null,
      backgroundColor: widget.suppliers
          ? Colors.transparent
          : const Color(0xff11151d),
      appBar: widget.suppliers
          ? OrdenSocHeader(
              title: Text(title),
              showSectionMenu: false,
              headerActions: [
                if (isDetail)
                  FutureBuilder<List<Map<String, Object?>>>(
                    future: _rows,
                    builder: (context, snapshot) {
                      final rows = snapshot.data;
                      if (snapshot.connectionState != ConnectionState.done ||
                          snapshot.hasError ||
                          rows == null ||
                          rows.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        tooltip: 'Editar proveedor',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editSupplier(rows.first),
                      );
                    },
                  ),
              ],
            )
          : OrdenSocHeader(
              title: Text(title),
              showSectionMenu: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    tooltip: 'Nuevo repuesto',
                    icon: const Icon(Icons.add),
                    onPressed: () => _editStockItem(),
                  ),
                ),
              ],
            ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _rows = _load()),
                child: Text(
                  widget.suppliers
                      ? 'No se pudieron cargar los proveedores. Reintentar'
                      : 'No se pudo cargar Stock. Reintentar',
                ),
              ),
            );
          }

          final rows = snapshot.requireData;
          if (rows.isEmpty && (!widget.suppliers || isDetail)) {
            return Center(
              child: Text(
                isDetail
                    ? 'Proveedor no disponible.'
                    : 'Todavía no hay repuestos registrados.',
              ),
            );
          }

          if (isDetail) {
            final supplier = rows.first;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Ficha de proveedor: identidad y contacto
                Card(
                  child: ListTile(
                    title: Text(
                      supplier['name'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: supplier['active'] == 1
                                ? const Color(0xff66bd88)
                                : const Color(0xffaab2be),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          supplier['active'] == 1 ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: supplier['active'] == 1
                                ? const Color(0xff66bd88)
                                : const Color(0xffaab2be),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                _SupplierContactDetails(supplier: supplier),
                const Divider(),
                const ListTile(title: Text('Repuestos asociados')),

                if (supplier['part'] == null)
                  const ListTile(title: Text('Sin repuestos asociados')),
                for (final row in rows)
                  if (row['part'] != null)
                    ListTile(
                      title: Text(row['part'] as String),
                      subtitle: Text(row['model'] as String),
                      trailing: Text('${row['quantity']} unidades'),
                    ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _deletingSupplier
                      ? null
                      : () => _deleteSupplier(supplier),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar proveedor'),
                ),
              ],
            );
          }

          final matches = rows.where((row) {
            final name = row['name'] as String;
            final model = row['model'] as String? ?? '';
            return '$name $model'.toLowerCase().contains(_search);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.suppliers) ...[
                _supplierAccentCard(
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Nuevo proveedor'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editSupplier(),
                  ),
                  const Color(0xff00cbe7),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  border: widget.suppliers ? const OutlineInputBorder() : null,
                  labelText: widget.suppliers
                      ? 'Buscar proveedor'
                      : 'Buscar repuesto o modelo',
                ),
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const ListTile(title: Text('Todavía no hay proveedores'))
              else if (matches.isEmpty)
                const ListTile(title: Text('Sin coincidencias')),
              for (final row in matches)
                widget.suppliers
                    ? _supplierAccentCard(
                        _supplierListTile(row),
                        const Color(0xffc9a6f2),
                      )
                    : Card(
                        child: ListTile(
                          title: Text(row['name'] as String),
                          subtitle: Text(
                            '${row['model']}\n${row['supplier'] ?? 'Sin proveedor'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${row['quantity']} u.'),
                              IconButton(
                                tooltip: 'Movimientos de stock',
                                icon: const Icon(Icons.swap_vert),
                                onPressed: () => _openStockMovements(row),
                              ),
                              IconButton(
                                tooltip: 'Editar repuesto',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editStockItem(row),
                              ),
                            ],
                          ),
                          onTap: row['supplier_id'] is int
                              ? () => _openSupplier(row['supplier_id'] as int)
                              : null,
                        ),
                      ),
            ],
          );
        },
      ),
    );
    return widget.suppliers ? OrdenSocBackdrop(child: page) : page;
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (status) {
      'Diagnóstico' => const Color(0xFFB8A7DD),
      'Presupuestado' => const Color(0xFFE0B87B),
      'Reparación' => const Color(0xFF8EC2D4),
      'Entregar' => const Color(0xFF9AC5A2),
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: accent),
          ),
        ),
      ),
    );
  }
}

Future<void> _createOrderPhotos(Database db) async {
  await db.execute('''
    CREATE TABLE order_photos (
      id INTEGER PRIMARY KEY,
      order_id INTEGER NOT NULL
        REFERENCES work_orders(id) ON DELETE CASCADE,
      image BLOB NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX order_photos_order_idx ON order_photos(order_id, id)',
  );
}

class _OrderPhotos extends StatefulWidget {
  const _OrderPhotos({required this.code});

  final String code;

  @override
  State<_OrderPhotos> createState() => _OrderPhotosState();
}

class _OrderPhotosState extends State<_OrderPhotos> {
  late var _photos = _load();
  bool _busy = false;

  Future<List<Map<String, Object?>>> _load() async {
    final db = await _openWorkshop();
    return db.rawQuery(
      '''
      SELECT p.id, p.image
      FROM order_photos p
      JOIN work_orders o ON o.id = p.order_id
      WHERE o.code = ?
      ORDER BY p.id DESC
    ''',
      [widget.code],
    );
  }

  Future<void> _change(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _photos = _load());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(ImageSource source) => _change(() async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (!mounted || file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 750 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Elegí una imagen válida de hasta 750 KB.'),
          ),
        );
      }
      return;
    }

    final db = await _openWorkshop();
    final inserted = await db.rawInsert(
      '''
      INSERT INTO order_photos (order_id, image, attached_at)
      VALUES ((SELECT id FROM work_orders WHERE code = ?), ?, ?)
    ''',
      [widget.code, bytes, DateTime.now().millisecondsSinceEpoch],
    );
    if (inserted < 1) throw StateError('No se guardó la foto.');
  }, 'No se pudo agregar la foto.');

  Future<void> _remove(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Quitar foto'),
        content: const Text('¿Querés quitar esta foto de la orden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialog).colorScheme.error,
              foregroundColor: Theme.of(dialog).colorScheme.onError,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _change(() async {
      final db = await _openWorkshop();
      await db.delete(
        'order_photos',
        where:
            'id = ? AND order_id IN '
            '(SELECT id FROM work_orders WHERE code = ?)',
        whereArgs: [id, widget.code],
      );
    }, 'No se pudo quitar la foto.');
  }

  void _view(List<Map<String, Object?>> photos, int initialIndex) {
    var index = initialIndex;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xff22272f),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    key: ValueKey(index),
                    child: Center(
                      child: Image.memory(
                        photos[index]['image'] as Uint8List,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Text('No se pudo mostrar la foto.'),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Foto anterior',
                      onPressed: index == 0
                          ? null
                          : () => setDialogState(() => index--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${index + 1} / ${photos.length}'),
                    IconButton(
                      tooltip: 'Foto siguiente',
                      onPressed: index == photos.length - 1
                          ? null
                          : () => setDialogState(() => index++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: 'Cerrar fotos',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fotos', style: Theme.of(context).textTheme.titleLarge),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _add(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Sacar foto'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _add(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ],
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _photos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _photos = _load()),
                  child: const Text(
                    'No se pudieron leer las fotos. Reintentar',
                  ),
                );
              }
              final photos = snapshot.requireData;
              if (photos.isEmpty) {
                return const Text('Todavía no hay fotos adjuntas.');
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (index, photo) in photos.indexed)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => _view(photos, index),
                            child: Image.memory(
                              photo['image'] as Uint8List,
                              width: 112,
                              height: 88,
                              cacheWidth: 224,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar foto',
                            onPressed: _busy
                                ? null
                                : () => _remove(photo['id'] as int),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _addCustomerEmail(Database db) =>
    db.execute('ALTER TABLE customers ADD COLUMN email TEXT');

class _CustomerEmailTile extends StatefulWidget {
  const _CustomerEmailTile({required this.customerId});

  final int customerId;

  @override
  State<_CustomerEmailTile> createState() => _CustomerEmailTileState();
}

class _CustomerEmailTileState extends State<_CustomerEmailTile> {
  late Future<String?> _email = _load();
  bool _saving = false;

  Future<String?> _load() async {
    final db = await _openWorkshop();
    final rows = await db.query(
      'customers',
      columns: ['email'],
      where: 'id = ?',
      whereArgs: [widget.customerId],
    );
    return rows.single['email'] as String?;
  }

  Future<void> _edit(String? current) async {
    final form = GlobalKey<FormState>();
    var input = current ?? '';

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Correo de contacto'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              helperText: 'Dejalo vacío para quitarlo.',
            ),
            onChanged: (value) => input = value.trim(),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty ||
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                return null;
              }
              return 'Ingresá un correo válido.';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(dialogContext).pop(input);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!mounted || email == null || _saving) return;
    final value = email.isEmpty ? null : email;
    if (value == current) return;

    setState(() => _saving = true);
    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'customers',
        {'email': value},
        where: 'id = ?',
        whereArgs: [widget.customerId],
      );
      if (updated != 1) throw StateError('Cliente no encontrado.');
      if (mounted) setState(() => _email = Future.value(value));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el correo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<String?>(
        future: _email,
        builder: (context, snapshot) {
          final loaded = snapshot.connectionState == ConnectionState.done;
          return ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Correo de contacto'),
            subtitle: Text(
              snapshot.hasError
                  ? 'No se pudo leer el correo. Tocá para reintentar.'
                  : !loaded
                  ? 'Cargando…'
                  : snapshot.data ?? 'Sin correo registrado',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: !loaded || _saving
                ? null
                : snapshot.hasError
                ? () => setState(() => _email = _load())
                : () => _edit(snapshot.data),
          );
        },
      ),
    );
  }
}

class _CustomerAddressTile extends StatefulWidget {
  const _CustomerAddressTile({required this.customerId});

  final int customerId;

  @override
  State<_CustomerAddressTile> createState() => _CustomerAddressTileState();
}

class _CustomerAddressTileState extends State<_CustomerAddressTile> {
  late Future<String?> _address = _load();
  bool _saving = false;

  Future<String?> _load() async {
    final db = await _openWorkshop();
    final rows = await db.query(
      'customers',
      columns: ['address'],
      where: 'id = ?',
      whereArgs: [widget.customerId],
    );
    return rows.single['address'] as String?;
  }

  Future<void> _edit(String? current) async {
    var input = current ?? '';

    final address = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Dirección del cliente'),
        content: TextFormField(
          initialValue: input,
          keyboardType: TextInputType.streetAddress,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            helperText: 'Dejalo vacío para quitarlo.',
          ),
          onChanged: (value) => input = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(input);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!mounted || address == null || _saving) return;
    final value = address.isEmpty ? null : address;
    if (value == current) return;

    setState(() => _saving = true);
    try {
      final db = await _openWorkshop();
      final updated = await db.update(
        'customers',
        {'address': value},
        where: 'id = ?',
        whereArgs: [widget.customerId],
      );
      if (updated != 1) throw StateError('Cliente no encontrado.');
      if (mounted) setState(() => _address = Future.value(value));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la dirección.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<String?>(
        future: _address,
        builder: (context, snapshot) {
          final loaded = snapshot.connectionState == ConnectionState.done;
          return ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Dirección del cliente'),
            subtitle: Text(
              snapshot.hasError
                  ? 'No se pudo leer la dirección. Tocá para reintentar.'
                  : !loaded
                  ? 'Cargando…'
                  : snapshot.data ?? 'Sin dirección registrada',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: !loaded || _saving
                ? null
                : snapshot.hasError
                ? () => setState(() => _address = _load())
                : () => _edit(snapshot.data),
          );
        },
      ),
    );
  }
}

Future<void> _addBudgetQuantity(Database db) => db.execute(
  'ALTER TABLE budget_items ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1',
);

typedef _BudgetLine = ({String description, int quantity, int unitCents});

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({required this.code});

  final String code;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final _lines = <_BudgetLine>[];
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _error;
  String _validity = '';
  String _warranty = '';
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = await _openWorkshop();
      final finance = await _readOrderFinance(db, widget.code);
      if (!mounted) return;
      final rows = await db.rawQuery(
        '''
        SELECT i.description, i.quantity, i.amount_cents
        FROM budget_items i
        JOIN budgets b ON b.id = i.budget_id
        JOIN work_orders o ON o.id = b.order_id
        WHERE o.code = ?
        ORDER BY i.id
      ''',
        [widget.code],
      );

      if (!mounted) return;
      setState(() {
        _validity = finance.validityDays?.toString() ?? '';
        _warranty = finance.warranty ?? '';
        _notes = finance.notes ?? '';
        for (final row in rows) {
          final quantity = row['quantity'] as int;
          _lines.add((
            description: row['description'] as String,
            quantity: quantity,
            unitCents: (row['amount_cents'] as int) ~/ quantity,
          ));
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = 'No se pudo cargar el presupuesto. Volvé a abrirlo.';
      });
    }
  }

  int? _parsePrice(String input) {
    return _parseAmount(input);
  }

  Future<void> _editLine([int? index]) async {
    final initial = index == null ? null : _lines[index];
    final form = GlobalKey<FormState>();
    var description = initial?.description ?? '';
    var quantity = initial?.quantity.toString() ?? '1';
    var price = initial == null
        ? ''
        : '${initial.unitCents ~/ 100},'
              '${(initial.unitCents % 100).toString().padLeft(2, '0')}';

    final line = await showDialog<_BudgetLine>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(index == null ? 'Agregar concepto' : 'Editar concepto'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                onChanged: (value) => description = value,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Ingresá un concepto.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: quantity,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => quantity = value,
                validator: (value) {
                  final number = int.tryParse((value ?? '').trim());
                  return number == null || number < 1 || number > 9999
                      ? 'Ingresá una cantidad de 1 a 9999.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: price,
                decoration: const InputDecoration(
                  labelText: 'Precio unitario en pesos',
                  prefixIcon: Icon(Icons.payments_outlined),
                  hintText: 'Ejemplo: 1250,50',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => price = value,
                validator: (value) => _parsePrice(value ?? '') == null
                    ? 'Ingresá un precio válido, sin separador de miles.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.of(dialog).pop((
                description: description.trim(),
                quantity: int.parse(quantity.trim()),
                unitCents: _parsePrice(price)!,
              ));
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (!mounted || line == null) return;
    setState(() {
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _lines.isEmpty) return;
    final days = int.tryParse(_validity.trim());
    if (_validity.trim().isNotEmpty &&
        (days == null || days < 1 || days > 3650)) {
      setState(() => _error = 'Ingresá una validez de 1 a 3650 días.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final db = await _openWorkshop();
      final before = await _readOrderFinance(db, widget.code);
      final newTotal = _lines.fold<int>(
        0,
        (sum, line) => sum + line.quantity * line.unitCents,
      );
      final oldTotal = before.agreed;
      if (oldTotal != null && oldTotal != newTotal) {
        if (before.paid) {
          throw StateError('Desmarcá Cobrado antes de cambiar el total.');
        }
        if (newTotal < before.received) {
          throw StateError('El nuevo total es menor que lo que ya cobraste.');
        }
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Corregir total acordado'),
            content: Text(
              'Total anterior: ${_money(oldTotal)}\n'
              'Total nuevo: ${_money(newTotal)}\n'
              'Saldo restante: ${_money(newTotal - before.received)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed != true) {
          setState(() => _saving = false);
          return;
        }
      }
      await db.transaction((txn) async {
        final finance = await _readOrderFinance(txn, widget.code);
        if (finance != before) {
          throw StateError(
            'La orden cambió. Revisá el resumen y volvé a guardar.',
          );
        }
        final orderId = finance.id;

        final budgets = await txn.query(
          'budgets',
          columns: ['id'],
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        final budgetId = budgets.isEmpty
            ? await txn.insert('budgets', {'order_id': orderId})
            : budgets.single['id'] as int;

        await txn.update(
          'budgets',
          {
            'validity_days': days,
            'warranty': _warranty.trim().isEmpty ? null : _warranty.trim(),
            'notes': _notes.trim().isEmpty ? null : _notes.trim(),
          },
          where: 'id = ?',
          whereArgs: [budgetId],
        );
        await txn.delete(
          'budget_items',
          where: 'budget_id = ?',
          whereArgs: [budgetId],
        );
        for (final line in _lines) {
          await txn.insert('budget_items', {
            'budget_id': budgetId,
            'description': line.description,
            'quantity': line.quantity,
            'amount_cents': line.quantity * line.unitCents,
          });
        }
        if (oldTotal != null && oldTotal != newTotal) {
          await txn.update(
            'work_orders',
            {'agreed_cents': newTotal},
            where: 'id = ?',
            whereArgs: [orderId],
          );
        }
      });

      if (mounted) Navigator.of(context).pop(true);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar. Tus cambios siguen en el editor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<int>(
      0,
      (sum, line) => sum + line.quantity * line.unitCents,
    );

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xff11151d),
        appBar: OrdenSocHeader(
          title: const Text('Editar presupuesto'),
          showSectionMenu: false,
        ),
        bottomNavigationBar: _loading || _loadFailed
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: const Color(0xff263943),
                      child: ListTile(
                        title: const Text('Total cotizado'),
                        trailing: Text(
                          _budgetAmount(total),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving || _lines.isEmpty ? null : _save,
                      child: Text(
                        _saving ? 'Guardando…' : 'Guardar presupuesto',
                      ),
                    ),
                  ],
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Conceptos'),
                    subtitle: Text('Orden ${widget.code}'),
                  ),
                  for (var i = 0; i < _lines.length; i++)
                    Card(
                      child: ListTile(
                        title: Text(_lines[i].description),
                        subtitle: Text(
                          '${_lines[i].quantity} × ${_budgetAmount(_lines[i].unitCents)}\n'
                          'Subtotal: ${_budgetAmount(_lines[i].quantity * _lines[i].unitCents)}',
                        ),
                        onTap: _saving ? null : () => _editLine(i),
                        trailing: IconButton(
                          tooltip: 'Quitar concepto',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _lines.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  if (!_loadFailed) ...[
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _editLine(),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar concepto'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _validity,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Validez en días',
                      ),
                      onChanged: (value) => _validity = value,
                    ),
                    TextFormField(
                      initialValue: _warranty,
                      enabled: !_saving,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Garantía'),
                      onChanged: (value) => _warranty = value,
                    ),
                    TextFormField(
                      initialValue: _notes,
                      enabled: !_saving,
                      maxLength: 400,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones del presupuesto',
                      ),
                      onChanged: (value) => _notes = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

Future<void> _addDeviceFields(Database db) async {
  await db.execute('ALTER TABLE devices ADD COLUMN brand TEXT');
  await db.execute('ALTER TABLE devices ADD COLUMN color TEXT');
  await db.execute('ALTER TABLE devices ADD COLUMN device_identifier TEXT');
}

String _deviceLabel(Map<String, Object?> device) {
  final brand = device['brand'] as String? ?? '';
  return '$brand ${device['model']}'.trim();
}

Future<bool?> _showWorkshopDevice(
  BuildContext context,
  Map<String, Object?> device, {
  bool canEdit = false,
}) async {
  final fichaFrp = _readDeviceFrp(device['id'] as int);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      backgroundColor: const Color(0xff22272f),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xff454b55)),
      ),
      title: const Text('Ficha del equipo'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_android),
            title: Text(_deviceLabel(device)),
          ),
          Text('Marca: ${device['brand'] ?? 'Sin registrar'}'),
          Text('Modelo: ${device['model']}'),
          Text('Color: ${device['color'] ?? 'Sin registrar'}'),
          Builder(
            builder: (tileContext) {
              final identifier =
                  (device['device_identifier'] as String?)?.trim() ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('IMEI / Número de serie'),
                subtitle: Text(
                  identifier.isEmpty ? 'Sin registrar' : identifier,
                ),
                onTap: identifier.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: identifier),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Identificador copiado.'),
                          ),
                        );
                      },
              );
            },
          ),
          FutureBuilder<Map<String, Object?>?>(
            future: fichaFrp,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('No se pudo leer la información FRP.'),
                );
              }

              final ficha = snapshot.data;
              return ficha == null
                  ? const SizedBox.shrink()
                  : _DeviceFrpDetails(ficha: ficha);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cerrar'),
        ),
        if (canEdit)
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Editar'),
          ),
      ],
    ),
  );
}

extension on _CustomerDetailsState {
  Future<void> _showDevice(Map<String, Object?> device) async {
    final edit = await _showWorkshopDevice(context, device, canEdit: true);
    if (mounted && edit == true) await _saveDevice(device);
  }

  Future<void> _saveDevice([Map<String, Object?>? device]) async {
    final form = GlobalKey<FormState>();
    final fields = <String, String>{
      'brand': 'Marca',
      'model': 'Modelo',
      'color': 'Color',
      'device_identifier': 'IMEI / Número de serie',
    };
    final values = <String, String>{
      for (final field in fields.keys) field: device?[field] as String? ?? '',
    };
    var saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            backgroundColor: const Color(0xff22272f),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff454b55)),
            ),
            title: Text(device == null ? 'Agregar equipo' : 'Editar equipo'),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields.entries)
                    TextFormField(
                      initialValue: values[field.key],
                      enabled: !saving,
                      decoration: InputDecoration(
                        labelText: field.value,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => values[field.key] = value.trim(),
                      validator: (value) {
                        final required =
                            field.key == 'brand' || field.key == 'model';
                        if (required && (value ?? '').trim().isEmpty) {
                          return 'Completá ${field.value.toLowerCase()}.';
                        }
                        return null;
                      },
                    ),
                  if (error != null) Text(error!),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (saving || !form.currentState!.validate()) return;
                        updateDialog(() {
                          saving = true;
                          error = null;
                        });

                        try {
                          final db = await _openWorkshop();
                          final customerId = widget.customer['customer_id'];
                          final data = <String, Object?>{
                            for (final entry in values.entries)
                              entry.key: entry.value.isEmpty
                                  ? null
                                  : entry.value,
                          };

                          if (device == null) {
                            await db.insert('devices', {
                              ...data,
                              'customer_id': customerId,
                            });
                          } else {
                            final updated = await db.update(
                              'devices',
                              data,
                              where: 'id = ? AND customer_id = ?',
                              whereArgs: [device['id'], customerId],
                            );
                            if (updated != 1) {
                              throw StateError('Equipo no encontrado.');
                            }
                          }

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            updateDialog(() {
                              saving = false;
                              error = 'No se pudo guardar el equipo.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Guardando…' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (mounted && saved == true) _reload();
  }
}

Future<void> _addReceptionFields(Database db) async {
  await db.execute('ALTER TABLE work_orders ADD COLUMN received_at INTEGER');
  await db.execute(
    'ALTER TABLE work_orders ADD COLUMN received_accessories TEXT',
  );
  await db.execute('ALTER TABLE work_orders ADD COLUMN intake_notes TEXT');
}

typedef _ReceptionData = ({
  String issue,
  String? accessories,
  String? notes,
  String status,
});

class _ReceptionDialog extends StatefulWidget {
  const _ReceptionDialog({required this.deviceLabel});

  final String deviceLabel;

  @override
  State<_ReceptionDialog> createState() => _ReceptionDialogState();
}

class _ReceptionDialogState extends State<_ReceptionDialog> {
  final _form = GlobalKey<FormState>();
  String _issue = '';
  String _accessories = '';
  String _notes = '';
  String _status = 'Pendiente';

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop<_ReceptionData>((
      issue: _issue,
      accessories: _accessories.isEmpty ? null : _accessories,
      notes: _notes.isEmpty ? null : _notes,
      status: _status,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: const Color(0xff22272f),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xff454b55)),
      ),
      title: const Text('Recepción de la orden'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_android),
              title: Text(
                widget.deviceLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Falla declarada',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: (value) => _issue = value.trim(),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Ingresá la falla que informó el cliente.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Accesorios recibidos',
              ),
              onChanged: (value) => _accessories = value.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Observaciones del ingreso',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: (value) => _notes = value.trim(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final status in _OrderDetailsState._statuses)
                  DropdownMenuItem(value: status, child: Text(status)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff10d9ef),
            foregroundColor: const Color(0xff11151d),
          ),
          child: const Text('Crear orden'),
        ),
      ],
    );
  }
}

class _OrderReceptionCard extends StatefulWidget {
  const _OrderReceptionCard({required this.code});

  final String code;

  @override
  State<_OrderReceptionCard> createState() => _OrderReceptionCardState();
}

class _OrderReceptionCardState extends State<_OrderReceptionCard> {
  late Future<Map<String, Object?>> _reception = _load();

  Future<void> _editField(
    String field,
    String label,
    Object? previous, {
    bool clear = false,
  }) async {
    Object? next;
    if (field == 'received_at') {
      final today = DateUtils.dateOnly(DateTime.now());
      final current = previous is int
          ? DateTime.fromMillisecondsSinceEpoch(previous)
          : today;
      final first = DateTime(current.year < 2000 ? current.year : 2000);
      final last = current.isAfter(today) ? DateUtils.dateOnly(current) : today;
      final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: first,
        lastDate: last,
      );
      if (picked == null) return;
      next = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      ).millisecondsSinceEpoch;
    } else if (!clear) {
      var value = previous as String? ?? '';
      next = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(label),
          content: TextFormField(
            initialValue: value,
            maxLines: 3,
            onChanged: (text) => value = text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(value.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (next == null || next == '') return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Quitar $label'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    try {
      final db = await _openWorkshop();
      final count = await db.update(
        'work_orders',
        {field: next},
        where: 'code = ? AND $field IS ?',
        whereArgs: [widget.code, previous],
      );
      if (!mounted) return;
      setState(() => _reception = _load());
      if (count != 1) throw StateError('La recepción cambió');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la recepción.')),
        );
      }
    }
  }

  Widget _field(String field, String label, String value, Object? previous) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      trailing: PopupMenuButton<bool>(
        tooltip: 'Acciones de $label',
        onSelected: (clear) => _editField(field, label, previous, clear: clear),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: false,
            child: Text(previous == null ? 'Agregar' : 'Editar'),
          ),
          if (field != 'received_at' && previous != null)
            const PopupMenuItem(value: true, child: Text('Quitar')),
        ],
      ),
    );
  }

  Future<Map<String, Object?>> _load() async {
    final db = await _openWorkshop();
    final rows = await db.query(
      'work_orders',
      columns: ['received_at', 'received_accessories', 'intake_notes'],
      where: 'code = ?',
      whereArgs: [widget.code],
    );
    return rows.single;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<Map<String, Object?>>(
        future: _reception,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: const Text('No se pudo leer la recepción.'),
              subtitle: const Text('Tocá para reintentar.'),
              onTap: () => setState(() => _reception = _load()),
            );
          }

          final data = snapshot.data;
          if (data == null) return const LinearProgressIndicator();

          final timestamp = data['received_at'] as int?;
          final date = timestamp == null
              ? 'Sin fecha registrada'
              : MaterialLocalizations.of(context).formatShortDate(
                  DateTime.fromMillisecondsSinceEpoch(timestamp),
                );

          return Column(
            children: [
              _field('received_at', 'Fecha de ingreso', date, timestamp),
              _field(
                'received_accessories',
                'Accesorios recibidos',
                data['received_accessories'] as String? ?? 'Sin registrar',
                data['received_accessories'],
              ),
              _field(
                'intake_notes',
                'Observaciones del ingreso',
                data['intake_notes'] as String? ?? 'Sin registrar',
                data['intake_notes'],
              ),
            ],
          );
        },
      ),
    );
  }
}

const _supplierFields = {
  'contact_person': 'Persona de contacto',
  'phone': 'Teléfono / WhatsApp',
  'address': 'Dirección',
  'city': 'Ciudad',
  'hours': 'Horarios de atención',
  'website': 'Página web',
  'email': 'Correo electrónico',
  'tax_id': 'CUIT',
  'category': 'Categoría / rubro',
  'payment_terms': 'Condiciones de pago',
  'warranty_days': 'Garantía (días)',
  'notes': 'Observaciones',
};

Uri? _supplierWebsite(String value) {
  final text = value.trim();
  if (text.isEmpty || RegExp(r'\s').hasMatch(text)) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

class _SupplierContactDetails extends StatelessWidget {
  const _SupplierContactDetails({required this.supplier});

  final Map<String, Object?> supplier;

  static Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show the same message if Android cannot open the destination.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el contacto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = (supplier['phone'] as String? ?? '').replaceAll(
      RegExp(r'[\s().-]'),
      '',
    );
    final address = supplier['address'] as String?;
    final city = supplier['city'] as String?;
    final website = _supplierWebsite(supplier['website'] as String? ?? '');
    final email = supplier['email'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Column(
            children: [
              if ((supplier['contact'] as String? ?? '').trim().isNotEmpty)
                ListTile(
                  title: const Text('Contacto registrado'),
                  subtitle: Text(supplier['contact'] as String),
                ),
              for (final field in _supplierFields.entries)
                if (supplier[field.key] != null)
                  ListTile(
                    leading: Icon(switch (field.key) {
                      'phone' => Icons.call_outlined,
                      'email' => Icons.mail_outline,
                      'address' || 'city' => Icons.location_on_outlined,
                      'website' => Icons.language,
                      'contact_person' => Icons.person_outline,
                      'hours' => Icons.schedule_outlined,
                      _ => Icons.info_outline,
                    }),
                    title: Text(field.value),

                    subtitle: Text(supplier[field.key].toString()),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (RegExp(r'^\+?[0-9]{6,15}$').hasMatch(phone))
                OutlinedButton.icon(
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Llamar'),
                  onPressed: () =>
                      _open(context, Uri(scheme: 'tel', path: phone)),
                ),
              if (RegExp(r'^\+[1-9][0-9]{5,14}$').hasMatch(phone))
                OutlinedButton.icon(
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Color(0xFF66BD88),
                    size: 18,
                  ),
                  label: const Text('WhatsApp'),
                  onPressed: () => _open(
                    context,
                    Uri.https('wa.me', '/${phone.substring(1)}'),
                  ),
                ),
              if (website != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.language),
                  label: const Text('Abrir web'),
                  onPressed: () => _open(context, website),
                ),
              if (email != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Enviar correo'),
                  onPressed: () =>
                      _open(context, Uri(scheme: 'mailto', path: email)),
                ),
              if (address != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Ver en Maps'),
                  onPressed: () => _open(
                    context,
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': [address, ?city].join(', '),
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupplierEditor extends StatefulWidget {
  const _SupplierEditor({this.supplier, this.supplierNavigation});

  final Widget? supplierNavigation;

  final Map<String, Object?>? supplier;

  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.supplier?['name'] as String? ?? '';
  late String _contact = widget.supplier?['contact'] as String? ?? '';
  late bool _active = widget.supplier?['active'] != 0;
  late final _fields = <String, String>{
    for (final key in _supplierFields.keys)
      key: widget.supplier?[key]?.toString() ?? '',
  };
  bool _saving = false;

  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final db = await _openWorkshop();
      final data = <String, Object?>{
        'name': _name.trim(),
        'contact': _contact.trim().isEmpty ? null : _contact.trim(),
        'active': _active ? 1 : 0,
        for (final field in _fields.entries)
          field.key: field.key == 'warranty_days'
              ? int.tryParse(field.value.trim())
              : field.value.trim().isEmpty
              ? null
              : field.value.trim(),
      };
      final supplier = widget.supplier;

      if (supplier == null) {
        await db.insert('suppliers', data);
      } else {
        final updated = await db.update(
          'suppliers',
          data,
          where: 'id = ?',
          whereArgs: [supplier['id']],
        );
        if (updated != 1) throw StateError('Proveedor no encontrado.');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el proveedor. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const camposPrincipales = ['phone', 'address', 'city'];
    return PopScope(
      canPop: !_saving,
      // Formulario de proveedor a pantalla completa.
      child: OrdenSocBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: OrdenSocHeader(
            title: Text(
              widget.supplier == null ? 'Nuevo proveedor' : 'Editar proveedor',
            ),
            showSectionMenu: false,
            headerActions: const [],
          ),
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      initialValue: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Nombre comercial',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _name = value,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Ingresá el nombre.'
                          : null,
                    ),
                  ),
                  for (final field in [
                    for (final key in camposPrincipales)
                      MapEntry(key, _supplierFields[key]!),
                    for (final field in _supplierFields.entries)
                      if (!camposPrincipales.contains(field.key)) field,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        initialValue: _fields[field.key],
                        enabled: !_saving,
                        minLines: field.key == 'notes' ? 3 : 1,
                        maxLines: field.key == 'notes' ? 6 : 1,
                        keyboardType: switch (field.key) {
                          'phone' => TextInputType.phone,
                          'website' => TextInputType.url,
                          'email' => TextInputType.emailAddress,
                          'warranty_days' => TextInputType.number,
                          'notes' => TextInputType.multiline,
                          _ => TextInputType.text,
                        },
                        decoration: InputDecoration(
                          labelText: field.value,
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(switch (field.key) {
                            'phone' => Icons.call_outlined,
                            'address' || 'city' => Icons.location_on_outlined,
                            'website' => Icons.language,
                            'email' => Icons.mail_outline,
                            'contact_person' => Icons.person_outline,
                            'hours' => Icons.schedule_outlined,
                            _ => Icons.info_outline,
                          }),

                          helperText: field.key == 'phone'
                              ? 'Para WhatsApp, usá + y el código de país.'
                              : null,
                        ),
                        onChanged: (value) => _fields[field.key] = value,
                        validator: (input) {
                          final value = (input ?? '').trim();
                          if (value.isEmpty) return null;
                          if (field.key == 'website' &&
                              _supplierWebsite(value) == null) {
                            return 'Ingresá una dirección web válida.';
                          }
                          if (field.key == 'phone' &&
                              !RegExp(r'^\+?[0-9]{6,15}$').hasMatch(
                                value.replaceAll(RegExp(r'[\s().-]'), ''),
                              )) {
                            return 'Ingresá un teléfono válido.';
                          }
                          if (field.key == 'warranty_days' &&
                              (int.tryParse(value) ?? -1) < 0) {
                            return 'Ingresá una cantidad de días válida.';
                          }
                          return null;
                        },
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_active ? 'Activo' : 'Inactivo'),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      initialValue: _contact,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Contacto anterior (opcional)',
                        helperText: 'Teléfono, correo o enlace',
                      ),
                      onChanged: (value) => _contact = value,
                    ),
                  ),
                  if (_error != null) Text(_error!),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Guardando…' : 'Guardar'),
                      ),
                    ],
                  ),
                ),
                if (widget.supplierNavigation case final navigation?)
                  ExcludeFocus(
                    excluding: _saving,
                    child: IgnorePointer(ignoring: _saving, child: navigation),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockItemEditor extends StatefulWidget {
  const _StockItemEditor({this.item});

  final Map<String, Object?>? item;

  @override
  State<_StockItemEditor> createState() => _StockItemEditorState();
}

class _StockItemEditorState extends State<_StockItemEditor> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.item?['name'] as String? ?? '';
  late String _model = widget.item?['model'] as String? ?? '';
  late int _supplierId = widget.item?['supplier_id'] as int? ?? 0;
  late Future<List<Map<String, Object?>>> _suppliers = _loadSuppliers();
  bool _saving = false;
  String? _error;

  Future<List<Map<String, Object?>>> _loadSuppliers() async {
    final db = await _openWorkshop();
    return db.query('suppliers', orderBy: 'name COLLATE NOCASE, id');
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final db = await _openWorkshop();
      final data = <String, Object?>{
        'name': _name.trim(),
        'model': _model.trim(),
        'supplier_id': _supplierId == 0 ? null : _supplierId,
      };
      final item = widget.item;

      if (item == null) {
        await db.insert('stock_items', {...data, 'quantity': 0});
      } else {
        final updated = await db.update(
          'stock_items',
          data,
          where: 'id = ?',
          whereArgs: [item['id']],
        );
        if (updated != 1) throw StateError('Repuesto no encontrado.');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el repuesto. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: FutureBuilder<List<Map<String, Object?>>>(
        future: _suppliers,
        builder: (context, snapshot) {
          final suppliers = snapshot.data;
          return AlertDialog(
            scrollable: true,
            backgroundColor: const Color(0xff22272f),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff454b55)),
            ),
            title: Text(
              widget.item == null ? 'Nuevo repuesto' : 'Editar repuesto',
            ),
            content: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    onChanged: (value) => _name = value,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresá el nombre del repuesto.'
                        : null,
                  ),
                  TextFormField(
                    initialValue: _model,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Modelo compatible',
                    ),
                    onChanged: (value) => _model = value,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresá el modelo compatible.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () =>
                          setState(() => _suppliers = _loadSuppliers()),
                      child: const Text(
                        'No se pudieron leer los proveedores. Reintentar',
                      ),
                    )
                  else if (suppliers == null)
                    const LinearProgressIndicator()
                  else
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _supplierId,
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('Sin proveedor'),
                        ),
                        for (final supplier in suppliers)
                          DropdownMenuItem(
                            value: supplier['id'] as int,
                            child: Text(
                              supplier['name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _supplierId = value);
                              }
                            },
                    ),
                  if (_error != null) Text(_error!),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving || suppliers == null ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _createStockMovements(Database db) async {
  await db.execute('''
    CREATE TABLE stock_movements (
      id INTEGER PRIMARY KEY,
      stock_item_id INTEGER NOT NULL REFERENCES stock_items(id),
      delta INTEGER NOT NULL CHECK (delta <> 0),
      reason TEXT NOT NULL,
      recorded_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX stock_movements_item_idx ON stock_movements(stock_item_id, id)',
  );
  await db.rawInsert(
    '''
    INSERT INTO stock_movements (stock_item_id, delta, reason, recorded_at)
    SELECT id, quantity, ?, ? FROM stock_items WHERE quantity > 0
  ''',
    ['Saldo inicial', DateTime.now().millisecondsSinceEpoch],
  );
}

typedef _StockMovementInput = ({int delta, String reason});

class _StockMovementsPage extends StatefulWidget {
  const _StockMovementsPage({required this.item});

  final Map<String, Object?> item;

  @override
  State<_StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<_StockMovementsPage> {
  int get _itemId => widget.item['id'] as int;
  late var _data = _load();
  bool _saving = false;

  Future<({int balance, List<Map<String, Object?>> history})> _load() async {
    final db = await _openWorkshop();
    return db.transaction((txn) async {
      final item = await txn.query(
        'stock_items',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [_itemId],
      );
      final history = await txn.query(
        'stock_movements',
        where: 'stock_item_id = ?',
        whereArgs: [_itemId],
        orderBy: 'id DESC',
      );
      return (balance: item.single['quantity'] as int, history: history);
    });
  }

  Future<void> _register(bool incoming) async {
    final form = GlobalKey<FormState>();
    var quantity = '';
    var reason = '';

    final input = await showDialog<_StockMovementInput>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xff22272f),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff454b55)),
        ),
        title: Text(incoming ? 'Registrar entrada' : 'Registrar salida'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                onChanged: (value) => quantity = value.trim(),
                validator: (value) {
                  final number = int.tryParse((value ?? '').trim());
                  if (number == null || number < 1 || number > 999999) {
                    return 'Ingresá una cantidad de 1 a 999999.';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Motivo'),
                onChanged: (value) => reason = value.trim(),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Ingresá un motivo.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final units = int.parse(quantity);
              Navigator.of(dialogContext).pop<_StockMovementInput>((
                delta: incoming ? units : -units,
                reason: reason,
              ));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!mounted || input == null || _saving) return;
    setState(() => _saving = true);

    try {
      final db = await _openWorkshop();
      final saved = await db.transaction((txn) async {
        final updated = await txn.rawUpdate(
          '''
          UPDATE stock_items
          SET quantity = quantity + ?
          WHERE id = ? AND quantity + ? >= 0
        ''',
          [input.delta, _itemId, input.delta],
        );
        if (updated != 1) return false;

        await txn.insert('stock_movements', {
          'stock_item_id': _itemId,
          'delta': input.delta,
          'reason': input.reason,
          'recorded_at': DateTime.now().millisecondsSinceEpoch,
        });
        return true;
      });

      if (!mounted) return;
      if (saved) {
        setState(() => _data = _load());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock insuficiente o repuesto no disponible.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el movimiento.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xff11151d),
        appBar: OrdenSocHeader(
          title: const Text('Movimientos de stock'),
          showSectionMenu: false,
        ),
        body: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: OutlinedButton(
                  onPressed: () => setState(() => _data = _load()),
                  child: const Text('No se pudo cargar el stock. Reintentar'),
                ),
              );
            }

            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(widget.item['name'] as String),
                    subtitle: Text('Saldo: ${data.balance} unidades'),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _saving ? null : () => _register(true),
                      child: const Text('Entrada'),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _register(false),
                      child: const Text('Salida'),
                    ),
                  ],
                ),
                const Divider(),
                if (data.history.isEmpty)
                  const ListTile(title: Text('Todavía no hay movimientos.')),
                for (final movement in data.history)
                  Card(
                    child: ListTile(
                      title: Text(movement['reason'] as String),
                      subtitle: Text(
                        MaterialLocalizations.of(context).formatShortDate(
                          DateTime.fromMillisecondsSinceEpoch(
                            movement['recorded_at'] as int,
                          ),
                        ),
                      ),
                      trailing: Text(
                        '${(movement['delta'] as int) > 0 ? '+' : ''}'
                        '${movement['delta']} u.',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkshopPdfButton extends StatefulWidget {
  const _WorkshopPdfButton({required this.code, this.budget = false});

  final String code;
  final bool budget;

  @override
  State<_WorkshopPdfButton> createState() => _WorkshopPdfButtonState();
}

class _WorkshopPdfButtonState extends State<_WorkshopPdfButton> {
  bool _busy = false;

  Future<List<Map<String, Object?>>?> _selectPhotos(
    List<Map<String, Object?>> photos,
  ) {
    final selected = <int>{};
    return showDialog<List<Map<String, Object?>>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setSelection) => AlertDialog(
          title: const Text('Fotos para compartir'),
          content: SizedBox(
            width: 420,
            height: 260,
            child: ListView.builder(
              itemCount: photos.length,
              itemBuilder: (context, index) => CheckboxListTile(
                title: Text('Foto ${index + 1}'),
                secondary: Image.memory(
                  photos[index]['image'] as Uint8List,
                  width: 52,
                  height: 44,
                  fit: BoxFit.cover,
                ),
                value: selected.contains(index),
                onChanged: (checked) => setSelection(() {
                  if (checked == true) {
                    selected.add(index);
                  } else {
                    selected.remove(index);
                  }
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop([
                for (var i = 0; i < photos.length; i++)
                  if (selected.contains(i)) photos[i],
              ]),
              child: Text(selected.isEmpty ? 'Exportar sin fotos' : 'Exportar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final db = await _openWorkshop();
      final data = await db.transaction((txn) async {
        final orders = await txn.rawQuery(
          '''
          SELECT o.id, o.code, o.issue, o.status, o.received_at,
                 o.received_accessories, o.intake_notes, o.pickup_date,
                 o.frp_method,
                 c.name AS customer,
                 c.phone AS customer_phone, c.email AS customer_email,
                 d.color AS device_color, d.device_identifier, d.brand, d.model,
                 b.id AS budget_id
          FROM work_orders o
          JOIN devices d ON d.id = o.device_id
          JOIN customers c ON c.id = d.customer_id
          LEFT JOIN budgets b ON b.order_id = o.id
          WHERE o.code = ?
        ''',
          [widget.code],
        );

        final order = orders.single;
        final items = widget.budget
            ? await txn.rawQuery(
                '''
                SELECT i.description, i.quantity, i.amount_cents
                FROM budget_items i
                JOIN budgets b ON b.id = i.budget_id
                WHERE b.order_id = ?
                ORDER BY i.id
              ''',
                [order['id']],
              )
            : <Map<String, Object?>>[];

        if (widget.budget && items.isEmpty) {
          throw StateError('Presupuesto sin conceptos.');
        }

        final photos = await txn.query(
          'order_photos',
          columns: ['image', 'attached_at'],
          where: 'order_id = ?',
          whereArgs: [order['id']],
          orderBy: 'id',
        );
        final finance = await _readOrderFinance(txn, widget.code);
        return (order: order, items: items, photos: photos, finance: finance);
      });

      if (!mounted) return;
      final order = data.order;
      final items = data.items;
      final photos = widget.budget && data.photos.isNotEmpty
          ? await _selectPhotos(data.photos)
          : data.photos;
      if (!mounted || photos == null) return;
      final finance = data.finance;
      final received = order['received_at'] as int?;
      final pickup = DateTime.tryParse(order['pickup_date'] as String? ?? '');
      final title = widget.budget ? 'Presupuesto' : 'Orden de trabajo';
      final agreed = finance.agreed;
      final total = agreed ?? finance.quoted;
      final balance = total == null ? null : total - finance.received;

      pw.Widget heading(String label) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

      pw.Widget field(String label, Object? value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(
          '$label: ${(value?.toString().trim() ?? '').isEmpty ? 'Sin registrar' : value}',
        ),
      );

      const budgetAccent = PdfColor(0.43, 0.33, 0.19);
      const budgetTint = PdfColor(0.96, 0.93, 0.87);
      pw.Widget economicRow(
        String label,
        String value, {
        bool highlight = false,
      }) {
        final style = pw.TextStyle(
          color: highlight ? budgetAccent : null,
          fontSize: highlight ? 13 : 10,
          fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
        );
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: style),
              pw.Text(value, style: style),
            ],
          ),
        );
      }

      String attachmentDate(int? timestamp) => timestamp == null
          ? ''
          : ' · Adjuntada el ${_displayDate(DateTime.fromMillisecondsSinceEpoch(timestamp))}';

      final documentReference = widget.budget
          ? "PR-${order['budget_id'].toString().padLeft(6, '0')}"
          : widget.code;
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(36),
          maxPages: 25 + photos.length,
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'v370',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Servicio técnico'),
              if (!widget.budget) pw.Text('Uso interno del taller'),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8),
                height: 2,
                width: 54,
                color: budgetAccent,
              ),
              pw.Divider(),
            ],
          ),
          footer: (page) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '$documentReference · Página ${page.pageNumber} de ${page.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (_) => [
            pw.SizedBox(height: 12),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (widget.budget) field('Presupuesto', documentReference),
            field(widget.budget ? 'Orden asociada' : 'Orden', order['code']),
            field('Fecha de emisión', _displayDate(DateTime.now())),
            heading('Datos del cliente'),
            field('Nombre', order['customer']),
            field('Teléfono', order['customer_phone']),
            field('Correo', order['customer_email']),
            heading('Datos del equipo'),
            field('Marca', order['brand']),
            field('Modelo', order['model']),
            field('IMEI / Número de serie', order['device_identifier']),
            field('Color', order['device_color']),
            if (widget.budget) ...[
              heading('Detalle del presupuesto'),
              pw.TableHelper.fromTextArray(
                headerDecoration: const pw.BoxDecoration(color: budgetTint),
                headers: const [
                  'Concepto',
                  'Cant.',
                  'Precio unitario',
                  'Subtotal',
                ],
                data: [
                  for (final item in items)
                    [
                      item['description'],
                      item['quantity'],
                      _money(
                        (item['amount_cents'] as int) ~/
                            (item['quantity'] as int),
                      ),
                      _money(item['amount_cents'] as int),
                    ],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellPadding: const pw.EdgeInsets.all(7),
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2.4),
                  3: const pw.FlexColumnWidth(2.4),
                },
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: const pw.BoxDecoration(color: budgetTint),
                child: economicRow(
                  'Total del presupuesto',
                  _money(finance.quoted ?? 0),
                  highlight: true,
                ),
              ),
            ] else ...[
              heading('Recepción'),
              field(
                'Fecha de ingreso',
                received == null
                    ? null
                    : _displayDate(
                        DateTime.fromMillisecondsSinceEpoch(received),
                      ),
              ),
              field('Accesorios recibidos', order['received_accessories']),
              field('Falla declarada', order['issue']),
              if (order['frp_method'] != null)
                field('Método FRP a utilizar', order['frp_method']),
              field('Observaciones del ingreso', order['intake_notes']),
              field('Estado', order['status']),
              if (pickup != null) field('Retiro pactado', _displayDate(pickup)),
            ],
            if (!widget.budget) ...[
              heading('Resumen económico'),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: const pw.BoxDecoration(color: budgetTint),
                child: pw.Column(
                  children: [
                    economicRow(
                      agreed != null ? 'Total acordado' : 'Total presupuestado',
                      total == null ? 'Sin presupuesto' : _money(total),
                    ),
                    economicRow('Seña recibida', _money(finance.deposits)),
                    economicRow('Total cobrado', _money(finance.received)),
                    economicRow(
                      balance != null && balance < 0
                          ? 'Cobrado por encima del presupuesto'
                          : 'Saldo restante',
                      balance == null ? 'Por calcular' : _money(balance.abs()),
                      highlight: true,
                    ),
                  ],
                ),
              ),
            ],
            if (widget.budget &&
                (finance.validityDays != null ||
                    finance.warranty != null ||
                    finance.notes != null)) ...[
              heading('Condiciones del presupuesto'),
              if (finance.validityDays != null)
                field('Validez', '${finance.validityDays} días'),
              if (finance.warranty != null) field('Garantía', finance.warranty),
              if (finance.notes != null) field('Observaciones', finance.notes),
            ],
            pw.SizedBox(height: 18),
            pw.Text(
              'Firma / conformidad del cliente __________________________',
            ),
            if (photos.isNotEmpty) ...[
              pw.NewPage(),
              heading('Registro fotográfico · ${widget.code}'),
              for (var index = 0; index < photos.length; index += 2)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Row(
                    mainAxisAlignment: photos.length == 1
                        ? pw.MainAxisAlignment.center
                        : pw.MainAxisAlignment.start,
                    children: [
                      for (var column = 0; column < 2; column++)
                        if (index + column < photos.length)
                          pw.Container(
                            width: photos.length == 1 ? 420 : 230,
                            margin: const pw.EdgeInsets.only(right: 8),
                            child: pw.Column(
                              children: [
                                pw.Image(
                                  pw.MemoryImage(
                                    photos[index + column]['image']
                                        as Uint8List,
                                  ),
                                  width: photos.length == 1 ? 420 : 230,
                                  height: photos.length == 1 ? 230 : 145,
                                  fit: pw.BoxFit.contain,
                                ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  'Foto ${index + column + 1}'
                                  '${attachmentDate(photos[index + column]['attached_at'] as int?)}',
                                  textAlign: pw.TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
      final bytes = await document.save();
      if (!mounted) return;

      final prefix = widget.budget ? 'presupuesto' : 'orden';
      await Printing.sharePdf(
        bytes: bytes,
        filename: '$prefix-$documentReference.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo exportar el PDF.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _export,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_busy ? 'Generando PDF…' : 'Exportar PDF'),
    );
  }
}

Future<void> _createDeviceFrp(Database db) => db.execute('''
  CREATE TABLE device_frp (
    device_id INTEGER PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    build_number TEXT NOT NULL,
    brand TEXT,
    model TEXT,
    android_version TEXT,
    processor_soc TEXT,
    binary TEXT,
    method TEXT
  )
''');

Future<List<Map<String, Object?>>> readFrpDevices() async {
  final db = await _openWorkshop();
  return db.rawQuery('''
    SELECT d.id, d.model, c.name AS customer,
           EXISTS(SELECT 1 FROM device_frp f WHERE f.device_id = d.id) AS has_frp
    FROM devices d
    JOIN customers c ON c.id = d.customer_id
    ORDER BY c.name COLLATE NOCASE, d.model COLLATE NOCASE, d.id
  ''');
}

Future<void> saveDeviceFrp(
  int deviceId,
  Map<String, Object?> ficha, {
  Map<String, Object?>? order,
}) async {
  final db = await _openWorkshop();
  await db.transaction((txn) async {
    await _writeDeviceFrp(txn, deviceId, ficha);
    if (order == null) return;
    final count = await txn.update(
      'work_orders',
      {'frp_method': ficha['method']},
      where: 'device_id = ? AND code = ? AND status <> ? AND frp_method IS ?',
      whereArgs: [deviceId, order['code'], 'Retirado', order['frp_method']],
    );
    if (count != 1) {
      throw StateError('La orden cambió durante la consulta.');
    }
  });
}

Future<Map<String, Object?>?> _readDeviceFrp(int deviceId) async {
  final db = await _openWorkshop();
  final filas = await db.query(
    'device_frp',
    where: 'device_id = ?',
    whereArgs: [deviceId],
    limit: 1,
  );
  return filas.isEmpty ? null : filas.single;
}

class _DeviceFrpDetails extends StatefulWidget {
  const _DeviceFrpDetails({required this.ficha});

  final Map<String, Object?> ficha;

  @override
  State<_DeviceFrpDetails> createState() => _DeviceFrpDetailsState();
}

class _DeviceFrpDetailsState extends State<_DeviceFrpDetails> {
  Map<String, Object?> get ficha => widget.ficha;

  bool _deleting = false;
  bool _deleted = false;

  Future<void> _delete(int deviceId) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      final confirmed = await _confirmFrpDelete(
        context,
        '¿Eliminar la información FRP?',
        'Se borrarán los datos FRP guardados en este equipo.',
      );
      if (!mounted || !confirmed) return;
      final db = await _openWorkshop();
      await db.delete(
        'device_frp',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
      if (mounted) setState(() => _deleted = true);
    } catch (_) {
      if (mounted) {
        _frpMessage(context, 'No se pudo eliminar la información FRP.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _valor(String campo, {String faltante = 'Sin verificar'}) {
    final valor = (ficha[campo] as String?)?.trim();
    return valor == null || valor.isEmpty ? faltante : valor;
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final deviceId = ficha['device_id'] as int?;
    final compilacion = ficha['build_number'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        Text('Información FRP', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Número de compilación'),
        Row(
          children: [
            Expanded(child: SelectableText(compilacion)),
            IconButton(
              tooltip: 'Copiar compilación',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: compilacion));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Compilación copiada')),
                );
              },
            ),
          ],
        ),
        Text('Marca detectada: ${_valor('brand')}'),
        Text('Modelo detectado: ${_valor('model')}'),
        Text('Procesador (SoC): ${_valor('processor_soc')}'),
        Text('Versión de Android: ${_valor('android_version')}'),
        Text('Binario: ${_valor('binary')}'),
        Row(
          children: [
            Expanded(
              child: Text(
                'Método FRP: ${_valor('method', faltante: 'Sin seleccionar')}',
              ),
            ),
            if (deviceId != null)
              IconButton(
                tooltip: 'Eliminar información FRP',
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleting ? null : () => _delete(deviceId),
              ),
          ],
        ),
      ],
    );
  }
}

// v370: cierre de copias y exportacion
