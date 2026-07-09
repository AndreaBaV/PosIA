/// Progreso reportado durante un ciclo de sincronizacion.
library;

/// Fases conocidas de sincronizacion manual.
class FaseProgresoSync {
	const FaseProgresoSync._();

	static const preparar = 'preparar';
	static const enviar = 'enviar';
	static const recibir = 'recibir';
	static const listo = 'listo';
}

/// Instantanea de avance para mostrar en UI.
class ProgresoSync {
	const ProgresoSync({
		required this.fase,
		required this.indice,
		required this.total,
		required this.mensaje,
	});

	final String fase;
	final int indice;
	final int total;
	final String mensaje;

	double? get fraccion => total > 0 ? indice / total : null;

	int get porcentaje =>
		total > 0 ? ((indice / total) * 100).round().clamp(0, 100) : 0;

	bool get tienePorcentaje => total > 0;
}

typedef ReporteProgresoSync = void Function(ProgresoSync progreso);
