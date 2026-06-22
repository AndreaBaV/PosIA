/// Implementacion de carga `.env` en plataformas con dart:io.
library;

import 'dart:io';

import 'cargador_env.dart';

/// Rutas tipicas del monorepo POSIA.
List<String> rutasEnvMonorepo({String? subcarpeta}) {
	final cwd = Directory.current.path;
	final base = subcarpeta != null ? '$cwd${Platform.pathSeparator}$subcarpeta' : cwd;
	final rutas = <String>[
		'$base${Platform.pathSeparator}.env',
		'$cwd${Platform.pathSeparator}.env',
		'$cwd${Platform.pathSeparator}apps${Platform.pathSeparator}posia_pos${Platform.pathSeparator}.env',
		'$cwd${Platform.pathSeparator}platform${Platform.pathSeparator}.env',
		'$cwd${Platform.pathSeparator}server${Platform.pathSeparator}sync_api${Platform.pathSeparator}.env',
	];
	var dir = Directory(cwd);
	for (var i = 0; i < 6; i++) {
		rutas.add(
			'${dir.path}${Platform.pathSeparator}platform${Platform.pathSeparator}.env',
		);
		rutas.add(
			'${dir.path}${Platform.pathSeparator}server${Platform.pathSeparator}sync_api${Platform.pathSeparator}.env',
		);
		if (dir.parent.path == dir.path) {
			break;
		}
		dir = dir.parent;
	}
	return rutas;
}

/// Lee archivos `.env` del disco.
Future<Map<String, String>> leerArchivosEnv(Iterable<String> rutas) {
	return CargadorEnv.cargarArchivos(rutas);
}

Future<Map<String, String>> leerEnvCompleto(Iterable<String> rutas) {
	return CargadorEnv.cargar(rutasArchivo: rutas);
}
