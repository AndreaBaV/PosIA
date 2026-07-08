/// Borrador de producto capturado por dictado de voz.
library;

import 'package:posia_core/posia_core.dart';

/// Campos opcionales rellenados desde una frase de alta.
class BorradorProductoVoz {
	const BorradorProductoVoz({
		this.nombre,
		this.codigoBarras,
		this.precioBase,
		this.costoUnitario,
		this.nombreCategoria,
		this.unidadMedida,
		this.nombreProveedor,
		this.stockInicial,
		this.stockMinimo,
		this.notas,
		this.precioMedioKilo,
		this.precioCuartoKilo,
		this.escalasMayoreo = const [],
		this.textoLimpio = '',
		this.camposDetectados = const [],
	});

	final String? nombre;
	final String? codigoBarras;
	final double? precioBase;
	final double? costoUnitario;
	final String? nombreCategoria;
	final UnidadMedida? unidadMedida;
	final String? nombreProveedor;
	final double? stockInicial;
	final double? stockMinimo;
	final String? notas;
	final double? precioMedioKilo;
	final double? precioCuartoKilo;
	final List<EscalaMayoreoVoz> escalasMayoreo;
	final String textoLimpio;
	final List<String> camposDetectados;

	/// True si hay al menos un campo util para rellenar el formulario.
	bool get tieneDatos => camposDetectados.isNotEmpty;

	/// Resumen legible de lo detectado (para confirmar antes de aplicar).
	List<String> get lineasResumen {
		final out = <String>[];
		if (nombre != null) {
			out.add('Nombre: $nombre');
		}
		if (codigoBarras != null) {
			out.add('Código: $codigoBarras');
		}
		if (unidadMedida != null) {
			out.add('Unidad: ${_etiquetaUnidad(unidadMedida!)}');
		}
		if (nombreCategoria != null) {
			out.add('Categoría: $nombreCategoria');
		}
		if (nombreProveedor != null) {
			out.add('Proveedor: $nombreProveedor');
		}
		if (costoUnitario != null) {
			out.add('Costo: \$${costoUnitario!.toStringAsFixed(2)}');
		}
		if (precioBase != null) {
			out.add('Precio: \$${precioBase!.toStringAsFixed(2)}');
		}
		if (precioMedioKilo != null) {
			out.add('Medio kilo: \$${precioMedioKilo!.toStringAsFixed(2)}');
		}
		if (precioCuartoKilo != null) {
			out.add('Cuarto: \$${precioCuartoKilo!.toStringAsFixed(2)}');
		}
		if (stockInicial != null) {
			out.add('Stock: ${_fmt(stockInicial!)}');
		}
		if (stockMinimo != null) {
			out.add('Mínimo: ${_fmt(stockMinimo!)}');
		}
		for (final e in escalasMayoreo) {
			out.add(
				'Mayoreo desde ${_fmt(e.cantidadMinima)}: '
				'\$${e.precioUnitario.toStringAsFixed(2)}',
			);
		}
		if (notas != null && notas!.trim().isNotEmpty) {
			out.add('Notas: $notas');
		}
		return out;
	}

	static String _etiquetaUnidad(UnidadMedida u) => switch (u) {
		UnidadMedida.pieza => 'pieza',
		UnidadMedida.kilogramo => 'kilogramo',
		UnidadMedida.litro => 'litro',
		UnidadMedida.caja => 'caja',
	};

	static String _fmt(double v) {
		if (v == v.roundToDouble()) {
			return v.toStringAsFixed(0);
		}
		return v.toStringAsFixed(2);
	}
}

/// Tramo de mayoreo dictado (cantidad minima + precio unitario).
class EscalaMayoreoVoz {
	const EscalaMayoreoVoz({
		required this.cantidadMinima,
		required this.precioUnitario,
	});

	final double cantidadMinima;
	final double precioUnitario;
}
