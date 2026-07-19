/// Modelo de almacen o centro de distribucion.
library;

/// Almacen independiente o vinculado a tienda.
class Almacen {
	const Almacen({
		required this.id,
		required this.nombre,
		this.tiendaId,
		required this.activo,
		this.latitud,
		this.longitud,
		this.radioMetros = 150,
	});

	final String id;
	final String nombre;
	final String? tiendaId;
	final bool activo;
	final double? latitud;
	final double? longitud;
	final double radioMetros;

	/// Placeholder creado por integridad FK (sync fuera de orden).
	///
	/// No es un almacen de negocio; no debe proyectarse a Neon.
	bool get esStubFk =>
		nombre.trim() == 'Almacén' &&
		latitud == null &&
		longitud == null &&
		radioMetros == 150;

	Almacen copiarCon({
		String? id,
		String? nombre,
		String? tiendaId,
		bool? activo,
		double? latitud,
		double? longitud,
		double? radioMetros,
		bool limpiarTiendaId = false,
	}) {
		return Almacen(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			tiendaId: limpiarTiendaId ? null : (tiendaId ?? this.tiendaId),
			activo: activo ?? this.activo,
			latitud: latitud ?? this.latitud,
			longitud: longitud ?? this.longitud,
			radioMetros: radioMetros ?? this.radioMetros,
		);
	}
}

/// Stock en almacen (distinto de stock en tienda).
class StockAlmacen {
	const StockAlmacen({
		required this.productoId,
		required this.almacenId,
		required this.cantidad,
		required this.actualizadoEn,
		this.stockMinimo = 0,
	});

	final String productoId;
	final String almacenId;
	final double cantidad;
	final DateTime actualizadoEn;
	final double stockMinimo;
}
