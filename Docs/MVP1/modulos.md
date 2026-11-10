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
| Base local | Apertura, migraciones, transacciones | Todos los módulos persistentes |

## Dependencias que merecen atención

- Consultas SQLite ejecutadas desde pantallas: localizar antes de extraer repositorios.
- `workshop_finance.dart` usa `part of`, por lo que depende de la biblioteca que define `workshop_sample.dart`.
- Altas de equipos sin cliente: contrastar consultas y claves foráneas que asumían siempre un cliente.
- Estados y presupuesto: documentar operaciones en transacciones y refresco de vistas.

Para cada módulo en la versión final registrar: ruta de archivo, clases/métodos principales, datos leídos y escritos, errores y pruebas.
