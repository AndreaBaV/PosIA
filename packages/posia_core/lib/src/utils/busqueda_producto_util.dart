/// Busqueda rapida de productos por nombre o codigo.
library;

import '../models/producto.dart';

/// Puntua coincidencia: prefijo de palabra > substring > codigo.
int puntajeBusquedaProducto(Producto producto, String consulta) {
	final q = consulta.trim().toLowerCase();
	if (q.isEmpty) {
		return 0;
	}
	final nombre = producto.nombre.toLowerCase();
	final codigo = producto.codigoBarras.toLowerCase();
	if (codigo == q) {
		return 1000;
	}
	if (nombre == q) {
		return 900;
	}
	if (codigo.startsWith(q)) {
		return 800;
	}
	if (nombre.startsWith(q)) {
		return 700;
	}
	final palabras = nombre.split(RegExp(r'\s+'));
	for (final palabra in palabras) {
		if (palabra.startsWith(q)) {
			return 600;
		}
	}
	var acumulado = 0;
	var indice = 0;
	for (final caracter in q.split('')) {
		final hallado = nombre.indexOf(caracter, indice);
		if (hallado < 0) {
			return 0;
		}
		acumulado = acumulado + (100 - hallado);
		indice = hallado + 1;
	}
	if (nombre.contains(q)) {
		acumulado = acumulado + 200;
	}
	if (codigo.contains(q)) {
		acumulado = acumulado + 150;
	}
	return acumulado;
}

/// Indica si el texto parece un codigo escaneado (no una busqueda por nombre).
bool pareceCodigoBarrasEscaneado(String texto) {
	final t = texto.trim();
	if (t.length < 4) {
		return false;
	}
	if (RegExp(r'^\d{4,}$').hasMatch(t)) {
		return true;
	}
	return RegExp(r'^[A-Za-z0-9\-]*\d[A-Za-z0-9\-]{3,}$').hasMatch(t);
}

/// Filtra y ordena productos por relevancia de busqueda.
List<Producto> filtrarProductosPorBusqueda(
	List<Producto> productos,
	String consulta,
) {
	final q = consulta.trim().toLowerCase();
	if (q.isEmpty) {
		return productos;
	}
	final puntuados = <({Producto producto, int puntaje})>[];
	for (final producto in productos) {
		final puntaje = puntajeBusquedaProducto(producto, q);
		if (puntaje > 0) {
			puntuados.add((producto: producto, puntaje: puntaje));
		}
	}
	puntuados.sort((a, b) => b.puntaje.compareTo(a.puntaje));
	return puntuados.map((e) => e.producto).toList();
}
