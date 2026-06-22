# Entrega rápida al cliente (< 1 hora)

Oracle suele estar sin capacidad. **Usa Render** (10 minutos, $0).

## A. Desplegar hub en Render (10 min)

1. Sube el repo a GitHub si aún no está.
2. [render.com](https://render.com) → **New +** → **Blueprint**
3. Conecta el repo → Render detecta `server/sync_api/render.yaml`
4. Al crear, pega estas variables:

| Variable | Valor |
|----------|-------|
| `DATABASE_URL` | Tu connection string Neon (desde `platform/.env`) |
| `API_KEY` | `posia-f34d5b870e192a6c` (o la de tu `.env`) |

5. Espera **Deploy live** (~5–8 min).
6. Copia la URL: `https://posia-sync-api.onrender.com` (o la que asigne Render).
7. Prueba:

```bash
curl https://TU-URL.onrender.com/v1/health
```

8. Actualiza `platform/.env`:

```env
POSIA_HUB_URL=https://TU-URL.onrender.com
POSIA_HUB_API_KEY=posia-f34d5b870e192a6c
```

> La primera petición tras inactividad puede tardar ~30 s (plan free). Para demo, abre `/v1/health` en el navegador 1 minuto antes.

---

## B. Usuarios en Neon (2 min)

En tu PC:

```powershell
cd platform\tenant_registry
dart pub get
dart run bin/posia_tenants.dart init
dart run bin/posia_tenants.dart seed-review --provision
```

**Credenciales para el cliente / revisores:**

| Rol | Código | PIN |
|-----|--------|-----|
| Administrador | `9001` | `1234` |
| Empleado | `9002` | `1234` |

---

## C. App en la caja (5 min)

### Opción 1 — Build con hub embebido

```powershell
$env:POSIA_HUB_URL="https://TU-URL.onrender.com"
$env:POSIA_HUB_API_KEY="posia-f34d5b870e192a6c"
cd apps\posia_pos
flutter build apk --release --dart-define=POSIA_HUB_URL=$env:POSIA_HUB_URL --dart-define=POSIA_HUB_API_KEY=$env:POSIA_HUB_API_KEY
```

APK: `apps\posia_pos\build\app\outputs\flutter-apk\app-release.apk`

### Opción 2 — Asistente técnico en la caja

1. Instalar APK/debug
2. Asistente: URL hub + API key + PIN técnico (ej. `5678`)
3. Login: `9001` / `1234`

---

## D. Checklist entrega

- [ ] `curl .../v1/health` → OK
- [ ] `seed-review --provision` ejecutado
- [ ] Cliente tiene APK o app instalada
- [ ] Login `9001` / `1234` funciona
- [ ] Admin elige tienda "Demo Review"

---

## E. Plan B — Hub local + túnel (si Render falla)

```powershell
cd server\sync_api
dart pub get
dart run bin/server.dart
```

En otra terminal (con [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)):

```powershell
cloudflared tunnel --url http://localhost:8080
```

Usa la URL `https://xxx.trycloudflare.com` como `POSIA_HUB_URL`.

---

## Después de la entrega

Migrar a Oracle Always Free cuando haya capacidad: [ORACLE_ALWAYS_FREE.md](ORACLE_ALWAYS_FREE.md)
