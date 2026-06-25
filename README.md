# POSIA — Punto de Venta Inteligente para México

POSIA es un sistema de punto de venta comercial, modular y offline-first, diseñado para tiendas de abarrotes, farmacias y carnicerías en México.

## Características principales

- Interfaz orientada a iconos para trabajadores con baja alfabetización
- Administración minimalista para dueños con baja alfabetización digital
- Multi-tienda con inventario compartido (hub central + sync LAN por sucursal)
- Precios mayoreo y precios preferenciales por cliente
- Licencia perpetua con módulos activables
- Hardware desacoplado mediante drivers plug-in
- Funcionamiento offline con cola de sincronización
- Categorías personalizables, corte de caja, historial de ventas
- Gestión de clientes, vendedores, proveedores e inventario

## Estructura del monorepo

```
POSIA/
├── apps/
│   └── posia_pos/          # Aplicación de caja (Windows + Android)
├── packages/
│   ├── posia_core/         # Dominio y contratos
│   ├── posia_database/     # Persistencia SQLite local
│   ├── posia_pricing/      # Motor de precios
│   ├── posia_inventory/    # Inventario multi-tienda
│   ├── posia_sync/         # Sincronización hub + LAN
│   ├── posia_licensing/    # Validación de licencia
│   ├── posia_hardware/     # Contratos de hardware
│   └── posia_ui/           # Componentes visuales de caja
├── docs/                   # Documentación técnica
├── platform/               # Registro maestro de tenants + CLI aprovisionamiento
│   └── tenant_registry/    # SQLite local → publica en Neon
└── server/                 # Hub de sync (API + Postgres)
```

## Documentación

| Documento | Descripción |
|-----------|-------------|
| [docs/MANUAL_TECNICO.md](docs/MANUAL_TECNICO.md) | Arquitectura, despliegue, builds, sync, publicación móvil |
| [docs/MANUAL_USUARIO.md](docs/MANUAL_USUARIO.md) | Operación de caja y admin; inventario de funciones |
| [docs/CONTROL_CAMBIOS.md](docs/CONTROL_CAMBIOS.md) | Historial de versiones |

## Requisitos

- Flutter SDK >= 3.41.0
- Dart SDK >= 3.11.0
- Windows 10+ (caja de escritorio) o Android 8+ (caja móvil)

## Inicio rápido

```bash
# Instalar dependencias del workspace
dart pub global activate melos
melos bootstrap

# Generar código de base de datos (Drift)
melos run build_runner

# Ejecutar caja en Windows
cd apps/posia_pos
flutter run -d windows
```

## Licencia

Software comercial con licencia perpetua. Ver [docs/MANUAL_TECNICO.md](docs/MANUAL_TECNICO.md).

## Autor

Equipo POSIA — Matrícula POSIA-2026-001

Fecha de creación: 2026-06-07 18:30:00 (UTC-6)
