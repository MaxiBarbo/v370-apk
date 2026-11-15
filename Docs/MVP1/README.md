# v370 — Documentación técnica del MVP 1

**Estado:** documentación preliminar basada en evidencia histórica y revisión parcial. No equivale a una auditoría del proyecto Flutter vigente.

**Revisión del 14/11/2026.** Se contrastaron la copia compartida de la APK y los paquetes de respaldo, planillas, trabajo realizado y bajas de proveedores. La validación del proyecto instalado sigue abierta.

[Datos, respaldos y verificación en Google Docs](https://docs.google.com/document/d/1t4I2aMLXi5aS_gOuq4nl300eNseGLkhIBG0MC-nB-eE/edit) · [Resumen del MVP 1 en Notion](https://app.notion.com/p/40f9f5dbfb9381b0a186d7ae4b8b0874)

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
