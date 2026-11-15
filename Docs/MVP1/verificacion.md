# Lista de verificación de cierre — MVP 1

## Faltan evidencias

- [ ] Árbol actual de `lib/` y `test/`.
- [ ] `pubspec.yaml` y `pubspec.lock` con versiones exactas.
- [ ] Código final de apertura y migraciones SQLite.
- [ ] Inventario de clases, métodos, imports y consultas SQL.
- [ ] Esquema SQLite real verificado sobre una copia.
- [ ] Compatibilidad de equipos sin cliente.
- [ ] Vinculación FRP a equipo y, cuando corresponde, a orden.
- [ ] Integridad financiera: señas, corrección de saldo, marcar/desmarcar cobrado.
- [ ] Fotografías y PDFs; rutas, limpieza y conservación.
- [ ] Pruebas offline, reinicio y actualización desde una versión anterior.
- [ ] Exportación y restauración de respaldos antes de usar datos reales importantes.

## Evidencia reciente y pruebas abiertas

- [x] Creación e importación de una copia local, informadas por el usuario en el emulador.
- [ ] Restaurar en otra instalación y repetir la importación. Validar fotos, coincidencias, cancelación, registros ajenos a la copia y relaciones.
- [ ] Confirmar extensión y contenido del archivo de planillas, las cuatro pestañas y sus cruces. Revisar fechas, presupuesto, cobros, saldo y el campo Trabajo realizado si v23 quedó aplicado.
- [ ] Revisar Agenda: avisado permanece, se puede volver a contactar y retirado deja de aparecer.
- [ ] Ejecutar la baja de un proveedor con repuestos asociados. Cancelar conserva la ficha. Confirmar quita el proveedor y conserva cantidades. El comportamiento de SQLite ya se ensayó por separado.
- [ ] Validar el rediseño del listado de Presupuestos, la apertura desde una orden, el logo hacia Inicio y la campanita hacia Consultas.

## Criterios de escalabilidad

No marcar un módulo como “modular y escalable” hasta comprobar que su responsabilidad, dependencias, persistencia, contratos y pruebas están documentados. Esta lista es una auditoría de cierre, no una propuesta de modificación inmediata de la APK.
