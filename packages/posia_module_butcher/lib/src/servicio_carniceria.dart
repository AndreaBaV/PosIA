/// Servicio de venta por peso para modulo carniceria.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';

import 'util_peso.dart';

/// Resultado de lectura de peso desde bascula o entrada manual.
class ResultadoLecturaPeso {
	/// Crea resultado de lectura de peso.
	///
	/// [pesoKg] Peso en kilogramos listo para venta.
	/// [valido] Indica si cumple reglas minimas.
	/// [mensajeError] Detalle cuando [valido] es falso.
	const ResultadoLecturaPeso({
		required this.pesoKg,
		required this.valido,
		required this.mensajeError,
	});

	/// Peso en kilogramos.
	final double pesoKg;

	/// Bandera de validez comercial.
	final bool valido;

	/// Mensaje de error para UI cuando aplica.
	final String mensajeError;
}

/// Coordina lectura de bascula y validacion de peso en carniceria.
class ServicioCarniceria {
	/// Crea servicio con bascula opcional conectada.
	///
	/// [bascula] Driver de bascula configurado o null para modo manual.
	ServicioCarniceria({Scale? bascula}) : _bascula = bascula;

	final Scale? _bascula;

	/// Obtiene stream de peso estable si hay bascula conectada.
	///
	/// Retorna stream en gramos o null sin hardware.
	Stream<double>? obtenerStreamPesoGramos() {
		final bascula = _bascula;
		if (bascula == null) {
			return null;
		}
		return bascula.pesoEstableGramos;
	}

	/// Valida peso manual o de bascula para venta.
	///
	/// [pesoKg] Peso capturado en kilogramos.
	/// Retorna [ResultadoLecturaPeso] con estado de validacion.
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
				mensajeError: 'Peso minimo: ${formatearPesoKg(convertirGramosAKilogramos(PESO_MINIMO_GRAMOS_CARNICERIA))}',
			);
		}
		return ResultadoLecturaPeso(
			pesoKg: pesoKg,
			valido: true,
			mensajeError: '',
		);
	}

	/// Convierte lectura de bascula en gramos a resultado de venta.
	///
	/// [gramos] Peso estable en gramos desde hardware.
	/// Retorna resultado validado en kilogramos.
	ResultadoLecturaPeso procesarLecturaBascula(double gramos) {
		final pesoKg = convertirGramosAKilogramos(gramos);
		return validarPesoParaVenta(pesoKg);
	}

	/// Verifica que producto pertenezca al flujo de carniceria.
	///
	/// [producto] Producto seleccionado en caja.
	/// Retorna verdadero si requiere captura de peso.
	bool productoRequierePeso(Producto producto) {
		return producto.requierePeso();
	}
}
