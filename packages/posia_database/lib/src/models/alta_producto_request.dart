/// Datos para alta o edicion completa de producto.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';

/// Solicitud de persistencia de producto con precios y stock inicial.
class AltaProductoRequest {
	const AltaProductoRequest({
		required this.nombre,
		required this.codigoBarras,
		required this.precioBase,
		required this.categoriaId,
		this.unidadMedida = UnidadMedida.pieza,
		this.piezasPorCaja,
		this.unidadesPorBulto,
		this.proveedorId,
		this.notas = '',
		this.activo = true,
		this.stockInicial = 0.0,
		this.stockMinimo = 0.0,
		this.escalasMayoreo = const [],
	});

	final String nombre;
	final String codigoBarras;
	final double precioBase;
	final String categoriaId;
	final UnidadMedida unidadMedida;
	final int? piezasPorCaja;
	final int? unidadesPorBulto;
	final String? proveedorId;
	final String notas;
	final bool activo;
	final double stockInicial;
	final double stockMinimo;
	final List<EscalaMayoreo> escalasMayoreo;
}

/// Inventario agrupado por producto con existencias por tienda.
class InventarioAgrupado {
	const InventarioAgrupado({
		required this.productoId,
		required this.nombreProducto,
		required this.existenciasPorTienda,
		required this.stockMinimoLocal,
		required this.cantidadLocal,
	});

	final String productoId;
	final String nombreProducto;
	final Map<String, double> existenciasPorTienda;
	final double stockMinimoLocal;
	final double cantidadLocal;

	double get totalGlobal {
		var suma = 0.0;
		for (final cantidad in existenciasPorTienda.values) {
			suma = suma + cantidad;
		}
		return suma;
	}

	bool get bajoMinimo => cantidadLocal < stockMinimoLocal && stockMinimoLocal > 0.0;
}
