part of 'workshop_sample.dart';

const frpMethods = [
  'Cambio de idioma',
  'Test Point',
  'F64',
  'ISP',
  'IMEI (vía red)',
  'Server',
];

Future<void> _addFrpWorkflow(Database db) async {
  await db.execute('ALTER TABLE work_orders ADD COLUMN frp_method TEXT');
  await db.execute('''
    CREATE TABLE frp_pending_devices (
      id INTEGER PRIMARY KEY,
      device_brand TEXT NOT NULL, device_model TEXT NOT NULL,
      device_color TEXT, device_identifier TEXT,
      build_number TEXT NOT NULL, brand TEXT, model TEXT,
      android_version TEXT, processor_soc TEXT, binary TEXT, method TEXT
    )
  ''');
}

Future<List<Map<String, Object?>>> readFrpOpenOrders(int deviceId) async {
  final db = await _openWorkshop();
  return db.query(
    'work_orders',
    columns: ['code', 'status', 'frp_method'],
    where: 'device_id = ? AND status <> ?',
    whereArgs: [deviceId, 'Retirado'],
    orderBy: 'id DESC',
  );
}

Future<void> _writeDeviceFrp(
  DatabaseExecutor db,
  int deviceId,
  Map<String, Object?> ficha,
) async {
  final count = await db.update(
    'device_frp',
    ficha,
    where: 'device_id = ?',
    whereArgs: [deviceId],
  );
  if (count == 0) {
    await db.insert('device_frp', {'device_id': deviceId, ...ficha});
  }
}

void _frpMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _confirmFrpDelete(
  BuildContext context,
  String title,
  String message,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ==
      true;
}

class _OrderFrpMethodTile extends StatefulWidget {
  const _OrderFrpMethodTile({required this.code});

  final String code;

  @override
  State<_OrderFrpMethodTile> createState() => _OrderFrpMethodTileState();
}

class _OrderFrpMethodTileState extends State<_OrderFrpMethodTile> {
  late Future<String?> _method = _load();
  bool _busy = false;

  Future<String?> _load() async {
    final db = await _openWorkshop();
    final rows = await db.query(
      'work_orders',
      columns: ['frp_method'],
      where: 'code = ?',
      whereArgs: [widget.code],
    );
    return rows.single['frp_method'] as String?;
  }

  Future<void> _update(String? previous, {required bool remove}) async {
    setState(() => _busy = true);
    try {
      String? next;
      if (remove) {
        final confirmed = await _confirmFrpDelete(
          context,
          '¿Quitar el método FRP de esta orden?',
          'La ficha FRP del teléfono se conserva.',
        );
        if (!mounted || !confirmed) return;
      } else {
        next = await showDialog<String>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: const Text('Método FRP a utilizar'),
            children: [
              for (final method in frpMethods)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(dialog).pop(method),
                  child: Text(method),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
        if (!mounted || next == null || next == previous) return;
      }
      final db = await _openWorkshop();
      final count = await db.update(
        'work_orders',
        {'frp_method': next},
        where: 'code = ? AND frp_method IS ?',
        whereArgs: [widget.code, previous],
      );
      if (!mounted) return;
      setState(() => _method = _load());
      if (count != 1) {
        _frpMessage(context, 'La orden cambió. Revisá el método actual.');
      }
    } catch (_) {
      if (mounted) {
        _frpMessage(context, 'No se pudo guardar el método FRP.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _method,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return ListTile(
            title: const Text('No se pudo leer el método FRP'),
            trailing: IconButton(
              tooltip: 'Reintentar',
              onPressed: () => setState(() => _method = _load()),
              icon: const Icon(Icons.refresh),
            ),
          );
        }
        final method = snapshot.data;
        return ListTile(
          title: const Text('Método FRP a utilizar'),
          subtitle: Text(method ?? 'Sin seleccionar'),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: method == null
                    ? 'Agregar método FRP'
                    : 'Editar método FRP',
                onPressed: _busy ? null : () => _update(method, remove: false),
                icon: Icon(method == null ? Icons.add : Icons.edit_outlined),
              ),
              if (method != null)
                IconButton(
                  tooltip: 'Quitar método FRP de la orden',
                  onPressed: _busy ? null : () => _update(method, remove: true),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        );
      },
    );
  }
}

const _frpDeviceLabels = {
  'brand': 'Marca',
  'model': 'Modelo',
  'color': 'Color',
  'device_identifier': 'IMEI / Número de serie',
};

const _frpFichaFields = [
  'build_number',
  'brand',
  'model',
  'android_version',
  'processor_soc',
  'binary',
  'method',
];

Future<bool> addPhoneFromFrp(
  BuildContext context,
  Map<String, Object?> ficha,
) => _openFrpPhoneForm(context, ficha);

Future<bool> _openFrpPhoneForm(
  BuildContext context,
  Map<String, Object?> ficha, {
  bool pending = false,
}) async {
  final db = await _openWorkshop();
  final customers = await db.query(
    'customers',
    orderBy: 'name COLLATE NOCASE, id',
  );
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _FrpPhoneForm(ficha: ficha, customers: customers, pending: pending),
      ) ==
      true;
}

class _FrpPhoneForm extends StatefulWidget {
  const _FrpPhoneForm({
    required this.ficha,
    required this.customers,
    required this.pending,
  });

  final Map<String, Object?> ficha;
  final List<Map<String, Object?>> customers;
  final bool pending;

