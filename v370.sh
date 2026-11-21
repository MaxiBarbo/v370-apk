#!/usr/bin/env bash

cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

SDK='/c/Users/maxi1/AppData/Local/Android/sdk'
ADB="$SDK/platform-tools/adb.exe"
DEVICE='emulator-5554'
LOG="$HOME/v370-emulador.log"

"$ADB" start-server || exit 1

if [[ "${1:-}" == 'cerrar' ]]; then
  "$ADB" -s "$DEVICE" emu kill
  exit $?
fi

if ! "$ADB" devices | grep -q "^${DEVICE}[[:space:]]"; then
  echo 'Hola Max...Abriendo el Pixel 8...'
  "$SDK/emulator/emulator.exe" -avd Pixel_8 -port 5554 -no-snapshot-load \
    > "$LOG" 2>&1 &
fi

echo 'Esperando a que Android termine de arrancar...'
for ((intento = 1; intento <= 60; intento++)); do
  arranque=$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  if [[ "$arranque" == '1' ]]; then
    echo 'Android listo. Ejecutando v370...'
    flutter run -d "$DEVICE"
    exit $?
  fi
  sleep 5
done

echo 'Android no confirmó el arranque durante la espera.'
"$ADB" devices -l
if [[ -f "$LOG" ]]; then
  tail -40 "$LOG"
fi
exit 1
