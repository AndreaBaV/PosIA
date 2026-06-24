# Plataforma POSIA — gestión de tenants

Herramientas internas para dar de alta y aprovisionar los **30+ negocios** que usan la misma app móvil. El tenant **no** va en el build: se registra aquí y se publica en Neon para que el login lo resuelva.

## Estructura

```
platform/
├── README.md                 # Este archivo
├── .env.example              # DATABASE_URL para Neon
├── scripts/
│   └── tenants.ps1           # Atajos PowerShell
└── tenant_registry/          # Paquete Dart + SQLite local
    ├── bin/posia_tenants.dart
    ├── data/
    │   └── registro_tenants.db   # Creado al primer uso (no se sube a git)
    └── lib/
```

## Base de datos local (`registro_tenants.db`)

| Tabla | Contenido |
|-------|-----------|
| `ejemplo` | Guia por seccion: columna `ejemplo` indica que datos capturar |
| `tenants` | Catálogo maestro: nombre, contacto, límites, estado hub |
| `tiendas` | Sucursales por tenant (se publican en `stores` de Neon) |
| `usuarios_bootstrap` | Primer admin/cajeros; PIN en claro **solo aquí** (máquina del implementador) |

Al **provisionar**, los PIN se hashean con `HasherPin` y se insertan en la tabla `users` del hub.

## Configuracion (`.env`)

Copie `platform/.env.example` a `platform/.env`:

```env
DATABASE_URL=postgresql://...@neon.tech/neondb?sslmode=require
POSIA_HUB_URL=ejemplo
POSIA_HUB_API_KEY=ejemplo
ADMIN_TOKEN=elige-un-secreto-largo
ADMIN_PORT=3847
```

El CLI carga `.env` automaticamente. La columna **`ejemplo`** en la base local indica que valor poner en cada seccion.

## Inicio rapido

```powershell
cd platform\tenant_registry
dart pub get

# Crear la base SQLite
dart run bin/posia_tenants.dart init

# Alta de un negocio
dart run bin/posia_tenants.dart crear --nombre "Abarrotes La Esquina" --contacto "Juan"

# Tienda y admin inicial (anota el tenant ID que imprime crear)
dart run bin/posia_tenants.dart add-tienda --tenant <TENANT_ID> --nombre "Sucursal Centro"
dart run bin/posia_tenants.dart add-usuario --tenant <TENANT_ID> --nombre "Admin" --codigo ADM001 --pin 1234

# Listar todos
dart run bin/posia_tenants.dart list

# Publicar en Neon (misma DATABASE_URL que server/sync_api)
$env:DATABASE_URL="postgresql://...@ep-xxx.neon.tech/neondb?sslmode=require"
dart run bin/posia_tenants.dart provision --tenant <TENANT_ID>
```

Si provisionaste antes de junio 2026 y las tiendas en Neon no tienen `tenant_id`, ejecuta una sola vez:

```powershell
dart run bin/backfill_tenant_stores.dart
```

Eso lee el registro local (`registro_tenants.db`), asigna `tenant_id` en Neon y publica eventos `storeUpserted` para que las cajas sincronicen.

## Panel web de administración

Interfaz local para listar negocios, crear tenants, agregar tiendas/usuarios, publicar en Neon y restablecer PINs.

```powershell
cd platform\tenant_registry
dart pub get
dart run bin/posia_admin_web.dart
```

Desde `platform\tenant_registry` también puedes usar:

```powershell
.\admin.ps1
```

Desde la raíz del repo:

```powershell
.\platform\scripts\tenants.ps1 admin
```

Abre **http://127.0.0.1:3847** (puerto configurable con `ADMIN_PORT`). Pega el `ADMIN_TOKEN` de `platform/.env` en la barra superior.

Solo escucha en `127.0.0.1` — úsalo desde tu PC, no lo expongas a internet sin un túnel seguro.

**Windows:** si `dart run` falla con `sqlite3.dll ... ya existe`, usa el atajo (limpia la caché automáticamente):

```powershell
.\platform\scripts\tenants.ps1 admin
```

O manualmente antes de arrancar:

```powershell
Remove-Item -Force platform\tenant_registry\.dart_tool\lib\sqlite3.dll -ErrorAction SilentlyContinue
dart run bin/posia_admin_web.dart
```

No ejecutes dos instancias del panel a la vez (mismo puerto 3847).

## Códigos de usuario

Los códigos son **alfanuméricos** (2–32 caracteres: letras, números, `.`, `_`, `-`). Se guardan en mayúsculas (`ADM001`, `CAJERO1`, `9001` sigue válido).

Si omites el código al crear usuario en el panel, se genera automáticamente (`ADM001`, `SUP001`, `EMP001`).

## Tenant para revisores (Play Store / App Store)

```powershell
$env:DATABASE_URL="postgresql://..."
dart run bin/posia_tenants.dart seed-review --provision
```

Credenciales:

| Rol | Código | PIN |
|-----|--------|-----|
| Administrador | 9001 | 1234 |
| Empleado | 9002 | 1234 |

Incluye estas credenciales en las **notas para el revisor** de Google Play y App Store.

## Atajos PowerShell

Desde la raíz del repo:

```powershell
.\platform\scripts\tenants.ps1 list
.\platform\scripts\tenants.ps1 crear -Nombre "Farmacia Norte"
```

## Flujo operativo por cliente

1. **crear** tenant en registro local.
2. **add-tienda** (una o más sucursales).
3. **add-usuario** (admin obligatorio; supervisores/empleados opcional).
4. **provision** → escribe en Neon (`stores` + `users`).
5. El cliente instala el **mismo APK/AAB** de Play Store y entra con su código + PIN.
6. La app abre `posia_t_{tenantId}.db` y sincroniza catálogo/ventas.

## Seguridad

- `platform/tenant_registry/data/*.db` está en `.gitignore` (contiene PINs en claro).
- No compartas el archivo `.db`; usa provision y entrega credenciales al cliente por canal seguro.
- Los códigos de usuario son **únicos globalmente** en Neon (`users.codigo UNIQUE`).

## Relación con otros componentes

| Componente | Rol |
|------------|-----|
| `platform/tenant_registry` | Catálogo maestro + alta inicial |
| `server/sync_api` | Hub sync + auth (`/v1/auth/login`) |
| `apps/posia_pos` | App única; tenant al login |

Ver también: [docs/MANUAL_TECNICO.md](../docs/MANUAL_TECNICO.md)
