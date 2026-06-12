# Modulo vertical farmacia POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 20:15:00 (UTC-6)

---

## Paquete

`packages/posia_module_pharmacy`

## Funcionalidades

- Control de lotes con numero y caducidad
- Seleccion FEFO en caja (First Expire, First Out)
- Alertas visuales: normal, advertencia (30 dias), critico (7 dias o vencido)
- Descuento de stock por lote al cobrar
- Admin: registro y consulta de lotes

## Tabla SQLite

`pharmacy_lots` (esquema v2)

## Productos demo

| Producto | Lotes demo |
|----------|------------|
| Paracetamol 500mg | LOT-2026-A (vigente), LOT-2025-B (critico) |
| Ibuprofeno 400mg | LOT-IBU-01 |

## Licencia

Modulo `ModuloLicencia.pharmacy`
