/// Calculo de descuento por combos de precio fijo en el carrito activo.
library;

import 'package:posia_core/posia_core.dart';

/// Combo que completo al menos un set en el carrito, con su ahorro total.
class ComboAplicado {
	const ComboAplicado({
		required this.combo,
		required this.veces,
		required this.ahorro,
	});

	final Combo combo;

	/// Cuantos sets completos del combo caben en el carrito actual.
	final int veces;

	/// Ahorro total (MXN) por los [veces] sets completos.
	final double ahorro;
}

/// Determina que combos activos completan al menos un set en [lineas] y
/// cuanto ahorran en total.
///
/// Un combo exige al menos `cantidadRequerida` de **cada** miembro; cada set
/// completo cobra `precioCombo` en vez de la suma de precios normales de sus
/// miembros. Las lineas de presentacion fija (p. ej. escaneo directo de una
/// caja) no cuentan para el umbral, igual que en lotes de promocion.
List<ComboAplicado> combosAplicadosEnCarrito(
	Iterable<Combo> combosActivos,
	Iterable<LineaCarrito> lineas,
) {
	final resultado = <ComboAplicado>[];
	for (final combo in combosActivos) {
		if (combo.miembros.isEmpty) {
			continue;
		}
		var vecesCompleto = -1;
		final precioPromedioPorMiembro = <String, double>{};
		for (final miembro in combo.miembros) {
			final disponible = _disponibleParaMiembro(miembro.productoId, lineas);
			final requerida = miembro.cantidadRequerida > 0
				? miembro.cantidadRequerida
				: 1.0;
			final veces = (disponible.cantidad / requerida).floor();
			if (vecesCompleto == -1 || veces < vecesCompleto) {
				vecesCompleto = veces;
			}
			precioPromedioPorMiembro[miembro.productoId] = disponible.precioPromedio;
			if (vecesCompleto <= 0) {
				break;
			}
		}
		if (vecesCompleto <= 0) {
			continue;
		}
		var precioNormalPorSet = 0.0;
		for (final miembro in combo.miembros) {
			final requerida = miembro.cantidadRequerida > 0
				? miembro.cantidadRequerida
				: 1.0;
			precioNormalPorSet +=
				requerida * (precioPromedioPorMiembro[miembro.productoId] ?? 0.0);
		}
		final ahorroPorSet = precioNormalPorSet - combo.precioCombo;
		if (ahorroPorSet <= 0.0) {
			continue;
		}
		resultado.add(
			ComboAplicado(
				combo: combo,
				veces: vecesCompleto,
				ahorro: redondearMonto(ahorroPorSet * vecesCompleto),
			),
		);
	}
	return resultado;
}

/// Suma el descuento total de todos los combos aplicados en el carrito.
double calcularDescuentoCombos(
	Iterable<Combo> combosActivos,
	Iterable<LineaCarrito> lineas,
) {
	var total = 0.0;
	for (final aplicado in combosAplicadosEnCarrito(combosActivos, lineas)) {
		total += aplicado.ahorro;
	}
	return redondearMonto(total);
}

class _Disponible {
	const _Disponible({required this.cantidad, required this.precioPromedio});
	final double cantidad;
	final double precioPromedio;
}

_Disponible _disponibleParaMiembro(
	String productoId,
	Iterable<LineaCarrito> lineas,
) {
	var cantidad = 0.0;
	var valor = 0.0;
	for (final linea in lineas) {
		final stockId = linea.productoStockId;
		final esPresentacionFija = stockId != null && stockId != linea.producto.id;
		if (esPresentacionFija) {
			continue;
		}
		final idLinea = stockId ?? linea.producto.id;
		if (idLinea != productoId) {
			continue;
		}
		cantidad += linea.cantidad;
		valor += linea.cantidad * linea.precioUnitario;
	}
	if (cantidad <= 0.0) {
		return const _Disponible(cantidad: 0.0, precioPromedio: 0.0);
	}
	return _Disponible(cantidad: cantidad, precioPromedio: valor / cantidad);
}
