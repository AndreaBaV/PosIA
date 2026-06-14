# Sincronizacion POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Modelo

POSIA usa **event log append-only** para sincronizacion entre cajas y tiendas.

Cada dispositivo mantiene:

- SQLite local (datos operativos)
- Tabla `sync_event_queue` (eventos pendientes de envio)
- Cursor `last_synced_event_id` (ultimo evento recibido del hub)

---

## 2. Dos niveles de sync

### Nivel 1 — LAN (por tienda)

- Alcance: 2 cajas en la misma sucursal
- Protocolo: HTTP local o multicast (implementacion en `LanSyncClient`)
- Proposito: Resiliencia cuando cae internet
- Descubrimiento: mDNS `posia-sync._tcp.local`

### Nivel 2 — Hub central

- Alcance: Todas las tiendas del tenant
- Hosting recomendado: VPS multi-tenant (~USD 5/mes)
- Alternativa: Cloudflare Workers + D1
- Escape hatch: Docker self-hosted (`server/sync_api`)

---

## 3. Tipos de evento

| Tipo | Descripcion | Conflicto |
|------|-------------|-----------|
| `SaleCompleted` | Venta cerrada | Ninguno (append) |
| `ProductUpserted` | Alta/edicion producto | Last-write-wins |
| `StockAdjusted` | Ajuste manual | Suma eventos |
| `TransferRequested` | Solicitud entre tiendas | Estado maquina |
| `TransferCompleted` | Recepcion confirmada | Append |
| `CustomerUpserted` | Cliente / precio preferencial | Last-write-wins |

---

## 4. API Hub (REST)

### POST /v1/events

Envia lote de eventos del dispositivo.

```json
{
  "tenantId": "uuid",
  "deviceId": "uuid",
  "storeId": "uuid",
  "events": [
    {
      "id": "uuid",
      "type": "SaleCompleted",
      "payload": {},
      "createdAt": "2026-06-07T18:30:00-06:00"
    }
  ]
}
```

### GET /v1/events?since={eventId}&tenantId={id}

Recibe eventos nuevos del hub para el tenant.

---

## 5. Comportamiento offline

| Escenario | Comportamiento |
|-----------|----------------|
| Sin internet en tienda | LAN activo; cola hub pendiente |
| Sin internet global | Cada tienda isla; ventas locales OK |
| Reconexion | Push cola + pull incremental |
| Conflicto catalogo | Banner admin; no bloquea caja |

---

## 6. Inventario multi-tienda

Stock remoto en caja = ultimo snapshot + eventos aplicados localmente.

UI muestra:

- Cantidad
- Timestamp de ultima actualizacion
- Icono de advertencia si > 15 min sin sync

---

## 7. Implementacion en codigo

| Componente | Paquete | Archivo |
|------------|---------|---------|
| Entidad evento | posia_sync | `sync_event.dart` |
| Cola local | posia_sync | `local_event_queue.dart` |
| Cliente hub | posia_sync | `hub_sync_client.dart` |
| Cliente LAN | posia_sync | `lan_sync_client.dart` |
| Orquestador | posia_sync | `sync_orchestrator.dart` |

---

## 9. Espejo Postgres (Neon / on-premise)

Arquitectura **offline-first**: la caja opera en SQLite local y sincroniza eventos con el hub. El hub proyecta esos eventos a tablas espejo en Postgres (`products`, `sales`, `stock_levels`, etc.) para consulta centralizada y backup.

| Capa | Rol |
|------|-----|
| SQLite (caja) | Fuente operativa offline |
| Hub `sync_api` | Log `sync_events` + proyector |
| Postgres (Neon) | Réplica espejo del POS |

La caja **no** conecta directo a Neon. Tras cambiar de equipo: configurar hub en Admin → Sincronizar → pull reconstruye SQLite.

---

## 10. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-12 | Proyector hub → Postgres espejo (Neon) |
| 2026-06-07 18:30 | Documento inicial |
