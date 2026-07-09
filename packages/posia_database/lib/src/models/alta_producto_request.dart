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
		this.costoUnitario = 0.0,
		this.permiteStockNegativo = true,
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
	final double costoUnitario;
	final bool permiteStockNegativo;
}

/// Inventario agrupado por producto con existencias por tienda y almacén.
class InventarioAgrupado {
	const InventarioAgrupado({
		required this.productoId,
		required this.nombreProducto,
		required this.existenciasPorTienda,
		required this.existenciasPorTiendaId,
		required this.stockMinimoPorTiendaId,
		required this.stockMinimoLocal,
		required this.cantidadLocal,
		this.existenciasPorAlmacen = const {},
		this.existenciasPorAlmacenId = const {},
		this.stockMinimoPorAlmacenId = const {},
	});

	final String productoId;
	final String nombreProducto;
	final Map<String, double> existenciasPorTienda;
	final Map<String, double> existenciasPorTiendaId;
	final Map<String, double> stockMinimoPorTiendaId;
	final Map<String, double> existenciasPorAlmacen;
	final Map<String, double> existenciasPorAlmacenId;
	final Map<String, double> stockMinimoPorAlmacenId;
	final double stockMinimoLocal;
	final double cantidadLocal;

	/// Suma de existencias en todas las tiendas.
	double get totalGlobal {
		var suma = 0.0;
		for (final cantidad in existenciasPorTiendaId.values) {
			suma = suma + cantidad;
		}
		return suma;
	}

	/// Suma de existencias en todos los almacenes.
	double get totalAlmacenes {
		var suma = 0.0;
		for (final cantidad in existenciasPorAlmacenId.values) {
			suma = suma + cantidad;
		}
		return suma;
	}

	/// Total en tiendas + almacenes.
	double get totalEmpresa => totalGlobal + totalAlmacenes;

	double cantidadEn(String tiendaId) => existenciasPorTiendaId[tiendaId] ?? 0.0;

	double cantidadEnAlmacen(String almacenId) =>
		existenciasPorAlmacenId[almacenId] ?? 0.0;

	double stockMinimoEn(String tiendaId) => stockMinimoPorTiendaId[tiendaId] ?? 0.0;

	bool bajoMinimoEn(String tiendaId) {
		final minimo = stockMinimoEn(tiendaId);
		return cantidadEn(tiendaId) < minimo && minimo > 0.0;
	}

	bool get bajoMinimo => cantidadLocal < stockMinimoLocal && stockMinimoLocal > 0.0;
}
