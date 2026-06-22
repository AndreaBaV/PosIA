/// CRUD del registro maestro de tenants.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import 'base_datos_registro.dart';
import 'modelos/tenant_registro.dart';

/// Persistencia SQLite del catalogo de negocios.
class RepositorioTenants {
	RepositorioTenants(this._base);

	final BaseDatosRegistro _base;
	static const _uuid = Uuid();

	Database get _db => _base.conexion;

	Future<List<TenantRegistro>> listarTenants({bool soloActivos = false}) async {
		final filas = await _db.query(
			'tenants',
			where: soloActivos ? 'activo = 1' : null,
			orderBy: 'nombre COLLATE NOCASE',
		);
		return filas.map(_mapearTenant).toList();
	}

	Future<TenantRegistro?> obtenerTenant(String id) async {
		final filas = await _db.query(
			'tenants',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearTenant(filas.first);
	}

	Future<TenantRegistro> crearTenant({
		required String nombre,
		String contacto = '',
		String email = '',
		String telefono = '',
		int maxUsuarios = 15,
		int maxTiendas = 5,
		String notas = '',
		String? id,
	}) async {
		final tenantId = id ?? _uuid.v4();
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _db.insert('tenants', {
			'id': tenantId,
			'nombre': nombre.trim(),
			'contacto': contacto.trim(),
			'email': email.trim(),
			'telefono': telefono.trim(),
			'activo': 1,
			'max_usuarios': maxUsuarios,
			'max_tiendas': maxTiendas,
			'notas': notas.trim(),
			'creado_en': ahora,
			'provisionado_en_hub': 0,
		});
		return (await obtenerTenant(tenantId))!;
	}

	Future<void> marcarProvisionado(String tenantId) async {
		await _db.update(
			'tenants',
			{
				'provisionado_en_hub': 1,
				'provisionado_en': DateTime.now().toUtc().toIso8601String(),
			},
			where: 'id = ?',
			whereArgs: [tenantId],
		);
	}

	Future<List<TiendaRegistro>> listarTiendas(String tenantId) async {
		final filas = await _db.query(
			'tiendas',
			where: 'tenant_id = ?',
			whereArgs: [tenantId],
			orderBy: 'nombre COLLATE NOCASE',
		);
		return filas.map(_mapearTienda).toList();
	}

	Future<TiendaRegistro> agregarTienda({
		required String tenantId,
		required String nombre,
		String direccion = '',
		String? id,
	}) async {
		final tiendaId = id ?? _uuid.v4();
		await _db.insert('tiendas', {
			'id': tiendaId,
			'tenant_id': tenantId,
			'nombre': nombre.trim(),
			'direccion': direccion.trim(),
			'activa': 1,
		});
		final filas = await _db.query(
			'tiendas',
			where: 'id = ?',
			whereArgs: [tiendaId],
			limit: 1,
		);
		return _mapearTienda(filas.first);
	}

	Future<List<UsuarioBootstrap>> listarUsuarios(String tenantId) async {
		final filas = await _db.query(
			'usuarios_bootstrap',
			where: 'tenant_id = ?',
			whereArgs: [tenantId],
			orderBy: 'codigo',
		);
		return filas.map(_mapearUsuario).toList();
	}

	Future<UsuarioBootstrap?> obtenerUsuario(String id) async {
		final filas = await _db.query(
			'usuarios_bootstrap',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearUsuario(filas.first);
	}

	Future<String> generarCodigoSiguiente(String tenantId, String rol) async {
		final prefijo = switch (rol) {
			'administrador' => 'ADM',
			'supervisor' => 'SUP',
			_ => 'EMP',
		};
		final usuarios = await listarUsuarios(tenantId);
		var maximo = 0;
		for (final usuario in usuarios) {
			final codigo = ValidadorCodigoUsuario.normalizar(usuario.codigo);
			if (!codigo.startsWith(prefijo) || codigo.length <= prefijo.length) {
				continue;
			}
			final numerico = int.tryParse(codigo.substring(prefijo.length));
			if (numerico != null && numerico > maximo) {
				maximo = numerico;
			}
		}
		return '$prefijo${(maximo + 1).toString().padLeft(3, '0')}';
	}

	Future<void> actualizarPinUsuario(String usuarioId, String pinPlano) async {
		final filas = await _db.update(
			'usuarios_bootstrap',
			{'pin_plano': pinPlano},
			where: 'id = ?',
			whereArgs: [usuarioId],
		);
		if (filas == 0) {
			throw StateError('Usuario no encontrado: $usuarioId');
		}
	}

	Future<UsuarioBootstrap> agregarUsuario({
		required String tenantId,
		required String nombre,
		required String codigo,
		required String pinPlano,
		String rol = 'administrador',
		String? tiendaId,
		String? id,
	}) async {
		final codigoLimpio = ValidadorCodigoUsuario.normalizar(codigo);
		final errorCodigo = ValidadorCodigoUsuario.validar(codigoLimpio);
		if (errorCodigo != null) {
			throw StateError(errorCodigo);
		}
		final usuarioId = id ?? _uuid.v4();
		await _db.insert('usuarios_bootstrap', {
			'id': usuarioId,
			'tenant_id': tenantId,
			'nombre': nombre.trim(),
			'codigo': codigoLimpio,
			'pin_plano': pinPlano,
			'rol': rol,
			'tienda_id': tiendaId,
			'activo': 1,
			'provisionado_en_hub': 0,
		});
		final filas = await _db.query(
			'usuarios_bootstrap',
			where: 'id = ?',
			whereArgs: [usuarioId],
			limit: 1,
		);
		return _mapearUsuario(filas.first);
	}

	Future<void> marcarUsuariosProvisionados(String tenantId) async {
		await _db.update(
			'usuarios_bootstrap',
			{'provisionado_en_hub': 1},
			where: 'tenant_id = ?',
			whereArgs: [tenantId],
		);
	}

	TenantRegistro _mapearTenant(Map<String, Object?> fila) {
		return TenantRegistro(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			contacto: fila['contacto'] as String? ?? '',
			email: fila['email'] as String? ?? '',
			telefono: fila['telefono'] as String? ?? '',
			activo: (fila['activo'] as int? ?? 1) == 1,
			maxUsuarios: fila['max_usuarios'] as int? ?? 15,
			maxTiendas: fila['max_tiendas'] as int? ?? 5,
			notas: fila['notas'] as String? ?? '',
			creadoEn: fila['creado_en'] as String,
			provisionadoEnHub: (fila['provisionado_en_hub'] as int? ?? 0) == 1,
			provisionadoEn: fila['provisionado_en'] as String?,
		);
	}

	TiendaRegistro _mapearTienda(Map<String, Object?> fila) {
		return TiendaRegistro(
			id: fila['id'] as String,
			tenantId: fila['tenant_id'] as String,
			nombre: fila['nombre'] as String,
			direccion: fila['direccion'] as String? ?? '',
			activa: (fila['activa'] as int? ?? 1) == 1,
		);
	}

	UsuarioBootstrap _mapearUsuario(Map<String, Object?> fila) {
		return UsuarioBootstrap(
			id: fila['id'] as String,
			tenantId: fila['tenant_id'] as String,
			nombre: fila['nombre'] as String,
			codigo: fila['codigo'] as String,
			pinPlano: fila['pin_plano'] as String,
			rol: fila['rol'] as String? ?? 'administrador',
			tiendaId: fila['tienda_id'] as String?,
			activo: (fila['activo'] as int? ?? 1) == 1,
			provisionadoEnHub: (fila['provisionado_en_hub'] as int? ?? 0) == 1,
		);
	}
}
