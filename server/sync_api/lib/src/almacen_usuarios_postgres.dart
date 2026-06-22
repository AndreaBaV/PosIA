/// Acceso a usuarios en Postgres para autenticacion multi-tenant.
library;

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

/// Lee cuentas proyectadas desde eventos userUpserted.
class AlmacenUsuariosPostgres {
	AlmacenUsuariosPostgres(this._conexion);

	final Connection _conexion;

	/// Perfil publico por codigo global (sin PIN).
	Future<Map<String, Object?>?> obtenerPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty) {
			return null;
		}
		final filas = await _conexion.execute(
			Sql.named('''
				SELECT id, tenant_id, nombre, codigo, rol, tienda_id, activo
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

	/// Valida PIN y devuelve perfil con credenciales para replica local.
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
				SELECT id, tenant_id, nombre, codigo, rol, tienda_id, activo,
					pin_hash, pin_salt, creado_en, actualizado_en
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
		final hash = cols['pin_hash'] as String? ?? '';
		final sal = cols['pin_salt'] as String? ?? '';
		if (!HasherPin.verificar(pin, sal, hash)) {
			return null;
		}
		return {
			..._mapearPerfil(cols),
			'pinHash': hash,
			'pinSalt': sal,
			'creadoEn': cols['creado_en'] as String? ?? '',
			'actualizadoEn': cols['actualizado_en'] as String? ?? '',
		};
	}

	Map<String, Object?> _mapearPerfil(Map<String, Object?> cols) {
		return {
			'id': cols['id'] as String? ?? '',
			'tenantId': cols['tenant_id'] as String? ?? '',
			'nombre': cols['nombre'] as String? ?? '',
			'codigo': cols['codigo'] as String? ?? '',
			'rol': cols['rol'] as String? ?? 'empleado',
			'tiendaId': cols['tienda_id'] as String?,
			'activo': (cols['activo'] as int? ?? 0) == 1,
		};
	}

	/// Tiendas activas del tenant (administradores operan sobre todas).
	Future<List<Map<String, Object?>>> listarTiendasActivasPorTenant(
		String tenantId,
	) async {
		final limpio = tenantId.trim();
		if (limpio.isEmpty) {
			return [];
		}
		final filas = await _conexion.execute(
			Sql.named('''
				SELECT id, nombre, direccion, activa
				FROM stores
				WHERE tenant_id = @tenant AND activa = 1
				ORDER BY nombre
			'''),
			parameters: {'tenant': limpio},
		);
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
