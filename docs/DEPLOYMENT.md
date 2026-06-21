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
2. Importar `posia.lic`
3. Seleccionar tienda e iniciar sesión
4. Admin → Sincronización: URL del hub y API key (opcional)
5. **Sincronizar ahora** para carga inicial
6. Configurar impresora (opcional)

Sync automática: cada 60 s y al recuperar red.

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

### Opción C — Neon + Render (nube gratuita)

| Componente | Servicio | Rol |
|------------|----------|-----|
| Postgres | [Neon](https://neon.tech) | Almacena `sync_events` |
| API | [Render](https://render.com) | `POST/GET /v1/events` |
| Caja | Local | SQLite + cola sync |

**Neon:** crear proyecto → copiar connection string con `?sslmode=require`. No crear tablas manualmente.

**Render:** Web Service, root `server/sync_api`, runtime Docker.

| Variable | Valor |
|----------|-------|
| `DATABASE_URL` | Connection string Neon |
| `API_KEY` | Clave secreta (`x-api-key`) |
| `PORT` | `8080` |

Verificar: `curl https://TU-URL.onrender.com/v1/health`

> El plan free de Render duerme tras inactividad; la primera sync puede tardar ~30 s.

**En cada caja:** Admin → Sincronizar → URL `https://TU-URL.onrender.com`, misma API key → Guardar → Sincronizar ahora.

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

`saleCompleted`, `saleVoided`, `salePartialReturn`, `productUpserted`, `variantUpserted`, `categoryUpserted`, `customerUpserted`, `stockAdjusted`, `transferRequested`, `transferCompleted`

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
