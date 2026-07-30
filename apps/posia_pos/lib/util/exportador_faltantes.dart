/// Exportacion y mensaje WhatsApp de la lista de faltantes.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

/// Armado de CSV y texto para surtir productos bajo el stock minimo.
class ExportadorFaltantes {
	const ExportadorFaltantes._();

	/// Unidades a pedir para llegar al minimo (nunca negativo).
	static double cantidadAPedir(AlertaFaltante alerta) {
		final faltante = alerta.stockMinimo - alerta.cantidadActual;
		return faltante > 0 ? faltante : 0;
	}

	static String formatearCantidad(double cantidad) {
		if (cantidad == cantidad.roundToDouble()) {
			return cantidad.toStringAsFixed(0);
		}
		return cantidad.toStringAsFixed(2);
	}

	/// Mensaje listo para WhatsApp / almacenes.
	static String textoWhatsApp({
		required String nombreTienda,
		required List<AlertaFaltante> alertas,
	}) {
		final ahora = DateTime.now().toLocal();
		final fecha =
			'${ahora.day.toString().padLeft(2, '0')}/'
			'${ahora.month.toString().padLeft(2, '0')}/'
			'${ahora.year} '
			'${ahora.hour.toString().padLeft(2, '0')}:'
			'${ahora.minute.toString().padLeft(2, '0')}';
		final lineas = <String>[
			'*FALTANTES — $nombreTienda*',
			fecha,
			'',
		];
		var i = 1;
		for (final a in alertas) {
			final pedir = formatearCantidad(cantidadAPedir(a));
			final hay = formatearCantidad(a.cantidadActual);
			final minimo = formatearCantidad(a.stockMinimo);
			lineas.add('$i. ${a.nombreProducto}');
			lineas.add('   Hay: $hay · Mínimo: $minimo · Pedir: $pedir');
			i = i + 1;
		}
		lineas.add('');
		lineas.add('— ${alertas.length} producto${alertas.length == 1 ? '' : 's'} —');
		lineas.add(NOMBRE_COMERCIAL_APP);
		return lineas.join('\n');
	}

	static String generarCsv({
		required String nombreTienda,
		required List<AlertaFaltante> alertas,
	}) {
		final generado = DateTime.now().toLocal();
		final lineas = <String>[
			'# $NOMBRE_COMERCIAL_APP - Faltantes',
			'# Tienda: $nombreTienda',
			'# Generado: ${generado.toIso8601String().substring(0, 19)}',
			'',
			'producto,actual,minimo,pedir',
			...alertas.map((a) {
				final nombre = a.nombreProducto.replaceAll('"', '""');
				return '"$nombre",'
					'${formatearCantidad(a.cantidadActual)},'
					'${formatearCantidad(a.stockMinimo)},'
					'${formatearCantidad(cantidadAPedir(a))}';
			}),
		];
		return lineas.join('\n');
	}

	static Future<String?> guardarCsv(String contenido) async {
		if (kIsWeb) {
			return null;
		}
		final carpeta = await getDownloadsDirectory() ??
			await getApplicationDocumentsDirectory();
		final marca =
			DateTime.now().toLocal().toIso8601String().replaceAll(':', '-');
		final ruta =
			'${carpeta.path}${Platform.pathSeparator}faltantes_$marca.csv';
		await File(ruta).writeAsString(contenido);
		return ruta;
	}
}
