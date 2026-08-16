/// Contrato de gestion del historial en Neon (uso, export y purga).
library;

import '../constants/posia_constants.dart';

/// Grupos de historial que el usuario puede exportar o borrar en la nube.
///
/// Nunca incluye catalogo ni existencias vigentes: productos, clientes,
/// stock, precios, usuarios y sucursales se conservan.
abstract final class GruposHistorialNeon {
	GruposHistorialNeon._();

	static const ventas = 'ventas';
	static const compras = 'compras';
	static const traspasos = 'traspasos';
	static const asistencia = 'asistencia';
	static const nomina = 'nomina';
	static const turnos = 'turnos';
	static const cotizaciones = 'cotizaciones';
	static const pedidos = 'pedidos';
	static const logSync = 'logSync';

	static const todos = [
		ventas,
		compras,
		traspasos,
		asistencia,
		nomina,
		turnos,
		cotizaciones,
		pedidos,
		logSync,
	];

	static const etiquetas = {
		ventas: 'Ventas',
		compras: 'Compras',
		traspasos: 'Traspasos',
		asistencia: 'Asistencia',
		nomina: 'Nómina',
		turnos: 'Turnos de caja',
		cotizaciones: 'Cotizaciones',
		pedidos: 'Pedidos',
		logSync: 'Log de sincronización',
	};

	static const descripciones = {
		ventas: 'Tickets y líneas anteriores a la fecha',
		compras: 'Compras a proveedor y destinos de mercancía',
		traspasos: 'Envíos entre sucursales y almacenes',
		asistencia: 'Checadas y PIN de entrada ya vencidos',
		nomina: 'Periodos cerrados y líneas de pago',
		turnos: 'Aperturas y cortes de caja',
		cotizaciones: 'Presupuestos guardados (no el catálogo)',
		pedidos: 'Pedidos entregados o cancelados',
		logSync: 'Eventos transaccionales del log (no el catálogo)',
	};

	/// Tablas espejo que un grupo puede borrar. El log `sync_events` se
	/// filtra por tipo, no se borra entero.
	static const tablasPorGrupo = {
		ventas: ['sale_lines', 'sales'],
		compras: ['purchase_allocations', 'purchase_lines', 'purchases'],
		traspasos: ['transfer_lines', 'transfers'],
		asistencia: ['attendance_records', 'attendance_challenges'],
		nomina: ['payroll_lines', 'payroll_periods'],
		turnos: ['cash_shifts'],
		cotizaciones: ['quote_lines', 'quotes'],
		pedidos: ['order_lines', 'orders'],
		logSync: ['sync_events'],
	};

	static List<String> validar(Iterable<String> grupos) {
		return grupos.where(todos.contains).toSet().toList();
	}
}

/// Uso de una tabla en Neon.
class FilaUsoTablaNeon {
	const FilaUsoTablaNeon({
		required this.tabla,
		required this.filas,
		required this.bytes,
	});

	final String tabla;
	final int filas;
	final int bytes;

	Map<String, Object?> aJson() => {
		'tabla': tabla,
		'filas': filas,
		'bytes': bytes,
	};

	factory FilaUsoTablaNeon.desdeJson(Map<String, Object?> json) {
		return FilaUsoTablaNeon(
			tabla: json['tabla'] as String? ?? '',
			filas: (json['filas'] as num?)?.toInt() ?? 0,
			bytes: (json['bytes'] as num?)?.toInt() ?? 0,
		);
	}
}

/// Huella de almacenamiento del proyecto Neon.
class UsoBaseNeon {
	const UsoBaseNeon({
		required this.bytesUsados,
		this.bytesLimite = LIMITE_BYTES_NEON_FREE,
		this.tablas = const [],
	});

	final int bytesUsados;
	final int bytesLimite;
	final List<FilaUsoTablaNeon> tablas;

