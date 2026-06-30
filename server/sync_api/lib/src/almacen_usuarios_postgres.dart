/// Acceso a usuarios en Postgres para autenticacion del hub.
library;

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

class AlmacenUsuariosPostgres {
	AlmacenUsuariosPostgres(this._conexion);

	final Connection _conexion;

	Future<Map<String, Object?>?> obtenerPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty) {
			return null;
		}
		final filas = await _conexion.execute(
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
		final filas = await _conexion.execute(
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
			'creadoEn': cols['creado_en'] as String? ?? '',
			'actualizadoEn': cols['actualizado_en'] as String? ?? '',
		};
	}

	Map<String, Object?> _mapearPerfil(Map<String, Object?> cols) {
		return {
			'id': cols['id'] as String? ?? '',
			'nombre': cols['nombre'] as String? ?? '',
			'codigo': cols['codigo'] as String? ?? '',
			'rol': cols['rol'] as String? ?? 'empleado',
			'tiendaId': cols['tienda_id'] as String?,
			'activo': (cols['activo'] as int? ?? 0) == 1,
		};
	}

	Future<List<Map<String, Object?>>> listarTodosParaDispositivo() async {
		final filas = await _conexion.execute('''
			SELECT id, nombre, codigo, rol, tienda_id, activo,
				pin_credencial, creado_en, actualizado_en
			FROM users
			ORDER BY nombre
		''');
		return filas
			.map((fila) {
				final cols = fila.toColumnMap();
				return {
					'id': cols['id'] as String? ?? '',
					'nombre': cols['nombre'] as String? ?? '',
					'codigo': cols['codigo'] as String? ?? '',
					'rol': cols['rol'] as String? ?? 'empleado',
					'tiendaId': cols['tienda_id'] as String?,
					'activo': (cols['activo'] as int? ?? 0) == 1,
					'pinCredencial': cols['pin_credencial'] as String? ?? '',
					'creadoEn': cols['creado_en'] as String? ?? '',
					'actualizadoEn': cols['actualizado_en'] as String? ?? '',
				};
			})
			.where((u) => (u['id'] as String).isNotEmpty)
			.where((u) => (u['pinCredencial'] as String).isNotEmpty)
			.toList();
	}

	Future<List<Map<String, Object?>>> listarTiendasActivas() async {
		final filas = await _conexion.execute('''
			SELECT id, nombre, direccion, activa
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
				};
			})
			.where((t) => (t['id'] as String).isNotEmpty)
			.toList();
	}
}
