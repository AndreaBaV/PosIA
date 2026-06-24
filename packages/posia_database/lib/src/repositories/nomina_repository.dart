/// Repositorio de periodos y lineas de nomina.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste calculos de nomina por periodo.
class NominaRepository {
	NominaRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<void> guardarPeriodo(PeriodoNomina periodo) async {
		await _baseDatos.insert(
			'periodos_nomina',
			{
				'id': periodo.id,
				'tienda_id': periodo.tiendaId,
				'inicio_en': periodo.inicioEn.toIso8601String(),
				'fin_en': periodo.finEn.toIso8601String(),
				'estado': periodo.estado,
				'cerrado_en': periodo.cerradoEn?.toIso8601String(),
				'cerrado_por': periodo.cerradoPor,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<List<PeriodoNomina>> listarPeriodos({String? tiendaId}) async {
		final filas = tiendaId == null
			? await _baseDatos.query(
				'periodos_nomina',
				orderBy: 'inicio_en DESC',
			)
			: await _baseDatos.query(
				'periodos_nomina',
				where: 'tienda_id = ? OR tienda_id IS NULL',
				whereArgs: [tiendaId],
				orderBy: 'inicio_en DESC',
			);
		return filas.map(_mapearPeriodo).toList();
	}

	Future<void> guardarLinea(LineaNomina linea) async {
		await _baseDatos.insert(
			'lineas_nomina',
			{
				'id': linea.id,
				'periodo_id': linea.periodoId,
				'usuario_id': linea.usuarioId,
				'horas_trabajadas': linea.horasTrabajadas,
				'tarifa_hora': linea.tarifaHora,
				'monto_bruto': linea.montoBruto,
				'monto_neto': linea.montoNeto,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<List<LineaNomina>> listarLineasPeriodo(String periodoId) async {
		final filas = await _baseDatos.query(
			'lineas_nomina',
			where: 'periodo_id = ?',
			whereArgs: [periodoId],
			orderBy: 'usuario_id ASC',
		);
		return filas.map(_mapearLinea).toList();
	}

	PeriodoNomina _mapearPeriodo(Map<String, Object?> fila) {
		final cerrado = fila['cerrado_en'] as String?;
		return PeriodoNomina(
			id: fila['id'] as String,
			tiendaId: fila['tienda_id'] as String?,
			inicioEn: DateTime.parse(fila['inicio_en'] as String),
			finEn: DateTime.parse(fila['fin_en'] as String),
			estado: fila['estado'] as String,
			cerradoEn: cerrado != null ? DateTime.parse(cerrado) : null,
			cerradoPor: fila['cerrado_por'] as String?,
		);
	}

	LineaNomina _mapearLinea(Map<String, Object?> fila) {
		return LineaNomina(
			id: fila['id'] as String,
			periodoId: fila['periodo_id'] as String,
			usuarioId: fila['usuario_id'] as String,
			horasTrabajadas: (fila['horas_trabajadas'] as num).toDouble(),
			tarifaHora: (fila['tarifa_hora'] as num).toDouble(),
			montoBruto: (fila['monto_bruto'] as num).toDouble(),
			montoNeto: (fila['monto_neto'] as num).toDouble(),
		);
	}
}
