/// Contrato de acceso a datos de precios comerciales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'models/escala_mayoreo.dart';
import 'models/precio_cliente_producto.dart';

/// Provee datos de precios para el motor de resolucion.
abstract class RepositorioPrecio {
	/// Obtiene precio preferencial cliente-producto si existe.
	///
	/// [clienteId] Identificador del cliente.
	/// [productoId] Identificador del producto.
	/// Retorna precio override o null si no hay registro.
	Future<PrecioClienteProducto?> obtenerPrecioClienteProducto(
		String clienteId,
		String productoId,
	);

	/// Obtiene precio de lista comercial para producto.
	///
	/// [listaPreciosId] Identificador de lista asignada al cliente.
	/// [productoId] Producto a consultar.
	/// Retorna precio de lista o null si no existe entrada.
	Future<double?> obtenerPrecioLista(String listaPreciosId, String productoId);

	/// Obtiene escalas de mayoreo ordenadas por cantidad minima.
	///
	/// [productoId] Producto a consultar.
	/// Retorna lista de escalas disponibles.
	Future<List<EscalaMayoreo>> obtenerEscalasMayoreo(String productoId);
}
