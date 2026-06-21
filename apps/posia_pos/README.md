# POSIA POS

Cliente Flutter del punto de venta POSIA (Windows, Android, iOS).

## Inicio rápido

```bash
cd apps/posia_pos
flutter pub get
flutter run -d windows   # o android / ios
```

## Flujo de acceso

1. **Seleccionar tienda** — pantalla inicial al abrir la app.
2. **Iniciar sesión** — código de **usuario** y **contraseña** (PIN de 4 dígitos).
3. **Caja** — operación diaria; **Admin** según permisos del rol.

## Cuentas de demostración

Los datos demo se cargan automáticamente en una base vacía:

| Usuario | Contraseña | Persona | Rol |
|---------|------------|---------|-----|
| `1000` | `1234` | Ana Administradora | Administrador |
| `2001` | `2345` | Carlos Supervisor Centro | Supervisor |
| `2002` | `2345` | Laura Supervisor Norte | Supervisor |
| `3001` | `3456` | Pedro Empleado | Empleado |

### Notas

- **Usuario** = código numérico asignado en Admin → Usuarios (visible en cada tarjeta).
- **Contraseña** = PIN de 4 dígitos (`LONGITUD_PIN_ADMIN`).
- Respaldo administrativo del dispositivo: usuario `0000` + PIN configurado en Admin → Configuración (demo: `1234`).
- Supervisores y empleados solo pueden entrar en la **tienda asignada**.
- En producción, crea usuarios propios y cambia las contraseñas antes de operar.

### Seguridad de usuarios (esquema v10)

- Código de usuario **único** (índice `UNIQUE` en SQLite).
- Contraseñas almacenadas como **hash + sal** (`pin_hash`, `pin_salt`); nunca en texto plano.
- Validación de rol y estado activo en la tabla (`CHECK` constraints).
- Al actualizar la app, las bases existentes migran automáticamente de PIN plano a hash.

## Documentación adicional

- [Manual de usuario](../../docs/MANUAL_USUARIO.md)
- [Panel de administración](../../docs/ADMIN.md)
- [Publicación móvil (Play Store / App Store)](../../docs/PUBLICACION_MOVIL.md)

## Publicación en tiendas (v1.0.0)

```powershell
# Desde la raíz del monorepo
.\scripts\generar_keystore_android.ps1   # una sola vez
.\scripts\build_movil_release.ps1 -Plataforma android
```

**Android (AAB):** `build/app/outputs/bundle/release/app-release.aab`  
**iOS:** requiere Mac — ver `docs/PUBLICACION_MOVIL.md`

Identificadores:

| Plataforma | ID |
|------------|-----|
| Android | `com.posia.posia_pos` |
| iOS | `com.posia.posiaPos` |
