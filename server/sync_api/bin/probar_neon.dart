import 'dart:io';

import 'package:posia_sync_api/posia_sync_api.dart';

Future<void> main(List<String> args) async {
	final config = await ConfigEntorno.cargar();
	final url = config.urlBaseDatos;
	if (url == null) {
		stderr.writeln('DATABASE_URL no configurada. Cree server/sync_api/.env');
		exitCode = 1;
		return;
	}
	stdout.writeln('Conectando a Neon...');
	final almacen = AlmacenEventosPostgres(urlConexion: url);
	try {
		await almacen.inicializar();
		stdout.writeln('OK: esquema espejo POS listo en Neon.');
		if (args.contains('--smoke')) {
			final ahora = DateTime.now().toUtc();
			const tiendaId = 'tienda-smoke';
			const productoId = 'prod-smoke-neon';
			final evento = EventoHub(
				seq: 0,
				id: 'ev-smoke-${ahora.millisecondsSinceEpoch}',
				tenantId: 'tenant-smoke',
				tiendaId: tiendaId,
				dispositivoId: 'smoke-script',
				tipo: 'productUpserted',
				payload: {
					'id': productoId,
					'nombre': 'Producto prueba Neon',
					'codigoBarras': '7500000000001',
					'precioBase': 19.99,
					'unidadMedida': 'pieza',
					'rutaImagen': '',
					'activo': true,
					'tiendaId': tiendaId,
					'moduloVertical': 'general',
				},
				creadoEn: ahora,
			);
			final aceptados = await almacen.guardarLote([evento]);
			stdout.writeln(
				'Smoke: $aceptados evento(s) guardado(s); producto $productoId proyectado.',
			);
		}
	} finally {
		await almacen.cerrar();
	}
}
