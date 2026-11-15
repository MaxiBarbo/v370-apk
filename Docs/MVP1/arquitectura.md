# Arquitectura de la APK — MVP 1

## En una frase

La APK v370 utiliza **Flutter/Dart** y una base **SQLite local**. Está diseñada para operar sin conexión. La integración con Raspberry Pi 5 es un proyecto posterior.

## Lo que muestra la evidencia disponible

| Archivo | Función identificada | Estado |
| --- | --- | --- |
| `lib/main.dart` | Entrada de la interfaz y navegación principal | Evidencia histórica |
| `lib/workshop_sample.dart` | Pantallas, reglas y acceso SQLite concentrados | Evidencia histórica |
| `lib/workshop_finance.dart` | Funciones financieras en `part of 'workshop_sample.dart'` | Evidencia histórica |
| `lib/v370_informacion_frp.dart` | Interfaz de información FRP | Mención en desarrollo; revisar versión vigente |
| `lib/v370_busqueda_compilacion.dart` | Catálogo de compilaciones y SoC | Fragmento de código compartido |
| `lib/v370_binario_samsung.dart` | Análisis de binario Samsung | Dependencia referenciada |
| `lib/velo_azul.dart` | Fondo animado | Mención en desarrollo; revisar versión vigente |

La copia compartida configura SQLite v21. Los paquetes agregan respaldo mediante `workshop_backup.dart` y un canal Android para elegir archivos, y exportación mediante `workshop_export.dart`. Ambos archivos Dart usan `part of 'workshop_sample.dart'`. La campanita abre la pantalla de Consultas, cuya conexión web figura pendiente en la copia revisada.

No se ha comprobado la distribución completa de clases, servicios e imports del código instalado. Separar un archivo no garantiza independencia modular: la relación `part of` comparte biblioteca Dart.

## Arquitectura objetivo (NO implementada completamente)

**Pantallas** → **reglas de aplicación** → **repositorios** → **SQLite local**.

El diseño futuro debe preservar la operación offline y añadir una capa de sincronización con un servicio remoto cuando se apruebe el MVP 2. No reemplazar el almacenamiento local por una conexión obligatoria a la Raspberry.

## Decisión para este cierre

No refactorizar durante la auditoría. Primero registrar módulos, métodos, dependencias, migraciones y pruebas; después evaluar cambios con respaldo y regresión.

## Visualizar el diagrama en Mermaid

- **[Abrir Mermaid Live Editor](https://mermaid.live/)** para ver y explorar el diagrama en el navegador.
- Abrí [`diagramas/arquitectura.mmd`](diagramas/arquitectura.mmd), copiá su contenido y pegalo en el panel izquierdo de Mermaid Live Editor. La vista gráfica aparecerá a la derecha.

> El diagrama es preliminar y representa la arquitectura conocida y la propuesta, no un análisis automático del código Flutter vigente.
