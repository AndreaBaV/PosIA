/// Resultado de reconciliar SQLite local con el hub en la nube.
library;

import 'package:posia_sync/posia_sync.dart';

/// Accion tomada durante la reconciliacion.
enum AccionReconciliacionHub {
	/// Sin hub configurado o hub no disponible.
	omitida,

	/// Solo sincronizacion incremental; los datos locales coinciden.
	incremental,

	/// Base vacia o con datos de ejemplo: pull completo desde la nube.
	pullCompleto,

	/// Datos locales desalineados con la nube: limpieza y pull completo.
	reconstruidaDesdeNube,
}

/// Resumen de una reconciliacion local ↔ hub.
class ResultadoReconciliacionHub {
	const ResultadoReconciliacionHub({
		required this.accion,
		required this.hubDisponible,
		this.datosEjemploEliminados = false,
		this.datosOperativosLimpiados = false,
		this.cursorReiniciado = false,
		this.tiendasCoinciden = true,
		this.sync = const ResultadoSync(
			eventosEnviados: 0,
			eventosRecibidos: 0,
			hubDisponible: false,
		),
	});

	final AccionReconciliacionHub accion;
	final bool hubDisponible;
	final bool datosEjemploEliminados;
	final bool datosOperativosLimpiados;
	final bool cursorReiniciado;
	final bool tiendasCoinciden;
	final ResultadoSync sync;
}
