# Documentación POSIA

Índice central del monorepo. La documentación operativa vive aquí; el código fuente es la referencia de implementación.

---

## Por audiencia

### Desarrollo

| Documento | Contenido |
|-----------|-----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Capas, principios, flujos de venta y sync |
| [CODING_STANDARDS.md](CODING_STANDARDS.md) | Convenciones obligatorias del código |
| [DATABASE.md](DATABASE.md) | Esquema SQLite, migraciones, repositorios |
| [SYNC.md](SYNC.md) | Hub central, LAN, event log, API |
| [PRICING.md](PRICING.md) | Mayoreo, preferencial, listas de precios |
| [HARDWARE.md](HARDWARE.md) | Contratos e impresoras ESC/POS |
| [MODULES.md](MODULES.md) | Licencias, verticales (carnicería, farmacia) |
| [UI_GUIDELINES.md](UI_GUIDELINES.md) | Interfaz de caja y admin |

### Operación

| Documento | Contenido |
|-----------|-----------|
| [MANUAL_USUARIO.md](MANUAL_USUARIO.md) | Caja, admin, sync, móvil por voz |
| [ADMIN.md](ADMIN.md) | Panel admin: pantallas, config, permisos |

### Despliegue y publicación

| Documento | Contenido |
|-----------|-----------|
| [DEPLOYMENT.md](DEPLOYMENT.md) | Builds, licencia, hub (VPS, Docker, Neon+Render) |
| [PUBLICACION_MOVIL.md](PUBLICACION_MOVIL.md) | Google Play y App Store |
| [PRIVACIDAD.md](PRIVACIDAD.md) | Política de privacidad (URL para tiendas) |

### Historial

| Documento | Contenido |
|-----------|-----------|
| [CHANGELOG.md](CHANGELOG.md) | Registro de versiones implementadas |

---

## Orden de lectura (nuevo en el proyecto)

1. [ARCHITECTURE.md](ARCHITECTURE.md) + [DATABASE.md](DATABASE.md)
2. [CODING_STANDARDS.md](CODING_STANDARDS.md)
3. [MANUAL_USUARIO.md](MANUAL_USUARIO.md) o [DEPLOYMENT.md](DEPLOYMENT.md) según rol

---

## Estado actual (v1.0)

| Área | Estado |
|------|--------|
| Caja Windows / Web / móvil | Operativo |
| Admin, inventario, reportes | Operativo |
| Usuarios y roles (schema v10) | Operativo — PIN hasheado |
| Sync hub | Operativo — VPS, Docker o Neon+Render |
| Tiendas móviles | AAB/iOS listos — ver [PUBLICACION_MOVIL.md](PUBLICACION_MOVIL.md) |
| CFDI / timbrado | Fuera de alcance actual |

Detalle por versión: [CHANGELOG.md](CHANGELOG.md).
