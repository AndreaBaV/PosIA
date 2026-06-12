# Despliegue y licenciamiento POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-11 16:20:00 (UTC-6)

---

## 1. Modelo comercial

- **Licencia perpetua** (pago unico)
- Modulos adicionales: compra unica por modulo
- **Primer ano de soporte y sync hub** incluido
- Renovacion anual opcional: actualizaciones + sync remoto + soporte

Sin renovacion: las cajas siguen vendiendo offline; sync entre sucursales deja de actualizarse en nube.

---

## 2. Despliegue por dispositivo

| Dispositivo | Plataforma | Rol | Comando de build |
|-------------|------------|-----|------------------|
| PC caja | Windows | Venta principal | `flutter build windows --release` |
| Tablet / movil | Android | Caja alterna / inventario | `flutter build apk --release` |
| Navegador | Web | Caja / consulta multiplataforma | `flutter build web --release` |
| PC admin | Windows / Web | Reportes, configuracion | (mismos builds) |

Las tres plataformas comparten el mismo codigo y la misma base SQLite local
(archivo en escritorio/movil; IndexedDB via WASM en web). La base local se
**crea y migra sola** en el primer arranque; no requiere pasos manuales.

### Artefactos generados

- Windows: `apps/posia_pos/build/windows/x64/runner/Release/` (carpeta completa distribuible)
- Android: `apps/posia_pos/build/app/outputs/flutter-apk/app-release.apk`
- Web: `apps/posia_pos/build/web/` (servir como sitio estatico; requiere `sqflite_sw.js` y `sqlite3.wasm` incluidos)

---

## 3. Hub de sincronizacion (nube)

El hub vive en `server/sync_api` (Dart + shelf). Dos modos de almacenamiento:

### Opcion recomendada: VPS multi-tenant con Docker

- Hetzner / Vultr ~ USD 5-6/mes
- `docker compose up -d --build` levanta Postgres + API
- La base Postgres y la tabla `sync_events` se crean automaticamente
- Un servidor sirve a multiples clientes (separados por `tenantId`)

### Self-host simple (sin Docker)

- Solo requiere Dart SDK: `dart run bin/server.dart`
- Persiste en archivo JSONL local (`EVENTS_FILE`)
- Adecuado para un solo negocio o pruebas

---

## 4. Instalacion caja

1. Instalar `posia_pos` (carpeta Windows / APK / URL web)
2. Importar archivo `posia.lic`
3. En Admin > Sincronizacion, capturar URL del hub (ej. `http://servidor:8080`)
4. Pulsar **Sincronizar ahora** para la carga inicial
5. Configurar hardware (opcional)

La sincronizacion despues es **automatica**: al recuperar conexion y cada 60
segundos la caja envia su cola pendiente y descarga eventos de otras cajas.

---

## 5. Variables de entorno (hub)

| Variable | Descripcion |
|----------|-------------|
| `DATABASE_URL` | Postgres connection; vacia = modo archivo |
| `EVENTS_FILE` | Archivo JSONL en modo sin Postgres |
| `API_KEY` | Clave compartida `x-api-key` (opcional) |
| `PORT` | Puerto API (default 8080) |

---

## 6. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Documento inicial |
| 2026-06-11 16:20 | Hub implementado, web habilitada, sync automatica |
