/// Catalogo de entradas del panel admin con palabras clave para busqueda.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../screens/pantalla_almacenes_admin.dart';
import '../screens/pantalla_asistencia_admin.dart';
import '../screens/pantalla_categorias_admin.dart';
import '../screens/pantalla_clientes_admin.dart';
import '../screens/pantalla_compras_admin.dart';
import '../screens/pantalla_configuracion_admin.dart';
import '../screens/pantalla_corte_caja.dart';
import '../screens/pantalla_cotizaciones_admin.dart';
import '../screens/pantalla_creditos_pendientes.dart';
import '../screens/pantalla_etiquetas_admin.dart';
import '../screens/pantalla_historial_ventas.dart';
import '../screens/pantalla_importar_productos_admin.dart';
import '../screens/pantalla_inventario_admin.dart';
import '../screens/pantalla_listas_precios_admin.dart';
import '../screens/pantalla_mi_cuenta.dart';
import '../screens/pantalla_movimientos_inventario.dart';
import '../screens/pantalla_nomina_admin.dart';
import '../screens/pantalla_pedidos_admin.dart';
import '../screens/pantalla_productos_admin.dart';
import '../screens/pantalla_promociones_admin.dart';
import '../screens/pantalla_proveedores_admin.dart';
import '../screens/pantalla_auditoria_precios.dart';
import '../screens/pantalla_reportes_admin.dart';
import '../screens/pantalla_roles_personalizados_admin.dart';
import '../screens/pantalla_sync_admin.dart';
import '../screens/pantalla_tipos_presentacion_admin.dart';
import '../screens/pantalla_tiendas_admin.dart';
import '../screens/pantalla_traspasos_admin.dart';
import '../screens/pantalla_usuarios_admin.dart';
import '../screens/pantalla_ventas_dia.dart';

/// Entrada navegable del menu de administracion.
class EntradaMenuAdmin {
	const EntradaMenuAdmin({
		required this.clave,
		required this.seccion,
		required this.titulo,
		required this.subtitulo,
		required this.icono,
		required this.color,
		required this.destino,
		this.palabrasClave = const [],
	});

	final String clave;
	final String seccion;
	final String titulo;
	final String subtitulo;
	final IconData icono;
	final Color color;
	final Widget destino;
	final List<String> palabrasClave;

	bool visiblePara(
		Usuario? usuario, {
		RolPersonalizado? rolPersonalizado,
	}) => tileAdminVisible(
		usuario,
		clave,
		rolPersonalizado: rolPersonalizado,
	);

	String get _textoBusqueda => [
		seccion,
		titulo,
		subtitulo,
		clave,
		...palabrasClave,
	].join(' ');

	bool coincideCon(String consulta) {
		final q = normalizarTextoBusqueda(consulta);
		if (q.isEmpty) {
			return true;
		}
		return normalizarTextoBusqueda(_textoBusqueda).contains(q);
	}
}

