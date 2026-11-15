# Módulos funcionales — MVP 1

Este mapa registra responsabilidades, **no asegura que cada módulo exista como paquete o carpeta independiente**.

| Área | Responsabilidad | Dependencias a auditar |
| --- | --- | --- |
| Inicio y Agenda | Resumen, pendientes, avisos y retiros | Órdenes, fechas y estados |
| Clientes | Datos de contacto y búsqueda | Equipos, órdenes |
| Equipos | Marca, modelo, identificación e historial | Clientes y FRP |
| Órdenes | Recepción, estado, seguimiento y fotos | Equipo, historial, presupuesto |
| Presupuestos/Ingresos | Conceptos, señas, saldo y cobros | Órdenes, pagos y PDF |
| Stock y proveedores | Catálogo, existencia y movimientos | Relaciones y restricciones de inventario |
| FRP | Compilación, binario, SoC y vinculación | Equipo y, opcionalmente, orden |
| PDF | Comprobantes y anexos | Cliente, equipo, orden, presupuesto, fotografías |
| Respaldo | Crear y combinar copias JSON con vista previa | `workshop_backup.dart`, SQLite, canal Android `v370/backup` |
| Exportación de planillas | XLSX con Resumen de trabajos, Clientes, Órdenes y Presupuestos | `workshop_export.dart`, consultas de taller y selector Android |
| Seguimiento manual | Abrir una planilla externa desde un enlace editable | Preferencias. Incluir el enlace en la copia depende del paquete v23 |
| Base local | Apertura, migraciones, transacciones | Todos los módulos persistentes |

## Dependencias que merecen atención

- Consultas SQLite ejecutadas desde pantallas: localizar antes de extraer repositorios.
- `workshop_finance.dart` usa `part of`, por lo que depende de la biblioteca que define `workshop_sample.dart`.
- Altas de equipos sin cliente: contrastar consultas y claves foráneas que asumían siempre un cliente.
- Estados y presupuesto: documentar operaciones en transacciones y refresco de vistas.

Para cada módulo en la versión final registrar: ruta de archivo, clases/métodos principales, datos leídos y escritos, errores y pruebas.
