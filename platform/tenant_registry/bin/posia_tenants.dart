#!/usr/bin/env dart
/// CLI para gestionar el catalogo maestro de tenants POSIA.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_tenant_registry/posia_tenant_registry.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> arguments) async {
	await ConfiguracionEntorno.cargar(
		rutas: ConfiguracionEntorno.rutasMonorepo(subcarpeta: 'platform'),
	);

	final parser = ArgParser()
		..addCommand('init', ArgParser()..addFlag('help', abbr: 'h', negatable: false))
		..addCommand(
			'list',
			ArgParser()
				..addFlag('activos', abbr: 'a', help: 'Solo tenants activos', negatable: false),
		)
		..addCommand(
			'show',
			ArgParser()..addOption('id', abbr: 'i', help: 'UUID del tenant', mandatory: true),
		)
		..addCommand(
			'crear',
			ArgParser()
				..addOption('nombre', abbr: 'n', help: 'Nombre del negocio', mandatory: true)
				..addOption('contacto', help: 'Persona de contacto')
				..addOption('email', help: 'Correo')
				..addOption('telefono', help: 'Telefono')
				..addOption('notas', help: 'Notas internas')
				..addOption('max-usuarios', defaultsTo: '15')
				..addOption('max-tiendas', defaultsTo: '5'),
		)
		..addCommand(
			'add-tienda',
			ArgParser()
				..addOption('tenant', abbr: 't', mandatory: true)
				..addOption('nombre', abbr: 'n', mandatory: true)
				..addOption('direccion', abbr: 'd', defaultsTo: ''),
		)
		..addCommand(
			'add-usuario',
			ArgParser()
				..addOption('tenant', abbr: 't', mandatory: true)
				..addOption('nombre', abbr: 'n', mandatory: true)
				..addOption('codigo', abbr: 'c', mandatory: true)
				..addOption('pin', abbr: 'p', mandatory: true)
				..addOption('rol', defaultsTo: 'administrador')
				..addOption('tienda', help: 'UUID tienda (supervisor/empleado)'),
		)
		..addCommand(
			'provision',
			ArgParser()
				..addOption('tenant', abbr: 't', mandatory: true)
				..addOption('database-url', help: 'Override de DATABASE_URL'),
		)
		..addCommand(
			'seed-review',
			ArgParser()
				..addFlag('provision', help: 'Publicar en Neon si hay DATABASE_URL', negatable: false),
		);

	late ArgResults results;
	try {
		results = parser.parse(arguments);
	} on FormatException catch (error) {
		_stderr('Error: $error\n\n${parser.usage}');
		exitCode = 64;
		return;
	}

	final comando = results.command;
	if (comando == null) {
		_stdout(parser.usage);
		return;
	}

	final base = await BaseDatosRegistro.abrir();
	final repo = RepositorioTenants(base);

	try {
		switch (comando.name) {
			case 'init':
				_stdout('Registro listo: ${BaseDatosRegistro.rutaPorDefecto()}');
			case 'list':
				await _listar(repo, soloActivos: comando['activos'] as bool);
			case 'show':
				await _mostrar(repo, comando['id'] as String);
			case 'crear':
				await _crear(repo, comando);
			case 'add-tienda':
				await _addTienda(repo, comando);
			case 'add-usuario':
				await _addUsuario(repo, comando);
			case 'provision':
				await _provision(repo, comando);
			case 'seed-review':
				await _seedReview(repo, provision: comando['provision'] as bool);
			default:
				_stderr('Comando desconocido');
				exitCode = 64;
		}
	} on Object catch (error) {
		_stderr('$error');
		exitCode = 1;
	} finally {
		await base.cerrar();
	}
}

Future<void> _listar(RepositorioTenants repo, {required bool soloActivos}) async {
	final tenants = await repo.listarTenants(soloActivos: soloActivos);
	if (tenants.isEmpty) {
		_stdout('Sin tenants. Usa: dart run bin/posia_tenants.dart crear --nombre "Mi negocio"');
		return;
	}
	_stdout('${'ID'.padRight(38)} ${'Nombre'.padRight(24)} Hub');
	for (final t in tenants) {
		final hub = t.provisionadoEnHub ? 'si' : 'no';
		_stdout('${t.id.padRight(38)} ${t.nombre.padRight(24)} $hub');
	}
	_stdout('\nTotal: ${tenants.length}');
}

Future<void> _mostrar(RepositorioTenants repo, String id) async {
	final tenant = await repo.obtenerTenant(id);
	if (tenant == null) {
		throw StateError('Tenant no encontrado: $id');
	}
	_stdout('Tenant: ${tenant.nombre}');
	_stdout('  ID:        ${tenant.id}');
	_stdout('  Contacto:  ${tenant.contacto}');
	_stdout('  Email:     ${tenant.email}');
	_stdout('  Telefono:  ${tenant.telefono}');
	_stdout('  Limites:   ${tenant.maxUsuarios} usuarios, ${tenant.maxTiendas} tiendas');
	_stdout('  Hub:       ${tenant.provisionadoEnHub ? "provisionado ${tenant.provisionadoEn}" : "pendiente"}');
	if (tenant.notas.isNotEmpty) {
		_stdout('  Notas:     ${tenant.notas}');
	}
	final tiendas = await repo.listarTiendas(id);
	_stdout('\nTiendas (${tiendas.length}):');
	for (final t in tiendas) {
		_stdout('  - ${t.nombre} (${t.id})');
	}
	final usuarios = await repo.listarUsuarios(id);
	_stdout('\nUsuarios bootstrap (${usuarios.length}):');
	for (final u in usuarios) {
		_stdout(
			'  - ${u.codigo} ${u.nombre} [${u.rol}]'
			' ${u.provisionadoEnHub ? "(hub)" : "(local)"}',
		);
	}
}

