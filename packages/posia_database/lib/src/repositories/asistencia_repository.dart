/// Repositorio de asistencia de empleados.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../database/conexion_operativa_ruteada.dart';
import '../utils/asegurador_padres_fk.dart';

/// Persiste desafios PIN y registros de entrada/salida.
class AsistenciaRepository {
	AsistenciaRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<void> guardarDesafio(
		DesafioAsistencia desafio, {
		DatabaseExecutor? db,
	}) async {
		// Si [db] es una Transaction, NO tocar la conexion externa: en sqflite
		// eso encola detras del tx y provoca deadlock (PIN que "se genera" en
		// pantalla pero nunca queda legible / sync que no aplica el desafio).
		if (db == null) {
			await _padresFk.asegurarTienda(desafio.tiendaId);
		}
		final exec = db ?? _baseDatos;
		await exec.insert(
			'desafios_asistencia',
			{
				'id': desafio.id,
				'tienda_id': desafio.tiendaId,
				'pin_hash': desafio.pinHash,
				'expira_en': desafio.expiraEn.toUtc().toIso8601String(),
				'creado_por': desafio.creadoPor,
				'latitud': desafio.latitud,
				'longitud': desafio.longitud,
				'radio_metros': desafio.radioMetros,
				'activo': desafio.activo ? 1 : 0,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<void> desactivarDesafiosTienda(
		String tiendaId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.update(
			'desafios_asistencia',
			{'activo': 0},
			where: 'tienda_id = ? AND activo = 1',
			whereArgs: [tiendaId],
		);
	}

	/// Garantiza fila padre de tienda sin abrir una transaccion.
	Future<void> asegurarTiendaPadre(String tiendaId) {
		return _padresFk.asegurarTienda(tiendaId);
	}

	/// Desafio activo y no expirado. Compara fechas en Dart (no por texto ISO).
	Future<DesafioAsistencia?> obtenerDesafioActivo(String tiendaId) async {
		final filas = await _consultar(
			'desafios_asistencia',
			where: 'tienda_id = ? AND activo = 1',
			whereArgs: [tiendaId],
			orderBy: 'expira_en DESC',
			lecturaFresca: true,
		);
		final ahora = DateTime.now().toUtc();
		for (final fila in filas) {
			final desafio = _mapearDesafio(fila);
			if (desafio.expiraEn.toUtc().isAfter(ahora)) {
				return desafio;
			}
		}
		return null;
	}

	/// Desafios activos no vencidos (cualquier tienda).
	Future<List<DesafioAsistencia>> listarDesafiosActivos() async {
		final filas = await _consultar(
			'desafios_asistencia',
			where: 'activo = 1',
			orderBy: 'expira_en DESC',
			lecturaFresca: true,
		);
		final ahora = DateTime.now().toUtc();
		return filas
			.map(_mapearDesafio)
			.where((d) => d.expiraEn.toUtc().isAfter(ahora))
			.toList();
	}

	/// Desafio cuyo PIN coincide, sin importar la tienda del dispositivo.
	Future<DesafioAsistencia?> obtenerDesafioPorPin(String pin) async {
		for (final desafio in await listarDesafiosActivos()) {
			if (HasherPin.verificar(pin, desafio.pinHash)) {
				return desafio;
			}
		}
		return null;
	}

	Future<void> guardarRegistro(RegistroAsistencia registro) async {
		await _padresFk.asegurarPadresDeRegistroAsistencia(registro);
		await _baseDatos.insert(
			'registros_asistencia',
			{
				'id': registro.id,
				'usuario_id': registro.usuarioId,
				'tienda_id': registro.tiendaId,
				'entrada_en': registro.entradaEn.toUtc().toIso8601String(),
				'salida_en': registro.salidaEn?.toUtc().toIso8601String(),
				'metodo': registro.metodo,
				'latitud': registro.latitud,
				'longitud': registro.longitud,
				'desafio_id': registro.desafioId,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<RegistroAsistencia?> obtenerEntradaAbierta(String usuarioId) async {
		final filas = await _consultar(
			'registros_asistencia',
			where: 'usuario_id = ? AND salida_en IS NULL',
			whereArgs: [usuarioId],
			orderBy: 'entrada_en DESC',
			limit: 1,
			lecturaFresca: true,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearRegistro(filas.first);
	}

	Future<List<RegistroAsistencia>> listarPorTiendaDia(
		String tiendaId,
		DateTime dia,
	) async {
		final inicio = DateTime.utc(dia.year, dia.month, dia.day);
		final fin = inicio.add(const Duration(days: 1));
		return listarPorTiendaRango(tiendaId, inicio, fin);
	}

	/// Lista registros de [tiendaId] con entrada en [inicio, fin) (instantes UTC).
	Future<List<RegistroAsistencia>> listarPorTiendaRango(
		String tiendaId,
		DateTime inicio,
		DateTime fin,
	) async {
		final filas = await _consultar(
			'registros_asistencia',
			where: 'tienda_id = ? AND entrada_en >= ? AND entrada_en < ?',
			whereArgs: [
				tiendaId,
				inicio.toUtc().toIso8601String(),
				fin.toUtc().toIso8601String(),
			],
			orderBy: 'entrada_en ASC',
			lecturaFresca: true,
		);
		return filas.map(_mapearRegistro).toList();
	}

	/// Lista registros con entrada en [inicio, fin) (instantes UTC), todas las tiendas.
	Future<List<RegistroAsistencia>> listarPorRango(
		DateTime inicio,
		DateTime fin,
	) async {
		final filas = await _consultar(
			'registros_asistencia',
			where: 'entrada_en >= ? AND entrada_en < ?',
			whereArgs: [
				inicio.toUtc().toIso8601String(),
				fin.toUtc().toIso8601String(),
			],
			orderBy: 'entrada_en ASC',
			lecturaFresca: true,
		);
		return filas.map(_mapearRegistro).toList();
	}

	Future<List<RegistroAsistencia>> listarPorUsuarioRango({
		required String usuarioId,
		required DateTime inicio,
		required DateTime fin,
	}) async {
		final filas = await _consultar(
			'registros_asistencia',
			where: 'usuario_id = ? AND entrada_en >= ? AND entrada_en < ?',
			whereArgs: [
				usuarioId,
				inicio.toUtc().toIso8601String(),
				fin.toUtc().toIso8601String(),
			],
			orderBy: 'entrada_en ASC',
		);
		return filas.map(_mapearRegistro).toList();
	}

	/// Consulta; con [lecturaFresca] usa la conexion de escritura si existe.
	Future<List<Map<String, Object?>>> _consultar(
		String tabla, {
		String? where,
		List<Object?>? whereArgs,
		String? orderBy,
		int? limit,
		bool lecturaFresca = false,
	}) async {
		final base = _baseDatos;
		if (lecturaFresca && base is ConexionOperativaRuteada) {
			return base.queryEscritura(
				tabla,
				where: where,
				whereArgs: whereArgs,
				orderBy: orderBy,
				limit: limit,
			);
		}
		return base.query(
			tabla,
			where: where,
			whereArgs: whereArgs,
			orderBy: orderBy,
			limit: limit,
		);
	}

	DesafioAsistencia _mapearDesafio(Map<String, Object?> fila) {
		return DesafioAsistencia(
			id: fila['id'] as String,
			tiendaId: fila['tienda_id'] as String,
			pinHash: fila['pin_hash'] as String,
			expiraEn: DateTime.parse(fila['expira_en'] as String),
			creadoPor: fila['creado_por'] as String,
			latitud: (fila['latitud'] as num?)?.toDouble(),
			longitud: (fila['longitud'] as num?)?.toDouble(),
			radioMetros: (fila['radio_metros'] as num?)?.toDouble() ?? 150,
			activo: (fila['activo'] as int) == 1,
		);
	}

	RegistroAsistencia _mapearRegistro(Map<String, Object?> fila) {
		final salida = fila['salida_en'] as String?;
		return RegistroAsistencia(
			id: fila['id'] as String,
			usuarioId: fila['usuario_id'] as String,
			tiendaId: fila['tienda_id'] as String,
			entradaEn: DateTime.parse(fila['entrada_en'] as String),
			salidaEn: salida != null ? DateTime.parse(salida) : null,
			metodo: fila['metodo'] as String,
			latitud: (fila['latitud'] as num?)?.toDouble(),
			longitud: (fila['longitud'] as num?)?.toDouble(),
			desafioId: fila['desafio_id'] as String?,
		);
	}
}
