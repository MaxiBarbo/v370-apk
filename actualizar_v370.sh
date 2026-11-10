#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

ADB="$(cygpath -u "$LOCALAPPDATA")/Android/sdk/platform-tools/adb.exe"

if [[ -n "${1:-}" ]]; then
  "$ADB" connect "$1"
fi

dispositivos=$("$ADB" devices -l)
telefono=$(awk '$2 == "device" && /model:SM_S901E/ {print $1; exit}' <<< "$dispositivos")
emulador=$(awk '$1 ~ /^emulator-/ && $2 == "device" {print $1; exit}' <<< "$dispositivos")

if [[ -z "$telefono" ]]; then
  echo 'El Galaxy S22 no está conectado a ADB. Revisá Depuración inalámbrica.'
  printf '%s\n' "$dispositivos"
  exit 1
fi

flutter build apk --debug
apk="$(cygpath -w "$PWD/build/app/outputs/flutter-apk/app-debug.apk")"

echo 'Actualizando v370 en el Galaxy S22...'
"$ADB" -s "$telefono" install -r "$apk"

if [[ -n "$emulador" ]]; then
  echo 'Actualizando v370 en el emulador...'
  "$ADB" -s "$emulador" install -r "$apk"
fi
