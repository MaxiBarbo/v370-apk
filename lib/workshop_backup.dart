part of 'workshop_sample.dart';

const _backupTables = <String, Map<String, String>>{
  'customers': {},
  'devices': {'customer_id': 'customers'},
  'work_orders': {'device_id': 'devices'},
  'order_status_history': {'order_id': 'work_orders'},
  'budgets': {'order_id': 'work_orders'},
  'budget_items': {'budget_id': 'budgets'},
  'suppliers': {},
  'stock_items': {'supplier_id': 'suppliers'},
  'stock_movements': {'stock_item_id': 'stock_items'},
  'order_photos': {'order_id': 'work_orders'},
  'order_payments': {'order_id': 'work_orders'},
  'paid_orders': {'order_id': 'work_orders', 'payment_id': 'order_payments'},
  'device_frp': {'device_id': 'devices'},
  'frp_pending_devices': {},
};

const _backupKeys = {'paid_orders': 'order_id', 'device_frp': 'device_id'};
const _backupSingletons = {'budgets': 'order_id', ..._backupKeys};
const _backupFile = MethodChannel('v370/backup');
const _backupLimit = 32 * 1024 * 1024;
const _backupTooLarge = 'La copia supera el límite de 32 MB.';

Future<void> _addBackupIds(Database db) async {
  for (final table in _backupTables.keys.where(
    (table) => !_backupSingletons.containsKey(table),
  )) {
    await db.execute('ALTER TABLE $table ADD COLUMN backup_id TEXT');
    await db.execute(
      'UPDATE $table SET backup_id = lower(hex(randomblob(16)))',
    );
    await db.execute(
      'CREATE UNIQUE INDEX ${table}_backup_idx ON $table(backup_id)',
    );
    await db.execute('''
      CREATE TRIGGER ${table}_backup_insert AFTER INSERT ON $table
      WHEN NEW.backup_id IS NULL
      BEGIN
        UPDATE $table SET backup_id = lower(hex(randomblob(16))) WHERE id = NEW.id;
      END
    ''');
  }
}

Future<Uint8List> _exportWorkshopBackup() async {
  final db = await _openWorkshop();
  final payload = await db.transaction((txn) async {
    final tables = <String, Object>{};
    for (final table in _backupTables.keys) {
      tables[table] = [
        for (final row in await txn.query(table))
          row.map(
            (key, value) =>
                MapEntry(key, value is Uint8List ? base64Encode(value) : value),
          ),
      ];
    }
    final sequence = (await txn.query('order_sequence')).single;
    final trackingUrl = await _backupTrackingUrl(txn);
    return {
      'format': 'v370-backup-1',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'lastOrder': sequence['last_number'],
      'trackingUrl': ?trackingUrl,
      'tables': tables,
    };
  });
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  if (bytes.length > _backupLimit) throw const FormatException(_backupTooLarge);
  return bytes;
}

class _WorkshopBackup {
  _WorkshopBackup(
    this.createdAt,
    this.lastOrder,
    this.tables,
    this.trackingUrl,
  );
  final String? trackingUrl;
  final DateTime createdAt;
  final int lastOrder;
  final Map<String, List<Map<String, Object?>>> tables;

  factory _WorkshopBackup.read(Uint8List bytes) {
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (data['format'] != 'v370-backup-1') {
      throw const FormatException('Formato de copia incompatible.');
    }
    final incoming = data['tables'] as Map<String, dynamic>;
    final trackingUrl = data['trackingUrl'] as String?;
    if (trackingUrl != null && _backupSheetsUri(trackingUrl) == null) {
      throw const FormatException('El enlace de seguimiento es inválido.');
    }
    if (incoming.length != _backupTables.length) {
      throw const FormatException('La copia está incompleta.');
    }
    final lastOrder = data['lastOrder'] as int;
    if (lastOrder < 0 || lastOrder > 9007199254740991) {
      throw const FormatException('Numeración de órdenes inválida.');
    }
    return _WorkshopBackup(
      DateTime.parse(data['createdAt'] as String).toLocal(),
      lastOrder,
      {
        for (final table in _backupTables.keys)
          table: [
            for (final row in incoming[table] as List<dynamic>)
              Map<String, Object?>.from(row as Map),
          ],
      },
      trackingUrl,
    );
  }
}

typedef _BackupCounts = ({int added, int updated, int kept});

class _BackupPreview implements Exception {
  const _BackupPreview(this.counts);
  final _BackupCounts counts;
}

