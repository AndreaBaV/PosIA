#!/usr/bin/env dart
/// Panel web local para administrar tenants POSIA.
library;

import 'dart:io';

import 'package:posia_core/posia_core.dart';
import 'package:posia_tenant_registry/posia_tenant_registry.dart';
import 'package:posia_tenant_registry/src/admin/servidor_admin_web.dart';

Future<void> main(List<String> arguments) async {
	await ConfiguracionEntorno.cargar(
		rutas: ConfiguracionEntorno.rutasMonorepo(subcarpeta: 'platform'),
	);

	final puerto = int.tryParse(
		ConfiguracionEntorno.obtener('ADMIN_PORT') ??
			Platform.environment['ADMIN_PORT'] ??
			'',
	) ?? 3847;
	final token = ConfiguracionEntorno.obtener('ADMIN_TOKEN') ??
		Platform.environment['ADMIN_TOKEN'] ??
		'posia-admin-cambiar';
	final databaseUrl = ConfiguracionEntorno.databaseUrl ??
		Platform.environment['DATABASE_URL'];

	if (token == 'posia-admin-cambiar') {
		stderr.writeln(
			'AVISO: define ADMIN_TOKEN en platform/.env (valor por defecto inseguro).',
		);
	}
	if (databaseUrl == null || databaseUrl.isEmpty) {
		stderr.writeln(
			'AVISO: sin DATABASE_URL no podras provisionar ni resetear PIN en Neon.',
		);
	}

	final base = await BaseDatosRegistro.abrir();
	final repo = RepositorioTenants(base);
	final servidor = ServidorAdminWeb(
		repositorio: repo,
		token: token,
		databaseUrl: databaseUrl,
		puerto: puerto,
	);

	ProcessSignal.sigint.watch().listen((_) async {
		await servidor.detener();
		exit(0);
	});

	await servidor.arrancar();
	stdout.writeln('Panel POSIA: http://127.0.0.1:$puerto');
	stdout.writeln('Token: header X-Admin-Token o ?token= en la URL');
}
