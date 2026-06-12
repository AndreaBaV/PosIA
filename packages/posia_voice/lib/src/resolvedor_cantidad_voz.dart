/// Resuelve cantidad de venta segun unidad hablada y catalogo.
library;

import 'package:posia_core/posia_core.dart';

/// Resultado de convertir cantidad hablada a cantidad de venta.
class CantidadVozResuelta {
	const CantidadVozResuelta({
		required this.cantidadVenta,
		required this.descripcion,
	});

	/// Cantidad a registrar en carrito.
	final double cantidadVenta;

	/// Texto legible para confirmacion (ej. "1 caja = 12 pzas").
	final String descripcion;
}

/// Convierte unidades habladas a cantidad comercial del producto.
class ResolvedorCantidadVoz {
	/// Calcula cantidad de venta y descripcion para UI.
	CantidadVozResuelta resolver({
		required double cantidadHablada,
		required UnidadMedida? unidadHablada,
		required Producto producto,
	}) {
		final unidad = unidadHablada ?? producto.unidadMedida;

		if (unidad == UnidadMedida.caja) {
			if (producto.unidadMedida == UnidadMedida.caja) {
				return CantidadVozResuelta(
					cantidadVenta: cantidadHablada,
					descripcion: '$cantidadHablada caja(s)',
				);
			}
			final piezas = producto.piezasPorCaja;
			if (piezas != null && piezas > 1) {
				final total = cantidadHablada * piezas;
				return CantidadVozResuelta(
					cantidadVenta: total,
					descripcion:
						'$cantidadHablada caja(s) × $piezas ${producto.unidadMedida.name} = $total',
				);
			}
			return CantidadVozResuelta(
				cantidadVenta: cantidadHablada,
				descripcion: '$cantidadHablada caja(s) (1 unidad por caja)',
			);
		}

		if (unidad == UnidadMedida.kilogramo) {
			if (producto.unidadMedida == UnidadMedida.kilogramo ||
				producto.requierePeso()) {
				return CantidadVozResuelta(
					cantidadVenta: cantidadHablada,
					descripcion: '$cantidadHablada kg',
				);
			}
			if (producto.unidadMedida == UnidadMedida.pieza &&
				producto.nombre.toLowerCase().contains('kg')) {
				return CantidadVozResuelta(
					cantidadVenta: cantidadHablada,
					descripcion: '$cantidadHablada bolsa(s) de ${producto.nombre}',
				);
			}
		}

		if (unidad == UnidadMedida.litro && producto.unidadMedida == UnidadMedida.litro) {
			return CantidadVozResuelta(
				cantidadVenta: cantidadHablada,
				descripcion: '$cantidadHablada L',
			);
		}

		if (unidad == UnidadMedida.pieza) {
			return CantidadVozResuelta(
				cantidadVenta: cantidadHablada,
				descripcion: '$cantidadHablada pza(s)',
			);
		}

		return CantidadVozResuelta(
			cantidadVenta: cantidadHablada,
			descripcion: '$cantidadHablada ${producto.unidadMedida.name}',
		);
	}
}
