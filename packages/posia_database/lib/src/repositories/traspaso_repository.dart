/// Repositorio SQLite de traspasos entre tiendas.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 23:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';
import '../utils/transaccion_sqlite.dart';

/// Persiste solicitudes y recepciones de traspaso.
class TraspasoRepository {
	TraspasoRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	AseguradorPadresFk _padresPara(DatabaseExecutor? db) =>
		db == null ? _padresFk : AseguradorPadresFk(db);

	Future<void> guardar(Traspaso traspaso, {DatabaseExecutor? db}) async {
		final padres = _padresPara(db);
		await padres.asegurarPadresDeTraspaso(traspaso);
		await padres.asegurarTraspaso(traspaso.id);
		await ejecutarEscrituraTransaccional(_baseDatos, db, (tx) async {
			await tx.insert(
				'transfers',
				{
					'id': traspaso.id,
					'tienda_origen_id': traspaso.tiendaOrigenId,
					'tienda_destino_id': traspaso.tiendaDestinoId,
					'estado': traspaso.estado.name,
					'solicitado_en': traspaso.solicitadoEn.toIso8601String(),
					'completado_en': traspaso.completadoEn?.toIso8601String(),
					'notas': traspaso.notas,
				},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
			await tx.delete('transfer_lines', where: 'transfer_id = ?', whereArgs: [traspaso.id]);
			for (final linea in traspaso.lineas) {
				await tx.insert('transfer_lines', {
					'transfer_id': traspaso.id,
					'producto_id': linea.productoId,
					'cantidad_solicitada': linea.cantidadSolicitada,
					'cantidad_recibida': linea.cantidadRecibida,
				});
			}
		});
	}

	Future<List<Traspaso>> listarTodos() async {
		final filas = await _baseDatos.query('transfers', orderBy: 'solicitado_en DESC');
		final resultado = <Traspaso>[];
		for (final fila in filas) {
			resultado.add(await _mapear(fila));
		}
		return resultado;
	}

	Future<Traspaso?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'transfers',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<Traspaso> _mapear(Map<String, Object?> fila) async {
		final id = fila['id'] as String;
		final lineasFilas = await _baseDatos.query(
			'transfer_lines',
			where: 'transfer_id = ?',
			whereArgs: [id],
		);
		final lineas = lineasFilas
			.map(
				(l) => LineaTraspaso(
					productoId: l['producto_id'] as String,
					nombreProducto: '',
					cantidadSolicitada: l['cantidad_solicitada'] as double,
					cantidadRecibida: l['cantidad_recibida'] as double?,
				),
			)
			.toList();
		final completadoCrudo = fila['completado_en'] as String?;
		return Traspaso(
			id: id,
			tiendaOrigenId: fila['tienda_origen_id'] as String,
			tiendaDestinoId: fila['tienda_destino_id'] as String,
			estado: EstadoTraspaso.values.byName(fila['estado'] as String),
			solicitadoEn: DateTime.parse(fila['solicitado_en'] as String),
			completadoEn: completadoCrudo == null ? null : DateTime.parse(completadoCrudo),
			notas: fila['notas'] as String? ?? '',
			lineas: lineas,
		);
	}
}
