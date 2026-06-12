# Despliegue en nube gratuita — Neon + Render

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha:** 2026-06-11

Guia para operar POSIA **local + nube** sin VPS propio, usando servicios gratuitos de terceros.

---

## Arquitectura

| Componente | Servicio gratuito | Rol |
|------------|-------------------|-----|
| Base de datos eventos | [Neon](https://neon.tech) PostgreSQL | Almacena log `sync_events` |
| API sync | [Render](https://render.com) Web Service | Expone `POST/GET /v1/events` |
| Caja POS | Windows local | SQLite + cola sync |

La caja **no** conecta directo a Neon. Solo habla HTTP con la API en Render, que usa `DATABASE_URL` de Neon.

---

## Paso 1 — Crear base en Neon

1. Cuenta en [neon.tech](https://neon.tech) (plan free).
2. Crear proyecto → copiar **connection string** con SSL:
   ```
   postgresql://usuario:clave@ep-xxx.neon.tech/neondb?sslmode=require
   ```
3. No crear tablas manualmente; la API las crea al arrancar.

---

## Paso 2 — Desplegar API en Render

1. Subir repo a GitHub (o conectar repositorio existente).
2. En Render: **New → Web Service**.
3. Root directory: `server/sync_api`
4. Runtime: **Docker** (usa `Dockerfile` del proyecto).
5. Variables de entorno:

| Variable | Valor |
|----------|-------|
| `DATABASE_URL` | Connection string de Neon (con `sslmode=require`) |
| `API_KEY` | Clave secreta larga (ej. generada por Render) |
| `PORT` | `8080` |

6. Deploy. URL resultante: `https://posia-sync-api.onrender.com`

7. Verificar salud:
   ```
   curl https://TU-URL.onrender.com/v1/health
   ```

> El plan free de Render **duerme** tras inactividad. La primera sync puede tardar ~30 s en despertar.

Alternativa: usar `render.yaml` en `server/sync_api` con Blueprint.

---

## Paso 3 — Configurar cada caja POS

1. Admin → **Sincronizar**
2. **URL del hub:** `https://TU-URL.onrender.com` (sin barra final)
3. **API Key:** la misma que `API_KEY` en Render
4. Guardar → **Sincronizar ahora**
5. Repetir en segunda caja (mismo tenant demo por defecto)

La sync automatica corre cada 60 segundos y al recuperar red.

---

## Eventos sincronizados (v4)

| Evento | Que replica |
|--------|-------------|
| `saleCompleted` | Ventas y descuento stock |
| `saleVoided` | Anulaciones |
| `salePartialReturn` | Devoluciones parciales |
| `productUpserted` | Catalogo |
| `variantUpserted` | Presentaciones |
| `categoryUpserted` | Categorias |
| `customerUpserted` | Clientes |
| `stockAdjusted` | Movimientos de inventario |
| `transferRequested` / `transferCompleted` | Traspasos |

---

## Desarrollo local con Neon

```powershell
cd server\sync_api
$env:DATABASE_URL="postgresql://...@ep-xxx.neon.tech/neondb?sslmode=require"
$env:API_KEY="dev-secret"
dart run bin/server.dart
```

En la caja: URL `http://localhost:8080` y misma API key.

---

## Modo solo local (sin nube)

Sin URL de hub configurada, la caja opera 100 % offline. No requiere Neon ni Render.

---

## Solucion de problemas

| Problema | Causa | Solucion |
|----------|-------|----------|
| Hub no configurado | URL vacia | Admin → Sincronizar |
| 401 Unauthorized | API key incorrecta | Igualar key en Render y caja |
| SSL error en server | `sslmode` omitido | Usar `?sslmode=require` en Neon URL |
| Timeout primera sync | Render dormido | Esperar o usar plan pago |
| Eventos no llegan | Tenant distinto | Mismo `tenant_id` en licencia/config |

---

## Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-11 | Guia inicial Neon + Render |
