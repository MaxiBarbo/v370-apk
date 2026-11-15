part of 'workshop_sample.dart';

Future<void> _addOrderFinance(Database db) async {
  await db.execute('ALTER TABLE work_orders ADD COLUMN agreed_cents INTEGER');
  await db.execute('ALTER TABLE budgets ADD COLUMN validity_days INTEGER');
  await db.execute('ALTER TABLE budgets ADD COLUMN warranty TEXT');
  await db.execute('ALTER TABLE budgets ADD COLUMN notes TEXT');
  await db.execute('ALTER TABLE order_photos ADD COLUMN attached_at INTEGER');
  await db.execute('''
    CREATE TABLE order_payments (
      id INTEGER PRIMARY KEY,
      order_id INTEGER NOT NULL REFERENCES work_orders(id) ON DELETE RESTRICT,
      amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
      is_deposit INTEGER NOT NULL CHECK (is_deposit IN (0, 1)),
      received_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX order_payments_order_idx ON order_payments(order_id)',
  );
}

Future<void> _addPaidOrders(Database db) async {
  await db.execute("""
    CREATE TABLE paid_orders (
      order_id INTEGER PRIMARY KEY REFERENCES work_orders(id) ON DELETE CASCADE,
      payment_id INTEGER UNIQUE REFERENCES order_payments(id),
      confirmed_at INTEGER NOT NULL
    )
  """);
}

Future<void> _savePaidOrder(
  Transaction txn,
  _OrderFinance finance,
  bool paid,
) async {
  if (finance.paid == paid) return;

  if (!paid) {
    final marker = (await txn.query(
      'paid_orders',
      columns: ['payment_id'],
      where: 'order_id = ?',
      whereArgs: [finance.id],
    )).single;
    await txn.delete(
      'paid_orders',
      where: 'order_id = ?',
      whereArgs: [finance.id],
    );
    final paymentId = marker['payment_id'];
    if (paymentId != null) {
      final deleted = await txn.delete(
        'order_payments',
        where: 'id = ? AND order_id = ? AND is_deposit = 0',
        whereArgs: [paymentId, finance.id],
      );
      if (deleted != 1) {
        throw StateError('No se encontró el pago vinculado a la confirmación.');
      }
    }
    return;
  }

  final agreed = finance.agreed;
  if (agreed == null || finance.received > agreed) {
    throw StateError('Revisá el total acordado y los pagos de la orden.');
  }
  final balance = agreed - finance.received;
  final now = DateTime.now().millisecondsSinceEpoch;
  final paymentId = balance == 0
      ? null
      : await _insertOrderPayment(
          txn,
          finance,
          balance,
          deposit: false,
          timestamp: now,
        );
  await txn.insert('paid_orders', {
    'order_id': finance.id,
    'payment_id': paymentId,
    'confirmed_at': now,
  });
}

typedef _OrderFinance = ({
  bool paid,
  int id,
  String status,
  int? quoted,
  int? agreed,
  int received,
  int deposits,
  int? validityDays,
  String? warranty,
  String? notes,
});

Future<_OrderFinance> _readOrderFinance(
  DatabaseExecutor db,
  String code,
) async {
  final rows = await db.rawQuery(
    '''
    SELECT o.id, o.status, o.agreed_cents, b.validity_days, b.warranty, b.notes,
           EXISTS(SELECT 1 FROM paid_orders WHERE order_id = o.id) AS paid,

           (SELECT SUM(i.amount_cents) FROM budget_items i
            WHERE i.budget_id = b.id) AS quoted_cents,
           COALESCE(p.received, 0) AS received,
           COALESCE(p.deposits, 0) AS deposits
    FROM work_orders o
    LEFT JOIN budgets b ON b.order_id = o.id
    LEFT JOIN (
      SELECT order_id, SUM(amount_cents) AS received,
             SUM(CASE WHEN is_deposit = 1 THEN amount_cents ELSE 0 END) AS deposits
      FROM order_payments
      GROUP BY order_id
    ) p ON p.order_id = o.id
    WHERE o.code = ?
  ''',
    [code],
  );
  final row = rows.single;
  return (
    paid: row['paid'] == 1,
    id: row['id'] as int,

    status: row['status'] as String,
    quoted: row['quoted_cents'] as int?,
    agreed: row['agreed_cents'] as int?,
    received: row['received'] as int,
    deposits: row['deposits'] as int,
    validityDays: row['validity_days'] as int?,
    warranty: row['warranty'] as String?,
    notes: row['notes'] as String?,
  );
}

Future<int> _insertOrderPayment(
  Transaction txn,
  _OrderFinance finance,
  int amount, {
  required bool deposit,
  required int timestamp,
}) async {
  final limit = finance.agreed;
  if (amount <= 0 || (limit != null && amount > limit - finance.received)) {
    throw StateError('El importe supera el saldo disponible.');
  }
  return txn.insert('order_payments', {
    'order_id': finance.id,
    'amount_cents': amount,
    'is_deposit': deposit ? 1 : 0,
    'received_at': timestamp,
  });
}

String _money(int cents) {
  final magnitude = cents.abs();
  final digits = (magnitude ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  final decimals = (magnitude % 100).toString().padLeft(2, '0');
  return 'ARS ${cents < 0 ? '-' : ''}$grouped,$decimals';
}

String _displayDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

int? _parseAmount(String input) {
  var amount = input.trim();
  if (RegExp(r'^[0-9]{1,3}(\.[0-9]{3})+(,[0-9]{1,2})?$').hasMatch(amount)) {
    amount = amount.replaceAll('.', '');
  }
  final match = RegExp(r'^([0-9]{1,9})(?:[.,]([0-9]{1,2}))?$')
      .firstMatch(amount);

  if (match == null) return null;
  final pesos = int.parse(match.group(1)!);
  final cents = int.parse((match.group(2) ?? '').padRight(2, '0'));
  return pesos * 100 + cents;
}

class WorkshopIncomeLink extends StatelessWidget {
  const WorkshopIncomeLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: const Text('Ingresos'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const _IncomePage())),
      ),
    );
  }
}

class _IncomePage extends StatefulWidget {
  const _IncomePage();

  @override
  State<_IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<_IncomePage> {
  static const _pageSize = 30;
  var _period = 'Este mes';
  DateTimeRange? _range;
  var _view = 'Por cobrar';
  var _page = 0;
  var _search = '';
  late var _data = _load();

  Future<
    ({
      int received,
      int outstanding,
      int count,
      int deposits,
      List<Map<String, Object?>> rows,
    })
  >
  _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (_period) {
      'Hoy' => today,
      'Rango' => _range!.start,
      _ => DateTime(now.year, now.month),
    };
    final endDay = _period == 'Rango' ? _range!.end : today;
    final end = DateTime(endDay.year, endDay.month, endDay.day + 1);
    final dates = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    final search = _search.trim();
    final view = _view;
    final pending = view == 'Por cobrar';
    final deposits = view == 'Señas';
    final offset = _page * _pageSize;
    final db = await _openWorkshop();
    return db.transaction((txn) async {
      final received =
          (await txn.rawQuery('''
        SELECT COALESCE(SUM(amount_cents), 0) AS total FROM order_payments
        WHERE received_at >= ? AND received_at < ?
      ''', dates)).single['total']
              as int;
      const balances = '''
        WITH balances AS (
          SELECT o.id, o.code, c.name,
                 o.agreed_cents - COALESCE((
                   SELECT SUM(p.amount_cents) FROM order_payments p
                   WHERE p.order_id = o.id
                 ), 0) AS amount
          FROM work_orders o
          JOIN devices d ON d.id = o.device_id
          JOIN customers c ON c.id = d.customer_id
          WHERE o.agreed_cents IS NOT NULL
        )
      ''';
      final summary = (await txn.rawQuery('''
        $balances SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
        FROM balances WHERE amount > 0
      ''')).single;
      const openDeposits = '''
        p.is_deposit = 1 AND NOT EXISTS (
          SELECT 1 FROM paid_orders m WHERE m.order_id = o.id
        ) AND (o.agreed_cents IS NULL OR o.agreed_cents > (
          SELECT COALESCE(SUM(all_p.amount_cents), 0) FROM order_payments all_p
          WHERE all_p.order_id = o.id
        ))
      ''';
      final depositsTotal =
          (await txn.rawQuery('''
        SELECT COALESCE(SUM(p.amount_cents), 0) AS total
        FROM order_payments p JOIN work_orders o ON o.id = p.order_id
        WHERE $openDeposits
      ''')).single['total']
              as int;
      final rows = pending
          ? await txn.rawQuery(
              '''
              $balances SELECT * FROM balances
              WHERE amount > 0 AND instr(lower(code || ' ' || name), lower(?)) > 0
              ORDER BY amount DESC, id DESC LIMIT ? OFFSET ?
            ''',
              [search, _pageSize + 1, offset],
            )
          : await txn.rawQuery(
              '''
              SELECT o.code, c.name, p.amount_cents AS amount,
                     p.received_at, p.is_deposit
              FROM order_payments p
              JOIN work_orders o ON o.id = p.order_id
              JOIN devices d ON d.id = o.device_id
              JOIN customers c ON c.id = d.customer_id
              WHERE ${deposits ? openDeposits : 'p.received_at >= ? AND p.received_at < ?'}
                AND instr(lower(o.code || ' ' || c.name), lower(?)) > 0
              ORDER BY p.received_at DESC, p.id DESC LIMIT ? OFFSET ?
            ''',
              [if (!deposits) ...dates, search, _pageSize + 1, offset],
            );
      return (
        received: received,
        outstanding: summary['total'] as int,
        count: summary['count'] as int,
        deposits: depositsTotal,
        rows: rows,
      );
    });
  }

  void _refresh() {
    _page = 0;
    _data = _load();
  }

  Future<void> _setPeriod(String period) async {
    if (period == 'Rango') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: _range,
      );
      if (!mounted || range == null) return;
      _range = range;
    }
    setState(() {
      _period = period;
      _refresh();
    });
  }

  Future<void> _openOrder(String code) async {
    try {
      final order = (await _readOrders(code: code)).firstOrNull;
      if (!mounted) return;
      if (order == null) throw StateError('Orden no disponible');
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _OrderDetails(order: order)),
      );
      if (mounted) setState(_refresh);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la orden.')),
      );
    }
  }

  void _selectView(String view) => setState(() {
    _view = view;
    _refresh();
  });

  Widget _summaryRow(
    String title,
    String amount,
    IconData icon,
    Color accent,
    String view, {
    String? detail,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xff22272f),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent),
      ),
      child: InkWell(
        onTap: () => _selectView(view),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 6),
              Text(title, style: theme.textTheme.titleSmall),
              Text(amount, style: theme.textTheme.titleLarge),
              if (detail != null)
                Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xff11151d),
      appBar: OrdenSocHeader(
        title: const Text('Ingresos'),
        showSectionMenu: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder(
            future: _data,
            builder: (context, snapshot) {
              final data = snapshot.connectionState == ConnectionState.done
                  ? snapshot.data
                  : null;
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisExtent: 150 * MediaQuery.textScalerOf(context).scale(1),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _summaryRow(
                    'Órdenes por cobrar',
                    data == null ? '—' : _money(data.outstanding),
                    Icons.receipt_long_outlined,
                    const Color(0xff10d9ef),
                    'Por cobrar',
                    detail: data == null
                        ? null
                        : data.count == 1
                        ? '1 orden con saldo'
                        : '${data.count} órdenes con saldo',
                  ),
                  _summaryRow(
                    'Señas de órdenes abiertas',
                    data == null ? '—' : _money(data.deposits),
                    Icons.sell_outlined,
                    const Color(0xffdba8ed),
                    'Señas',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final view in ['Por cobrar', 'Señas', 'Movimientos'])
                ChoiceChip(
                  label: Text(view),
                  selected: _view == view,
                  selectedColor: const Color(0xff263943),
                  side: BorderSide(
                    color: _view != view
                        ? const Color(0xff454b55)
                        : view == 'Señas'
                        ? const Color(0xffdba8ed)
                        : const Color(0xff10d9ef),
                  ),
                  onSelected: (_) => _selectView(view),
                ),
            ],
          ),
          if (_view == 'Movimientos') ...[
            Wrap(
              spacing: 8,
              children: [
                for (final period in ['Hoy', 'Este mes', 'Rango'])
                  ChoiceChip(
                    label: Text(period),
                    selected: _period == period,
                    onSelected: (_) => _setPeriod(period),
                  ),
              ],
            ),
            if (_period == 'Rango')
              Text(
                '${_displayDate(_range!.start)} – ${_displayDate(_range!.end)}',
              ),
            FutureBuilder(
              future: _data,
              builder: (context, snapshot) => ListTile(
                title: const Text('Cobrado en el período'),
                trailing: Text(
                  snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData
                      ? _money(snapshot.requireData.received)
                      : '—',
                ),
              ),
            ),
          ],
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar cliente u orden',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() {
              _search = value;
              _refresh();
            }),
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return OutlinedButton(
                  onPressed: () => setState(_refresh),
                  child: const Text(
                    'No se pudieron cargar los ingresos. Reintentar',
                  ),
                );
              }
              final rows = snapshot.requireData.rows;
              if (rows.isEmpty) {
                return Text(switch (_view) {
                  'Por cobrar' => 'Sin órdenes pendientes para esta búsqueda.',
                  'Señas' =>
                    'Sin señas de órdenes abiertas para esta búsqueda.',
                  _ => 'Sin movimientos para esta búsqueda y período.',
                });
              }
              return Column(
                children: [
                  for (final row in rows.take(_pageSize))
                    Card(
                      child: ListTile(
                        title: Text(row['name'] as String),
                        subtitle: Text(
                          _view == 'Por cobrar'
                              ? row['code'] as String
                              : '${row['code']} · ${row['is_deposit'] == 1 ? 'Seña' : 'Cobro'}\n'
                                    '${_displayDate(DateTime.fromMillisecondsSinceEpoch(row['received_at'] as int))}',
                        ),
                        trailing: Text(
                          _money(row['amount'] as int),
                          style: theme.textTheme.titleSmall,
                        ),
                        onTap: () => _openOrder(row['code'] as String),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_page > 0)
                        TextButton(
                          onPressed: () => setState(() {
                            _page--;
                            _data = _load();
                          }),
                          child: const Text('Anterior'),
                        ),
                      if (rows.length > _pageSize)
                        TextButton(
                          onPressed: () => setState(() {
                            _page++;
                            _data = _load();
                          }),
                          child: const Text('Siguiente'),
                        ),
                    ],
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
