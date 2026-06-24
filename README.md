# POSIA — Punto de Venta Inteligente para Mexico

POSIA es un sistema de punto de venta comercial, modular y offline-first, disenado para tiendas de abarrotes, farmacias y carnicerias en Mexico.

## Caracteristicas principales

- Interfaz orientada a iconos para trabajadores con baja alfabetizacion
- Administracion minimalista para duenos con baja alfabetizacion digital
- Multi-tienda con inventario compartido (hub central + sync LAN por sucursal)
- Precios mayoreo y precios preferenciales por cliente
- Licencia perpetua con modulos activables
- Hardware desacoplado mediante drivers plug-in
- Funcionamiento offline con cola de sincronizacion
- Categorias personalizables, corte de caja, historial de ventas
- Gestion de clientes, vendedores, proveedores e inventario

## Estructura del monorepo

```
POSIA/
├── apps/
│   └── posia_pos/          # Aplicacion de caja (Windows + Android)
├── packages/
│   ├── posia_core/         # Dominio y contratos
│   ├── posia_database/     # Persistencia SQLite local
│   ├── posia_pricing/      # Motor de precios
│   ├── posia_inventory/    # Inventario multi-tienda
│   ├── posia_sync/         # Sincronizacion hub + LAN
│   ├── posia_licensing/    # Validacion de licencia
│   ├── posia_hardware/     # Contratos de hardware
│   └── posia_ui/           # Componentes visuales de caja
├── docs/                   # Documentacion tecnica
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
- Windows 10+ (caja de escritorio) o Android 8+ (caja movil)

## Inicio rapido

```bash
# Instalar dependencias del workspace
dart pub global activate melos
melos bootstrap

# Generar codigo de base de datos (Drift)
melos run build_runner

# Ejecutar caja en Windows
cd apps/posia_pos
flutter run -d windows
```

## Licencia

Software comercial con licencia perpetua. Ver [docs/MANUAL_TECNICO.md](docs/MANUAL_TECNICO.md).

## Autor

Equipo POSIA — Matricula POSIA-2026-001

Fecha de creacion: 2026-06-07 18:30:00 (UTC-6)
