#!/usr/bin/env bash

ADB='/c/Users/maxi1/AppData/Local/Android/sdk/platform-tools/adb.exe'
DEVICE='emulator-5554'

if "$ADB" devices | grep -q "^${DEVICE}[[:space:]]"; then
  echo 'Cerrando el Pixel 8...'
  if ! "$ADB" -s "$DEVICE" emu kill; then
    echo 'No pude cerrar el Pixel 8. Cerralo desde su ventana y volvé a ejecutar el script.'
    exit 1
  fi
fi

echo 'Deteniendo el servidor ADB...'
"$ADB" kill-server || exit 1
echo 'Listo Max... Apagado de v370 completo.'