  @override
  State<_FrpPhoneForm> createState() => _FrpPhoneFormState();
}

class _FrpPhoneFormState extends State<_FrpPhoneForm> {
  final _form = GlobalKey<FormState>();
  late final _device = <String, String>{
    'brand': widget.ficha['brand'] as String? ?? '',
    'model': widget.ficha['model'] as String? ?? '',
    'color': '',
    'device_identifier': '',
  };
  int? _destination;
  String _name = '';
  String _phone = '';
  bool _saving = false;
  String? _error;

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final destination = _destination!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = await _openWorkshop();
      await db.transaction((txn) async {
        final source = widget.ficha;
        final device = widget.pending
            ? <String, Object?>{
                'brand': source['device_brand'],
                'model': source['device_model'],
                'color': source['device_color'],
                'device_identifier': source['device_identifier'],
              }
            : <String, Object?>{
                for (final entry in _device.entries)
                  entry.key: _optional(entry.value),
              };
        final ficha = <String, Object?>{
          for (final field in _frpFichaFields) field: source[field],
        };
        if (destination == 0) {
          await txn.insert('frp_pending_devices', {
            ...ficha,
            'device_brand': device['brand'],
            'device_model': device['model'],
            'device_color': device['color'],
            'device_identifier': device['device_identifier'],
          });
          return;
        }
        if (widget.pending) {
          final removed = await txn.delete(
            'frp_pending_devices',
            where: 'id = ?',
            whereArgs: [source['id']],
          );
          if (removed != 1) {
            throw StateError('El equipo ya no está pendiente.');
          }
        }
        final customerId = destination == -1
            ? await txn.insert('customers', {
                'name': _name.trim(),
                'phone': _optional(_phone.replaceAll(RegExp(r'[\s().-]'), '')),
              })
            : destination;
        final deviceId = await txn.insert('devices', {
          ...device,
          'customer_id': customerId,
        });
        await _writeDeviceFrp(txn, deviceId, ficha);
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el equipo. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adding = !widget.pending;
    return AlertDialog(
      scrollable: true,
      title: Text(adding ? 'Agregar teléfono' : 'Asignar a un cliente'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adding) ...[
              for (final field in _frpDeviceLabels.entries)
                TextFormField(
                  initialValue: _device[field.key],
                  enabled: !_saving,
                  decoration: InputDecoration(labelText: field.value),
                  onChanged: (value) => _device[field.key] = value,
                  validator: (value) {
                    if ((field.key == 'brand' || field.key == 'model') &&
                        (value ?? '').trim().isEmpty) {
                      return 'Completá ${field.value.toLowerCase()}.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Guardar con'),
              items: [
                if (adding)
                  const DropdownMenuItem(value: 0, child: Text('Sin cliente')),
                const DropdownMenuItem(value: -1, child: Text('Crear cliente')),
                for (final customer in widget.customers)
                  DropdownMenuItem(
                    value: customer['id'] as int,
                    child: Text(
                      '${customer['name']} · #${customer['id']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _destination = value),
              validator: (value) => value == null ? 'Elegí una opción.' : null,
            ),
            if (_destination == -1) ...[
              TextFormField(
                initialValue: _name,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente',
                ),
                onChanged: (value) => _name = value,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Completá el nombre.' : null,
              ),
              TextFormField(
                initialValue: _phone,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => _phone = value,
              ),
            ],
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
    );
  }
}

class FrpPendingDevicesPage extends StatefulWidget {
  const FrpPendingDevicesPage({super.key});

  @override
  State<FrpPendingDevicesPage> createState() => _FrpPendingDevicesPageState();
}

class _FrpPendingDevicesPageState extends State<FrpPendingDevicesPage> {
  late var _rows = _load();
  bool _busy = false;

  Future<List<Map<String, Object?>>> _load() async {
    final db = await _openWorkshop();
    return db.query('frp_pending_devices', orderBy: 'id DESC');
  }

  Future<void> _act(Map<String, Object?> row, {required bool remove}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (remove) {
        final confirmed = await _confirmFrpDelete(
          context,
          '¿Eliminar el teléfono sin cliente?',
          'Se borrarán este registro y su información FRP.',
        );
        if (!mounted || !confirmed) return;
        final db = await _openWorkshop();
        await db.delete(
          'frp_pending_devices',
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } else {
        final saved = await _openFrpPhoneForm(context, row, pending: true);
        if (!saved) return;
      }
      if (mounted) setState(() => _rows = _load());
    } catch (_) {
      if (mounted) {
        _frpMessage(context, 'No se pudo actualizar el equipo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipos sin cliente')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _rows = _load()),
                child: const Text(
                  'No se pudieron leer los equipos. Reintentar',
                ),
              ),
            );
          }
          final rows = snapshot.data;
          if (rows == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return const Center(child: Text('No hay equipos sin cliente.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(
                      '${row['device_brand']} ${row['device_model']}',
                    ),
                    subtitle: Text(row['build_number'] as String),
                    onTap: _busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              scrollable: true,
                              title: const Text('Ficha del equipo'),
                              content: _DeviceFrpDetails(ficha: row),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialog).pop(),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Asignar a un cliente',
                          onPressed: _busy
                              ? null
                              : () => _act(row, remove: false),
                          icon: const Icon(Icons.person_add_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar equipo sin cliente',
                          onPressed: _busy
                              ? null
                              : () => _act(row, remove: true),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
