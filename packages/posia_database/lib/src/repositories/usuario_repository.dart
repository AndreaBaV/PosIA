/// Repositorio SQLite de cuentas de usuario.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste usuarios con rol y tienda asignada.
class UsuarioRepository {
	UsuarioRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<List<Usuario>> listarTodos() async {
		final filas = await _baseDatos.query('usuarios', orderBy: 'nombre ASC');
		return filas.map(_mapear).toList();
	}

	Future<List<Usuario>> listarActivos() async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	/// Cuenta usuarios activos para validar limite de licencia.
	Future<int> contarActivos() async {
		final resultado = Sqflite.firstIntValue(
			await _baseDatos.rawQuery('SELECT COUNT(*) FROM usuarios WHERE activo = 1'),
		);
		return resultado ?? 0;
	}

	Future<List<Usuario>> listarPorTienda(String? tiendaId) async {
		if (tiendaId == null) {
			return listarTodos();
		}
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'tienda_id = ? OR rol = ?',
			whereArgs: [tiendaId, RolUsuario.administrador.name],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<Usuario?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<Usuario?> obtenerPorCodigo(String codigo, {String? excluirId}) async {
		final codigoLimpio = ValidadorCodigoUsuario.normalizar(codigo);
		final filas = await _baseDatos.query(
			'usuarios',
			where: excluirId == null ? 'codigo = ?' : 'codigo = ? AND id != ?',
			whereArgs: excluirId == null ? [codigoLimpio] : [codigoLimpio, excluirId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<Usuario?> autenticar(String codigo, String pin) async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'codigo = ? AND activo = 1',
			whereArgs: [ValidadorCodigoUsuario.normalizar(codigo)],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		final fila = filas.first;
		if (!_verificarFila(fila, pin)) {
			return null;
		}
		return _mapear(fila);
	}

	/// Autentica por PIN cuando el codigo no se solicita en pantalla.
	Future<Usuario?> autenticarPorPin(String pin) async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'activo = 1',
		);
		Usuario? coincidencia;
		for (final fila in filas) {
			if (!_verificarFila(fila, pin)) {
				continue;
			}
			if (coincidencia != null) {
				return null;
			}
			coincidencia = _mapear(fila);
		}
		return coincidencia;
	}

	Future<Usuario?> autenticarPorPinYRol(String pin, RolUsuario rol) async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'rol = ? AND activo = 1',
			whereArgs: [rol.name],
		);
		for (final fila in filas) {
			if (_verificarFila(fila, pin)) {
				return _mapear(fila);
			}
		}
		return null;
	}

	/// Verifica el PIN de un usuario sin exponer el hash.
	Future<bool> verificarPin(String usuarioId, String pin) async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'id = ?',
			whereArgs: [usuarioId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return false;
		}
		return _verificarFila(filas.first, pin);
	}

	Future<String> generarSiguienteCodigo(
		RolUsuario rol, {
		Iterable<String> codigosReservados = const [],
	}) async {
		final prefijo = switch (rol) {
			RolUsuario.administrador => 'ADM',
			RolUsuario.supervisor => 'SUP',
			RolUsuario.empleado => 'EMP',
		};
		final reservados = codigosReservados
			.map(ValidadorCodigoUsuario.normalizar)
			.toSet();
		final todos = await listarTodos();
		var maximo = 0;
		for (final usuario in todos) {
			final codigo = ValidadorCodigoUsuario.normalizar(usuario.codigo);
			if (!codigo.startsWith(prefijo) || codigo.length <= prefijo.length) {
				continue;
			}
			final numerico = int.tryParse(codigo.substring(prefijo.length));
			if (numerico != null && numerico > maximo) {
				maximo = numerico;
			}
		}
		for (final codigo in reservados) {
			if (!codigo.startsWith(prefijo) || codigo.length <= prefijo.length) {
				continue;
			}
			final numerico = int.tryParse(codigo.substring(prefijo.length));
			if (numerico != null && numerico > maximo) {
				maximo = numerico;
			}
		}
		var candidato = '';
		do {
			maximo++;
			candidato = '$prefijo${maximo.toString().padLeft(3, '0')}';
		} while (reservados.contains(candidato));
		return candidato;
	}

	Future<void> guardar(Usuario usuario) async {
		final codigoLimpio = ValidadorCodigoUsuario.normalizar(usuario.codigo);
		final duplicado = await obtenerPorCodigo(codigoLimpio, excluirId: usuario.id);
		if (duplicado != null) {
			throw StateError('Ya existe un usuario con el codigo $codigoLimpio');
		}

		final filaExistente = await _baseDatos.query(
			'usuarios',
			where: 'id = ?',
			whereArgs: [usuario.id],
			limit: 1,
		);
		final ahora = DateTime.now().toUtc().toIso8601String();
		late final String pinCredencial;
		final creadoEn = filaExistente.isEmpty
			? ahora
			: filaExistente.first['creado_en'] as String? ?? ahora;

		if (usuario.pin != null && usuario.pin!.isNotEmpty) {
			pinCredencial = HasherPin.codificar(usuario.pin!);
		} else if (filaExistente.isNotEmpty) {
			pinCredencial = filaExistente.first['pin_credencial'] as String;
		} else {
			throw StateError('El PIN es obligatorio para usuarios nuevos');
		}

		try {
			await _baseDatos.insert(
				'usuarios',
				{
					'id': usuario.id,
					'nombre': usuario.nombre.trim(),
					'codigo': codigoLimpio,
					'pin_credencial': pinCredencial,
					'rol': usuario.rol.name,
					'tienda_id': usuario.tiendaId,
					'activo': usuario.activo ? 1 : 0,
					'creado_en': creadoEn,
					'actualizado_en': ahora,
				},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
		} on DatabaseException catch (error) {
			if (error.isUniqueConstraintError()) {
				throw StateError('Ya existe un usuario con el codigo $codigoLimpio');
			}
			rethrow;
		}
	}

	/// Persiste usuario recibido por sync (hash de PIN ya calculado).
	///
	/// Retorna false si la copia local es mas reciente que el evento remoto.
	Future<bool> guardarRemoto({
		required String id,
		required String nombre,
		required String codigo,
		required RolUsuario rol,
		String? tiendaId,
		required bool activo,
		required String pinCredencial,
		required String creadoEn,
		required String actualizadoEn,
	}) async {
		final filaExistente = await _baseDatos.query(
			'usuarios',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filaExistente.isNotEmpty) {
			final localActualizado =
				filaExistente.first['actualizado_en'] as String? ?? '';
			if (localActualizado.compareTo(actualizadoEn) > 0) {
				return false;
			}
		}
		final codigoLimpio = ValidadorCodigoUsuario.normalizar(codigo);
		final duplicado = await obtenerPorCodigo(codigoLimpio, excluirId: id);
		if (duplicado != null) {
			final filaDuplicado = await _baseDatos.query(
				'usuarios',
				where: 'id = ?',
				whereArgs: [duplicado.id],
				limit: 1,
			);
			final actualizadoDuplicado =
				filaDuplicado.first['actualizado_en'] as String? ?? '';
			if (actualizadoEn.compareTo(actualizadoDuplicado) < 0) {
				return false;
			}
			await _reasignarCodigoPorConflicto(duplicado.id, codigoLimpio);
		}
		await _baseDatos.insert(
			'usuarios',
			{
				'id': id,
				'nombre': nombre.trim(),
				'codigo': codigoLimpio,
				'pin_credencial': pinCredencial,
				'rol': rol.name,
				'tienda_id': tiendaId,
				'activo': activo ? 1 : 0,
				'creado_en': creadoEn,
				'actualizado_en': actualizadoEn,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
		return true;
	}

	/// Libera un codigo ocupado por otra cuenta cuando llega un evento mas reciente.
	Future<void> _reasignarCodigoPorConflicto(
		String usuarioId,
		String codigoOcupado,
	) async {
		final usuario = await obtenerPorId(usuarioId);
		if (usuario == null) {
			return;
		}
		final reservados = {codigoOcupado};
		final nuevoCodigo = await generarSiguienteCodigo(
			usuario.rol,
			codigosReservados: reservados,
		);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.update(
			'usuarios',
			{
				'codigo': nuevoCodigo,
				'actualizado_en': ahora,
			},
			where: 'id = ?',
			whereArgs: [usuarioId],
		);
	}

	/// Lee credenciales y marcas de tiempo para replicar por sync.
	Future<UsuarioSnapshotSync?> obtenerSnapshotSync(String id) async {
		final filas = await _baseDatos.query(
			'usuarios',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		final fila = filas.first;
		final credencial = fila['pin_credencial'] as String?;
		if (credencial == null || credencial.isEmpty) {
			return null;
		}
		return UsuarioSnapshotSync(
			pinCredencial: credencial,
			creadoEn: fila['creado_en'] as String? ?? DateTime.now().toUtc().toIso8601String(),
			actualizadoEn:
				fila['actualizado_en'] as String? ?? DateTime.now().toUtc().toIso8601String(),
		);
	}

	bool _verificarFila(Map<String, Object?> fila, String pin) {
		final credencial = fila['pin_credencial'] as String?;
		if (credencial == null || credencial.isEmpty) {
			return false;
		}
		return HasherPin.verificar(pin, credencial);
	}

	Usuario _mapear(Map<String, Object?> fila) {
		return Usuario(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			codigo: fila['codigo'] as String,
			rol: RolUsuario.values.byName(fila['rol'] as String),
			tiendaId: fila['tienda_id'] as String?,
			activo: (fila['activo'] as int) == 1,
		);
	}
}

/// Datos de usuario necesarios para eventos de sincronizacion.
class UsuarioSnapshotSync {
	const UsuarioSnapshotSync({
		required this.pinCredencial,
		required this.creadoEn,
		required this.actualizadoEn,
	});

	final String pinCredencial;
	final String creadoEn;
	final String actualizadoEn;
}
