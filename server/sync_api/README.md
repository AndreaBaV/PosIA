# POSIA Sync API

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-11 16:20:00 (UTC-6)

API REST minimalista para hub de sincronizacion multi-tenant (event log append-only).

## Endpoints

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| POST | `/v1/events` | Recibe lote de eventos del dispositivo |
| GET | `/v1/events?tenantId=&since=&excludeDevice=` | Pull incremental por cursor seq |
| GET | `/v1/health` | Health check |

Ver [docs/SYNC.md](../../docs/SYNC.md) para contrato completo.

## Variables de entorno

| Variable | Descripcion | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Conexion Postgres; si falta usa archivo local | (vacio) |
| `EVENTS_FILE` | Ruta del archivo JSONL en modo sin Postgres | `posia_sync_events.jsonl` |
| `API_KEY` | Clave compartida (cabecera `x-api-key`); vacia desactiva auth | (vacio) |
| `PORT` | Puerto HTTP | `8080` |

## Opcion A — Desarrollo / self-host simple (sin Docker)

Solo requiere Dart SDK. Persiste eventos en archivo JSONL:

```bash
cd server/sync_api
dart pub get
dart run bin/server.dart
```

## Opcion B — Produccion con Docker (Postgres)

Levanta Postgres + API compilada AOT:

```bash
cd server/sync_api
docker compose up -d --build
```

La tabla `sync_events` y el **espejo operativo** (`products`, `sales`, `customers`, etc.) se crean al arrancar.

Al recibir eventos (POST `/v1/events`), el hub los persiste en `sync_events` y los **proyecta** a tablas espejo via `ProyectorEventosPostgres` (mismo modelo que SQLite local).

Scripts utiles con Neon:

```bash
dart run bin/probar_neon.dart          # verifica conexion y esquema
dart run bin/probar_neon.dart --smoke  # inserta producto de prueba proyectado
dart run bin/consultar_neon.dart       # conteos por tabla
dart run bin/ver_eventos_neon.dart     # detalle de sync_events
dart run bin/reproyectar_neon.dart     # backfill eventos → tablas espejo
```

## Pruebas

```bash
dart test
```
