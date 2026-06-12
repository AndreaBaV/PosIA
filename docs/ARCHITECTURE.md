# Arquitectura POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Vision

POSIA es un POS modular comercial para Mexico con:

- Multi-tienda (cliente tipico: N tiendas x 2 cajas)
- Offline-first con SQLite local en cada caja
- Sync en dos niveles: LAN (2 cajas por tienda) + Hub central (inventario entre sucursales)
- UI accesible (iconos, numeros grandes, voz en fases posteriores)
- Hardware desacoplado por drivers

---

## 2. Diagrama de capas

```
┌──────────────────────────────────────────────────────────────┐
│ apps/posia_pos          UI Caja + Admin basico               │
├──────────────────────────────────────────────────────────────┤
│ posia_ui                Widgets reutilizables (iconos)       │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│ posia_   │ posia_   │ posia_   │ posia_   │ posia_          │
│ pricing  │ inventory│ sync     │ licensing│ hardware        │
├──────────┴──────────┴──────────┴──────────┴─────────────────┤
│ posia_database          SQLite / Drift                       │
├──────────────────────────────────────────────────────────────┤
│ posia_core              Entidades, enums, contratos          │
└──────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Hub Sync (VPS)    │
                    │ Event Log API     │
                    └───────────────────┘
```

---

## 3. Principios de diseno

| Principio | Implementacion |
|-----------|----------------|
| Modularidad | Modulos activables via licencia (`posia_licensing`) |
| Bajo acoplamiento | Contratos abstractos en `posia_core` e interfaces en cada paquete |
| Offline-first | SQLite es fuente de verdad en caja; sync es eventual |
| Event sourcing (sync) | Ventas append-only; catálogo last-write-wins |
| Accesibilidad | Modo iconos por defecto en caja |

---

## 4. Flujo de venta

```
Usuario selecciona producto (icono / codigo)
        │
        ▼
MotorPrecio resuelve precio (mayoreo / cliente)
        │
        ▼
Carrito en memoria
        │
        ▼
Cobro → Venta persistida en SQLite
        │
        ├── Evento SaleCompleted → cola sync
        ├── Ajuste stock local
        └── Ticket (hardware o PDF)
```

---

## 5. Multi-tienda

Perfil tipico de cliente:

- 3-5 tiendas
- 2 cajas por tienda
- 1 administrador (movil + PC)

Sync:

1. **LAN:** Caja 1 ↔ Caja 2 en misma tienda (mDNS / IP fija)
2. **Hub:** Todas las tiendas del tenant → VPS multi-tenant

Sin internet en una tienda: las 2 cajas operan; stock remoto muestra ultima snapshot con indicador de frescura.

---

## 6. Stack tecnologico

| Capa | Tecnologia |
|------|------------|
| UI | Flutter 3.41+ |
| Estado | Riverpod |
| DB local | Drift + sqlite3 |
| Sync hub | API REST + Postgres (servidor) |
| Licencia | Archivo JSON firmado (RSA) offline |

---

## 7. Verticales (modulos)

| Modulo | Rubro |
|--------|-------|
| `grocery` | Abarrotes — mayoreo por cantidad |
| `pharmacy` | Farmacia — lotes, caducidad |
| `butcher` | Carniceria — peso, cortes |

Implementacion incremental en `packages/` como extensiones del nucleo.

---

## 8. Seguridad

- Roles por permisos visuales (cajero, supervisor, admin)
- Licencia validada localmente
- Eventos de sync firmados con `tenant_id` + `device_id`
- TLS obligatorio en comunicacion con hub

---

## 9. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Documento inicial |
