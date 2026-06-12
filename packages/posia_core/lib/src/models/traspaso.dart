/// Traspaso de mercancia entre sucursales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 23:30:00 (UTC-6)
library;

import '../enums/estado_traspaso.dart';

/// Linea de producto en un traspaso.
class LineaTraspaso {
	const LineaTraspaso({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidadSolicitada,
		this.cantidadRecibida,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidadSolicitada;
	final double? cantidadRecibida;
}

/// Solicitud de transferencia entre tiendas.
class Traspaso {
	const Traspaso({
		required this.id,
		required this.tiendaOrigenId,
		required this.tiendaDestinoId,
		required this.estado,
		required this.solicitadoEn,
		required this.completadoEn,
		required this.notas,
		required this.lineas,
	});

	final String id;
	final String tiendaOrigenId;
	final String tiendaDestinoId;
	final EstadoTraspaso estado;
	final DateTime solicitadoEn;
	final DateTime? completadoEn;
	final String notas;
	final List<LineaTraspaso> lineas;
}
