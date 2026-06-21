/// Constantes globales del sistema POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Identificador del tenant de demostracion incluido en datos semilla.
const String TENANT_DEMO_ID = '550e8400-e29b-41d4-a716-446655440000';

/// Identificador de tienda demo centro.
const String TIENDA_DEMO_CENTRO_ID = '660e8400-e29b-41d4-a716-446655440001';

/// Identificador de tienda demo norte.
const String TIENDA_DEMO_NORTE_ID = '660e8400-e29b-41d4-a716-446655440002';

/// Identificador de caja demo 1.
const String CAJA_DEMO_1_ID = '770e8400-e29b-41d4-a716-446655440001';

/// Version actual del esquema local SQLite.
const int SCHEMA_VERSION = 10;

/// Identificador de categoria virtual "Todos" en caja.
const String CATEGORIA_TODOS_ID = '__todos__';

/// Dias antes de caducidad para alerta amarilla en farmacia.
const int DIAS_ALERTA_CADUCIDAD_AMARILLA = 30;

/// Dias antes de caducidad para alerta roja en farmacia.
const int DIAS_ALERTA_CADUCIDAD_ROJA = 7;

/// Gramos minimos validos para venta por peso en carniceria.
const double PESO_MINIMO_GRAMOS_CARNICERIA = 100.0;

/// Decimales permitidos para montos en MXN.
const int DECIMALES_MONEDA = 2;

/// Umbral en minutos para marcar inventario remoto como desactualizado.
const int UMBRAL_STOCK_DESACTUALIZADO_MINUTOS = 15;

/// Puerto por defecto del servicio sync LAN.
const int PUERTO_SYNC_LAN_DEFAULT = 8765;

/// Intervalo del ciclo periodico de sincronizacion en segundos.
const int INTERVALO_SYNC_PERIODICO_SEGUNDOS = 60;

/// Nombre del servicio mDNS para descubrimiento LAN.
const String MDNS_SERVICIO_SYNC = 'posia-sync';

/// PIN demo de acceso administrativo en entorno de desarrollo.
/// Rol Administrador en inicio de sesion. Ver tambien README de posia_pos.
const String PIN_ADMIN_DEMO = '1234';

/// Longitud requerida del PIN de usuario y administrador.
const int LONGITUD_PIN_ADMIN = 4;

/// Identificadores de cuentas demo (codigo + PIN en pantalla de acceso).
const String ID_USUARIO_DEMO_ADMIN = 'usr-demo-admin';
const String CODIGO_USUARIO_DEMO_ADMIN = '1000';
const String ID_USUARIO_DEMO_SUP_CENTRO = 'usr-demo-sup-centro';
const String CODIGO_USUARIO_DEMO_SUP_CENTRO = '2001';
const String ID_USUARIO_DEMO_SUP_NORTE = 'usr-demo-sup-norte';
const String CODIGO_USUARIO_DEMO_SUP_NORTE = '2002';
const String ID_USUARIO_DEMO_EMP_CENTRO = 'usr-demo-emp-centro';
const String CODIGO_USUARIO_DEMO_EMP_CENTRO = '3001';

/// PIN demo supervisor (rol Supervisor en inicio de sesion).
const String PIN_USUARIO_DEMO_SUPERVISOR = '2345';

/// PIN demo empleado (rol Empleado en inicio de sesion).
const String PIN_USUARIO_DEMO_EMPLEADO = '3456';

/// Maximo de tiendas activas permitidas por licencia estandar.
const int LIMITE_MAX_TIENDAS = 5;

/// Identificadores de categorias demo para derivar modulo vertical.
const String ID_CAT_CARNICERIA = 'cat-carniceria';
const String ID_CAT_FARMACIA = 'cat-farmacia';
