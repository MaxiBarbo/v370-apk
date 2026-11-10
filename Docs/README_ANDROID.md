# v370 — Guía rápida de Flutter y Android desde VS Code

Esta guía está preparada para la terminal **Git Bash** de Visual Studio Code en Windows 11.

# Comandos que utilizaremos habitualmente

### Ver emuladores disponibles
flutter emulators

### Iniciar Pixel 8 sin abrir Android Studio
flutter emulators --launch Pixel_8
"/c/Users/maxi1/AppData/Local/Android/sdk/emulator/emulator.exe" -avd Pixel_8 -no-snapshot-load

### Comprobar que Android está conectado
adb devices -l
"/c/Users/maxi1/AppData/Local/Android/sdk/platform-tools/adb.exe" devices -l
flutter devices

### Ejecutar v370
flutter run -d emulator-5554

### Actualizar conexion s22
bash actualizar_v370.sh

### Kill v370
ADB='/c/Users/maxi1/AppData/Local/Android/sdk/platform-tools/adb.exe'
"$ADB" -s emulator-5554 emu kill
"$ADB" kill-server

### Up todo


## Ubicaciones del entorno

| Componente | Ruta |
|---|---|
| Proyecto v370 APK | `H:\Repositorios Github\Web-Reparacion-Celulares\V370_apk` |
| Flutter SDK | `H:\Desarrollo\flutter` |
| Android SDK y ADB | `C:\Users\maxi1\AppData\Local\Android\Sdk` |

> No hace falta mantener Android Studio abierto. Sí debe estar funcionando el emulador para probar la aplicación en él.

## 1. Abrir el proyecto en VS Code

Abrir la carpeta `H:\Repositorios Github\Web-Reparacion-Celulares\V370_apk` y seleccionar **Terminal → Nueva terminal** (Git Bash).

Si la terminal no está ubicada en el proyecto:

```bash
cd '/h/Repositorios Github/Web-Reparacion-Celulares/V370_apk'
```

## 2. Ver los emuladores disponibles

```bash
flutter emulators
```

Anotar el **ID** que aparezca. No confundirlo con `emulator-5554`, que es el ID del dispositivo cuando está ejecutándose.

## 3. Iniciar el emulador sin abrir Android Studio

```bash
flutter emulators --launch ID_DEL_EMULADOR
```

Reemplazar `ID_DEL_EMULADOR` por el ID real obtenido en el paso anterior. Esperar a que Android termine de arrancar.

## 4. Comprobar la conexión del emulador

```bash
adb devices -l
flutter devices
```

ADB debería mostrar un dispositivo con estado `device`, por ejemplo:

```text
emulator-5554    device
```

Si muestra `offline`, esperar a que termine el arranque y volver a comprobar. Si persiste:

```bash
adb kill-server
adb start-server
adb devices -l
```

## 5. Ejecutar la aplicación v370

Con el emulador encendido y detectado:

```bash
flutter run -d emulator-5554
```

Si el dispositivo tiene otro ID, usar el que muestre `flutter devices`. La primera compilación puede tardar varios minutos.

### Atajos mientras `flutter run` está activo

| Tecla | Acción |
|---|---|
| `r` | Hot reload: aplicar cambios de código compatibles |
| `R` | Hot restart: reiniciar la aplicación |
| `q` | Finalizar la ejecución de Flutter |
| `h` | Mostrar ayuda de comandos interactivos |

Los atajos se escriben en la terminal donde está ejecutándose `flutter run`.

## 6. Verificar la instalación y los dispositivos

```bash
flutter --version
flutter doctor
flutter devices
```

La advertencia sobre **Visual Studio para aplicaciones de escritorio Windows** no impide desarrollar APK para Android.

## 7. Compilar una APK de prueba

Desde la raíz del proyecto:

```bash
flutter build apk --debug
```

Archivo generado:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Para una compilación de publicación:

```bash
flutter build apk --release
```

Archivo habitual:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> La APK `release` no está lista automáticamente para publicar en Google Play: antes hay que configurar el identificador definitivo, la firma de publicación, los permisos y las medidas de seguridad.

## 8. Instalar la APK de prueba en un Android conectado

Comprobar primero el dispositivo:

```bash
adb devices -l
```

Instalar la APK debug:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Si hay varios dispositivos conectados, especificar el identificador con `adb -s ID_DISPOSITIVO install -r ...`.

## 9. Detener o cerrar el emulador

Para cerrar el emulador que aparece como `emulator-5554`:

```bash
adb -s emulator-5554 emu kill
```

Si solo querés dejar de ejecutar Flutter pero mantener Android abierto, pulsá `q` en la terminal de `flutter run`.

## 10. Si aparece un problema de conexión

```bash
adb devices -l
flutter devices
flutter doctor -v
```

Antes de modificar el PATH o reinstalar herramientas, revisar el mensaje exacto. El ADB elegido para este entorno es el de Android Studio:

```text
C:\Users\maxi1\AppData\Local\Android\Sdk\platform-tools\adb.exe
```

## Arquitectura prevista para v370

- Interfaz Android **minimalista**, con grafito, dorado mate, grises y blanco.
- Código Flutter independiente del gestor web.
- Datos centralizados en la **Raspberry Pi 5**, mediante la API Flask de v370.
- No duplicar la base de datos SQLite en el teléfono.
- Antes de habilitar acceso remoto: autenticación y conexión segura (HTTPS o VPN).

---

**Nota:** este archivo es una guía de comandos; no modifica el proyecto ni instala componentes por sí solo.
