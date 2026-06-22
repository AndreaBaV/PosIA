/// Publica tiendas y usuarios del registro local en Postgres (Neon).
library;

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';
import 'package:posia_sync_api/posia_sync_api.dart';

import 'repositorio_tenants.dart';

/// Resultado de aprovisionar un tenant en el hub.
class ResultadoProvision {
	const ResultadoProvision({
		required this.tenantId,
		required this.tiendas,
		required this.usuarios,
	});

	final String tenantId;
	final int tiendas;
	final int usuarios;
}

/// Inserta en tablas `stores` y `users` del hub sync.
class ServicioProvisionHub {
	ServicioProvisionHub({
		required String urlConexion,
		RepositorioTenants? repositorio,
	}) : _urlConexion = urlConexion,
	     _repositorio = repositorio;

	final String _urlConexion;
	final RepositorioTenants? _repositorio;
	Connection? _conexion;

	Future<ResultadoProvision> provisionarTenant(
		String tenantId, {
		RepositorioTenants? repositorio,
	}) async {
		final repo = repositorio ?? _repositorio;
		if (repo == null) {
			throw StateError('RepositorioTenants requerido');
		}
		final tenant = await repo.obtenerTenant(tenantId);
		if (tenant == null) {
			throw StateError('Tenant no encontrado: $tenantId');
		}
		final tiendas = await repo.listarTiendas(tenantId);
		final usuarios = await repo.listarUsuarios(tenantId);
		if (usuarios.isEmpty) {
			throw StateError(
				'El tenant "${tenant.nombre}" no tiene usuarios bootstrap. '
				'Agrega al menos un administrador con add-usuario.',
			);
		}

		final conexion = await _abrirConexion();
		await EsquemaPosPostgres.crearEsquemaCompleto(conexion);
		var tiendasOk = 0;
		for (final tienda in tiendas) {
			await conexion.execute(
				Sql.named('''
					INSERT INTO stores (id, nombre, direccion, activa)
					VALUES (@id, @nombre, @direccion, @activa)
					ON CONFLICT (id) DO UPDATE SET
						nombre = EXCLUDED.nombre,
						direccion = EXCLUDED.direccion,
						activa = EXCLUDED.activa
				'''),
				parameters: {
					'id': tienda.id,
					'nombre': tienda.nombre,
					'direccion': tienda.direccion,
					'activa': tienda.activa ? 1 : 0,
				},
			);
			tiendasOk++;
		}

		var usuariosOk = 0;
		for (final usuario in usuarios) {
			final existente = await conexion.execute(
				Sql.named('SELECT id FROM users WHERE id = @id'),
				parameters: {'id': usuario.id},
			);
			final ahora = DateTime.now().toUtc().toIso8601String();
			if (existente.isEmpty) {
				final sal = HasherPin.generarSal();
				final hash = HasherPin.hashPin(usuario.pinPlano, sal);
				await conexion.execute(
					Sql.named('''
						INSERT INTO users (
							id, tenant_id, nombre, codigo, rol, tienda_id, activo,
							pin_hash, pin_salt, creado_en, actualizado_en
						) VALUES (
							@id, @tenant, @nombre, @codigo, @rol, @tienda, @activo,
							@hash, @salt, @creado, @actualizado
						)
					'''),
					parameters: {
						'id': usuario.id,
						'tenant': tenantId,
						'nombre': usuario.nombre,
						'codigo': usuario.codigo,
						'rol': usuario.rol,
						'tienda': usuario.tiendaId,
						'activo': usuario.activo ? 1 : 0,
						'hash': hash,
						'salt': sal,
						'creado': ahora,
						'actualizado': ahora,
					},
				);
			} else {
				await conexion.execute(
					Sql.named('''
						UPDATE users SET
							tenant_id = @tenant,
							nombre = @nombre,
							codigo = @codigo,
							rol = @rol,
							tienda_id = @tienda,
							activo = @activo,
							actualizado_en = @actualizado
						WHERE id = @id
					'''),
					parameters: {
						'id': usuario.id,
						'tenant': tenantId,
						'nombre': usuario.nombre,
						'codigo': usuario.codigo,
						'rol': usuario.rol,
						'tienda': usuario.tiendaId,
						'activo': usuario.activo ? 1 : 0,
						'actualizado': ahora,
					},
				);
			}
			usuariosOk++;
		}

		await repo.marcarProvisionado(tenantId);
		await repo.marcarUsuariosProvisionados(tenantId);

		return ResultadoProvision(
			tenantId: tenantId,
			tiendas: tiendasOk,
			usuarios: usuariosOk,
		);
	}

	/// Actualiza el PIN de un usuario ya publicado en Neon.
	Future<void> actualizarPinUsuario({
		required String usuarioId,
		required String pinPlano,
	}) async {
		final sal = HasherPin.generarSal();
		final hash = HasherPin.hashPin(pinPlano, sal);
		final ahora = DateTime.now().toUtc().toIso8601String();
		final conexion = await _abrirConexion();
		final resultado = await conexion.execute(
			Sql.named('''
				UPDATE users SET
					pin_hash = @hash,
					pin_salt = @salt,
					actualizado_en = @actualizado
				WHERE id = @id
			'''),
			parameters: {
				'id': usuarioId,
				'hash': hash,
				'salt': sal,
				'actualizado': ahora,
			},
		);
		if (resultado.affectedRows == 0) {
			throw StateError('Usuario no encontrado en Neon: $usuarioId');
		}
	}

	Future<void> cerrar() async {
		await _conexion?.close();
		_conexion = null;
	}

	Future<Connection> _abrirConexion() async {
		final existente = _conexion;
		if (existente != null && existente.isOpen) {
			return existente;
		}
		final uri = Uri.parse(_urlConexion);
		final infoUsuario = uri.userInfo.split(':');
		final conexion = await Connection.open(
			Endpoint(
				host: uri.host,
				port: uri.hasPort ? uri.port : 5432,
				database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
				username: infoUsuario.isNotEmpty ? infoUsuario[0] : 'posia',
				password: infoUsuario.length > 1 ? infoUsuario[1] : '',
			),
			settings: ConnectionSettings(sslMode: _resolverSsl(uri)),
		);
		_conexion = conexion;
		return conexion;
	}

	SslMode _resolverSsl(Uri uri) {
		final sslParam = uri.queryParameters['sslmode'];
		if (uri.host.contains('neon.tech') ||
			sslParam == 'require' ||
			sslParam == 'verify-full') {
			return SslMode.require;
		}
		return SslMode.disable;
	}
}
