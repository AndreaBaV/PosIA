# POSIA POS

Cliente Flutter del punto de venta POSIA (Windows, Android, iOS).

## Inicio rápido

```bash
cd apps/posia_pos
flutter pub get
flutter run -d windows   # o android / ios
```

## Flujo de acceso

1. **Iniciar sesión** — código de **usuario** y **contraseña** (PIN de 4 dígitos).
2. **Administrador** — elige la tienda de la sesión.
3. **Supervisor / empleado** — entran directo a su tienda asignada.
4. **Caja** — operación diaria; **Admin** según permisos del rol.

## Primera instalación

La base local arranca **vacía**. Usuarios, tiendas y catálogo llegan por **sincronización con el hub** o se crean en Admin tras el primer acceso con cuenta provisionada.

- **Usuario** = código numérico asignado en Admin → Usuarios.
- **Contraseña** = PIN de 4 dígitos (`LONGITUD_PIN_ADMIN`).
- Respaldo técnico del dispositivo: usuario `0000` + PIN configurado en Admin → Configuración (solo si ya se guardó un PIN).
- Licencia estándar: hasta **15 cuentas activas** por tenant.

### Seguridad de usuarios (esquema v10)

- Código de usuario **único** (índice `UNIQUE` en SQLite).
- Contraseñas almacenadas como **hash + sal** (`pin_hash`, `pin_salt`); nunca en texto plano.
- Validación de rol y estado activo en la tabla (`CHECK` constraints).

## Documentación adicional

- [Manual de usuario](../../docs/MANUAL_USUARIO.md)
- [Manual técnico](../../docs/MANUAL_TECNICO.md) — despliegue, sync, publicación móvil
- [Control de cambios](../../docs/CONTROL_CAMBIOS.md)

## Publicación en tiendas (v1.0.0)

```powershell
# Desde la raíz del monorepo
.\scripts\generar_keystore_android.ps1   # una sola vez
.\scripts\build_movil_release.ps1 -Plataforma android
```

**Android (AAB):** `build/app/outputs/bundle/release/app-release.aab`  
**iOS:** GitHub Actions o Mac — ver `docs/MANUAL_TECNICO.md` §11

Identificadores:

| Plataforma | ID |
|------------|-----|
| Android | `com.posia.posia_pos` |
| iOS | `com.posia.posiaPos` |
