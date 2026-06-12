/// Contexto de cotizacion para el motor de precios.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import '../enums/canal_venta.dart';
import 'cliente.dart';
import 'producto.dart';

/// Agrupa datos necesarios para resolver precio unitario.
class ContextoPrecio {
	/// Crea el contexto de precio para una cotizacion.
	///
	/// [producto] Producto a cotizar.
	/// [cantidad] Cantidad solicitada en unidades del producto.
	/// [tiendaId] Tienda donde se realiza la venta.
	/// [cliente] Cliente opcional; null indica mostrador.
	/// [canal] Canal comercial solicitado.
	const ContextoPrecio({
		required this.producto,
		required this.cantidad,
		required this.tiendaId,
		required this.cliente,
		required this.canal,
	});

	/// Producto sujeto a cotizacion.
	final Producto producto;

	/// Cantidad de unidades o kilogramos.
	final double cantidad;

	/// Identificador de tienda activa.
	final String tiendaId;

	/// Cliente seleccionado opcionalmente.
	final Cliente? cliente;

	/// Canal comercial de la cotizacion.
	final CanalVenta canal;
}