Future<_BackupCounts> _mergeWorkshopBackup(
  _WorkshopBackup backup, {
  _BackupCounts? confirmed,
}) async {
  final db = await _openWorkshop();
  try {
    return await db.transaction((txn) async {
      var added = 0;
      var updated = 0;
      var kept = 0;
      final mapped = <String, Map<int, int>>{};
      final touchedOrders = <int>{};
      final touchedStock = <int>{};
      final identity = RegExp(r'^[0-9a-f]{32}$');
      for (final entry in _backupTables.entries) {
        final table = entry.key;
        final primary = _backupKeys[table] ?? 'id';
        final singleton = _backupSingletons[table];
        final fields = (await txn.rawQuery('PRAGMA table_info($table)'))
            .map((column) => column['name'] as String)
            .toSet();
        final rows = mapped[table] = {};
        final matched = <int>{};
        final seenKeys = <Object?>{};
        final existingCount = Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM $table'),
        )!;
        for (final source in backup.tables[table]!) {
          final oldOrder =
              table == 'work_orders' && !source.containsKey('work_performed');
          if (source.length != fields.length - (oldOrder ? 1 : 0) ||
              !source.keys.every(fields.contains)) {
            throw const FormatException(
              'La estructura de la copia es incompatible.',
            );
          }
          final row = Map<String, Object?>.of(source);
          final sourceId = row[primary] as int;
          if (sourceId <= 0 || rows.containsKey(sourceId)) {
            throw const FormatException(
              'Hay identificadores duplicados o inválidos.',
            );
          }
          for (final relation in entry.value.entries) {
            final value = row[relation.key];
            if (value == null) continue;
            row[relation.key] =
                mapped[relation.value]?[value] ??
                (throw const FormatException(
                  'Faltan registros relacionados en la copia.',
                ));
          }
          if (table == 'order_photos') {
            row['image'] = base64Decode(row['image'] as String);
          }
          final key = singleton ?? 'backup_id';
          final stableId = row[key];
          if (!seenKeys.add(stableId)) {
            throw const FormatException(
              'Un registro aparece más de una vez en la copia.',
            );
          }
          if (singleton == null &&
              (stableId is! String || !identity.hasMatch(stableId))) {
            throw const FormatException(
              'Hay identificadores de respaldo inválidos.',
            );
          }
          final candidates = await txn.query(
            table,
            where: '$key = ?',
            whereArgs: [stableId],
            limit: 1,
          );
          final current = candidates.isEmpty ? null : candidates.single;
          if (current != null) {
            final id = current[primary] as int;
            if (!matched.add(id)) {
              throw const FormatException(
                'Un registro aparece más de una vez en la copia.',
              );
            }
            row[primary] = id;
            if (table == 'work_orders') row['code'] = current['code'];
            if (table == 'stock_items') row['quantity'] = current['quantity'];
            if (row.entries.any(
              (field) => !_sameBackupValue(field.value, current[field.key]),
            )) {
              await txn.update(
                table,
                row,
                where: '$primary = ?',
                whereArgs: [id],
              );
              updated++;
            } else {
              kept++;
            }
            rows[sourceId] = id;
          } else {
            if (primary == 'id') row.remove(primary);
            if (table == 'work_orders') {
              final code = row['code'] as String;
              if (!RegExp(r'^V370-[0-9]+$').hasMatch(code)) {
                throw const FormatException('Hay un código de orden inválido.');
              }
              final collision = await txn.query(
                table,
                columns: ['id'],
                where: 'code = ?',
                whereArgs: [code],
                limit: 1,
              );
              if (collision.isNotEmpty) {
                int number;
                do {
                  number = await _reserveOrderNumber(txn);
                  row['code'] = 'V370-${number.toString().padLeft(3, '0')}';
                } while ((await txn.query(
                  table,
                  columns: ['id'],
                  where: 'code = ?',
                  whereArgs: [row['code']],
                  limit: 1,
                )).isNotEmpty);
              }
            }
            if (table == 'stock_items') row['quantity'] = 0;
            final inserted = await txn.insert(table, row);
            rows[sourceId] = primary == 'id' ? inserted : row[primary] as int;
            added++;
          }
          if (table == 'order_payments' || table == 'paid_orders') {
            touchedOrders.add(row['order_id'] as int);
          }
          if (table == 'stock_items') touchedStock.add(rows[sourceId]!);
        }
        kept += existingCount - matched.length;
      }

      // Prevent an imported paid marker from referencing a different order.
      for (final id in touchedOrders) {
        final invalid = await txn.rawQuery(
          '''
          SELECT 1 FROM paid_orders m JOIN order_payments p ON p.id = m.payment_id
          WHERE m.order_id = ? AND p.order_id <> m.order_id
        ''',
          [id],
        );
        if (invalid.isNotEmpty) {
          throw const FormatException('Hay cobros mal vinculados.');
        }
      }
      for (final id in touchedStock) {
        final balance = Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COALESCE(SUM(delta), 0) FROM stock_movements WHERE stock_item_id = ?',
            [id],
          ),
        )!;
        if (balance < 0) {
          throw const FormatException('La copia dejaría stock negativo.');
        }
        await txn.update(
          'stock_items',
          {'quantity': balance},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await txn.rawUpdate(
        '''
        UPDATE order_sequence SET last_number = MAX(last_number, ?,
          (SELECT COALESCE(MAX(CAST(SUBSTR(code, 6) AS INTEGER)), 0) FROM work_orders))
        WHERE id = 1
      ''',
        [backup.lastOrder],
      );
      final trackingUrl = backup.trackingUrl;
      final previous = await _backupTrackingUrl(txn);
      if (trackingUrl == null && previous != null) {
        kept++;
      }
      if (trackingUrl != null) {
        if (previous != trackingUrl) {
          await txn.execute('''
            CREATE TABLE IF NOT EXISTS workshop_preferences (
              name TEXT PRIMARY KEY, value TEXT NOT NULL
            )
          ''');
          await txn.insert('workshop_preferences', {
            'name': 'tracking_url',
            'value': trackingUrl,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          if (previous == null) {
            added++;
          } else {
            updated++;
          }
        } else {
          kept++;
        }
      }
      final counts = (added: added, updated: updated, kept: kept);
      if (confirmed == null) throw _BackupPreview(counts);
      if (confirmed != counts) {
        throw const FormatException(
          'Los datos cambiaron. Volvé a revisar la importación.',
        );
      }
      return counts;
    });
  } on _BackupPreview catch (preview) {
    return preview.counts;
  }
}

bool _sameBackupValue(Object? a, Object? b) {
  if (a is Uint8List && b is Uint8List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return a == b;
}

class WorkshopBackupPage extends StatelessWidget {
  const WorkshopBackupPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff11151d),
    appBar: OrdenSocHeader(
      title: const Text('Copias de seguridad'),
      headerActions: const [],
      showSectionMenu: false,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final create in [true, false])
          Card(
            child: ListTile(
              leading: Icon(create ? Icons.note_add_outlined : Icons.restore),
              title: Text(create ? 'Crear copia' : 'Importar copia'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => _WorkshopBackupAction(create: create),
                ),
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exportar a Google Sheets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const _WorkshopExportPage(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WorkshopBackupAction extends StatefulWidget {
  const _WorkshopBackupAction({required this.create});
  final bool create;

  @override
  State<_WorkshopBackupAction> createState() => _WorkshopBackupActionState();
}

class _WorkshopBackupActionState extends State<_WorkshopBackupAction> {
  bool _busy = false;
  _WorkshopBackup? _selected;
  _BackupCounts? _preview;
  String? _message;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) _message = error.message;
    } catch (_) {
      if (mounted) {
        _message = widget.create ? 'No se pudo guardar la copia.' : 'No se pudo leer o importar la copia. Revisá el archivo e intentá de nuevo.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final bytes = await _exportWorkshopBackup();
    if (!mounted) return;
    final saved = await _backupFile.invokeMethod<bool>('save', bytes);
    if (mounted && saved == true) _message = 'Copia guardada.';
  });

  Future<void> _choose() => _run(() async {
    final bytes = await _backupFile.invokeMethod<Uint8List>('open');
    if (!mounted || bytes == null) return;
    _selected = null;
    _preview = null;
    _selected = _WorkshopBackup.read(bytes);
  });

  Future<void> _review() => _run(() async {
    final counts = await _mergeWorkshopBackup(_selected!);
    if (mounted) _preview = counts;
  });

  Future<void> _confirm() => _run(() async {
    final confirmed = _preview!;
    _preview = null;
    final counts = await _mergeWorkshopBackup(_selected!, confirmed: confirmed);
    if (!mounted) return;
    _selected = null;
    _message =
        'Copia importada. Se agregaron ${counts.added} registros y se actualizaron ${counts.updated}.';
  });

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final preview = _preview;
    final format = MaterialLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: Text(
          widget.create
              ? 'Crear copia'
              : preview == null
              ? 'Importar copia'
              : 'Confirmar importación',
        ),
        headerActions: const [],
        showSectionMenu: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.create) ...[
            const Text('Datos del taller y archivos adjuntos'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Elegir dónde guardar'),
            ),
          ] else if (preview != null) ...[
            for (final item in [
              ('Se agregan', preview.added, Icons.person_add_outlined),
              ('Se actualizan', preview.updated, Icons.sync),
              ('Se conservan', preview.kept, Icons.verified_user_outlined),
            ])
              Card(
                child: ListTile(
                  leading: Icon(item.$3),
                  title: Text('${item.$1} · ${item.$2}'),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Los registros con el mismo ID se actualizan.'),
            ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _preview = null),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: const Text('Importar copia'),
                ),
              ],
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.folder_open),
              label: const Text('Elegir archivo'),
            ),
            if (selected != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    '${format.formatShortDate(selected.createdAt)} · '
                    '${format.formatTimeOfDay(TimeOfDay.fromDateTime(selected.createdAt))}',
                  ),
                  subtitle: Text(
                    '${selected.tables['customers']!.length} clientes · '
                    '${selected.tables['work_orders']!.length} órdenes',
                  ),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : _review,
                child: const Text('Revisar importación'),
              ),
            ],
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
        ],
      ),
    );
  }
}

