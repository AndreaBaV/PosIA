/// Descarga e instalacion de actualizaciones de la app en Windows.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

/// Resultado de aplicar un paquete ya descargado.
enum ResultadoInstalacionActualizacion {
	reinicioPendiente,
	instaladorAbierto,
	noSoportada,
}

/// Plataforma que el hub espera en `GET /v1/app/update`.
String plataformaActualizacionApp() {
	if (kIsWeb) {
		return 'web';
	}
	if (Platform.isWindows) {
		return 'windows';
	}
	if (Platform.isAndroid) {
		return 'android';
	}
	if (Platform.isIOS) {
		return 'ios';
	}
	if (Platform.isMacOS) {
		return 'macos';
	}
	if (Platform.isLinux) {
		return 'linux';
	}
	return 'unknown';
}

class ServicioActualizacionApp {
	ServicioActualizacionApp({required HubSyncClient clienteHub})
		: _clienteHub = clienteHub;

	final HubSyncClient _clienteHub;

	/// En laptops Windows el ZIP se extrae y reemplaza la carpeta portable.
	bool get soportaInstalacionAutomatica =>
		!kIsWeb && Platform.isWindows;

	Future<ManifestoActualizacionApp?> consultar({
		required String plataforma,
	}) {
		return _clienteHub.obtenerActualizacionApp(plataforma);
	}

	Future<File> descargar({
		required PaqueteActualizacionApp paquete,
		void Function(int recibidos, int? total)? alProgreso,
	}) async {
		final temp = await getTemporaryDirectory();
		final destino = File(
			'${temp.path}${Platform.pathSeparator}${paquete.nombreArchivo}',
		);
		if (await destino.exists()) {
			await destino.delete();
		}
		final sink = destino.openWrite();
		try {
			await _clienteHub.descargarArchivo(
				url: paquete.url,
				alChunk: sink.add,
				alProgreso: alProgreso,
			);
		} finally {
			await sink.close();
		}
		if (paquete.tieneHuella) {
			final calculada = sha256.convert(await destino.readAsBytes()).toString();
			if (calculada.toLowerCase() != paquete.sha256.toLowerCase()) {
				await destino.delete();
				throw StateError(
					'El archivo descargado no coincide con la huella publicada. '
					'Vuelva a intentar.',
				);
			}
		}
		return destino;
	}

	Future<ResultadoInstalacionActualizacion> instalar(File paquete) async {
		if (!soportaInstalacionAutomatica) {
			return ResultadoInstalacionActualizacion.noSoportada;
		}
		final nombre = paquete.path.toLowerCase();
		if (nombre.endsWith('.zip')) {
			await _instalarZipWindows(paquete);
			return ResultadoInstalacionActualizacion.reinicioPendiente;
		}
		await Process.start(
			paquete.path,
			const [],
			mode: ProcessStartMode.detached,
		);
		return ResultadoInstalacionActualizacion.instaladorAbierto;
	}

	Future<void> _instalarZipWindows(File zip) async {
		final bytes = await zip.readAsBytes();
		final archivo = ZipDecoder().decodeBytes(bytes);
		final temp = await getTemporaryDirectory();
		final extraido = Directory(
			'${temp.path}${Platform.pathSeparator}posia_update_extract',
		);
		if (await extraido.exists()) {
			await extraido.delete(recursive: true);
		}
		await extraido.create(recursive: true);
		for (final entrada in archivo) {
			final nombre = entrada.name.replaceAll('\\', '/');
			if (!entrada.isFile ||
				nombre.endsWith('/') ||
				nombre.contains('..') ||
				nombre.startsWith('/')) {
				continue;
			}
			final destino = File(
				'${extraido.path}${Platform.pathSeparator}'
				'${nombre.replaceAll('/', Platform.pathSeparator)}',
			);
			await destino.parent.create(recursive: true);
			await destino.writeAsBytes(entrada.content, flush: true);
		}
		final origen = _carpetaConEjecutable(extraido);
		if (origen == null) {
			throw StateError(
				'El paquete no contiene posia_pos.exe. Publique el ZIP de Release.',
			);
		}
		final destinoApp = File(Platform.resolvedExecutable).parent;
		final bat = File(
			'${temp.path}${Platform.pathSeparator}posia_aplicar_update.bat',
		);
		await bat.writeAsString(
			_scriptActualizacionWindows(
				destino: destinoApp.path,
				origen: origen.path,
				ejecutable: Platform.resolvedExecutable,
			),
		);
		await Process.start(
			bat.path,
			const [],
			mode: ProcessStartMode.detached,
			runInShell: true,
		);
	}

	Directory? _carpetaConEjecutable(Directory raiz) {
		final exe = File(
			'${raiz.path}${Platform.pathSeparator}posia_pos.exe',
		);
		if (exe.existsSync()) {
			return raiz;
		}
		final hijos = raiz.listSync().whereType<Directory>().toList();
		if (hijos.length == 1) {
			final anidado = File(
				'${hijos.first.path}${Platform.pathSeparator}posia_pos.exe',
			);
			if (anidado.existsSync()) {
				return hijos.first;
			}
		}
		return null;
	}

	String _scriptActualizacionWindows({
		required String destino,
		required String origen,
		required String ejecutable,
	}) {
		return '''
@echo off
setlocal
set "DEST=$destino"
set "SRC=$origen"
set "EXE=$ejecutable"
timeout /t 3 /nobreak >nul
:wait
tasklist /FI "IMAGENAME eq posia_pos.exe" | find /I "posia_pos.exe" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait
)
xcopy /E /Y /Q "%SRC%\\*" "%DEST%\\" >nul
start "" "%EXE%"
endlocal
''';
	}
}
