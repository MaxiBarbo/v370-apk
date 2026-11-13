part of 'workshop_sample.dart';

class WorkshopInicio extends StatefulWidget {
  const WorkshopInicio({super.key, this.agendaOnly = false});

  final bool agendaOnly;

  @override
  State<WorkshopInicio> createState() => _WorkshopInicioState();
}

class _WorkshopInicioState extends State<WorkshopInicio>
    with WidgetsBindingObserver {
  static const _cyan = Color(0xff00cbe7);
  static const _purple = Color(0xffc9a6f2);
  static const _red = Color(0xffff676f);
  static const _whatsapp = Color(0xff66bd88);
  static const _ink = Color(0xffedf1f6);
  DateTime? _day;
  Timer? _midnight;
  bool _saving = false;
  late Future<List<Map<String, Object?>>> _orders = _readOrders();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayChange();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleDayChange();
      _reload();
    }
  }

  void _scheduleDayChange() {
    _midnight?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(tomorrow.difference(now), () {
      if (!mounted) return;
      _reload();
      _scheduleDayChange();
    });
  }

  void _reload() {
    setState(() {
      _orders = _readOrders();
    });
  }

  Future<void> _refresh() async {
    _reload();
    try {
      await _orders;
    } catch (_) {
      // FutureBuilder muestra el error y permite reintentar.
    }
  }

  Future<void> _chooseDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = await showDatePicker(
      context: context,
      initialDate: _day ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
      helpText: 'Elegir día de agenda',
    );
    if (!mounted || day == null) return;
    setState(() => _day = DateUtils.isSameDay(day, today) ? null : day);
    _reload();
  }

  Future<void> _openOrder(Map<String, Object?> order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _OrderDetails(order: order)),
    );
    if (mounted) _reload();
  }

  Future<void> _notify(Map<String, Object?> order) async {
    setState(() => _saving = true);
    try {
      await _saveCustomerNotice(order['code'] as String);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar el aviso.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _needsContact(Map<String, Object?> order) =>
      order['status'] == 'Entregar' && order['customer_notified_at'] == null;

  Widget _panel({required Widget child, Color? accent}) {
    final panel = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xd923272f),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent ?? const Color(0xff3b414b)),
      ),
      child: child,
    );
    if (accent == null) return panel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          panel,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: IgnorePointer(child: ColoredBox(color: accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final number = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{5,14}$').hasMatch(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incluí + y el código de país en el teléfono.'),
        ),
      );
      return;
    }
    await _SupplierContactDetails._open(
      context,
      Uri.https('wa.me', '/${number.substring(1)}'),
    );
  }

  Widget _agendaCard(
    Map<String, Object?> order, {
    required String today,
    required bool contact,
    required DateTime? pickup,
  }) {
    final overdue =
        pickup != null && _pickupDayKey(pickup).compareTo(today) < 0;
    final pickupToday = pickup != null && _pickupDayKey(pickup) == today;
    final dateLabel = pickup == null
        ? ''
        : '${pickup.day}/${pickup.month}/${pickup.year}';
    final title = overdue
        ? 'Entrega vencida · pactada para el $dateLabel'
        : pickupToday
        ? 'Retiro pactado para hoy'
        : pickup != null
        ? 'Retiro pactado · $dateLabel'
        : 'Listo para entregar';
    // Seguimiento hasta el retiro.
    final notified =
        order['status'] == 'Entregar' && order['customer_notified_at'] != null;
    final accent = overdue
        ? _red
        : pickupToday
        ? _purple
        : contact
        ? const Color(0xffeeb85d)
        : const Color(0xff707b8b);

    final phone = (order['customer_phone'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _panel(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: overdue ? _red : _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.circle, size: 7, color: accent),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${order['customer']}'),
                      if (phone.isNotEmpty)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(phone),
                            IconButton(
                              tooltip: 'Abrir WhatsApp',
                              onPressed: _saving
                                  ? null
                                  : () => _openWhatsApp(phone),
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                color: _whatsapp,
                                size: 18,
                              ),
                            ),
                          ],
                        )
                      else
                        const Text('Sin teléfono registrado'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${order['model']}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (contact)
              const Text(
                'Contacto pendiente',
                style: TextStyle(color: Color(0xffeeb85d)),
              ),
            if (notified)
              const Text(
                '✓ Cliente avisado',
                style: TextStyle(color: Color(0xff81dba6)),
              ),
            if (notified && pickup == null) const Text('Sin fecha de retiro'),

            Wrap(
              spacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _openOrder(order),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Ver orden'),
                ),
                if (phone.isNotEmpty)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _openDialer(context, phone),
                    child: const Text('Llamar'),
                  ),
                if (contact)
                  TextButton(
                    onPressed: _saving ? null : () => _notify(order),
                    child: const Text('Cliente avisado'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(int count, String label, IconData icon, Color accent) {
    return _panel(
      child: Row(
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _orders,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Map<String, Object?>>[];
        final today = _pickupDayKey(DateTime.now());
        final date = _pickupDayKey(_day ?? DateTime.now());
        final isToday = date == today;
        final overdue =
            all.where((row) {
              final pickup = row['pickup_date'] as String?;
              return row['status'] != 'Retirado' &&
                  pickup != null &&
                  DateTime.tryParse(pickup) != null &&
                  pickup.compareTo(today) < 0;
            }).toList()..sort(
              (a, b) => (a['pickup_date'] as String).compareTo(
                b['pickup_date'] as String,
              ),
            );
        final pickups = all.where(
          (row) => row['pickup_date'] == date && row['status'] != 'Retirado',
        );
        final contacts = isToday
            ? all.where(
                (row) =>
                    row['status'] == 'Entregar' &&
                    row['pickup_date'] != today &&
                    !overdue.contains(row),
              )
            : const <Map<String, Object?>>[];
        final agenda = [if (isToday) ...overdue, ...pickups, ...contacts];
        final todayPickups = all
            .where(
              (row) =>
                  row['pickup_date'] == today && row['status'] != 'Retirado',
            )
            .length;
        final active = all.where((row) => row['status'] != 'Retirado').length;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _AgendaShoulder(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 18, 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  color: _cyan,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    isToday ? 'Agenda de hoy' : 'Agenda',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _chooseDay,
                        child: Text(
                          _day == null
                              ? 'Hoy ▾'
                              : '${_day!.day}/${_day!.month} ▾',
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.hasError)
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('No se pudo leer Agenda. Reintentar'),
                    )
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (agenda.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        isToday
                            ? 'No hay pendientes para hoy.'
                            : 'No hay retiros pactados para ese día.',
                      ),
                    )
                  else
                    for (final order in agenda)
                      _agendaCard(
                        order,
                        today: today,
                        contact: _needsContact(order),
                        pickup: DateTime.tryParse(
                          order['pickup_date'] as String? ?? '',
                        ),
                      ),
                ],
              ),
              if (!widget.agendaOnly &&
                  !snapshot.hasError &&
                  all.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _metric(
                        active,
                        'Órdenes activas',
                        Icons.build_outlined,
                        _cyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metric(
                        todayPickups,
                        'Retiros de hoy',
                        Icons.inventory_2_outlined,
                        _purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.layers_outlined, color: _cyan),
                    SizedBox(width: 8),
                    Text(
                      'Últimas órdenes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final order in all.take(3)) ...[
                  _panel(
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_android_outlined),
                      title: Text("${order['code']} · ${order['model']}"),
                      subtitle: Text("${order['status']}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openOrder(order),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AgendaShoulder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 2 || size.height < 4) return;
    final outline = Path()
      ..moveTo(0.5, 0.5)
      ..lineTo(size.width * 0.70, 0.5)
      ..lineTo(size.width - 0.5, size.height * 0.68)
      ..lineTo(size.width - 0.5, size.height - 0.5)
      ..lineTo(0.5, size.height - 0.5)
      ..close();
    canvas.drawPath(outline, Paint()..color = const Color(0xff1c2028));
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xff303641)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _AgendaShoulder oldDelegate) => false;
}