class WorkshopTrackingLink extends StatelessWidget {
  const WorkshopTrackingLink({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.open_in_new),
      title: const Text('Planilla de seguimiento'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const _TrackingPage()),
      ),
    ),
  );
}

class _TrackingPage extends StatefulWidget {
  const _TrackingPage();

  @override
  State<_TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<_TrackingPage> {
  static const _defaultUrl =
      'https://docs.google.com/spreadsheets/d/1ATeXLwJFMw5Pk3Y0v-BhJy_n3suEONU31AkIBKoR_n8/edit?gid=717450933#gid=717450933';

  late Future<String> _url = _readUrl();
  bool _editing = false;

  Future<Database> _preferencesDb() async {
    final db = await _openWorkshop();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workshop_preferences (
        name TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    return db;
  }

  Future<String> _readUrl() async {
    final db = await _preferencesDb();
    final rows = await db.query(
      'workshop_preferences',
      columns: ['value'],
      where: 'name = ?',
      whereArgs: ['tracking_url'],
    );
    return rows.isEmpty ? _defaultUrl : rows.single['value'] as String;
  }

  Uri? _sheetsUri(String value) => _backupSheetsUri(value);

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _open(String value) async {
    final uri = _sheetsUri(value);
    if (uri != null) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Android may have no application that can open the link.
      }
    }
    _message('No se pudo abrir la planilla.');
  }

