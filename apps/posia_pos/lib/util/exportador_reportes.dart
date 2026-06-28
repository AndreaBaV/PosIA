/// Exportacion de reportes a CSV (archivo y portapapeles).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

/// Genera y guarda reportes en formato CSV.
class ExportadorReportes {
	const ExportadorReportes._();

	static String generarCsv({
		required String etiquetaPeriodo,
		required String etiquetaTienda,
		required double totalVendido,
		required int cantidadVentas,
		required double ticketPromedio,
		required List<ResumenVentasDia> resumenTiendas,
		required List<ResumenVendedor> resumenVendedores,
		required List<ResumenProductoVenta> topProductos,
		required List<ResumenVentasHora> resumenPorHora,
		ResumenVentasHora? horaPico,
		required Map<MetodoPago, double> porMetodoPago,
		required List<AlertaFaltante> alertas,
		required Map<String, String> nombresTienda,
	}) {
		final generado = DateTime.now().toLocal();
		final productosMasVendidos = List<ResumenProductoVenta>.from(topProductos)
			..sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
		final productosMenosVendidos = List<ResumenProductoVenta>.from(topProductos)
			..sort((a, b) => a.totalVendido.compareTo(b.totalVendido));
		final horasActivas =
			resumenPorHora.where((h) => h.cantidadVentas > 0).toList();
		final lineas = <String>[
			'# $NOMBRE_COMERCIAL_APP - Reporte de ventas e inventario',
			'# Periodo: $etiquetaPeriodo',
			'# Tienda: $etiquetaTienda',
			'# Generado: ${generado.toIso8601String().substring(0, 19)}',
			'',
			'resumen,metrica,valor',
			'resumen,Total vendido,$totalVendido',
			'resumen,Cantidad ventas,$cantidadVentas',
			'resumen,Ticket promedio,$ticketPromedio',
			if (horaPico != null)
				'resumen,Hora pico,"${horaPico.etiquetaFranja} (${horaPico.cantidadVentas} ventas, ${horaPico.totalVendido})"',
			'',
			'hora,franja,ventas,total',
			...horasActivas.map(
				(h) => 'hora,${h.hora},"${h.etiquetaFranja}",${h.cantidadVentas},${h.totalVendido}',
			),
			'',
			'tienda,nombre,ventas,total',
			...resumenTiendas.map(
				(r) =>
					'tienda,"${_escapar(r.nombreTienda)}",${r.cantidadVentas},${r.totalVendido}',
			),
			'',
			'vendedor,nombre,ventas,total',
			...resumenVendedores.map(
				(r) =>
					'vendedor,"${_escapar(r.nombreVendedor)}",${r.cantidadVentas},${r.totalVendido}',
			),
			'',
			'producto_top,nombre,cantidad,total',
			...productosMasVendidos.take(20).map(
				(r) =>
					'producto_top,"${_escapar(r.nombreProducto)}",${r.cantidadVendida},${r.totalVendido}',
			),
			'',
			'producto_bajo,nombre,cantidad,total',
			...productosMenosVendidos.take(20).map(
				(r) =>
					'producto_bajo,"${_escapar(r.nombreProducto)}",${r.cantidadVendida},${r.totalVendido}',
			),
			'',
			'metodo_pago,metodo,total',
			...porMetodoPago.entries.map(
				(e) => 'metodo_pago,${etiquetaMetodoPago(e.key)},${e.value}',
			),
			'',
			'alerta,tienda,producto,actual,minimo',
			...alertas.map(
				(a) =>
					'alerta,"${_escapar(nombresTienda[a.tiendaId] ?? a.tiendaId)}",'
					'"${_escapar(a.nombreProducto)}",${a.cantidadActual},${a.stockMinimo}',
			),
		];
		return lineas.join('\n');
	}

	static Future<String?> guardarArchivo(String contenido) async {
		if (kIsWeb) {
			return null;
		}
		final carpeta = await getDownloadsDirectory() ??
			await getApplicationDocumentsDirectory();
		final marca = DateTime.now().toLocal().toIso8601String().replaceAll(':', '-');
		final ruta =
			'${carpeta.path}${Platform.pathSeparator}la_fortuna_reporte_$marca.csv';
		final archivo = File(ruta);
		await archivo.writeAsString(contenido);
		return ruta;
	}

	static Future<void> copiarPortapapeles(String contenido) async {
		await Clipboard.setData(ClipboardData(text: contenido));
	}

	static String _escapar(String texto) => texto.replaceAll('"', '""');
}