	double get fraccion {
		if (bytesLimite <= 0) {
			return 0;
		}
		return bytesUsados / bytesLimite;
	}

	bool get cercaDelLimite => fraccion >= 0.7;

	bool get sobreElLimite => fraccion >= 0.95;

	Map<String, Object?> aJson() => {
		'bytesUsados': bytesUsados,
		'bytesLimite': bytesLimite,
		'tablas': tablas.map((t) => t.aJson()).toList(),
	};

	factory UsoBaseNeon.desdeJson(Map<String, Object?> json) {
		return UsoBaseNeon(
			bytesUsados: (json['bytesUsados'] as num?)?.toInt() ?? 0,
			bytesLimite:
				(json['bytesLimite'] as num?)?.toInt() ?? LIMITE_BYTES_NEON_FREE,
			tablas: _mapas(json['tablas'])
				.map(FilaUsoTablaNeon.desdeJson)
				.toList(),
		);
	}
}

/// Hoja tabular para armar un Excel.
class HojaExportacionNeon {
	const HojaExportacionNeon({
		required this.nombre,
		required this.columnas,
		required this.filas,
	});

	final String nombre;
	final List<String> columnas;
	final List<List<String>> filas;

	Map<String, Object?> aJson() => {
		'nombre': nombre,
		'columnas': columnas,
		'filas': filas,
	};

	factory HojaExportacionNeon.desdeJson(Map<String, Object?> json) {
		final filasCrudas = json['filas'];
		final columnasCrudas = json['columnas'];
		return HojaExportacionNeon(
			nombre: json['nombre'] as String? ?? 'Hoja',
			columnas: columnasCrudas is List
				? [for (final c in columnasCrudas) '$c']
				: const [],
			filas: [
				if (filasCrudas is List)
					for (final f in filasCrudas)
						if (f is List) [for (final c in f) '$c'],
			],
		);
	}
}

/// Resultado de exportar historial desde Neon.
class ResultadoExportacionNeon {
	const ResultadoExportacionNeon({
		required this.hojas,
		this.truncado = false,
		this.antesDe,
	});

	final List<HojaExportacionNeon> hojas;
	final bool truncado;
	final DateTime? antesDe;

	int get filasTotales =>
		hojas.fold(0, (acc, h) => acc + h.filas.length);

	Map<String, Object?> aJson() => {
		'hojas': hojas.map((h) => h.aJson()).toList(),
		'truncado': truncado,
		if (antesDe != null) 'antesDe': antesDe!.toUtc().toIso8601String(),
	};

	factory ResultadoExportacionNeon.desdeJson(Map<String, Object?> json) {
		final antes = json['antesDe'] as String?;
		return ResultadoExportacionNeon(
			hojas: _mapas(json['hojas']).map(HojaExportacionNeon.desdeJson).toList(),
			truncado: json['truncado'] == true,
			antesDe: antes == null ? null : DateTime.tryParse(antes)?.toUtc(),
		);
	}
}

/// Resultado de borrar historial en Neon.
class ResultadoPurgaNeon {
	const ResultadoPurgaNeon({
		required this.filasEliminadas,
		this.grupos = const [],
	});

	final int filasEliminadas;
	final List<String> grupos;

	Map<String, Object?> aJson() => {
		'filasEliminadas': filasEliminadas,
		'grupos': grupos,
	};

	factory ResultadoPurgaNeon.desdeJson(Map<String, Object?> json) {
		final grupos = json['grupos'];
		return ResultadoPurgaNeon(
			filasEliminadas: (json['filasEliminadas'] as num?)?.toInt() ?? 0,
			grupos: grupos is List ? grupos.map((g) => '$g').toList() : const [],
		);
	}
}

List<Map<String, Object?>> _mapas(Object? crudo) {
	if (crudo is! List) {
		return const [];
	}
	return [
		for (final item in crudo)
			if (item is Map) Map<String, Object?>.from(item),
	];
}
