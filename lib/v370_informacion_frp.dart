import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'v370_binario_samsung.dart';
import 'v370_busqueda_compilacion.dart';
import 'workshop_sample.dart'
    show
        FrpPendingDevicesPage,
        addPhoneFromFrp,
        frpMethods,
        readFrpDevices,
        readFrpOpenOrders,
        saveDeviceFrp;

/// Entrada para el grupo de extras del menú Gestión.
class InformacionFrpExtra extends StatelessWidget {
  const InformacionFrpExtra({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.phonelink_lock_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Información FRP'),
      subtitle: const Text('Identificación de software y binario'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const InformacionFrpPage()),
      ),
    );
  }
}

// Catálogo inicial. Android se completa por coincidencia exacta de compilación.
// Fuente: https://samfw.com/firmware/SM-A226B/INS
const _modelosSamsung = {'A226B': 'Galaxy A22 5G'};
const _androidPorCompilacion = {
  'A226BXXSADXH2': '13',
  'A226BXXSBDYA2': '13',
  'A226BXXS9DXD2': '13',
};

class InformacionFrpPage extends StatefulWidget {
  const InformacionFrpPage({super.key, this.marcaOrden, this.modeloOrden});

  final String? marcaOrden;
  final String? modeloOrden;

  @override
  State<InformacionFrpPage> createState() => _InformacionFrpPageState();
}

