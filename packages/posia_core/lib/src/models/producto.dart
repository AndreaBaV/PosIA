/// Modelo inmutable de producto comercial.
library;

import '../enums/modulo_vertical.dart';
import '../enums/unidad_medida.dart';

/// Representa un articulo vendible en catalogo.
class Producto {
	const Producto({
		required this.id,
		required this.nombre,
		required this.codigoBarras,
		required this.precioBase,
		required this.unidadMedida,
		required this.rutaImagen,
		required this.activo,
		required this.tiendaId,
		this.moduloVertical = ModuloVertical.general,
		this.categoriaId,
		this.piezasPorCaja,
		this.unidadesPorBulto,
		this.proveedorId,
		this.notas = '',
		this.costoUnitario = 0.0,
		this.favoritoCaja = false,
	});

	final String id;
	final String nombre;
	final String codigoBarras;
	final double precioBase;
	final UnidadMedida unidadMedida;
	final String rutaImagen;
	final bool activo;
	final String tiendaId;
	final ModuloVertical moduloVertical;
	final String? categoriaId;
	final int? piezasPorCaja;
	final int? unidadesPorBulto;
	final String? proveedorId;
	final String notas;
	final double costoUnitario;
	final bool favoritoCaja;

	bool requierePeso() {
		return moduloVertical == ModuloVertical.carniceria &&
			unidadMedida == UnidadMedida.kilogramo;
	}

	bool requiereLote() {
		return moduloVertical == ModuloVertical.farmacia;
	}

	Producto copiarCon({
		String? id,
		String? nombre,
		String? codigoBarras,
		double? precioBase,
		UnidadMedida? unidadMedida,
		String? rutaImagen,
		bool? activo,
		String? tiendaId,
		ModuloVertical? moduloVertical,
		String? categoriaId,
		int? piezasPorCaja,
		int? unidadesPorBulto,
		String? proveedorId,
		String? notas,
		double? costoUnitario,
		bool? favoritoCaja,
	}) {
		return Producto(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			codigoBarras: codigoBarras ?? this.codigoBarras,
			precioBase: precioBase ?? this.precioBase,
			unidadMedida: unidadMedida ?? this.unidadMedida,
			rutaImagen: rutaImagen ?? this.rutaImagen,
			activo: activo ?? this.activo,
			tiendaId: tiendaId ?? this.tiendaId,
			moduloVertical: moduloVertical ?? this.moduloVertical,
			categoriaId: categoriaId ?? this.categoriaId,
			piezasPorCaja: piezasPorCaja ?? this.piezasPorCaja,
			unidadesPorBulto: unidadesPorBulto ?? this.unidadesPorBulto,
			proveedorId: proveedorId ?? this.proveedorId,
			notas: notas ?? this.notas,
			costoUnitario: costoUnitario ?? this.costoUnitario,
			favoritoCaja: favoritoCaja ?? this.favoritoCaja,
		);
	}
}
