import 'dart:io';

import 'package:posia_sync_api/posia_sync_api.dart';

Future<void> main() async {
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
		stdout.writeln('OK: tabla sync_events lista en Neon.');
	} finally {
		await almacen.cerrar();
	}
}
