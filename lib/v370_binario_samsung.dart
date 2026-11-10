// Lee compilaciones Samsung en formato AP/PDA estándar.
// Ejemplos: S938BXXS6CYI1 y A226BXXSADXH2.
// Se admite el prefijo de compilación Android (por ejemplo, UP1A.231005.007).
// Uso: analizarBinarioSamsung('A226BXXSADXH2')?.binario devuelve 10.

enum ObjetivoSamsung { identificar, actualizar, recuperarActualizacion, frp }

class RevisionSamsung {
  const RevisionSamsung({
    required this.compilacion,
    required this.variante,
    required this.caracter,
    required this.binario,
    required this.orientacion,
  });

  final String compilacion;
  final String variante;
  final String caracter;
  final int binario;
  final String orientacion;
}

// Variante + grupo de mercado (dos letras) + U/S + revisión + sufijo.
// Se limita a los formatos reconocidos y a las equivalencias del apunte.
final _compilacionSamsung = RegExp(
  r'^(?:[A-Z0-9]+(?:\.[A-Z0-9]+)+\.)?'
  r'(([A-Z][0-9]{3}[A-Z0-9]{0,3})[A-Z]{2}[US]([0-9A-J])'
  r'[A-Z][A-Z][A-L][0-9A-Z])$',
);

/// Devuelve null si la compilación es incompleta o tiene un formato no admitido.
/// La orientación depende del objetivo informado, no del valor del binario.
RevisionSamsung? analizarBinarioSamsung(
  String entrada, {
  ObjetivoSamsung objetivo = ObjetivoSamsung.identificar,
}) {
  final codigo = entrada.trim().toUpperCase();
  final coincidencia = _compilacionSamsung.firstMatch(codigo);
  if (coincidencia == null || coincidencia.end != codigo.length) return null;

  final caracter = coincidencia.group(3)!;
  return RevisionSamsung(
    compilacion: coincidencia.group(1)!,
    variante: coincidencia.group(2)!,
    caracter: caracter,
    binario: int.parse(caracter, radix: 36),
    orientacion: _orientacionSamsung(objetivo),
  );
}

String _orientacionSamsung(ObjetivoSamsung objetivo) {
  switch (objetivo) {
    case ObjetivoSamsung.identificar:
      return 'Seleccioná el objetivo: actualizar, recuperar una actualización '
          'fallida o recuperar la cuenta de Google (FRP).';
    case ObjetivoSamsung.actualizar:
      return 'Consultá Actualización de software o Smart Switch si reconoce '
          'el equipo y ofrece una actualización. Para evaluar un paquete, '
          'verificá la variante completa, el CSC y la revisión.';
    case ObjetivoSamsung.recuperarActualizacion:
      return 'Consultá la recuperación de emergencia de Smart Switch si la '
          'actualización fallida y el dispositivo aparecen en esa opción.';
    case ObjetivoSamsung.frp:
      return 'El titular puede iniciar sesión con una cuenta de Google '
          'previamente sincronizada o recuperarla en accounts.google.com/signin/recovery.';
  }
}
