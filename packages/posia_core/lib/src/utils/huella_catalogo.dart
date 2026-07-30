/// Huella de integridad del catalogo: mismo algoritmo en hub y dispositivo.
///
/// Un conteo por si solo no detecta que el catalogo diverge cuando el total
/// de filas coincide mientras el contenido no (p. ej. un producto que se
/// perdio en un dispositivo y otro que quedo huerfano en otro, misma suma).
/// Esta huella hashea el catalogo activo completo con la misma formula en
/// Postgres y SQLite: cualquier diferencia de una sola fila cambia el hash.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Fila minima de un producto activo necesaria para calcular la huella.
class FilaHuellaProducto {
	const FilaHuellaProducto({
		required this.id,
		required this.nombre,
		required this.codigoBarras,
	});

	final String id;
	final String nombre;
	final String codigoBarras;
}

/// Resultado de auditar el catalogo activo: conteos y huella de contenido.
class HuellaCatalogo {
	const HuellaCatalogo({
		required this.productosActivos,
		required this.categoriasActivas,
		required this.huellaProductos,
	});

	final int productosActivos;
	final int categoriasActivas;
	final String huellaProductos;

	Map<String, Object?> aJson() => {
		'productosActivos': productosActivos,
		'categoriasActivas': categoriasActivas,
		'huellaProductos': huellaProductos,
	};

	static HuellaCatalogo desdeJson(Map<String, Object?> json) {
		return HuellaCatalogo(
			productosActivos: (json['productosActivos'] as num?)?.toInt() ?? 0,
			categoriasActivas: (json['categoriasActivas'] as num?)?.toInt() ?? 0,
			huellaProductos: json['huellaProductos'] as String? ?? '',
		);
	}

	/// true si ambos lados describen exactamente el mismo catalogo activo.
	bool coincideCon(HuellaCatalogo otra) =>
		productosActivos == otra.productosActivos &&
		categoriasActivas == otra.categoriasActivas &&
		huellaProductos == otra.huellaProductos;
}

/// Calcula un hash MD5 deterministico sobre el catalogo de productos activos.
///
/// Mismo canon en servidor (Neon) y cliente (SQLite): ordena por id y
/// concatena id/nombre/codigo de barras. Si el catalogo local diverge del
/// hub en una sola fila -aunque el conteo total coincida- el hash cambia.
String calcularHuellaCatalogo(List<FilaHuellaProducto> filas) {
	final ordenadas = [...filas]..sort((a, b) => a.id.compareTo(b.id));
	final buffer = StringBuffer();
	for (final fila in ordenadas) {
		buffer
			..write(fila.id)
			..write('|')
			..write(fila.nombre.trim())
			..write('|')
			..write(fila.codigoBarras.trim())
			..write('\n');
	}
	return md5.convert(utf8.encode(buffer.toString())).toString();
}
