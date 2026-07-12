/// Constantes globales del sistema POSIA.
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-07-12 11:55:00 (UTC-6)

library;

/// Version actual del esquema local SQLite.
const int SCHEMA_VERSION = 34;

/// Ultima version de esquema sin rebuild de FOREIGN KEY (pre-integridad).
const int SCHEMA_VERSION_PRE_INTEGRIDAD = 32;

/// Dias de retencion del log append-only `sync_events` en el hub.
const int DIAS_RETENCION_SYNC_EVENTS = 90;

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

/// Utilidad minima sobre costo de compra para cualquier precio de venta.
const double MARGEN_UTILIDAD_MINIMA_PORCENTAJE = 1.0;

/// Utilidad sugerida por defecto al calcular precio de venta.
const double UTILIDAD_SUGERIDA_PORCENTAJE = 25.0;

/// Plazo de credito predeterminado para clientes (dias).
const int DIAS_CREDITO_PREDETERMINADO = 15;

/// Umbral en minutos para marcar inventario remoto como desactualizado.
const int UMBRAL_STOCK_DESACTUALIZADO_MINUTOS = 15;

/// Puerto por defecto del servicio sync LAN.
const int PUERTO_SYNC_LAN_DEFAULT = 8765;

/// Intervalo del ciclo periodico de sincronizacion en segundos.
const int INTERVALO_SYNC_PERIODICO_SEGUNDOS = 60;

/// Ping periódico al hub para mantener la conexión activa (cada 10 min).
///
/// Útil en despliegues gratuitos o con auto-suspend por inactividad.
const int INTERVALO_MANTENER_HUB_VIVO_SEGUNDOS = 600;

/// Timeout HTTP normal de sync (falla rapido y reintenta en el siguiente ciclo).
const int TIMEOUT_HUB_SYNC_SEGUNDOS = 15;

/// Timeout del health check del hub.
///
/// Algunos planes gratuitos (Northflank spot, etc.) suspenden el contenedor por
/// inactividad y pueden tardar decenas de segundos en despertar en frío. Se
/// toleran 60 s en el ping inicial para que un dispositivo recién instalado no
/// vea "usuario no encontrado" por un falso negativo de red mientras el
/// servidor arranca.
const int TIMEOUT_HUB_DESPERTAR_SEGUNDOS = 60;

/// Eventos por lote al empujar la cola local al hub.
const int TAMANO_LOTE_SYNC_HUB = 40;

/// Si la cola local supera este umbral, no se reencola el catalogo completo
/// (evita multiplicar pendientes al pulsar "Sincronizar" varias veces).
const int UMBRAL_NO_REENCOLAR_CATALOGO = 200;

/// Nombre del servicio mDNS para descubrimiento LAN.
const String MDNS_SERVICIO_SYNC = 'posia-sync';

/// Longitud requerida del PIN de usuario y administrador.
const int LONGITUD_PIN_ADMIN = 4;

/// Indica build de produccion (release); false en debug/profile.
const bool MODO_RELEASE = bool.fromEnvironment('dart.vm.product');

/// Maximo de tiendas activas permitidas por licencia estandar.
const int LIMITE_MAX_TIENDAS = 5;

/// Maximo de cuentas de usuario activas por tenant en licencia estandar.
const int LIMITE_MAX_USUARIOS = 15;

/// Identificadores de categorias para derivar modulo vertical (carniceria / farmacia).
const String ID_CAT_CARNICERIA = 'cat-carniceria';
const String ID_CAT_FARMACIA = 'cat-farmacia';

/// Dias de vigencia por defecto en cotizaciones impresas.
const int VIGENCIA_COTIZACION_DIAS = 7;

/// Nombre comercial visible en interfaz, tickets y documentos.
const String NOMBRE_COMERCIAL_APP = 'La Fortuna';

/// Carpeta bajo Documents para tickets, etiquetas y archivos locales.
const String CARPETA_DOCUMENTOS_APP = 'La Fortuna';
