/// Publica tiendas y usuarios del registro local en Postgres (Neon).
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';
import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:uuid/uuid.dart';

import 'repositorio_tenants.dart';
import 'modelos/tenant_registro.dart';

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
	static const _uuid = Uuid();

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
					INSERT INTO stores (id, nombre, direccion, activa, tenant_id)
					VALUES (@id, @nombre, @direccion, @activa, @tenant)
					ON CONFLICT (id) DO UPDATE SET
						nombre = EXCLUDED.nombre,
						direccion = EXCLUDED.direccion,
						activa = EXCLUDED.activa,
						tenant_id = EXCLUDED.tenant_id
				'''),
				parameters: {
					'id': tienda.id,
					'nombre': tienda.nombre,
					'direccion': tienda.direccion,
					'activa': tienda.activa ? 1 : 0,
					'tenant': tenantId,
				},
			);
			await _publicarEventoTienda(conexion, tenantId, tienda);
			tiendasOk++;
		}

		var usuariosOk = 0;
		for (final usuario in usuarios) {
			final existente = await conexion.execute(
				Sql.named('SELECT id FROM users WHERE id = @id'),
				parameters: {'id': usuario.id},
			);
			final ahora = DateTime.now().toUtc().toIso8601String();
			late final String pinHash;
			late final String pinSalt;
			late final String creadoEn;
			if (existente.isEmpty) {
				final sal = HasherPin.generarSal();
				final hash = HasherPin.hashPin(usuario.pinPlano, sal);
				pinHash = hash;
				pinSalt = sal;
				creadoEn = ahora;
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
						'hash': pinHash,
						'salt': pinSalt,
						'creado': creadoEn,
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
				final credenciales = await conexion.execute(
					Sql.named('''
						SELECT pin_hash, pin_salt, creado_en
						FROM users WHERE id = @id
					'''),
					parameters: {'id': usuario.id},
				);
				final cols = credenciales.first.toColumnMap();
				pinHash = cols['pin_hash'] as String? ?? '';
				pinSalt = cols['pin_salt'] as String? ?? '';
				creadoEn = cols['creado_en'] as String? ?? ahora;
			}
			await _publicarEventoUsuario(
				conexion,
				tenantId: tenantId,
				usuario: usuario,
				pinHash: pinHash,
				pinSalt: pinSalt,
				creadoEn: creadoEn,
				actualizadoEn: ahora,
			);
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

	Future<void> _publicarEventoTienda(
		Connection conexion,
		String tenantId,
		TiendaRegistro tienda,
	) async {
		final ahora = DateTime.now().toUtc();
		await conexion.execute(
			Sql.named('''
				INSERT INTO sync_events
					(id, tenant_id, store_id, device_id, type, payload, created_at)
				VALUES
					(@id, @tenant, @store, @device, @type, @payload, @created)
				ON CONFLICT (id) DO NOTHING
			'''),
			parameters: {
				'id': _uuid.v4(),
				'tenant': tenantId,
				'store': tienda.id,
				'device': 'provision-bootstrap',
				'type': 'storeUpserted',
				'payload': jsonEncode({
					'id': tienda.id,
					'nombre': tienda.nombre,
					'direccion': tienda.direccion,
					'activa': tienda.activa,
				}),
				'created': ahora,
			},
		);
	}

	Future<void> _publicarEventoUsuario(
		Connection conexion, {
		required String tenantId,
		required UsuarioBootstrap usuario,
		required String pinHash,
		required String pinSalt,
		required String creadoEn,
		required String actualizadoEn,
	}) async {
		if (pinHash.isEmpty || pinSalt.isEmpty) {
			return;
		}
		final ahora = DateTime.now().toUtc();
		await conexion.execute(
			Sql.named('''
				INSERT INTO sync_events
					(id, tenant_id, store_id, device_id, type, payload, created_at)
				VALUES
					(@id, @tenant, @store, @device, @type, @payload, @created)
				ON CONFLICT (id) DO NOTHING
			'''),
			parameters: {
				'id': _uuid.v4(),
				'tenant': tenantId,
				'store': usuario.tiendaId ?? '',
				'device': 'provision-bootstrap',
				'type': 'userUpserted',
				'payload': jsonEncode({
					'id': usuario.id,
					'nombre': usuario.nombre,
					'codigo': usuario.codigo,
					'rol': usuario.rol,
					'tiendaId': usuario.tiendaId,
					'activo': usuario.activo,
					'pinHash': pinHash,
					'pinSalt': pinSalt,
					'creadoEn': creadoEn,
					'actualizadoEn': actualizadoEn,
				}),
				'created': ahora,
			},
		);
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
