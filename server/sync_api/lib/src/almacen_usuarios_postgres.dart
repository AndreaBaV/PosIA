/// Acceso a usuarios en Postgres para autenticacion del hub.
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

class AlmacenUsuariosPostgres {
	AlmacenUsuariosPostgres(this._obtenerConexion);

	final Future<Connection> Function() _obtenerConexion;

	Future<Map<String, Object?>?> obtenerPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty) {
			return null;
		}
		final conexion = await _obtenerConexion();
		final filas = await conexion.execute(
			Sql.named('''
				SELECT id, nombre, codigo, rol, tienda_id, activo
				FROM users
				WHERE codigo = @codigo AND activo = 1
				LIMIT 1
			'''),
			parameters: {'codigo': limpio},
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearPerfil(filas.first.toColumnMap());
	}

	Future<Map<String, Object?>?> autenticar({
		required String codigo,
		required String pin,
	}) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty || pin.isEmpty) {
			return null;
		}
		final conexion = await _obtenerConexion();
		final filas = await conexion.execute(
			Sql.named('''
				SELECT id, nombre, codigo, rol, tienda_id, activo,
					pin_credencial, creado_en, actualizado_en
				FROM users
				WHERE codigo = @codigo AND activo = 1
				LIMIT 1
			'''),
			parameters: {'codigo': limpio},
		);
		if (filas.isEmpty) {
			return null;
		}
		final cols = filas.first.toColumnMap();
		final credencial = cols['pin_credencial'] as String? ?? '';
		if (!HasherPin.verificar(pin, credencial)) {
			return null;
		}
		return {
			..._mapearPerfil(cols),
			'pinCredencial': credencial,
			'creadoEn': _textoTemporal(cols['creado_en']),
			'actualizadoEn': _textoTemporal(cols['actualizado_en']),
		};
	}

	Map<String, Object?> _mapearPerfil(Map<String, Object?> cols) {
		return {
			'id': cols['id'] as String? ?? '',
			'nombre': cols['nombre'] as String? ?? '',
			'codigo': cols['codigo'] as String? ?? '',
			'rol': cols['rol'] as String? ?? 'empleado',
			'tiendaId': cols['tienda_id'] as String?,
			'rolPersonalizadoId': cols['rol_personalizado_id'] as String?,
			'activo': (cols['activo'] as int? ?? 0) == 1,
		};
	}

	String _textoTemporal(Object? valor) {
		if (valor is DateTime) {
			return valor.toUtc().toIso8601String();
		}
		if (valor is String) {
			return valor;
		}
		return '';
	}

	Future<List<Map<String, Object?>>> listarTiendasActivas() async {
		final conexion = await _obtenerConexion();
		final filas = await conexion.execute('''
			SELECT id, nombre, direccion, activa, latitud, longitud, radio_metros
			FROM stores
			WHERE activa = 1
			ORDER BY nombre
		''');
		return filas
			.map((fila) {
				final cols = fila.toColumnMap();
				return {
					'id': cols['id'] as String? ?? '',
					'nombre': cols['nombre'] as String? ?? '',
					'direccion': cols['direccion'] as String? ?? '',
					'activa': (cols['activa'] as int? ?? 0) == 1,
					'latitud': cols['latitud'],
					'longitud': cols['longitud'],
					'radioMetros': cols['radio_metros'] ?? 150,
					'radioMetrosAsistencia': cols['radio_metros'] ?? 150,
				};
			})
			.where((t) => (t['id'] as String).isNotEmpty)
			.toList();
	}

	/// Lista todas las cuentas del tenant para replicar en dispositivos POS.
	Future<List<Map<String, Object?>>> listarUsuarios() async {
		final conexion = await _obtenerConexion();
		final filas = await conexion.execute('''
			SELECT id, nombre, codigo, rol, tienda_id, activo,
				pin_credencial, creado_en, actualizado_en, rol_personalizado_id
			FROM users
			ORDER BY nombre
		''');
		return filas.map((fila) {
			final cols = fila.toColumnMap();
			return {
				..._mapearPerfil(cols),
				'pinCredencial': cols['pin_credencial'] as String? ?? '',
				'creadoEn': _textoTemporal(cols['creado_en']),
				'actualizadoEn': _textoTemporal(cols['actualizado_en']),
			};
		}).where((u) => (u['id'] as String).isNotEmpty).toList();
	}

	/// Lista roles personalizados del tenant para replicar en dispositivos POS.
	Future<List<Map<String, Object?>>> listarRolesPersonalizados() async {
		final conexion = await _obtenerConexion();
		final filas = await conexion.execute('''
			SELECT id, nombre, descripcion, permisos_json, categorias_json, activo, tienda_id
			FROM custom_roles
			ORDER BY nombre
		''');
		return filas.map((fila) {
			final cols = fila.toColumnMap();
			return {
				'id': cols['id'] as String? ?? '',
				'nombre': cols['nombre'] as String? ?? '',
				'descripcion': cols['descripcion'] as String? ?? '',
				'permisosAdmin': _decodificarListaJson(cols['permisos_json']),
				'categoriasPermitidas': _decodificarListaJson(cols['categorias_json']),
				'activo': (cols['activo'] as int? ?? 0) == 1,
				'tiendaId': cols['tienda_id'] as String?,
			};
		}).where((r) => (r['id'] as String).isNotEmpty).toList();
	}

	List<String> _decodificarListaJson(Object? crudo) {
		if (crudo == null) {
			return [];
		}
		if (crudo is List) {
			return crudo.map((e) => e.toString()).toList();
		}
		final texto = crudo.toString();
		if (texto.isEmpty) {
			return [];
		}
		try {
			final lista = jsonDecode(texto);
			if (lista is! List) {
				return [];
			}
			return lista.map((e) => e.toString()).toList();
		} on Object {
			return [];
		}
	}
}
