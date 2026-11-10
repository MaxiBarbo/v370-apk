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
  late var _payments = _load();

  Future<({List<Map<String, Object?>> payments, int outstanding})>
  _load() async {
    final db = await _openWorkshop();
    return db.transaction((txn) async {
      final payments = await txn.rawQuery('''
      SELECT COALESCE(
               (SELECT SUM(p.amount_cents) FROM order_payments p
                WHERE p.order_id = m.order_id), 0
             ) AS amount_cents, 2 AS kind,

             m.confirmed_at AS received_at, o.code, c.name
      FROM paid_orders m
      JOIN work_orders o ON o.id = m.order_id
      JOIN devices d ON d.id = o.device_id
      JOIN customers c ON c.id = d.customer_id
      UNION ALL
      SELECT p.amount_cents, p.is_deposit, p.received_at, o.code, c.name
      FROM order_payments p
      JOIN work_orders o ON o.id = p.order_id
      JOIN devices d ON d.id = o.device_id
      JOIN customers c ON c.id = d.customer_id
      WHERE NOT EXISTS (SELECT 1 FROM paid_orders WHERE order_id = o.id)
      ORDER BY received_at DESC, code DESC
    ''');
      final rows = await txn.rawQuery('''
        SELECT COALESCE(SUM(MAX(
          o.agreed_cents - COALESCE((
            SELECT SUM(p.amount_cents)
            FROM order_payments p
            WHERE p.order_id = o.id
          ), 0), 0
        )), 0) AS outstanding
        FROM work_orders o
        WHERE o.agreed_cents IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM paid_orders m WHERE m.order_id = o.id
          )
      ''');
      return (
        payments: payments,
        outstanding: rows.single['outstanding'] as int,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresos')),
      body: FutureBuilder(
        future: _payments,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _payments = _load()),
                child: const Text(
                  'No se pudieron cargar los ingresos. Reintentar',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snapshot.requireData;
          final payments = summary.payments;
          var paidTotal = 0;
          var pendingDeposits = 0;
          var pendingPayments = 0;
          for (final payment in payments) {
            final amount = payment['amount_cents'] as int;
            switch (payment['kind']) {
              case 2:
                paidTotal += amount;
              case 1:
                pendingDeposits += amount;
              default:
                pendingPayments += amount;
            }
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('Total de órdenes cobradas'),
                      trailing: Text(_money(paidTotal)),
                    ),
                    ListTile(
                      title: const Text('Total de órdenes por cobrar'),
                      trailing: Text(_money(summary.outstanding)),
                    ),
                    ListTile(
                      title: const Text('Señas de órdenes pendientes'),
                      trailing: Text(_money(pendingDeposits)),
                    ),
                    if (pendingPayments > 0)
                      ListTile(
                        title: const Text('Otros pagos de órdenes pendientes'),
                        trailing: Text(_money(pendingPayments)),
                      ),
                  ],
                );
              }
              final payment = payments[index - 1];
              final date = DateTime.fromMillisecondsSinceEpoch(
                payment['received_at'] as int,
              );
              final kind = switch (payment['kind']) {
                2 => 'Orden cobrada',
                1 => 'Seña',
                _ => 'Pago registrado',
              };

              return Card(
                child: ListTile(
                  title: Text('${payment['code']} · ${payment['name']}'),
                  subtitle: Text('$kind · ${_displayDate(date)}'),
                  trailing: Text(_money(payment['amount_cents'] as int)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