Future<void> _crear(RepositorioTenants repo, ArgResults args) async {
	final tenant = await repo.crearTenant(
		nombre: args['nombre'] as String,
		contacto: args['contacto'] as String? ?? '',
		email: args['email'] as String? ?? '',
		telefono: args['telefono'] as String? ?? '',
		notas: args['notas'] as String? ?? '',
		maxUsuarios: int.parse(args['max-usuarios'] as String),
		maxTiendas: int.parse(args['max-tiendas'] as String),
	);
	_stdout('Tenant creado: ${tenant.nombre}');
	_stdout('  ID: ${tenant.id}');
	_stdout('\nSiguiente:');
	_stdout('  add-tienda --tenant ${tenant.id} --nombre "Sucursal principal"');
	_stdout(
		'  add-usuario --tenant ${tenant.id} --nombre "Admin" --codigo ADM001 --pin 1234',
	);
}

Future<void> _addTienda(RepositorioTenants repo, ArgResults args) async {
	final tienda = await repo.agregarTienda(
		tenantId: args['tenant'] as String,
		nombre: args['nombre'] as String,
		direccion: args['direccion'] as String? ?? '',
	);
	_stdout('Tienda agregada: ${tienda.nombre} (${tienda.id})');
}

Future<void> _addUsuario(RepositorioTenants repo, ArgResults args) async {
	final codigoRaw = args['codigo'] as String;
	final error = ValidadorCodigoUsuario.validar(codigoRaw);
	if (error != null) {
		throw StateError(error);
	}
	final usuario = await repo.agregarUsuario(
		tenantId: args['tenant'] as String,
		nombre: args['nombre'] as String,
		codigo: args['codigo'] as String,
		pinPlano: args['pin'] as String,
		rol: args['rol'] as String? ?? 'administrador',
		tiendaId: args['tienda'] as String?,
	);
	_stdout('Usuario agregado: ${usuario.codigo} ${usuario.nombre} (${usuario.rol})');
}

Future<void> _provision(RepositorioTenants repo, ArgResults args) async {
	final url = args['database-url'] as String? ??
		ConfiguracionEntorno.databaseUrl ??
		Platform.environment['DATABASE_URL'];
	if (url == null || url.isEmpty) {
		throw StateError(
			'Define DATABASE_URL en el entorno o usa --database-url',
		);
	}
	final tenantId = args['tenant'] as String;
	final servicio = ServicioProvisionHub(urlConexion: url, repositorio: repo);
	try {
		final resultado = await servicio.provisionarTenant(tenantId);
		_stdout(
			'Provisionado en Neon: tenant ${resultado.tenantId} '
			'(${resultado.tiendas} tiendas, ${resultado.usuarios} usuarios)',
		);
	} finally {
		await servicio.cerrar();
	}
}

Future<void> _seedReview(RepositorioTenants repo, {required bool provision}) async {
	const tenantId = '00000000-0000-4000-8000-000000000099';
	const tiendaId = '00000000-0000-4000-8000-000000000199';

	final existente = await repo.obtenerTenant(tenantId);
	if (existente == null) {
		await repo.crearTenant(
			id: tenantId,
			nombre: 'POSIA Review (App Store / Play)',
			notas: 'Tenant para revisores de tiendas. No usar en produccion.',
		);
		await repo.agregarTienda(
			tenantId: tenantId,
			id: tiendaId,
			nombre: 'Tienda Demo Review',
			direccion: 'Solo pruebas',
		);
		await repo.agregarUsuario(
			tenantId: tenantId,
			id: const Uuid().v4(),
			nombre: 'Admin Review',
			codigo: '9001',
			pinPlano: '1234',
			rol: 'administrador',
		);
		await repo.agregarUsuario(
			tenantId: tenantId,
			id: const Uuid().v4(),
			nombre: 'Cajero Review',
			codigo: '9002',
			pinPlano: '1234',
			rol: 'empleado',
			tiendaId: tiendaId,
		);
		_stdout('Tenant review creado en registro local.');
	} else {
		_stdout('Tenant review ya existe en registro local.');
	}

	_stdout('\nCredenciales para revisores:');
	_stdout('  Admin:    codigo 9001 / PIN 1234');
	_stdout('  Empleado: codigo 9002 / PIN 1234');
	_stdout('  Tenant:   $tenantId');

	if (provision) {
		final url = ConfiguracionEntorno.databaseUrl ??
			Platform.environment['DATABASE_URL'];
		if (url == null || url.isEmpty) {
			_stderr('\nDATABASE_URL no definida; omitiendo provision en hub.');
			return;
		}
		final servicio = ServicioProvisionHub(urlConexion: url, repositorio: repo);
		try {
			final r = await servicio.provisionarTenant(tenantId);
			_stdout('\nPublicado en Neon: ${r.usuarios} usuarios, ${r.tiendas} tiendas.');
		} finally {
			await servicio.cerrar();
		}
	} else {
		_stdout('\nPara publicar en Neon:');
		_stdout('  dart run bin/posia_tenants.dart seed-review --provision');
	}
}

void _stdout(String message) => stdout.writeln(message);
void _stderr(String message) => stderr.writeln(message);
