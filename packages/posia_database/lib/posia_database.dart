/// Barrel export de persistencia POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

export 'src/bootstrap/fabrica_servicios.dart';
export 'src/bootstrap/aprovisionador_dispositivo.dart';
export 'src/bootstrap/aprovisionador_offline.dart';
export 'src/database/migraciones_esquema.dart';
export 'src/database/posia_local_database.dart';
export 'src/models/alta_producto_request.dart';
export 'src/models/alerta_faltante.dart';
export 'src/models/config_dispositivo.dart';
export 'src/models/config_impresora.dart';
export 'src/models/estado_sync_admin.dart';
export 'src/models/item_lista_precios.dart';
export 'src/models/resumen_precios_producto.dart';
export 'src/models/resumen_vendedor.dart';
export 'src/models/resumen_ventas_dia.dart';
export 'src/models/resultado_importacion_productos.dart';
export 'src/models/resultado_reconciliacion_hub.dart';
export 'src/models/stock_por_tienda.dart';
export 'src/models/stock_por_almacen.dart';
export 'src/models/linea_compra_solicitud.dart';
export 'src/models/linea_pedido_solicitud.dart';
export 'src/repositories/pedido_repository.dart';
export 'src/models/linea_traspaso_solicitud.dart';
export 'src/repositories/compra_repository.dart';
export 'src/repositories/cotizacion_repository.dart';
export 'src/repositories/categoria_repository.dart';
export 'src/repositories/descuento_cliente_repository.dart';
export 'src/repositories/cliente_repository.dart';
export 'src/repositories/movimiento_inventario_repository.dart';
export 'src/repositories/proveedor_repository.dart';
export 'src/repositories/config_repository.dart';
export 'src/repositories/ticket_espera_repository.dart';
export 'src/repositories/tienda_repository.dart';
export 'src/repositories/inventario_repository.dart';
export 'src/repositories/lote_farmacia_repository.dart';
export 'src/repositories/precio_repository.dart';
export 'src/repositories/producto_repository.dart';
export 'src/repositories/sync_event_repository.dart';
export 'src/repositories/sync_state_repository.dart';
export 'src/repositories/traspaso_repository.dart';
export 'src/repositories/usuario_repository.dart';
export 'src/repositories/turno_caja_repository.dart';
export 'src/repositories/variante_repository.dart';
export 'src/repositories/vendedor_repository.dart';
export 'src/repositories/venta_repository.dart';
export 'src/services/servicio_admin.dart';
export 'src/services/servicio_autenticacion.dart';
export 'src/services/servicio_configuracion_dispositivo.dart';
export 'src/models/resultado_autenticacion.dart';
export 'src/models/motivo_fallo_auth.dart';
export 'src/services/servicio_caja.dart';
export 'src/services/servicio_carniceria.dart';
export 'src/repositories/almacen_repository.dart';
export 'src/repositories/asistencia_repository.dart';
export 'src/repositories/empleado_perfil_repository.dart';
export 'src/repositories/nomina_repository.dart';
export 'src/repositories/presentacion_repository.dart';
export 'src/services/servicio_asistencia.dart';
export 'src/services/servicio_nomina.dart';
export 'src/services/servicio_reconciliacion_hub.dart';
export 'src/utils/diagnostico_base_local.dart';
export 'src/utils/limpiador_base_local.dart';
