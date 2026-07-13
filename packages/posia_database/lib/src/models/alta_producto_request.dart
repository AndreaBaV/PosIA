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
		this.precioCaja,
		this.codigoCaja = '',
		this.lotePromocionCodigo,
		this.presentaciones = const [],
		this.categoriaACrear,
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

	/// Precio total de la presentacion caja (opcional; si falta se deriva).
	final double? precioCaja;

	/// Codigo de barras de la caja (opcional).
	final String codigoCaja;

	/// Codigo de lote de promocion del archivo (ej. "1"); null = sin lote.
	final String? lotePromocionCodigo;

	/// Presentaciones adicionales (granel: gramos → factor a kilo).
	final List<PresentacionImportacionSolicitud> presentaciones;

	/// Si no es null, la categoria se crea al importar (aún no existe en catalogo).
	final String? categoriaACrear;

	AltaProductoRequest copiarCon({
		String? nombre,
		String? codigoBarras,
		double? precioBase,
		String? categoriaId,
		UnidadMedida? unidadMedida,
		int? piezasPorCaja,
		int? unidadesPorBulto,
		String? proveedorId,
		String? notas,
		bool? activo,
		double? stockInicial,
		double? stockMinimo,
		List<EscalaMayoreo>? escalasMayoreo,
		double? costoUnitario,
		bool? permiteStockNegativo,
		double? precioCaja,
		String? codigoCaja,
		String? lotePromocionCodigo,
		List<PresentacionImportacionSolicitud>? presentaciones,
		String? categoriaACrear,
		bool limpiarCategoriaACrear = false,
	}) {
		return AltaProductoRequest(
			nombre: nombre ?? this.nombre,
			codigoBarras: codigoBarras ?? this.codigoBarras,
			precioBase: precioBase ?? this.precioBase,
			categoriaId: categoriaId ?? this.categoriaId,
			unidadMedida: unidadMedida ?? this.unidadMedida,
			piezasPorCaja: piezasPorCaja ?? this.piezasPorCaja,
			unidadesPorBulto: unidadesPorBulto ?? this.unidadesPorBulto,
			proveedorId: proveedorId ?? this.proveedorId,
			notas: notas ?? this.notas,
			activo: activo ?? this.activo,
			stockInicial: stockInicial ?? this.stockInicial,
			stockMinimo: stockMinimo ?? this.stockMinimo,
			escalasMayoreo: escalasMayoreo ?? this.escalasMayoreo,
			costoUnitario: costoUnitario ?? this.costoUnitario,
			permiteStockNegativo:
					permiteStockNegativo ?? this.permiteStockNegativo,
			precioCaja: precioCaja ?? this.precioCaja,
			codigoCaja: codigoCaja ?? this.codigoCaja,
			lotePromocionCodigo: lotePromocionCodigo ?? this.lotePromocionCodigo,
			presentaciones: presentaciones ?? this.presentaciones,
			categoriaACrear: limpiarCategoriaACrear
					? null
					: (categoriaACrear ?? this.categoriaACrear),
		);
	}
}

/// Presentacion a crear al importar (factor relativo a la unidad base).
class PresentacionImportacionSolicitud {
	const PresentacionImportacionSolicitud({
		required this.nombre,
		required this.factorABase,
		required this.precio,
		this.esPresentacionBase = false,
	});

	final String nombre;
	final double factorABase;
	final double precio;
	final bool esPresentacionBase;
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
