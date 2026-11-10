# SQLite — MVP 1

**Base referenciada:** `v370_workshop.db` mediante `sqflite`.

## Tablas observadas o mencionadas

`customers`, `devices`, `work_orders`, `order_status_history`, `order_sequence`, `budgets`, `budget_items`, `suppliers`, `stock_items`, `stock_movements`, `order_photos`, `device_frp`, `order_payments`, `paid_orders`.

**Importante:** esta relación combina evidencia parcial e historial de scripts, y **no es un inventario definitivo de tablas existentes**. La cifra “12” indicada en una revisión anterior no debe tratarse como definitiva. `order_payments` aparece expresamente en el script de migración financiera a versión 15; `paid_orders` aparece en un script posterior relacionado con la versión 16. Falta verificar el esquema actualizado en ejecución.

## Relaciones de referencia

- Cliente → equipos.
- Equipo → órdenes e información FRP.
- Orden → presupuesto, historial, fotografías y pagos.
- Proveedor → repuestos; repuesto → movimientos de stock.

Las cardinalidades y restricciones exactas deben comprobarse en el esquema real antes de declararlas cerradas.

## Proceso de verificación pendiente

1. Trabajar sobre **una copia segura**, sin modificar los datos reales.
2. Registrar versión real: `PRAGMA user_version;`.
3. Listar tablas reales desde `sqlite_master`.
4. Para cada tabla, registrar columnas con `PRAGMA table_info(...)`, claves con `PRAGMA foreign_key_list(...)` e índices con `PRAGMA index_list(...)`.
5. Contrastar el esquema nuevo con las migraciones `onCreate` / `onUpgrade` del código vigente.
6. Validar instalación limpia y actualización preservando los registros.

Ninguna sentencia de prueba debe borrar, modificar o reinicializar la base productiva.