class _InformacionFrpPageState extends State<InformacionFrpPage> {
  late final _marca = TextEditingController(text: widget.marcaOrden);
  late final _modelo = TextEditingController(text: widget.modeloOrden);
  final _android = TextEditingController();
  final _compilacion = TextEditingController();
  bool _leyendoCamara = false;
  RevisionSamsung? _revision;
  bool _hayCompilacion = false;
  String? _metodoFrp;
  String _compilacionConsultada = '';
  bool _vinculando = false;

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _android.dispose();
    _compilacion.dispose();
    super.dispose();
  }

  void _actualizarSugerencia(
    TextEditingController campo,
    String? anterior,
    String? nueva,
  ) {
    if (campo.text.trim().isEmpty || campo.text == anterior) {
      final texto = nueva ?? '';
      if (campo.text != texto) campo.text = texto;
    }
  }

  String? _marcaDetectada(RevisionSamsung? revision) {
    if (revision == null) return null;
    return _modelosSamsung.containsKey(revision.variante)
        ? 'Samsung'
        : 'Samsung probable';
  }

  String? _modeloDetectado(RevisionSamsung? revision) {
    if (revision == null) return null;
    return 'SM-${revision.variante}';
  }

  Future<void> _leerConCamara() async {
    if (_leyendoCamara) return;

    FocusScope.of(context).unfocus();
    setState(() => _leyendoCamara = true);
    try {
      final foto = await ImagePicker().pickImage(source: ImageSource.camera);
      if (!mounted || foto == null) return;

      final lector = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText lectura;
      try {
        lectura = await lector.processImage(InputImage.fromFilePath(foto.path));
      } finally {
        await lector.close();
      }
      if (!mounted) return;

      final lineas = {
        for (final bloque in lectura.blocks)
          for (final linea in bloque.lines)
            if (linea.text.trim().isNotEmpty) linea.text.trim(),
      };

      if (lineas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer texto en la foto.')),
        );
        return;
      }

      final reconocidas = lineas
          .where((linea) => analizarBinarioSamsung(linea) != null)
          .toSet();
      final opciones = [
        ...reconocidas,
        ...lineas.where((linea) => !reconocidas.contains(linea)),
      ];

      final elegida = await showDialog<String>(
        context: context,
        builder: (dialogo) => SimpleDialog(
          title: const Text('Elegí el número de compilación'),
          children: [
            for (final linea in opciones)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogo).pop(linea),
                child: Text(linea),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (!mounted || elegida == null) return;

      _compilacion.value = TextEditingValue(
        text: elegida,
        selection: TextSelection.collapsed(offset: elegida.length),
      );
      _leerCompilacion(elegida);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer con la cámara.')),
      );
    } finally {
      if (mounted) setState(() => _leyendoCamara = false);
    }
  }

  DatosCompilacion _datosCompilacion = const DatosCompilacion();

  void _leerCompilacion(String entrada) {
    _leerCompilacionSamsung(entrada);
    final datos = buscarDatosCompilacion(entrada);
    setState(() {
      _datosCompilacion = datos;
      _marca.text = datos.marca ?? '';
      _modelo.text = datos.codigoModelo ?? datos.nombreComercial ?? '';
      _android.text = datos.android ?? '';
    });
  }

  void _leerCompilacionSamsung(String entrada) {
    _compilacionConsultada = entrada.trim();
    final anterior = _revision;
    final nueva = analizarBinarioSamsung(entrada);
    setState(() {
      _hayCompilacion = entrada.trim().isNotEmpty;
      _revision = nueva;
      _actualizarSugerencia(
        _marca,
        _marcaDetectada(anterior),
        _marcaDetectada(nueva),
      );
      _actualizarSugerencia(
        _modelo,
        _modeloDetectado(anterior),
        _modeloDetectado(nueva),
      );
      _actualizarSugerencia(
        _android,
        anterior == null ? null : _androidPorCompilacion[anterior.compilacion],
        nueva == null ? null : _androidPorCompilacion[nueva.compilacion],
      );
    });
  }

  Map<String, Object?> _fichaActual() {
    final revision = _revision;
    return <String, Object?>{
      'build_number': _compilacionConsultada,
      'brand': _marca.text,
      'model': _modelo.text,
      'android_version': _android.text,
      'processor_soc': _datosCompilacion.procesadorSoc,
      'binary': revision == null
          ? null
          : '${revision.binario} (${revision.caracter})',
      'method': _metodoFrp,
    };
  }

  Future<void> _agregarTelefono() async {
    if (_vinculando || _compilacionConsultada.isEmpty) return;
    final ficha = _fichaActual();
    setState(() => _vinculando = true);
    try {
      final saved = await addPhoneFromFrp(context, ficha);
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teléfono e información FRP guardados.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el alta del equipo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _vinculando = false);
    }
  }

  Future<void> _vincularEquipo() async {
    if (_vinculando || _compilacionConsultada.isEmpty) return;
    final ficha = _fichaActual();

    setState(() => _vinculando = true);
    try {
      final equipos = await readFrpDevices();
      if (!mounted) return;

      final variante = _normalizarModelo(_modelo.text);
      bool coincide(Map<String, Object?> equipo) =>
          variante.isNotEmpty &&
          _normalizarModelo(equipo['model'] as String) == variante;
      final ordenados = [
        ...equipos.where(coincide),
        ...equipos.where((equipo) => !coincide(equipo)),
      ];

      var busqueda = '';
      final equipo = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (dialogo) => StatefulBuilder(
          builder: (contexto, refrescar) {
            final visibles = ordenados.where((fila) {
              final texto =
                  '${fila['customer']} ${fila['model']} #${fila['id']}';
              return texto.toLowerCase().contains(busqueda);
            }).toList();
            return AlertDialog(
              title: const Text('Elegí el equipo'),
              content: SizedBox(
                width: 360,
                height: 280,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por cliente o modelo',
                      ),
                      onChanged: (texto) => refrescar(
                        () => busqueda = texto.trim().toLowerCase(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visibles.isEmpty
                          ? const Center(
                              child: Text('Sin equipos para mostrar.'),
                            )
                          : ListView.builder(
                              itemCount: visibles.length,
                              itemBuilder: (contexto, indice) {
                                final fila = visibles[indice];
                                return ListTile(
                                  title: Text(fila['model'] as String),
                                  subtitle: Text(
                                    '${fila['customer']} · Equipo #${fila['id']}',
                                  ),
                                  onTap: () => Navigator.of(dialogo).pop(fila),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogo).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || equipo == null) return;

      final deviceId = equipo['id'] as int;
      final metodo = ficha['method'] as String?;
      final ordenes = metodo == null
          ? <Map<String, Object?>>[]
          : await readFrpOpenOrders(deviceId);
      if (!mounted) return;

      // Cuando hay varias, el valor inicial guarda únicamente en el equipo.
      var destino = ordenes.length == 1 ? ordenes.single['code'] as String : '';
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogo) => StatefulBuilder(
          builder: (context, refrescar) {
            final seleccionada = destino.isEmpty
                ? null
                : ordenes.singleWhere((orden) => orden['code'] == destino);
            final anterior = seleccionada?['frp_method'] as String?;
            return AlertDialog(
              scrollable: true,
              title: const Text('Guardar información FRP'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${equipo['customer']} · ${equipo['model']} · Equipo #${equipo['id']}\n'
                    'Compilación: ${ficha['build_number']}',
                  ),
                  if (equipo['has_frp'] == 1)
                    const Text('Se reemplazará la ficha anterior del equipo.'),
                  if (ordenes.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: destino,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Aplicar método en',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Solo el equipo'),
                        ),
                        for (final orden in ordenes)
                          DropdownMenuItem(
                            value: orden['code'] as String,
                            child: Text(
                              '${orden['code']} · ${orden['status']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (valor) =>
                          refrescar(() => destino = valor ?? ''),
                    ),
                    if (anterior != null && anterior != metodo)
                      Text(
                        'Al guardar, «$anterior» se reemplazará por «$metodo» en $destino.',
                      )
                    else if (destino.isNotEmpty)
                      Text('Se guardará «$metodo» en $destino.'),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogo).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogo).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || confirmar != true) return;

      final orden = destino.isEmpty
          ? null
          : ordenes.singleWhere((orden) => orden['code'] == destino);
      await saveDeviceFrp(deviceId, ficha, order: orden);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orden == null
                ? 'Información FRP guardada en el equipo.'
                : 'Ficha guardada. Método FRP actualizado en $destino.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la información FRP.')),
      );
    } finally {
      if (mounted) setState(() => _vinculando = false);
    }
  }

  String _normalizarModelo(String valor) {
    return valor.trim().toUpperCase().replaceFirst(RegExp(r'^SM-'), '');
  }

  @override
  Widget build(BuildContext context) {
    final revision = _revision;
    final marca = _marca.text.trim().toUpperCase();
    final modelo = _normalizarModelo(_modelo.text);
    final marcaCoincide =
        marca.isEmpty || marca == 'SAMSUNG' || marca == 'SAMSUNG PROBABLE';
    final hayDiferencia =
        revision != null &&
        (!marcaCoincide || (modelo.isNotEmpty && modelo != revision.variante));
    final binario = revision == null || hayDiferencia
        ? 'Sin verificar'
        : '${revision.binario} (${revision.caracter})';
    final nombreComercial = revision == null || hayDiferencia
        ? null
        : _modelosSamsung[revision.variante];
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información FRP'),
        actions: [
          IconButton(
            tooltip: 'Agregar teléfono',
            onPressed: !_hayCompilacion || _vinculando
                ? null
                : _agregarTelefono,

            icon: const Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.smartphone),
                Positioned(
                  top: -3,
                  right: -5,
                  child: Icon(Icons.add, size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                TextField(
                  controller: _compilacion,
                  decoration: InputDecoration(
                    labelText: 'Número de compilación',
                    suffixIcon: IconButton(
                      tooltip: 'Leer número de compilación con la cámara',
                      onPressed: _leyendoCamara ? null : _leerConCamara,
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    isDense: true,
                    hintText: 'Ej. A226BXXSADXH2',
                    prefixIcon: const Icon(Icons.tag),
                    border: const OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _leerCompilacion,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pegalo desde Ajustes → Información de software. '
                  'Es el único dato necesario para intentar la lectura.',
                  style: tema.textTheme.bodySmall,
                ),
                if (_hayCompilacion &&
                    revision == null &&
                    _datosCompilacion.marca == null) ...[
                  const SizedBox(height: 8),
                  const Text('Compilación sin datos verificados.'),
                ],
                if (hayDiferencia) ...[
                  const SizedBox(height: 8),
                  Text(
                    'La compilación indica Samsung ${revision.variante}. '
                    'Revisá la marca y el modelo ingresados.',
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _marca,
                  readOnly: true,
                  showCursor: false,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'Sin verificar',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelo,
                  readOnly: true,
                  showCursor: false,
                  decoration: InputDecoration(
                    labelText: 'Modelo',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'Sin verificar',
                    isDense: true,
                    helperText: nombreComercial,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Procesador (SoC)',
                    isDense: true,
                  ),
                  child: Text(
                    _datosCompilacion.procesadorSoc ?? 'Sin verificar',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _android,
                  readOnly: true,
                  showCursor: false,
                  decoration: const InputDecoration(
                    labelText: 'Versión de Android',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'Sin verificar',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      Icons.memory,
                      color: tema.colorScheme.primary,
                    ),
                    dense: true,
                    title: const Text('Binario'),
                    subtitle: Text(
                      binario,
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _metodoFrp,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Método FRP',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Seleccioná un método'),
                  items: [
                    for (final metodo in frpMethods)
                      DropdownMenuItem(value: metodo, child: Text(metodo)),
                  ],
                  onChanged: (metodo) => setState(() => _metodoFrp = metodo),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: !_hayCompilacion || _vinculando
                      ? null
                      : _vincularEquipo,
                  icon: const Icon(Icons.link),
                  label: const Text('Vincular a un equipo'),
                ),
                TextButton(
                  onPressed: _vinculando
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const FrpPendingDevicesPage(),
                          ),
                        ),
                  child: const Text('Equipos sin cliente'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: const Row(
                      children: [
                        Expanded(
                          child: _StickerFrp(
                            titulo: 'Cómo leer la compilación',
                            recurso: 'assets/frp/lectura_compilacion.png',
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _StickerFrp(
                            titulo: 'Equivalencias de binarios',
                            recurso: 'assets/frp/tabla_binarios.png',
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
      ),
    );
  }
}

class _StickerFrp extends StatelessWidget {
  const _StickerFrp({required this.titulo, required this.recurso});

  final String titulo;
  final String recurso;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ampliar: $titulo',
      button: true,
      child: Tooltip(
        message: 'Ampliar: $titulo',
        child: Material(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(titulo),
                scrollable: true,
                content: ColoredBox(
                  color: Colors.black,
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.asset(recurso, fit: BoxFit.contain),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Ink.image(image: AssetImage(recurso), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
