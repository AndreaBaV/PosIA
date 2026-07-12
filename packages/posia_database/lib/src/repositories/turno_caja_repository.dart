/// Repositorio SQLite de turnos de corte de caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Persiste aperturas y cierres de caja.
class TurnoCajaRepository {
	TurnoCajaRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<TurnoCaja?> obtenerPorId(String id, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'cash_shifts',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	/// Turno abierto de la tienda (compartido entre dispositivos de la sucursal).
	Future<TurnoCaja?> obtenerTurnoAbierto(String tiendaId, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'cash_shifts',
			where: 'tienda_id = ? AND estado = ?',
			whereArgs: [tiendaId, EstadoTurnoCaja.abierto.name],
			orderBy: 'abierto_en DESC',
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<void> guardar(TurnoCaja turno, {DatabaseExecutor? db}) async {
		await _padresFk.asegurarTienda(turno.tiendaId);
		await _padresFk.asegurarVendedor(turno.vendedorId, tiendaId: turno.tiendaId);
		final exec = db ?? _baseDatos;
		if (turno.estado == EstadoTurnoCaja.abierto) {
			await exec.update(
				'cash_shifts',
				{
					'estado': EstadoTurnoCaja.cerrado.name,
					'cerrado_en': DateTime.now().toUtc().toIso8601String(),
				},
				where: 'tienda_id = ? AND estado = ? AND id <> ?',
				whereArgs: [
					turno.tiendaId,
					EstadoTurnoCaja.abierto.name,
					turno.id,
				],
			);
		}
		await exec.insert(
			'cash_shifts',
			_mapearMapa(turno),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<List<TurnoCaja>> listarPorTienda(String tiendaId, {int limite = 20}) async {
		final filas = await _baseDatos.query(
			'cash_shifts',
			where: 'tienda_id = ?',
			whereArgs: [tiendaId],
			orderBy: 'abierto_en DESC',
			limit: limite,
		);
		return filas.map(_mapear).toList();
	}

	TurnoCaja _mapear(Map<String, Object?> fila) {
		final cerradoCrudo = fila['cerrado_en'] as String?;
		return TurnoCaja(
			id: fila['id'] as String,
			tiendaId: fila['tienda_id'] as String,
			cajaId: fila['caja_id'] as String,
			vendedorId: fila['vendedor_id'] as String?,
			fondoInicial: fila['fondo_inicial'] as double,
			totalEfectivo: fila['total_efectivo'] as double,
			totalTarjeta: fila['total_tarjeta'] as double,
			totalTransferencia: fila['total_transferencia'] as double,
			totalVentas: fila['total_ventas'] as double,
			cantidadVentas: fila['cantidad_ventas'] as int,
			abiertoEn: DateTime.parse(fila['abierto_en'] as String),
			cerradoEn: cerradoCrudo == null ? null : DateTime.parse(cerradoCrudo),
			estado: EstadoTurnoCaja.values.byName(fila['estado'] as String),
		);
	}

	Map<String, Object?> _mapearMapa(TurnoCaja turno) {
		return {
			'id': turno.id,
			'tienda_id': turno.tiendaId,
			'caja_id': turno.cajaId,
			'vendedor_id': turno.vendedorId,
			'fondo_inicial': turno.fondoInicial,
			'total_efectivo': turno.totalEfectivo,
			'total_tarjeta': turno.totalTarjeta,
			'total_transferencia': turno.totalTransferencia,
			'total_ventas': turno.totalVentas,
			'cantidad_ventas': turno.cantidadVentas,
			'abierto_en': turno.abiertoEn.toIso8601String(),
			'cerrado_en': turno.cerradoEn?.toIso8601String(),
			'estado': turno.estado.name,
		};
	}
}