  Future<void> _edit(String current) async {
    if (_editing) return;
    setState(() => _editing = true);
    final form = GlobalKey<FormState>();
    var input = current;

    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Editar enlace'),
          content: Form(
            key: form,
            child: TextFormField(
              initialValue: current,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Enlace de Google Sheets',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => input = value,
              validator: (value) => _sheetsUri(value ?? '') == null
                  ? 'Pegá un enlace válido de Google Sheets.'
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

      if (!mounted || value == null || value == current) return;
      final db = await _preferencesDb();
      await db.insert('workshop_preferences', {
        'name': 'tracking_url',
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (mounted) {
        setState(() => _url = Future.value(value));
        _message('Enlace guardado.');
      }
    } catch (_) {
      _message('No se pudo guardar el enlace.');
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff11151d),
    appBar: OrdenSocHeader(
      title: const Text('Planilla de seguimiento'),
      headerActions: const [],
      showSectionMenu: false,
    ),
    body: FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: () => setState(() => _url = _readUrl()),
              child: const Text('No se pudo leer el enlace. Reintentar'),
            ),
          );
        }
        final url = snapshot.data;
        if (url == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Seguimiento manual'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _editing ? null : () => _open(url),
              child: const Text('Abrir planilla'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _editing ? null : () => _edit(url),
              child: const Text('Editar enlace'),
            ),
          ],
        );
      },
    ),
  );
}

Future<String?> _backupTrackingUrl(DatabaseExecutor db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workshop_preferences'",
  );
  if (tables.isEmpty) return null;
  final rows = await db.query(
    'workshop_preferences',
    columns: ['value'],
    where: 'name = ?',
    whereArgs: ['tracking_url'],
  );
  return rows.isEmpty ? null : rows.single['value'] as String;
}

Uri? _backupSheetsUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'docs.google.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !RegExp(r'^/spreadsheets/d/[A-Za-z0-9_-]+(?:/|$)').hasMatch(uri.path)) {
    return null;
  }
  return uri;
}

// v370: cierre de copias y exportacion
