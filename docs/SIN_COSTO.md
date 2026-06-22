# Varias cajas sin pagar ($0)

Si necesitas **varias cajas sincronizadas**, hace falta un **hub** compartido. No hay forma segura de saltárselo (la app no puede ir directo a Neon).

La buena noticia: **puede costar $0** con Render Free + Neon Free.

```
Caja 1 ──┐
Caja 2 ──┼──► Hub Render (free) ──► Neon Postgres (free)
Caja 3 ──┘
```

Cada caja sigue trabajando en SQLite local; el hub solo sincroniza eventos y valida login.

---

## Paso 1 — Hub en Render (plan Free, $0)

### Opción A — Blueprint (recomendado)

1. **Sube a GitHub** los archivos nuevos: `render.yaml` (raíz) y `server/sync_api/Dockerfile.render`
2. [render.com](https://render.com) → **New +** → **Blueprint**
3. Repo `AndreaBaV/PosIA` → Render lee `render.yaml` de la **raíz**
4. Pega variables `DATABASE_URL` y `API_KEY`
5. Deploy

### Opción B — Web Service manual (si ya creaste el servicio)

En **Settings** del servicio:

| Campo | Valor |
|-------|-------|
| **Root Directory** | *(vacío — raíz del repo)* |
| **Dockerfile Path** | `Dockerfile` |
| **Docker Context** | `.` |

> Render busca `Dockerfile` en la **raíz** del repo por defecto. El archivo ya está en la raíz del monorepo.

### Variables de entorno

| Variable | Valor |
|----------|-------|
| `DATABASE_URL` | Connection string de Neon (`platform/.env`) |
| `API_KEY` | Una clave secreta larga (la misma en todas las cajas) |

### Verificar

```bash
curl https://TU-URL.onrender.com/v1/health
```

Debe responder `{"status":"ok"}`.

---

## Paso 2 — Evitar que Render se duerma ($0)

Render Free se apaga tras ~15 min sin tráfico. Tres capas (usa al menos una):

### A. UptimeRobot (recomendado, gratis)

1. [uptimerobot.com](https://uptimerobot.com) → monitor HTTP cada **5 min**
2. URL: `https://TU-URL.onrender.com/v1/health`

### B. Las cajas despiertan el hub solas (ya en la app)

Con la app abierta, cada caja hace un ping silencioso cada **10 min** al hub (timeout largo para el arranque en frío). Si hay cajas encendidas en horario de tienda, el hub suele permanecer activo.

### C. Sync en segundo plano (ya en la app)

- **Cada 60 s** la app sincroniza en silencio (no bloquea la venta).
- Si el hub no responde, **la caja sigue vendiendo** con su SQLite local.
- Cuando el hub vuelve, aplica inventario y ventas de otras tiendas automáticamente.
- El cajero **no ve error** en pantalla de venta; solo Admin → Estado de la nube muestra el detalle.

No hace falta bajar a “cada hora”: ya es más frecuente, pero **sin molestar al usuario**.

---

## Paso 3 — Usuarios en Neon

En tu PC (una sola vez por negocio):

```powershell
cd platform
dart run tenant_registry/bin/posia_tenants.dart init
dart run tenant_registry/bin/posia_tenants.dart crear --nombre "Negocio del cliente"
dart run tenant_registry/bin/posia_tenants.dart add-tienda --tenant <UUID> --nombre "Sucursal 1"
dart run tenant_registry/bin/posia_tenants.dart add-usuario --tenant <UUID> --nombre "Admin" --codigo 1001 --pin 1234 --rol administrador
dart run tenant_registry/bin/posia_tenants.dart add-usuario --tenant <UUID> --nombre "Cajero" --codigo 3001 --pin 1234 --rol empleado --tienda <TIENDA_UUID>
dart run tenant_registry/bin/posia_tenants.dart provision --tenant <UUID>
```

O para demo rápida:

```powershell
cd platform
dart run tenant_registry/bin/posia_tenants.dart seed-review --provision
```

Credenciales demo: `9001`/`1234` (admin), `9002`/`1234` (empleado).

---

## Paso 4 — Mismo APK en todas las cajas

Un solo build para todas las cajas y todos los negocios:

```powershell
$env:POSIA_HUB_URL="https://TU-URL.onrender.com"
$env:POSIA_HUB_API_KEY="tu-api-key-secreta"

cd apps\posia_pos
flutter build apk --release `
  --dart-define=POSIA_HUB_URL=$env:POSIA_HUB_URL `
  --dart-define=POSIA_HUB_API_KEY=$env:POSIA_HUB_API_KEY
```

Instala el mismo APK en cada dispositivo.

---

## Paso 5 — Instalación en cada caja

1. Asistente técnico: **activar** “Conectar al hub en la nube”
   - URL: `https://TU-URL.onrender.com`
   - API Key: la misma de Render
   - PIN técnico del dispositivo (distinto por caja si quieres)
2. Login con usuario provisionado (ej. `1001` / `1234`)
3. Admin elige tienda; empleado entra directo a su tienda

Cada caja genera su propio `caja_id` automáticamente. La sync corre cada 60 s.

---

## Qué pasa si el hub duerme (sin UptimeRobot)

- La caja **sigue vendiendo** (offline)
- La sync se encola y se envía cuando el hub responde
- El primer login tras dormir puede tardar ~30 s

Para operación seria con varias cajas: **usa UptimeRobot** o migra después a Oracle/Hetzner.

---

## Alternativas $0 al hub

| Opción | Multi-caja | Notas |
|--------|------------|-------|
| **Render Free + UptimeRobot** | Sí | Recomendado hoy |
| **Oracle Always Free** | Sí | Cuando haya capacidad ARM |
| **PC tuyo + Cloudflare Tunnel** | Sí | Gratis si el PC está 24/7 |
| **Modo solo offline** | **No** | Una caja aislada, sin sync |

---

## Checklist entrega multi-caja

- [ ] `curl .../v1/health` → OK
- [ ] UptimeRobot configurado (opcional pero recomendado)
- [ ] `provision` ejecutado en Neon
- [ ] Mismo APK en todas las cajas (hub URL + API key en el build)
- [ ] Cada caja completó instalación técnica
- [ ] Login funciona en caja 1 y caja 2
- [ ] Venta en caja 1 aparece en caja 2 tras sync (~1 min)

---

## Cuando tengas presupuesto

| Mejora | Costo aprox. |
|--------|----------------|
| Render **Starter** (sin dormir) | ~$7/mes |
| Hetzner VPS + Docker | ~€5/mes |
| Oracle Always Free | $0 (si hay capacidad) |

Ver también: [ENTREGA_RAPIDA.md](ENTREGA_RAPIDA.md), [ORACLE_ALWAYS_FREE.md](ORACLE_ALWAYS_FREE.md)
