/// Resultado de resolucion de precio unitario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import '../enums/regla_precio.dart';

/// Contiene precio resuelto y regla aplicada para auditoria.
class ResultadoPrecio {
	/// Crea resultado de cotizacion.
	///
	/// [precioUnitario] Precio final por unidad en MXN.
	/// [reglaAplicada] Regla que determino el precio.
	const ResultadoPrecio({
		required this.precioUnitario,
		required this.reglaAplicada,
	});

	/// Precio unitario final redondeado.
	final double precioUnitario;

	/// Regla comercial aplicada.
	final ReglaPrecio reglaAplicada;
}
