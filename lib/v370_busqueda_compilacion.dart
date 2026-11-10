import 'v370_binario_samsung.dart';

class DatosCompilacion {
  const DatosCompilacion({
    this.marca,
    this.codigoModelo,
    this.nombreComercial,
    this.procesadorSoc,
    this.android,
    this.binarioSamsung,
    this.caracterBinario,
  });

  final String? marca;
  final String? codigoModelo;
  final String? nombreComercial;
  final String? procesadorSoc;
  final String? android;
  final int? binarioSamsung;
  final String? caracterBinario;
}

// Hardware por variante. El nombre comercial puede repetirse.
const _modelosSamsung = {
  // https://www.tiomovil.com/especificaciones/samsung/galaxy-a22-5g/sm-a226b/
  'A226B': DatosCompilacion(
    nombreComercial: 'Galaxy A22 5G',
    procesadorSoc: 'MediaTek Dimensity 700',
  ),
  // https://www.phonemore.com/specs/samsung/galaxy-a54/sm-a546eds-256gb/
  'A546E': DatosCompilacion(
    nombreComercial: 'Galaxy A54 5G',
    procesadorSoc: 'Samsung Exynos 1380',
  ),
  // https://www.techinsights.com/blog/survey-plus-teardown-samsung-galaxy-a15-sm-a155m-smartphone
  'A155M': DatosCompilacion(
    nombreComercial: 'Galaxy A15',
    procesadorSoc: 'MediaTek Helio G99',
  ),
  // https://www.deviceinfo.app/devices/samsung/galaxy-s22/
  'S901B': DatosCompilacion(
    nombreComercial: 'Galaxy S22',
    procesadorSoc: 'Samsung Exynos 2200',
  ),
  'S901E': DatosCompilacion(
    nombreComercial: 'Galaxy S22',
    procesadorSoc: 'Qualcomm Snapdragon 8 Gen 1',
  ),
};

// Android se completa por compilación exacta, nunca solo por modelo.
// Fuentes Samsung: https://doc.samsungmobile.com/ (historial por variante).
const _androidSamsung = {
  'A226BXXSADXH2': '13',
  'A226BXXSBDYA2': '13',
  'A226BXXS9DXD2': '13',
  'A226BXXU7DWH4': '13',
  'S901BXXSDEYA1': '14',
  'A546EXXU5BWK4': '14',
  'A546EXXUCDYDB': '15',
  'A155MUBS6BYE2': '14',
};

const _otrasCompilaciones = {
  // Actualizaciones documentadas por Telefónica España.
  'U1TD34.94-12-7': DatosCompilacion(
    marca: 'Motorola',
    nombreComercial: 'moto G54 5G',
    // https://en-us.support.motorola.com/app/answers/detail/a_id/176649/p/30
    procesadorSoc: 'MediaTek Dimensity 7020',
    android: '14',
  ),
  'U1TC34.22-64-11': DatosCompilacion(
    marca: 'Motorola',
    nombreComercial: 'moto G84 5G',
    // https://en-us.support.motorola.com/app/answers/detail/a_id/176157/~/moto-g84-5g---specifiche
    procesadorSoc: 'Qualcomm Snapdragon 695 5G',
    android: '14',
  ),
  'CPH2577_14.0.0.630(EX01)': DatosCompilacion(
    marca: 'OPPO',
    codigoModelo: 'CPH2577',
    nombreComercial: 'A58',
    // https://www.oppo.com/latin/smartphones/series-a/a58/specs/
    procesadorSoc: 'MediaTek Helio G85',
    android: '14',
  ),
  'CPH2557_14.0.0.820(EX01)': DatosCompilacion(
    marca: 'OPPO',
    codigoModelo: 'CPH2557',
    nombreComercial: 'A79 5G',
    // https://network.mobile.rakuten.co.jp/product/smartphone/a79-5g/spec.html
    procesadorSoc: 'MediaTek Dimensity 6020',
    android: '14',
  ),
  'CPH2579_14.0.0.630(EX01)': DatosCompilacion(
    marca: 'OPPO',
    codigoModelo: 'CPH2579',
    nombreComercial: 'A38',
    // https://www.oppo.com/cl/smartphones/series-a/a38/specs/
    procesadorSoc: 'MediaTek Helio G85',
    android: '14',
  ),
  // https://ximitime.com/hyperos/sapphire/version/OS1.0.7.0.UNGMIXM/
  'OS1.0.7.0.UNGMIXM': DatosCompilacion(
    marca: 'Xiaomi',
    nombreComercial: 'Redmi Note 13 4G',
    // https://www.mi.com/ar/product/redmi-note-13/specs/
    procesadorSoc: 'Qualcomm Snapdragon 685',
    android: '14',
  ),
  // https://developers.google.com/android/drivers
  'BD4A.250405.003': DatosCompilacion(
    marca: 'Google',
    nombreComercial: 'Pixel 9a',
    // https://store.google.com/us/product/pixel_9a_specs
    procesadorSoc: 'Google Tensor G4',
    android: '15',
  ),
};

/// Recibe el valor ingresado a mano. Los campos null quedan sin verificar.
/// Conservá el texto ingresado en el formulario aunque no exista en el catálogo.
DatosCompilacion buscarDatosCompilacion(String entrada) {
  final codigo = entrada.trim().toUpperCase();
  final exacta = _otrasCompilaciones[codigo];
  if (exacta != null) return exacta;

  final samsung = analizarBinarioSamsung(codigo);
  if (samsung == null) return const DatosCompilacion();

  final modelo = _modelosSamsung[samsung.variante];
  return DatosCompilacion(
    marca: modelo == null ? 'Samsung probable' : 'Samsung',
    codigoModelo: 'SM-${samsung.variante}',
    nombreComercial: modelo?.nombreComercial,
    procesadorSoc: modelo?.procesadorSoc,
    android: _androidSamsung[samsung.compilacion],
    binarioSamsung: samsung.binario,
    caracterBinario: samsung.caracter,
  );
}
