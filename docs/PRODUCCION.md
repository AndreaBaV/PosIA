# Checklist de producción POSIA

Guía para desplegar el hub, registrar tenants y publicar la app móvil.

## 1. Datos que debes tener listos

| Dato | Dónde se usa |
|------|----------------|
| `DATABASE_URL` (Neon Postgres) | Hub en Render + CLI `platform/tenant_registry` |
| `API_KEY` | Hub sync API (mismo valor que `POSIA_HUB_API_KEY` en la app) |
| `POSIA_HUB_URL` | URL pública del hub (Render) |
| `POSIA_HUB_API_KEY` | Builds móviles y `.env` de la app |
| Keystore Android + secrets GitHub | AAB firmado para Play Store |
| Certificado Apple + provisioning profile | IPA para App Store |
| URL política de privacidad | Play Console / App Store Connect |
| Email de contacto privacidad | Sustituir placeholder en la tienda |
| Tenants reales | Nombre, admin, tiendas vía CLI |

## 2. Hub en la nube

### Opción recomendada ($0): Oracle Always Free + Neon

Guía completa: **[ORACLE_ALWAYS_FREE.md](ORACLE_ALWAYS_FREE.md)**

Resumen:

1. VM **Ampere A1** en Oracle (1 OCPU, 6 GB RAM).
2. Neon para `DATABASE_URL` (ya lo tienes en `platform/.env`).
3. Dominio gratuito (DuckDNS) + HTTPS con Caddy.
4. `POSIA_HUB_URL=https://tu-dominio.duckdns.org`

### Alternativa: Render + Neon

1. Crea proyecto en [Neon](https://neon.tech) y copia `DATABASE_URL`.
2. Despliega `server/sync_api` en Render (Web Service, Docker).

```env
DATABASE_URL=postgresql://...
API_KEY=<clave-segura-aleatoria>
POSIA_ENV=production
PORT=8080
```

3. El servidor **falla al arrancar** si `POSIA_ENV=production` (o `RENDER=true`) y faltan `DATABASE_URL` o `API_KEY`.

4. Verifica salud: `GET https://tu-api.onrender.com/v1/health`

## 3. Registrar tenants (`platform/`)

```powershell
copy platform\.env.example platform\.env
# Edita DATABASE_URL y API_KEY en platform\.env

cd platform\tenant_registry
dart pub get
dart run bin/posia_tenants.dart init
dart run bin/posia_tenants.dart crear --nombre "Mi negocio"
dart run bin/posia_tenants.dart add-tienda --tenant <UUID> --nombre "Sucursal 1"
dart run bin/posia_tenants.dart add-usuario --tenant <UUID> --nombre "Admin" --codigo 1001 --pin 1234 --rol administrador
dart run bin/posia_tenants.dart provision --tenant <UUID>
```

`provision` crea el esquema en Neon si no existe e inserta tiendas/usuarios. **Re-provisionar no cambia el PIN** de usuarios ya existentes.

### Tenant para revisión de tiendas

```powershell
dart run bin/posia_tenants.dart seed-review
dart run bin/posia_tenants.dart provision --tenant 00000000-0000-4000-8000-000000000099
```

Usuarios demo: códigos `9001` / `9002`, PIN `1234`.

## 4. App móvil (un solo APK/AAB)

El build **no incluye tenant**. Solo hub URL y API key.

```powershell
copy apps\posia_pos\.env.example apps\posia_pos\.env
# O usa --dart-define en release

$env:POSIA_HUB_URL="https://tu-api.onrender.com"
$env:POSIA_HUB_API_KEY="<API_KEY>"
.\scripts\build_movil_release.ps1
```

### Primera instalación en caja

1. Asistente técnico: URL hub, API key (opcional si van en el build), **PIN técnico de 4 dígitos**.
2. Login: el tenant se resuelve con usuario + PIN contra el hub.
3. "Configuración técnica" desde login requiere el PIN técnico definido en la instalación.

### Release vs debug

- En **release** no se insertan datos demo locales (usuario `9998`).
- La tabla guía `ejemplo` sigue documentando el esquema.

## 5. GitHub Actions

| Workflow | Cuándo |
|----------|--------|
| `ci.yml` | Push/PR a main: analyze + test |
| `mobile-release.yml` | Tag `mobile-v*` o manual |

Secrets obligatorios para **tags** `mobile-v*`:

- `POSIA_HUB_URL`, `POSIA_HUB_API_KEY`
- `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`
- iOS: `IOS_DIST_CERTIFICATE_BASE64`, `IOS_DIST_CERTIFICATE_PASSWORD`, `IOS_PROVISION_PROFILE_BASE64`, `IOS_PROVISION_PROFILE_NAME`, `APPLE_TEAM_ID`

## 6. Seguridad

- Rota `API_KEY` si se filtra; actualiza secrets y reinstala/reconfigura cajas.
- No subas `.env` al repositorio.
- Usa PINs distintos por usuario en producción (no `1234`).
- El PIN técnico del dispositivo es independiente de los PIN de usuario.

## 7. Verificación rápida

```powershell
# Tests
melos bootstrap
melos run analyze
melos run test

# Login contra hub (desde app o curl)
curl -s -H "X-API-Key: $API_KEY" "https://tu-api/v1/auth/preview?codigo=1001"
```

## Documentación relacionada

- [DEPLOYMENT.md](DEPLOYMENT.md) — despliegue general
- [PUBLICACION_MOVIL.md](PUBLICACION_MOVIL.md) — Play Store / App Store
- [platform/README.md](../platform/README.md) — CLI de tenants
- [ORACLE_ALWAYS_FREE.md](ORACLE_ALWAYS_FREE.md) — hub gratis 24/7 en Oracle
