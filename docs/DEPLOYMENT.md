# Despliegue y licenciamiento

## Modelo comercial

- **Licencia perpetua** (pago único); módulos adicionales por compra única
- Primer año de soporte y sync hub incluido
- Renovación anual opcional: actualizaciones + sync remoto + soporte

Sin renovación las cajas siguen vendiendo offline; la sync en nube deja de actualizarse.

---

## Builds por plataforma

| Dispositivo | Plataforma | Comando |
|-------------|------------|---------|
| PC caja | Windows | `flutter build windows --release` |
| Móvil / tablet | Android (Play Store) | `flutter build appbundle --release` |
| Móvil / tablet | iOS (App Store) | `flutter build ipa --release` (requiere Mac) |
| Navegador | Web | `flutter build web --release` |

Scripts: `scripts/build_movil_release.ps1`, `scripts/generar_keystore_android.ps1`  
Publicación móvil: [PUBLICACION_MOVIL.md](PUBLICACION_MOVIL.md)

### Artefactos

| Plataforma | Ruta |
|------------|------|
| Windows | `apps/posia_pos/build/windows/x64/runner/Release/` |
| Android AAB | `apps/posia_pos/build/app/outputs/bundle/release/app-release.aab` |
| Android APK | `apps/posia_pos/build/app/outputs/flutter-apk/app-release.apk` |
| Web | `apps/posia_pos/build/web/` |

SQLite local se crea y migra en el primer arranque. En web usa IndexedDB vía WASM (`sqflite_sw.js`, `sqlite3.wasm`).

---

## Instalación en caja

1. Instalar binario (carpeta Windows, AAB/APK o URL web)
2. **Asistente de instalación técnica** (opcional): URL del hub y API key
3. Importar `posia.lic` si aplica
4. **Iniciar sesión** con usuario y contraseña del negocio (el tenant se resuelve automáticamente)
5. Administrador: elegir tienda. Supervisor/empleado: tienda asignada
6. Configurar impresora (opcional)

La sync es automática cada 60 s. Reconfigurar hub: **Configuración técnica** en login (PIN del dispositivo).

---

## Hub de sincronización

Código: `server/sync_api` (Dart + shelf). La caja solo habla HTTP con el hub; no conecta directo a Postgres.

### Opción A — VPS con Docker (producción)

```bash
cd server/sync_api
docker compose up -d --build
```

- Postgres + API en un servidor (~USD 5–6/mes en Hetzner/Vultr)
- Tabla `sync_events` se crea al arrancar
- Multi-tenant por `tenantId`

### Opción B — Self-host sin Docker

```bash
cd server/sync_api
dart run bin/server.dart
```

Persiste en JSONL (`EVENTS_FILE`). Adecuado para un negocio o desarrollo.

### Opción C — Neon + Render (nube gratuita, se duerme)

| Componente | Servicio | Rol |
|------------|----------|-----|
| Postgres | [Neon](https://neon.tech) | Almacena `sync_events` |
| API | [Render](https://render.com) | `POST/GET /v1/events` |
| Caja | Local | SQLite + cola sync |

> El plan free de Render duerme tras inactividad; la primera sync puede tardar ~30 s.

### Opción D — Neon + Oracle Always Free (recomendado $0)

| Componente | Servicio | Rol |
|------------|----------|-----|
| Postgres | Neon | Base de datos |
| API | VM ARM Oracle | Hub 24/7 + HTTPS (Caddy) |
| Caja | Local | SQLite + cola sync |

Guía paso a paso: **[ORACLE_ALWAYS_FREE.md](ORACLE_ALWAYS_FREE.md)**

```bash
cd server/sync_api
cp deploy/oracle/.env.example .env   # editar DATABASE_URL, API_KEY, dominio
docker compose -f docker-compose.prod.yml up -d --build
```

Verificar: `curl https://TU-DOMINIO/v1/health`

### Opción C (detalle) — Neon + Render

**Neon:** crear proyecto → copiar connection string con `?sslmode=require`. No crear tablas manualmente.

**Render:** Web Service, root `server/sync_api`, runtime Docker.

| Variable | Valor |
|----------|-------|
| `DATABASE_URL` | Connection string Neon |
| `API_KEY` | Clave secreta (`x-api-key`) |
| `PORT` | `8080` |

Verificar: `curl https://TU-URL.onrender.com/v1/health`

> El plan free de Render duerme tras inactividad; la primera sync puede tardar ~30 s.

**En cada caja:** un solo APK/AAB sirve para **todos los tenants**. El build puede incluir URL del hub y API key (`POSIA_HUB_URL`, `POSIA_HUB_API_KEY`). Al abrir la app, el dispositivo se auto-registra con un `caja_id` único. El **tenant se resuelve al iniciar sesión** (usuario + contraseña contra el hub).

**Build de producción (una vez, para todos los negocios):**

```powershell
$env:POSIA_HUB_URL="https://tu-api.onrender.com"
$env:POSIA_HUB_API_KEY="tu-clave-secreta"
.\scripts\build_movil_release.ps1
```

Cada tenant tiene su propia base SQLite local (`posia_t_{tenantId}.db`) y su espacio en Postgres, aislados por `tenantId`.

**Desarrollo local con Neon:**

```powershell
cd server\sync_api
$env:DATABASE_URL="postgresql://...@ep-xxx.neon.tech/neondb?sslmode=require"
$env:API_KEY="dev-secret"
dart run bin/server.dart
```

Caja: URL `http://localhost:8080` y misma API key.

### Variables de entorno (hub)

| Variable | Descripción |
|----------|-------------|
| `DATABASE_URL` | Postgres; vacía = modo archivo JSONL |
| `EVENTS_FILE` | Archivo JSONL sin Postgres |
| `API_KEY` | Clave compartida (opcional) |
| `PORT` | Puerto API (default 8080) |

### Eventos sincronizados

`saleCompleted`, `saleVoided`, `salePartialReturn`, `productUpserted`, `variantUpserted`, `categoryUpserted`, `customerUpserted`, `stockAdjusted`, `transferRequested`, `transferCompleted`, `storeUpserted`, `userUpserted`

### Solución de problemas (sync)

| Problema | Solución |
|----------|----------|
| Hub no configurado | Admin → Sincronizar, capturar URL |
| 401 Unauthorized | Igualar API key en servidor y caja |
| SSL error | `?sslmode=require` en URL Neon |
| Timeout primera sync | Render dormido — esperar o plan pago |
| Eventos no llegan | Mismo `tenant_id` en licencia/config |

Sin URL de hub la caja opera 100 % offline.

---

## Referencias

- API del hub: `server/sync_api/README.md`
- Operación diaria: [MANUAL_USUARIO.md](MANUAL_USUARIO.md) §10
- Protocolo sync: [SYNC.md](SYNC.md)
