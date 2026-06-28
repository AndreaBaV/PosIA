/// Venta por peso con bascula opcional.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';

/// Resultado de lectura de peso desde bascula o entrada manual.
class ResultadoLecturaPeso {
	const ResultadoLecturaPeso({
		required this.pesoKg,
		required this.valido,
		required this.mensajeError,
	});

	final double pesoKg;
	final bool valido;
	final String mensajeError;
}

/// Lectura de bascula y validacion de peso para productos por kg.
class ServicioCarniceria {
	ServicioCarniceria({Scale? bascula}) : _bascula = bascula;

	final Scale? _bascula;

	Stream<double>? obtenerStreamPesoGramos() {
		final bascula = _bascula;
		if (bascula == null) {
			return null;
		}
		return bascula.pesoEstableGramos;
	}

	ResultadoLecturaPeso validarPesoParaVenta(double pesoKg) {
		if (pesoKg <= 0.0) {
			return const ResultadoLecturaPeso(
				pesoKg: 0.0,
				valido: false,
				mensajeError: 'El peso debe ser mayor a cero',
			);
		}
		if (!validarPesoMinimoKg(pesoKg)) {
			return ResultadoLecturaPeso(
				pesoKg: pesoKg,
				valido: false,
				mensajeError:
					'Peso minimo: ${formatearPesoKg(convertirGramosAKilogramos(PESO_MINIMO_GRAMOS_CARNICERIA))}',
			);
		}
		return ResultadoLecturaPeso(
			pesoKg: pesoKg,
			valido: true,
			mensajeError: '',
		);
	}

	ResultadoLecturaPeso procesarLecturaBascula(double gramos) {
		final pesoKg = convertirGramosAKilogramos(gramos);
		return validarPesoParaVenta(pesoKg);
	}

	bool productoRequierePeso(Producto producto) {
		return producto.requierePeso();
	}
}
