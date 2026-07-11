/// Repositorio SQLite de tiendas o sucursales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../seed/placeholders_ejemplo.dart';

/// Persiste y consulta sucursales del tenant.
class TiendaRepository {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	TiendaRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Lista tiendas activas ordenadas por nombre.
	///
	/// Retorna sucursales habilitadas para operacion.
	Future<List<Tienda>> listarActivas() async {
		final filas = await _baseDatos.query(
			'stores',
			where: 'activa = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearTienda).toList();
	}

	/// Lista tiendas activas excluyendo placeholders de desarrollo.
	Future<List<Tienda>> listarActivasOperativas() async {
		final filas = await _baseDatos.query(
			'stores',
			where: 'activa = 1 AND id <> ?',
			whereArgs: [IdsEjemplo.tienda],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearTienda).toList();
	}

	/// Lista todas las tiendas incluyendo inactivas.
	Future<List<Tienda>> listarTodas() async {
		final filas = await _baseDatos.query(
			'stores',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearTienda).toList();
	}

	/// Cuenta tiendas activas para validar limite de licencia.
	Future<int> contarActivas() async {
		final resultado = Sqflite.firstIntValue(
			await _baseDatos.rawQuery('SELECT COUNT(*) FROM stores WHERE activa = 1'),
		);
		return resultado ?? 0;
	}

	/// Guarda o actualiza tienda.
	Future<void> guardar(Tienda tienda) async {
		await _baseDatos.insert(
			'stores',
			{
				'id': tienda.id,
				'nombre': tienda.nombre,
				'direccion': tienda.direccion,
				'activa': tienda.activa ? 1 : 0,
				'latitud': tienda.latitud,
				'longitud': tienda.longitud,
				'radio_metros': tienda.radioMetrosAsistencia,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Fusiona datos remotos preservando ubicacion local si la remota no la trae.
	Future<void> fusionarRemota(Tienda remota) async {
		final existente = await obtenerPorId(remota.id);
		if (existente == null) {
			await guardar(remota);
			return;
		}
		final tieneUbicacionRemota =
			remota.latitud != null && remota.longitud != null;
		await guardar(
			Tienda(
				id: remota.id,
				nombre: remota.nombre,
				direccion: remota.direccion,
				activa: remota.activa,
				latitud: remota.latitud ?? existente.latitud,
				longitud: remota.longitud ?? existente.longitud,
				radioMetrosAsistencia: tieneUbicacionRemota
					? remota.radioMetrosAsistencia
					: existente.radioMetrosAsistencia,
			),
		);
	}

	/// Elimina tienda fisicamente (solo si no tiene ventas).
	Future<void> eliminar(String tiendaId) async {
		await _baseDatos.delete(
			'stores',
			where: 'id = ?',
			whereArgs: [tiendaId],
		);
	}

	/// Obtiene tienda por identificador.
	///
	/// [tiendaId] Identificador buscado.
	/// Retorna tienda o null si no existe.
	Future<Tienda?> obtenerPorId(String tiendaId) async {
		final filas = await _baseDatos.query(
			'stores',
			where: 'id = ?',
			whereArgs: [tiendaId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearTienda(filas.first);
	}

	/// Convierte fila SQLite a entidad [Tienda].
	///
	/// [fila] Registro de base de datos.
	/// Retorna instancia de dominio.
	Tienda _mapearTienda(Map<String, Object?> fila) {
		return Tienda(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			direccion: fila['direccion'] as String,
			activa: (fila['activa'] as int) == 1,
			latitud: (fila['latitud'] as num?)?.toDouble(),
			longitud: (fila['longitud'] as num?)?.toDouble(),
			radioMetrosAsistencia: _leerRadioMetros(fila),
		);
	}

	/// Lee radio de asistencia aceptando columna nueva o legacy.
	double _leerRadioMetros(Map<String, Object?> fila) {
		final nuevo = fila['radio_metros'];
		if (nuevo is num) {
			return nuevo.toDouble();
		}
		final legacy = fila['radio_metros_asistencia'];
		if (legacy is num) {
			return legacy.toDouble();
		}
		return 150;
	}
}
