# v370 — Documentación técnica del MVP 1

**Estado:** documentación preliminar basada en evidencia histórica y revisión parcial. No equivale a una auditoría del proyecto Flutter vigente.

## Por dónde empezar

1. [`arquitectura.md`](arquitectura.md): qué está construido y qué se propone.
2. [`modulos.md`](modulos.md): responsabilidades y dependencias.
3. [`base_de_datos.md`](base_de_datos.md): SQLite, migraciones e integridad.
4. [`verificacion.md`](verificacion.md): qué falta confirmar antes de cerrar el MVP.
5. [`diagramas/arquitectura.mmd`](diagramas/arquitectura.mmd): diagrama Mermaid editable.

## Convención documental

- **Confirmado en evidencia histórica:** presente en un fragmento de código o script conservado; no confirma ejecución actual.
- **Verificado en código vigente:** exige revisar los archivos actuales de la PC.
- **Probado:** requiere prueba ejecutada con resultado.
- **Propuesta:** diseño futuro, aún no implementado.

**Regla:** cuando exista una versión verificada del código, actualizar estos documentos junto al mismo cambio. Notion se usa como índice, resumen y registro de decisiones; el detalle vive aquí.

**Integración con Raspberry Pi 5:** fuera del alcance del MVP 1.
