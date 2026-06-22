import 'dart:convert';
import 'dart:io';

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:posia_tenant_registry/posia_tenant_registry.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

/// Alinea Neon con el registro local: tenant_id en stores + eventos storeUpserted.
Future<void> main(List<String> args) async {
	await ConfiguracionEntorno.cargar(
		rutas: ConfiguracionEntorno.rutasMonorepo(subcarpeta: 'platform'),
	);
	final databaseUrl = ConfiguracionEntorno.databaseUrl ??
		Platform.environment['DATABASE_URL'];
	if (databaseUrl == null || databaseUrl.isEmpty) {
		stderr.writeln('Define DATABASE_URL en platform/.env');
		exitCode = 1;
		return;
	}

	final soloTenant = args.isNotEmpty ? args.first : null;
	final base = await BaseDatosRegistro.abrir();
	final repo = RepositorioTenants(base);
	final tenants = await repo.listarTenants();
	final objetivos = soloTenant == null
		? tenants
		: tenants.where((t) => t.id == soloTenant).toList();

	if (objetivos.isEmpty) {
		stderr.writeln('Sin tenants en registro local.');
		exitCode = 1;
		return;
	}

	final conexion = await _abrir(databaseUrl);
	await EsquemaPosPostgres.crearEsquemaCompleto(conexion);
	const uuid = Uuid();
	var tiendasActualizadas = 0;
	var eventosPublicados = 0;

	try {
		for (final tenant in objetivos) {
			final tiendas = await repo.listarTiendas(tenant.id);
			stdout.writeln('Tenant ${tenant.nombre} (${tenant.id}): ${tiendas.length} tiendas');
			for (final tienda in tiendas) {
				final resultado = await conexion.execute(
					Sql.named('''
						UPDATE stores SET tenant_id = @tenant
						WHERE id = @id
					'''),
					parameters: {'tenant': tenant.id, 'id': tienda.id},
				);
				if (resultado.affectedRows > 0) {
					tiendasActualizadas++;
				}
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
						'tenant': tenant.id,
					},
				);
				final eventoId = uuid.v4();
				final payload = jsonEncode({
					'id': tienda.id,
					'nombre': tienda.nombre,
					'direccion': tienda.direccion,
					'activa': tienda.activa,
				});
				final insertado = await conexion.execute(
					Sql.named('''
						INSERT INTO sync_events
							(id, tenant_id, store_id, device_id, type, payload, created_at)
						VALUES
							(@id, @tenant, @store, @device, @type, @payload::jsonb, @created)
						ON CONFLICT (id) DO NOTHING
					'''),
					parameters: {
						'id': eventoId,
						'tenant': tenant.id,
						'store': tienda.id,
						'device': 'backfill-tenant-stores',
						'type': 'storeUpserted',
						'payload': payload,
						'created': DateTime.now().toUtc(),
					},
				);
				if (insertado.affectedRows > 0) {
					eventosPublicados++;
				}
				stdout.writeln('  OK ${tienda.nombre} (${tienda.id})');
			}
		}
		stdout.writeln(
			'\nListo: $tiendasActualizadas updates, $eventosPublicados eventos storeUpserted nuevos.',
		);
	} finally {
		await conexion.close();
		await base.cerrar();
	}
}

Future<Connection> _abrir(String urlConexion) async {
	final uri = Uri.parse(urlConexion);
	final infoUsuario = uri.userInfo.split(':');
	return Connection.open(
		Endpoint(
			host: uri.host,
			port: uri.hasPort ? uri.port : 5432,
			database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
			username: infoUsuario.isNotEmpty ? infoUsuario[0] : 'posia',
			password: infoUsuario.length > 1 ? infoUsuario[1] : '',
		),
		settings: ConnectionSettings(sslMode: _resolverSsl(uri)),
	);
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
