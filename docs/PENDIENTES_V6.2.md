# POSIA v6.2 — Competir con Sicar / Eleventa

**Estado:** Implementada — 2026-06-12  
**Prerequisito:** v6.1 completada

---

## Objetivo

Cerrar brechas operativas frente a POS mexicanos de referencia: **multipago**, **descuentos**, **favoritos en caja**, **listas de precios**, **reportes avanzados** y **costo unitario**.

---

## Entregado

| Feature | Descripcion |
|---------|-------------|
| **Multipago** | Dialogo cobro: efectivo (con cambio), tarjeta, transferencia, mixto, credito/fiado |
| **Descuentos** | Por linea (tocar carrito) y por ticket (dialogo cobro) |
| **Favoritos caja** | Estrella en Admin → Productos; barra rapida en caja |
| **Listas precios** | Admin → Listas precios; selector en ficha cliente |
| **Reportes** | Top productos + ventas por metodo de pago (7 dias) |
| **Costo unitario** | Campo en alta producto (schema v6) |
| **Schema v6** | Migracion SQLite: descuentos, montos mixto, favoritos, price_lists |

---

## Pendiente v7 (vs Sicar/Eleventa completo)

| Feature | Prioridad |
|---------|-----------|
| Cuentas por cobrar (saldo, abonos, estado de cuenta) | P0 |
| Ordenes de compra a proveedor | P0 |
| Auth multi-usuario (cajero / supervisor / dueno) | P1 |
| CFDI / timbrado Mexico | P1 |
| Reporte utilidad (costo vs venta) | P1 |
| Teclas rapidas configurables (layout) | P2 |

---

## Referencias

- [ESTADO_PROYECTO.md](ESTADO_PROYECTO.md)
- [CHANGELOG.md](CHANGELOG.md)