/// Entradas del panel admin visibles para el usuario, con palabras clave.
List<EntradaMenuAdmin> construirCatalogoMenuAdmin(
	Usuario? usuario, {
	RolPersonalizado? rolPersonalizado,
}) {
	const todas = [
		EntradaMenuAdmin(
			clave: 'mi_cuenta',
			seccion: 'Cuenta',
			titulo: 'Mi cuenta',
			subtitulo: 'Perfil y PIN',
			icono: Icons.account_circle,
			color: Colors.blueGrey,
			destino: PantallaMiCuenta(),
			palabrasClave: [
				'perfil', 'pin', 'contraseña', 'password', 'biometria', 'face id',
				'huella', 'sesion', 'usuario actual',
			],
		),
		EntradaMenuAdmin(
			clave: 'usuarios',
			seccion: 'Cuenta',
			titulo: 'Equipo',
			subtitulo: 'Cuentas, PIN y ventas',
			icono: Icons.groups,
			color: Colors.deepPurple,
			destino: PantallaUsuariosAdmin(),
			palabrasClave: [
				'usuarios', 'empleados', 'personal', 'vendedores', 'cuentas',
				'pin', 'codigo', 'rol', 'activar', 'desactivar', 'nueva cuenta',
			],
		),
		EntradaMenuAdmin(
			clave: 'asistencia',
			seccion: 'Cuenta',
			titulo: 'Asistencia',
			subtitulo: 'PIN entrada empleados',
			icono: Icons.pin,
			color: Colors.teal,
			destino: PantallaAsistenciaAdmin(),
			palabrasClave: [
				'asistencia', 'entrada', 'salida', 'checador', 'check-in',
				'gps', 'ubicacion', 'geolocalizacion', 'radio', 'desafio',
				'latitud', 'longitud', 'empleado', 'horario',
			],
		),
		EntradaMenuAdmin(
			clave: 'nomina',
			seccion: 'Cuenta',
			titulo: 'Nómina',
			subtitulo: 'Horas y tarifa',
			icono: Icons.payments,
			color: Color(0xFF388E3C),
			destino: PantallaNominaAdmin(),
			palabrasClave: [
				'nomina', 'sueldo', 'pago', 'horas', 'tarifa', 'salario',
				'empleado', 'trabajo',
			],
		),
		EntradaMenuAdmin(
			clave: 'roles_personalizados',
			seccion: 'Cuenta',
			titulo: 'Roles personalizados',
			subtitulo: 'Permisos granulares de admin',
			icono: Icons.admin_panel_settings,
			color: Colors.indigo,
			destino: PantallaRolesPersonalizadosAdmin(),
			palabrasClave: [
				'rol', 'permiso', 'acceso', 'pre-supervisor', 'personalizado',
				'categorias', 'restriccion', 'equipo',
			],
		),
		EntradaMenuAdmin(
			clave: 'ventas',
			seccion: 'Ventas',
			titulo: 'Ventas por tienda',
			subtitulo: 'Detalle multi-sucursal',
			icono: Icons.attach_money,
			color: PosiaColors.cobrar,
			destino: PantallaVentasDia(),
			palabrasClave: [
				'ventas', 'vendido', 'ingresos', 'tienda', 'sucursal', 'dia',
				'tickets', 'facturacion',
			],
		),
		EntradaMenuAdmin(
			clave: 'pedidos',
			seccion: 'Ventas',
			titulo: 'Pedidos',
			subtitulo: 'Recibir y asignar a empleados',
			icono: Icons.local_shipping,
			color: Colors.deepOrange,
			destino: PantallaPedidosAdmin(),
			palabrasClave: [
				'pedidos', 'orden', 'entrega', 'asignar', 'reparto', 'surte',
			],
		),
		EntradaMenuAdmin(
			clave: 'historial',
			seccion: 'Ventas',
			titulo: 'Historial',
			subtitulo: 'Ventas, pedidos y cancelaciones',
			icono: Icons.history,
			color: Colors.green,
			destino: PantallaHistorialVentas(),
			palabrasClave: [
				'historial', 'cancelacion', 'devolucion', 'ticket', 'venta pasada',
				'buscar venta', 'pedido', 'entrega', 'entregado',
			],
		),
		EntradaMenuAdmin(
			clave: 'creditos',
			seccion: 'Ventas',
			titulo: 'Créditos',
			subtitulo: 'Fiar, pendientes y liquidar',
			icono: Icons.account_balance_wallet,
			color: Color(0xFFFF8F00),
			destino: PantallaCreditosPendientes(),
			palabrasClave: [
				'credito', 'fiar', 'fiado', 'cobrar', 'pendiente', 'deuda',
				'cliente', 'liquidacion', 'abono',
			],
		),
		EntradaMenuAdmin(
			clave: 'cotizaciones',
			seccion: 'Ventas',
			titulo: 'Cotizaciones',
			subtitulo: 'Historial guardado',
			icono: Icons.request_quote,
			color: Colors.blueGrey,
			destino: PantallaCotizacionesAdmin(),
			palabrasClave: [
				'cotizacion', 'presupuesto', 'propuesta', 'quote',
			],
		),
		EntradaMenuAdmin(
			clave: 'corte',
			seccion: 'Ventas',
			titulo: 'Corte de caja',
			subtitulo: 'Abrir / cerrar turno',
			icono: Icons.point_of_sale,
			color: Colors.teal,
			destino: PantallaCorteCaja(),
			palabrasClave: [
				'corte', 'turno', 'caja', 'abrir', 'cerrar', 'efectivo',
				'arqueo', 'cierre',
			],
		),
		EntradaMenuAdmin(
			clave: 'categorias',
			seccion: 'Catálogo',
			titulo: 'Categorías',
			subtitulo: 'Iconos, color y orden',
			icono: Icons.category,
			color: Colors.orange,
			destino: PantallaCategoriasAdmin(),
			palabrasClave: [
				'categoria', 'icono', 'color', 'orden', 'departamento', 'grupo',
			],
		),
		EntradaMenuAdmin(
			clave: 'productos',
			seccion: 'Catálogo',
			titulo: 'Productos',
			subtitulo: 'Catálogo unificado',
			icono: Icons.inventory_2,
			color: PosiaColors.neutro,
			destino: PantallaProductosAdmin(),
			palabrasClave: [
				'producto', 'catalogo', 'articulo', 'sku', 'codigo barras',
				'precio', 'costo', 'empaque', 'mayoreo', 'presentacion', 'stock',
				'nuevo producto', 'editar producto',
			],
		),
		EntradaMenuAdmin(
			clave: 'importar_productos',
			seccion: 'Catálogo',
			titulo: 'Importar productos',
			subtitulo: 'Carga masiva CSV / Excel',
			icono: Icons.upload_file,
			color: Colors.teal,
			destino: PantallaImportarProductosAdmin(),
			palabrasClave: [
				'importar', 'excel', 'csv', 'xlsx', 'lote', 'masivo', 'bulk',
				'plantilla', 'carga', 'archivo', 'productos',
			],
		),
		EntradaMenuAdmin(
			clave: 'etiquetas',
			seccion: 'Catálogo',
			titulo: 'Etiquetas',
			subtitulo: 'PDF con código de barras',
			icono: Icons.label,
			color: Colors.blueGrey,
			destino: PantallaEtiquetasAdmin(),
			palabrasClave: [
				'etiqueta', 'pdf', 'imprimir', 'codigo barras', 'gondola', 'precio',
			],
		),
		EntradaMenuAdmin(
			clave: 'precios',
			seccion: 'Catálogo',
			titulo: 'Listas de precios',
			subtitulo: 'Precios por lista y clientes',
			icono: Icons.sell,
			color: Colors.green,
			destino: PantallaListasPreciosAdmin(),
			palabrasClave: [
				'lista precios', 'mayoreo', 'menudeo', 'distribuidor', 'precio especial',
				'cliente', 'descuento lista',
			],
		),
		EntradaMenuAdmin(
			clave: 'promociones',
			seccion: 'Catálogo',
			titulo: 'Promociones',
			subtitulo: 'Lotes de mayoreo y combos',
			icono: Icons.local_offer,
			color: Colors.pink,
			destino: PantallaPromocionesAdmin(),
			palabrasClave: [
				'promocion', 'lote', 'mayoreo', 'combo', 'oferta', 'descuento',
				'kit', 'paquete', 'sopas', 'familia', 'variantes',
			],
		),
		EntradaMenuAdmin(
			clave: 'existencias',
			seccion: 'Inventario',
			titulo: 'Existencias',
			subtitulo: 'Multi-tienda',
			icono: Icons.warehouse,
			color: Colors.blueGrey,
			destino: PantallaInventarioAdmin(),
			palabrasClave: [
				'existencias', 'inventario', 'stock', 'cantidad', 'multi tienda',
				'consultar stock',
			],
		),
		EntradaMenuAdmin(
			clave: 'compras',
			seccion: 'Inventario',
			titulo: 'Compras',
			subtitulo: 'Proveedor, productos y costo',
			icono: Icons.shopping_cart,
			color: Colors.brown,
			destino: PantallaComprasAdmin(),
			palabrasClave: [
				'compra', 'entrada', 'mercancia', 'proveedor', 'costo', 'factura compra',
				'recepcion',
			],
		),
		EntradaMenuAdmin(
			clave: 'movimientos',
			seccion: 'Inventario',
			titulo: 'Movimientos',
			subtitulo: 'Salidas y ajustes',
			icono: Icons.swap_vert,
			color: Colors.indigo,
			destino: PantallaMovimientosInventario(),
			palabrasClave: [
				'movimiento', 'salida', 'ajuste', 'merma', 'robo', 'caducidad',
				'inventario fisico',
			],
		),
		EntradaMenuAdmin(
			clave: 'traspasos',
			seccion: 'Inventario',
			titulo: 'Traspasos',
			subtitulo: 'Entre sucursales',
			icono: Icons.swap_horiz,
			color: Colors.cyan,
			destino: PantallaTraspasosAdmin(),
			palabrasClave: [
				'traspaso', 'transferencia', 'sucursal', 'envio', 'recibir mercancia',
			],
		),
		EntradaMenuAdmin(
			clave: 'almacenes',
			seccion: 'Inventario',
			titulo: 'Almacenes',
			subtitulo: 'Centros de distribución',
			icono: Icons.inventory,
			color: Colors.blue,
			destino: PantallaAlmacenesAdmin(),
			palabrasClave: [
				'almacen', 'bodega', 'cedis', 'distribucion', 'centro',
			],
		),
		EntradaMenuAdmin(
			clave: 'presentaciones',
			seccion: 'Inventario',
			titulo: 'Presentaciones',
			subtitulo: 'Tipos caja/bulto',
			icono: Icons.layers,
			color: Color(0xFFE65100),
			destino: PantallaTiposPresentacionAdmin(),
			palabrasClave: [
				'presentacion', 'caja', 'bulto', 'empaque', 'kilogramo', 'tipo empaque',
				'conversion',
			],
		),
		EntradaMenuAdmin(
			clave: 'clientes',
			seccion: 'Personas',
			titulo: 'Clientes',
			subtitulo: 'Gestión de clientes',
			icono: Icons.people,
			color: Colors.blue,
			destino: PantallaClientesAdmin(),
			palabrasClave: [
				'cliente', 'credito', 'lista precios', 'contacto', 'telefono',
			],
		),
		EntradaMenuAdmin(
			clave: 'proveedores',
			seccion: 'Personas',
			titulo: 'Proveedores',
			subtitulo: 'Gestión de proveedores',
			icono: Icons.local_shipping,
			color: Colors.brown,
			destino: PantallaProveedoresAdmin(),
			palabrasClave: [
				'proveedor', 'supplier', 'compra', 'contacto proveedor',
			],
		),
		EntradaMenuAdmin(
			clave: 'tiendas',
			seccion: 'Reportes y sistema',
			titulo: 'Tiendas',
			subtitulo: 'Alta, baja y límite 5',
			icono: Icons.store,
			color: Colors.deepOrange,
			destino: PantallaTiendasAdmin(),
			palabrasClave: [
				'tienda', 'sucursal', 'sucursales', 'latitud', 'longitud', 'gps',
				'ubicacion', 'coordenadas', 'geolocalizacion', 'asistencia',
				'radio', 'direccion', 'alta tienda',
			],
		),
		EntradaMenuAdmin(
			clave: 'reportes',
			seccion: 'Reportes y sistema',
			titulo: 'Reportes',
			subtitulo: 'Ventas y alertas',
			icono: Icons.assessment,
			color: Colors.purple,
			destino: PantallaReportesAdmin(),
			palabrasClave: [
				'reporte', 'estadistica', 'alerta', 'exportar', 'excel', 'resumen',
			],
		),
		EntradaMenuAdmin(
			clave: 'auditoria_precios',
			seccion: 'Reportes y sistema',
			titulo: 'Precios manuales',
			subtitulo: 'Auditoría de sobreprecio',
			icono: Icons.price_change_outlined,
			color: Colors.deepOrange,
			destino: PantallaAuditoriaPrecios(),
			palabrasClave: [
				'precio manual', 'sobreprecio', 'descuento', 'auditoria', 'auditar',
				'empleado', 'vendedor', 'manual',
			],
		),
		EntradaMenuAdmin(
			clave: 'sync',
			seccion: 'Reportes y sistema',
			titulo: 'Estado de la nube',
			subtitulo: 'Sync automática',
			icono: Icons.cloud_sync,
			color: Colors.indigo,
			destino: PantallaSyncAdmin(),
			palabrasClave: [
				'sync', 'sincronizacion', 'nube', 'cloud', 'servidor', 'conexion',
				'respaldo', 'online', 'offline', 'hub',
			],
		),
		EntradaMenuAdmin(
			clave: 'config',
			seccion: 'Reportes y sistema',
			titulo: 'Configuración',
			subtitulo: 'PIN y dispositivo',
			icono: Icons.settings,
			color: Colors.grey,
			destino: PantallaConfiguracionAdmin(),
			palabrasClave: [
				'configuracion', 'ajustes', 'pin admin', 'dispositivo', 'atajos',
				'teclado', 'impresora', 'licencia', 'opciones',
			],
		),
	];

	return todas
		.where((e) => e.visiblePara(usuario, rolPersonalizado: rolPersonalizado))
		.toList();
}

/// Filtra entradas del catalogo por consulta de texto.
List<EntradaMenuAdmin> filtrarCatalogoMenuAdmin(
	List<EntradaMenuAdmin> entradas,
	String consulta,
) {
	final q = consulta.trim();
	if (q.isEmpty) {
		return entradas;
	}
	return entradas.where((e) => e.coincideCon(q)).toList();
}

/// Agrupa entradas por nombre de seccion conservando el orden de aparicion.
Map<String, List<EntradaMenuAdmin>> agruparPorSeccion(
	List<EntradaMenuAdmin> entradas,
) {
	final mapa = <String, List<EntradaMenuAdmin>>{};
	for (final e in entradas) {
		mapa.putIfAbsent(e.seccion, () => []).add(e);
	}
	return mapa;
}

