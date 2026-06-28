# Manual técnico — POSIA

**Autor:** Equipo POSIA  
**Matrícula:** POSIA-2026-001  
**Versión app:** 1.0.0  
**Última actualización:** 2026-06-24

Documentación para desarrolladores, integradores y despliegue de infraestructura.

---

## Tabla de contenido

1. [Arquitectura](#1-arquitectura)
2. [Monorepo y paquetes](#2-monorepo-y-paquetes)
3. [Estándares de código](#3-estándares-de-código)
4. [Base de datos local](#4-base-de-datos-local)
5. [Motor de precios](#5-motor-de-precios)
6. [Sincronización](#6-sincronización)
7. [Módulos y licencias](#7-módulos-y-licencias)
8. [Hardware](#8-hardware)
9. [Interfaz (guía UI)](#9-interfaz-guía-ui)
10. [Despliegue y builds](#10-despliegue-y-builds)
11. [Publicación móvil](#11-publicación-móvil)
12. [Configuración del dispositivo](#12-configuración-del-dispositivo)
13. [Política de privacidad (tiendas)](#13-política-de-privacidad-tiendas)

---

## 1. Arquitectura

### Visión

POSIA es un POS modular comercial para México:

- Multi-tienda (típico: N tiendas × 2 cajas)
- Offline-first con SQLite local en cada caja
- Sync en dos niveles: LAN (2 cajas por tienda) + Hub central
- Hardware desacoplado por drivers
- UI accesible (iconos, números grandes, voz en móvil)

### Diagrama de capas

```
┌──────────────────────────────────────────────────────────────┐
│ apps/posia_pos          UI Caja + Admin                      │
├──────────────────────────────────────────────────────────────┤
│ posia_ui                Widgets reutilizables                  │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│ posia_   │ posia_   │ posia_   │ posia_   │ posia_          │
│ pricing  │ inventory│ sync     │ licensing│ hardware        │
├──────────┴──────────┴──────────┴──────────┴─────────────────┤
│ posia_database          SQLite / Drift                         │
├──────────────────────────────────────────────────────────────┤
│ posia_core              Entidades, enums, contratos          │
└──────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Hub Sync (VPS)    │
                    │ Event Log API     │
                    └───────────────────┘
```

### Principios

| Principio | Implementación |
|-----------|----------------|
| Modularidad | Módulos activables vía licencia (`posia_licensing`) |
| Bajo acoplamiento | Contratos en `posia_core` |
| Offline-first | SQLite es fuente de verdad en caja; sync eventual |
| Event sourcing (sync) | Ventas append-only; catálogo last-write-wins |
| Accesibilidad | Modo iconos por defecto en caja |

### Flujo de venta

```
Producto (icono / código / voz)
        → MotorPrecio (mayoreo / cliente)
        → Carrito en memoria
        → Cobro → Venta en SQLite
        → Evento SaleCompleted → cola sync
        → Ajuste stock local
        → Ticket (hardware o archivo)
```

### Stack

| Capa | Tecnología |
|------|------------|
| UI | Flutter 3.41+ |
| Estado | Riverpod |
| DB local | Drift + sqlite3 |
| Sync hub | API REST + Postgres |
| Licencia | JSON firmado (RSA) offline |
| Monorepo | Melos |

### Seguridad

- Roles por permisos visuales (empleado, supervisor, admin)
- PIN hasheado (schema v10); nunca en claro en sync
- Eventos firmados con `tenant_id` + `device_id`
- TLS obligatorio hacia el hub

---

## 2. Monorepo y paquetes

```
POSIA/
├── apps/posia_pos/           # App Flutter (Windows, iOS, Android)
├── packages/
│   ├── posia_core/           # Dominio y contratos
│   ├── posia_database/       # SQLite / Drift
│   ├── posia_pricing/        # Motor de precios
│   ├── posia_inventory/      # Inventario multi-tienda
│   ├── posia_sync/           # Hub + LAN
│   ├── posia_licensing/      # Licencia offline
│   ├── posia_hardware/       # Impresora, escáner, báscula
│   ├── posia_ui/             # Widgets y temas
│   ├── posia_voice/          # Comandos de voz (móvil)
│   ├── posia_module_butcher/ # Carnicería
│   └── posia_module_pharmacy/# Farmacia
├── platform/tenant_registry/ # CLI aprovisionamiento tenants
└── server/sync_api/          # Hub sync (Dart + Postgres)
```

### Inicio rápido desarrollo

```bash
dart pub global activate melos
melos bootstrap
melos run build_runner
cd apps/posia_pos && flutter run -d windows
```

### Calidad

```bash
melos run analyze
melos run test
melos run format
```

---

## 3. Estándares de código

| Elemento | Convención | Ejemplo |
|----------|------------|---------|
| Variables y funciones | camelCase | `precioUnitario` |
| Constantes | UPPER_SNAKE_CASE | `MAX_CAJAS_POR_TIENDA` |
| Clases | PascalCase | `MotorPrecio` |
| Archivos | snake_case | `motor_precio.dart` |
| Paquetes | snake_case | `posia_pricing` |

- Dominio de negocio en español; infraestructura en inglés cuando sea convención del ecosistema.
- Sangría: un Tab por nivel.
- Encabezado obligatorio en cada `.dart` con autor, matrícula y fechas.
- Documentar funciones públicas antes de la definición.
- State: Riverpod; persistencia: Drift; tests: `*_test.dart`.

---

## 4. Base de datos local

- **Motor:** SQLite vía sqflite/Drift
- **Archivos:** `posia_dispositivo.db` (config) + `posia_t_{tenantId}.db` (operación)
- **Migraciones:** `packages/posia_database/lib/src/database/migraciones_esquema.dart`

### Tablas principales

| Grupo | Tablas |
|-------|--------|
| Config | `app_config`, `sync_state` |
| Catálogo | `categories`, `products`, `product_variants`, `customers`, `wholesale_tiers`, `price_lists` |
| Operación | `sales`, `sale_lines`, `cash_shifts`, `stock_levels` |
| Inventario | `inventory_movements`, `transfers`, `pharmacy_lots` |
| Sync | `sync_event_queue` |
| RRHH | `users`, asistencia, nómina (según versión schema) |

### Estados de venta

| Valor | Significado |
|-------|-------------|
| `completada` | Venta vigente |
| `cancelada` | Anulada; stock revertido |

---

## 5. Motor de precios

Paquete: `posia_pricing`

### Orden de prioridad

```
1. PrecioClienteProducto (cliente + producto)
2. ListaPreciosCliente
3. EscalaMayoreo (cantidad >= umbral)
4. PrecioBase tienda + producto
```

---

## 6. Sincronización

Paquete: `posia_sync` · Servidor: `server/sync_api`

### Modelo

Event log append-only. Cada dispositivo mantiene cola `sync_event_queue` y cursor `last_synced_event_id`.

### Niveles

| Nivel | Alcance | Protocolo |
|-------|---------|-----------|
| LAN | 2 cajas misma tienda | HTTP local / mDNS `posia-sync._tcp.local` |
| Hub | Todas las tiendas del tenant | REST + Postgres |

### Eventos principales

`saleCompleted`, `saleVoided`, `salePartialReturn`, `productUpserted`, `variantUpserted`, `categoryUpserted`, `customerUpserted`, `stockAdjusted`, `transferRequested`, `transferCompleted`, `storeUpserted`, `userUpserted`

`UserUpserted` replica `pinHash` y `pinSalt`; nunca el PIN en claro.

### API Hub

| Endpoint | Uso |
|----------|-----|
| `POST /v1/events` | Push lote de eventos |
| `GET /v1/events?since=&tenantId=` | Pull incremental |
| `POST /v1/auth/login` | Login código + PIN → tenantId |
| `GET /v1/health` | Health check |

### Comportamiento offline

| Escenario | Comportamiento |
|-----------|----------------|
| Sin internet en tienda | LAN activo; cola hub pendiente |
| Reconexión | Push cola + pull incremental |
| Conflicto catálogo | Last-write-wins; banner admin |

### Despliegue del hub

Código: `server/sync_api`. La caja solo habla HTTP; no conecta directo a Postgres.

#### Opción A — Docker en VPS (~USD 5/mes)

```bash
cd server/sync_api
docker compose up -d --build
```

#### Opción B — Self-host JSONL (desarrollo)

```bash
cd server/sync_api
dart run bin/server.dart
```

#### Opción C — Neon + Render (free, se duerme)

| Variable | Valor |
|----------|-------|
| `DATABASE_URL` | Connection string Neon (`?sslmode=require`) |
| `API_KEY` | Clave compartida (`x-api-key`) |
| `PORT` | `8080` |

#### Opción D — Neon + Oracle Always Free (recomendado $0, 24/7)

1. VM **Ampere A1** Ubuntu 22.04 aarch64 (1 OCPU, 6 GB RAM)
2. Puertos 22, 80, 443 abiertos; 8080 solo local
3. Neon para `DATABASE_URL`
4. DuckDNS + Caddy para HTTPS
5. Deploy:

```bash
cd server/sync_api
cp deploy/oracle/.env.example .env
docker compose -f docker-compose.prod.yml up -d --build
curl https://TU-DOMINIO/v1/health
```

### Variables de entorno (hub)

| Variable | Descripción |
|----------|-------------|
| `DATABASE_URL` | Postgres; vacía = JSONL local |
| `EVENTS_FILE` | Archivo JSONL sin Postgres |
| `API_KEY` | Clave compartida |
| `PORT` | Default 8080 |

### Build producción (embeber hub en app)

```powershell
$env:POSIA_HUB_URL="https://tu-api.onrender.com"
$env:POSIA_HUB_API_KEY="tu-clave-secreta"
.\scripts\build_movil_release.ps1
```

Un solo APK/IPA sirve para todos los tenants; el tenant se resuelve al iniciar sesión.

### Solución de problemas sync

| Problema | Solución |
|----------|----------|
| 401 Unauthorized | Igualar API key servidor y app |
| SSL error | `?sslmode=require` en Neon |
| Timeout primera sync | Render dormido — esperar ~30 s |
| Sin URL hub | Caja opera 100 % offline |

---

## 7. Módulos y licencias

### Núcleo (siempre activo)

`core`, `multi_store`, `sync_hub`, `sync_lan`

### Módulos opcionales

| ID | Rubro |
|----|-------|
| `wholesale_pricing` | Mayoreo |
| `customer_pricing` | Precio preferencial |
| `credit_sales` | Fiado |
| `pharmacy` | Lotes FEFO |
| `butcher` | Peso / báscula |
| `voice_commands` | Caja móvil por voz |
| `cfdi` | Fuera de alcance v1.0 |

### Archivo `posia.lic`

```json
{
  "tenantId": "uuid",
  "modules": ["core", "multi_store"],
  "maxStores": 5,
  "maxRegisters": 10,
  "supportExpiresAt": "2027-06-07"
}
```

Límites estándar: 5 tiendas, 10 cajas, 15 usuarios.

### Verticales

- **Carnicería** (`posia_module_butcher`): venta por kg, báscula vía `Scale`
- **Farmacia** (`posia_module_pharmacy`): lotes, FEFO, alertas caducidad

En admin se gestionan como categorías dentro de Productos.

---

## 8. Hardware

Principio: el núcleo nunca accede a hardware directamente. Contratos en `posia_hardware`.

| Interfaz | Propósito |
|----------|-----------|
| `BarcodeScanner` | Stream de códigos |
| `Scale` | Peso en gramos |
| `ReceiptPrinter` | ESC/POS o archivo |
| `CashDrawer` | Pulso apertura cajón |

### Drivers incluidos

| Driver | Uso |
|--------|-----|
| `TecladoBarcodeScanner` | USB wedge (producción Windows) |
| `EscPosNetworkPrinter` | Red IP:9100 |
| `ArchivoReceiptPrinter` | Fallback `Documents/POSIA/tickets` |
| `ImpresoraConfigurable` | Modo archivo / red / ambos |

### Fallbacks

| Ausente | Comportamiento |
|---------|----------------|
| Impresora | Guardar archivo |
| Báscula | Entrada manual de peso |
| Escáner móvil | Voz o texto |
| Cajón | Pulso vía impresora red |

---

## 9. Interfaz (guía UI)

### Caja (trabajadores)

- Iconos grandes (mín. 64 dp)
- Total en tipografía extra grande
- Máximo 4 acciones en barra inferior (desktop)
- Colores: cobrar verde `#2E7D32`, cancelar rojo `#C62828`

### Admin

- Grid por secciones; responsive con `LayoutResponsivo`
- Mismo panel en Windows, iOS y Android

### Plataformas

| Plataforma | Caja | Detección |
|------------|------|-----------|
| Windows | `PantallaCaja` (grilla + escáner) | `plataforma_util.dart` |
| iOS/Android | `PantallaCajaMovil` (voz) | `esPlataformaMovilNativa()` |

---

## 10. Despliegue y builds

### Modelo comercial

- Licencia perpetua; módulos por compra única
- Primer año soporte + sync hub incluido
- Sin renovación: cajas venden offline; sync nube deja de actualizarse

### Comandos por plataforma

| Plataforma | Comando |
|------------|---------|
| Windows | `flutter build windows --release` |
| Android AAB | `flutter build appbundle --release` |
| Android APK | `flutter build apk --release` |
| iOS IPA | `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist` |

Scripts: `scripts/build_movil_release.ps1`, `scripts/generar_keystore_android.ps1`, `scripts/preparar_secretos_github.ps1`

### Artefactos

| Plataforma | Ruta |
|------------|------|
| Windows | `apps/posia_pos/build/windows/x64/runner/Release/` |
| Android AAB | `build/app/outputs/bundle/release/app-release.aab` |
| iOS IPA | `build/ios/ipa/*.ipa` |

### Instalación en caja

1. Instalar binario
2. Asistente técnico (opcional): hub y API key
3. Importar `posia.lic` si aplica
4. Login usuario + PIN
5. Admin elige tienda; configurar impresora

### Checklist producción

| Dato | Uso |
|------|-----|
| `DATABASE_URL` | Hub Postgres |
| `API_KEY` | Hub = `POSIA_HUB_API_KEY` en app |
| `POSIA_HUB_URL` | URL pública hub |
| Keystore Android + secrets GitHub | Play Store |
| Certificado Apple + provisioning | App Store / TestFlight |
| URL política privacidad | Tiendas (§13) |

---

## 11. Publicación móvil

**Versión tienda:** 1.0.0 (build 1)  
**Android:** `com.posia.posia_pos`  
**iOS:** `com.posia.posiaPos`

### GitHub Actions — workflow `Mobile Release`

| Disparador | Cuándo |
|------------|--------|
| Manual | Actions → Mobile Release → Run workflow |
| Tag | `git tag mobile-v1.0.0 && git push origin mobile-v1.0.0` |

Artefactos: `posia-android-aab`, `posia-android-apk`, `posia-ios-ipa`

### Secrets GitHub

**Android:**

| Secret | Valor |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | Keystore en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña keystore |
| `ANDROID_KEY_PASSWORD` | Contraseña clave |
| `ANDROID_KEY_ALIAS` | `posia` |

**Google Play (subida automática del AAB tras compilar):**

| Secret | Valor |
|--------|-------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Contenido completo del JSON de la cuenta de servicio (Google Cloud → IAM → claves JSON) |
| `GOOGLE_PLAY_TRACK` | *(Opcional)* `internal` (default), `alpha`, `beta` o `production` |

En Play Console → **Usuarios y permisos**, invita la cuenta de servicio con permiso **Publicar en Google Play**. La app `com.posia.posia_pos` debe existir al menos una vez subida manualmente (primera versión).

**Hub (recomendado):**

| Secret | Valor |
|--------|-------|
| `POSIA_HUB_URL` | URL del hub |
| `POSIA_HUB_API_KEY` | API key |

**iOS:**

| Secret | Valor |
|--------|-------|
| `IOS_DIST_CERTIFICATE_BASE64` | `.p12` en base64 |
| `IOS_DIST_CERTIFICATE_PASSWORD` | Contraseña p12 |
| `IOS_PROVISION_PROFILE_BASE64` | `.mobileprovision` en base64 |
| `IOS_PROVISION_PROFILE_NAME` | Nombre exacto del perfil |
| `APPLE_TEAM_ID` | Team ID (10 caracteres) |
| `KEYCHAIN_PASSWORD` | String cualquiera (CI) |

**TestFlight (subida automática tras compilar el IPA):**

Opción A — **recomendada** (API Key, sin contraseña de aplicación):

| Secret | Valor |
|--------|-------|
| `APPLE_ISSUER_ID` | Issuer ID en App Store Connect → Usuarios y acceso → Integraciones → Claves API |
| `APPLE_API_KEY_ID` | Key ID de la clave API (ej. `AB12CD34EF`) |
| `APPLE_API_PRIVATE_KEY` | Contenido completo del archivo `.p8` (incluye `-----BEGIN PRIVATE KEY-----`) |

Crear la clave en App Store Connect con rol **App Manager** o **Admin** y permiso de subida de builds.

Opción B — **contraseña de aplicación** (como Transporter manual):

| Secret | Valor |
|--------|-------|
| `APPLE_ID` | Apple ID del desarrollador (correo) |
| `APPLE_APP_SPECIFIC_PASSWORD` | Contraseña de aplicación generada en appleid.apple.com |
| `APPLE_ASC_PROVIDER` | *(Opcional)* Provider short name si tienes varias cuentas (ej. `Z6WHV5G6M3`) |

Si configuras ambas opciones, el workflow usa la **API Key** (opción A).

Tras un release con tag `mobile-v*` o un run manual con `platform: ios` / `all`, el job **iOS IPA** sube el build a TestFlight automáticamente. En App Store Connect → TestFlight aparece en unos minutos (procesamiento de Apple).

Codificar en PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('distribucion.p12'))
[Convert]::ToBase64String([IO.File]::ReadAllBytes('POSIA_AppStore.mobileprovision'))
```

### Prueba en iPhone (TestFlight)

1. Apple Developer → App ID `com.posia.posiaPos` → certificado Distribution → perfil App Store
2. Configurar secrets de firma iOS y **TestFlight** (§11) en GitHub
3. Publicar release:
   - Tag: `git tag mobile-v1.0.0 && git push origin mobile-v1.0.0`, o
   - Actions → **Mobile Release** → `platform: ios`
4. El workflow compila el IPA y **lo sube a TestFlight** automáticamente
5. App Store Connect → TestFlight → tester interno → instalar con la app TestFlight

**Subida manual (opcional):** descarga el artefacto `posia-ios-ipa` y usa [Transporter](https://apps.apple.com/app/transporter/id1450874784) si no configuraste secrets de TestFlight.

**Ad Hoc:** registrar UDID, perfil Ad Hoc, cambiar `ios/ExportOptions.plist` → `method: ad-hoc`.

**Desarrollo con Mac:**

```bash
cd apps/posia_pos
flutter run -d <iphone> --dart-define=POSIA_HUB_URL=... --dart-define=POSIA_HUB_API_KEY=...
```

### Tiendas

- **Play Store:** subir AAB; política privacidad §13; notas revisor: credenciales del negocio
- **App Store:** bundle `com.posia.posiaPos`; `ITSAppUsesNonExemptEncryption = false` en Info.plist

### Versiones futuras

En `pubspec.yaml`: `version: 1.0.1+2` · Tag: `mobile-v1.0.1`

---

## 12. Configuración del dispositivo

Persistido en `app_config`:

| Clave | Valor |
|-------|-------|
| `tenant_id` | UUID del tenant |
| `store_id` / `tienda_id` | Tienda activa |
| `register_id` / `caja_id` | Identificador de caja |
| `pin_admin` | PIN respaldo técnico |
| `printer_mode` | archivo / red / ambos |
| `printer_host` | IP impresora |
| `printer_port` | Default 9100 |

Cambiar tenant o tienda requiere reiniciar la app.

### Permisos por rol (admin)

| Rol | Admin |
|-----|-------|
| Administrador | Completo |
| Supervisor | Sin Tiendas, Sync, Config global |
| Empleado | Solo Mi cuenta (perfil) |

---

## 13. Política de privacidad (tiendas)

Publique este texto en una URL pública para Play Console y App Store Connect.

**Aplicación:** POSIA (`com.posia.posia_pos` / `com.posia.posiaPos`)

POSIA es un punto de venta para comercios. Los datos se almacenan **principalmente en el dispositivo**. No vendemos datos para publicidad.

| Dato | Uso | Dónde |
|------|-----|-------|
| Usuario y credenciales | Acceso por rol | Dispositivo (hash) |
| Ventas, inventario | Operación | SQLite local |
| Audio micrófono | Voz opcional móvil | Procesado en dispositivo |
| URL hub | Sync opcional | Config local |

**Permisos:** Internet (sync); micrófono y voz (caja móvil).

**Sync nube:** si el negocio configura hub, los eventos van al servidor del administrador. POSIA no opera ese servidor.

**Eliminación:** desinstalar app o borrar datos desde admin del dispositivo.

**Contacto:** sustituir `privacidad@posia.app` antes de publicar.

---

## Referencias en código

| Tema | Ruta |
|------|------|
| App entrada | `apps/posia_pos/lib/main.dart` |
| Branch móvil/desktop | `apps/posia_pos/lib/util/plataforma_util.dart` |
| Caja móvil | `apps/posia_pos/lib/screens/pantalla_caja_movil.dart` |
| CI móvil | `.github/workflows/mobile-release.yml` |
| iOS export | `apps/posia_pos/ios/ExportOptions.plist` |
| API hub | `server/sync_api/README.md` |
| Tenants | `platform/README.md` |
