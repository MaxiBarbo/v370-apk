# v370 — Accesos rápidos Flutter y Android (VS Code)

Guía de uso diario del proyecto **v370** en Windows 11, con **Git Bash** y Visual Studio Code. Los comandos están ordenados por flujo de trabajo y reunidos en bloques `bash` para facilitar su lectura.

> **Ejecución sin copiar y pegar:** VS Code no incluye un botón ▶ que ejecute directamente cada bloque Bash de un archivo Markdown. El archivo complementario `tasks.json` permite lanzar estas acciones desde **Terminal → Run Task / Ejecutar tarea**, eligiendo la acción por su nombre. No es necesario copiar comandos. **Antes de reemplazar un `tasks.json` existente, comparalo y conservá sus tareas.**

## 1. Abrir el proyecto

Ruta en Windows: `H:\Repositorios Github\Web-Reparacion-Celulares\V370_apk`

En VS Code, abrir esa carpeta. Si Git Bash quedó ubicado fuera del proyecto:

```bash
cd '/h/Repositorios Github/Web-Reparacion-Celulares/V370_apk'
```

## 2. Inicio rápido: emulador y aplicación

### Conectar S22 a la pc

ADB="$(cygpath -u "$LOCALAPPDATA")/Android/sdk/platform-tools/adb.exe"
read -rp 'IP y puerto de vinculación: ' VINCULACION
"$ADB" pair "$VINCULACION"

### Ver emuladores disponibles

```bash
flutter emulators
```

### Iniciar Pixel 8 (sin Android Studio)

```bash
flutter emulators --launch Pixel_8
```

**Alternativa** para iniciar Pixel 8 sin cargar un snapshot anterior (no ejecutarla simultáneamente con la anterior):

```bash
"/c/Users/maxi1/AppData/Local/Android/sdk/emulator/emulator.exe" -avd Pixel_8 -no-snapshot-load
```

### Comprobar la conexión con Android

```bash
adb devices -l
flutter devices
```

Si `adb` no se reconoce desde la terminal, su ruta explícita es:

```bash
"/c/Users/maxi1/AppData/Local/Android/sdk/platform-tools/adb.exe" devices -l
```

El emulador en ejecución suele aparecer como `emulator-5554    device`. **Pixel_8** es el nombre del AVD; **emulator-5554** es un ID que puede cambiar.

### Ejecutar v370 en el emulador

```bash
flutter run -d emulator-5554
```

Si el ID es diferente, tomarlo de `flutter devices` y cambiarlo en el comando. El emulador debe estar iniciado y listo.

### Actualizar conexión con Samsung S22

Script propio de este proyecto (se ejecuta desde su carpeta raíz y debe existir el archivo):

```bash
bash actualizar_v370.sh
```

## 3. Detener, reiniciar y recuperar conexión

### Detener Flutter sin cerrar Android

En la terminal donde está corriendo `flutter run`, escribir **`q`**. Otras teclas disponibles:

| Tecla | Función |
| --- | --- |
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Salir de `flutter run` |
| `h` | Ayuda |

### Cerrar solamente el emulador

```bash
adb -s emulator-5554 emu kill
```

### Cerrar el emulador y reiniciar ADB

```bash
ADB='/c/Users/maxi1/AppData/Local/Android/sdk/platform-tools/adb.exe'
"$ADB" -s emulator-5554 emu kill
"$ADB" kill-server
```

**Atención:** `kill-server` interrumpe temporalmente las conexiones ADB, incluido un teléfono físico conectado. No detiene automáticamente una sesión de `flutter run` abierta en otra terminal; para esa sesión usá `q`.

### Recuperar ADB si el dispositivo aparece `offline`

```bash
adb kill-server
adb start-server
adb devices -l
```

## 4. Diagnóstico del entorno

```bash
flutter --version
flutter doctor
flutter devices
```

Si hay problemas de conexión:

```bash
adb devices -l
flutter devices
flutter doctor -v
```

Antes de cambiar `PATH` o reinstalar herramientas, revisar el error exacto. Una advertencia sobre **Visual Studio para aplicaciones de escritorio Windows** no impide compilar Android.

## 5. Compilar e instalar APK

### Compilar versión de prueba (debug)

```bash
flutter build apk --debug
```

Salida habitual: `build/app/outputs/flutter-apk/app-debug.apk`.

### Compilar versión release

```bash
flutter build apk --release
```

Salida habitual: `build/app/outputs/flutter-apk/app-release.apk`.

> Una compilación `release` no está automáticamente lista para distribuirse o publicar en Google Play. Antes hay que validar el identificador de aplicación, la firma, permisos y seguridad.

### Instalar la APK debug en Android conectado

```bash
adb devices -l
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Si aparece más de un dispositivo, especificar el destino con `adb -s ID_DISPOSITIVO install -r ...`.

## 6. Ubicaciones del entorno

| Componente | Ruta |
| --- | --- |
| Proyecto v370 APK | `H:\Repositorios Github\Web-Reparacion-Celulares\V370_apk` |
| Flutter SDK | `H:\Desarrollo\flutter` |
| Android SDK y ADB | `C:\Users\maxi1\AppData\Local\Android\Sdk` |
| Documentación MVP 1 | `H:\Repositorios Github\Web-Reparacion-Celulares\V370_apk\Docs\MVP1` |

No es necesario mantener Android Studio abierto si el emulador ya está funcionando.

## 7. Arquitectura: estado actual y evolución

- **MVP 1 actual:** APK Flutter independiente del gestor web, con **SQLite local** y funcionamiento sin conexión.
- **Diseño visual:** se han explorado estilos grafito, dorado mate, grises y blanco, además de prototipos posteriores. La guía visual vigente prevalece sobre referencias anteriores.
- **Evolución prevista / MVP 2:** integración de la APK con Raspberry Pi 5 mediante la API Flask, manteniendo el modo local y definiendo sincronización.
- **Seguridad futura:** antes del acceso remoto, definir autenticación y conexiones seguras (HTTPS o VPN).

La descripción antigua de «datos exclusivamente centralizados en Raspberry» y «sin SQLite en el teléfono» correspondía a otra propuesta de arquitectura; **no describe el funcionamiento actual del MVP 1**.

## 8. Ejecutar las acciones desde VS Code sin copiar comandos

Con el archivo complementario `.vscode/tasks.json` instalado en el proyecto:

1. Abrir **Terminal → Run Task** (o **Terminal → Ejecutar tarea**).
2. Elegir una tarea cuyo nombre empiece por `v370:`; por ejemplo, `v370: Iniciar Pixel 8`.
3. VS Code abre la terminal y ejecuta el comando correspondiente.

También podés abrir **Command Palette** (`Ctrl+Shift+P`) y escribir `Tasks: Run Task`. Las tareas no modifican el código Dart; las tareas de compilación generan archivos en `build/`, y las de cierre detienen procesos/dispositivos indicados.

**Importante:** esto no convierte los bloques `bash` del Markdown en botones Play. Para ejecutar fragmentos seleccionados desde el documento haría falta una extensión específica y verificar cómo opera. Las tareas integradas son la opción reproducible sin extensiones.

---

Esta guía es documental: no instala ni ejecuta componentes por el mero hecho de abrirla.
