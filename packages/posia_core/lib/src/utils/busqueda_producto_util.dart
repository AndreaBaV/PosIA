/// Busqueda rapida de productos por nombre o codigo.
library;

import '../models/producto.dart';

/// Normaliza texto de busqueda: minusculas y sin acentos (í → i, ñ → n, etc.).
String normalizarTextoBusqueda(String texto) {
	const acentos = {
		'á': 'a',
		'à': 'a',
		'ä': 'a',
		'â': 'a',
		'é': 'e',
		'è': 'e',
		'ë': 'e',
		'ê': 'e',
		'í': 'i',
		'ì': 'i',
		'ï': 'i',
		'î': 'i',
		'ó': 'o',
		'ò': 'o',
		'ö': 'o',
		'ô': 'o',
		'ú': 'u',
		'ù': 'u',
		'ü': 'u',
		'û': 'u',
		'ñ': 'n',
	};
	var s = texto.toLowerCase();
	for (final entry in acentos.entries) {
		s = s.replaceAll(entry.key, entry.value);
	}
	return s;
}

/// Coincide un token de consulta con una palabra del nombre (prefijo, substring o abreviatura).
bool _tokenCoincideConPalabra(String token, String palabra) {
	if (token.isEmpty) {
		return true;
	}
	if (palabra.startsWith(token) || palabra.contains(token)) {
		return true;
	}
	var indice = 0;
	for (final caracter in token.split('')) {
		final hallado = palabra.indexOf(caracter, indice);
		if (hallado < 0) {
			return false;
		}
		indice = hallado + 1;
	}
	return true;
}

/// Puntaje de un token contra las palabras del nombre.
int _puntajeTokenEnNombre(String token, List<String> palabras) {
	var mejor = 0;
	for (final palabra in palabras) {
		if (palabra == token) {
			mejor = mejor < 300 ? 300 : mejor;
			continue;
		}
		if (palabra.startsWith(token)) {
			mejor = mejor < 250 ? 250 : mejor;
			continue;
		}
		if (palabra.contains(token)) {
			mejor = mejor < 180 ? 180 : mejor;
			continue;
		}
		if (_tokenCoincideConPalabra(token, palabra)) {
			mejor = mejor < 120 ? 120 : mejor;
		}
	}
	return mejor;
}

/// Indica si todos los tokens de la consulta coinciden con alguna palabra del nombre.
bool _todosLosTokensCoinciden(List<String> tokens, List<String> palabras) {
	for (final token in tokens) {
		final coincide = palabras.any((p) => _tokenCoincideConPalabra(token, p));
		if (!coincide) {
			return false;
		}
	}
	return true;
}

/// Coincidencia secuencial de caracteres en todo el texto (abreviatura global).
int _puntajeSecuencia(String consulta, String texto) {
	var acumulado = 0;
	var indice = 0;
	for (final caracter in consulta.split('')) {
		if (caracter == ' ') {
			final hallado = texto.indexOf(' ', indice);
			if (hallado < 0) {
				return 0;
			}
			indice = hallado + 1;
			continue;
		}
		final hallado = texto.indexOf(caracter, indice);
		if (hallado < 0) {
			return 0;
		}
		acumulado = acumulado + (100 - hallado);
		indice = hallado + 1;
	}
	return acumulado;
}

/// Puntua coincidencia: prefijo de palabra > substring > codigo.
///
/// Soporta consultas multi-token (`sam 1k` → "Saman arroz 1kg") e ignora acentos.
int puntajeBusquedaProducto(Producto producto, String consulta) {
	final q = normalizarTextoBusqueda(consulta).trim();
	if (q.isEmpty) {
		return 0;
	}
	final nombre = normalizarTextoBusqueda(producto.nombre);
	final codigo = normalizarTextoBusqueda(producto.codigoBarras);
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

	final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
	final palabras = nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

	if (tokens.length == 1) {
		final token = tokens.first;
		for (final palabra in palabras) {
			if (palabra.startsWith(token)) {
				return 600;
			}
		}
		var acumulado = _puntajeSecuencia(token, nombre);
		if (acumulado <= 0) {
			if (codigo.contains(token)) {
				return 150;
			}
			return 0;
		}
		if (nombre.contains(token)) {
			acumulado = acumulado + 200;
		}
		if (codigo.contains(token)) {
			acumulado = acumulado + 150;
		}
		return acumulado;
	}

	// Multi-token: cada token debe coincidir con alguna palabra del nombre.
	if (!_todosLosTokensCoinciden(tokens, palabras)) {
		// Fallback: secuencia sobre el nombre completo (incluye espacios).
		var acumulado = _puntajeSecuencia(q, nombre);
		if (acumulado <= 0) {
			if (codigo.contains(q.replaceAll(' ', ''))) {
				return 150;
			}
			return 0;
		}
		if (nombre.contains(q)) {
			acumulado = acumulado + 200;
		}
		return acumulado;
	}

	var acumulado = 0;
	for (final token in tokens) {
		final puntajeToken = _puntajeTokenEnNombre(token, palabras);
		if (puntajeToken <= 0) {
			return 0;
		}
		acumulado = acumulado + puntajeToken;
	}
	if (nombre.contains(q)) {
		acumulado = acumulado + 200;
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
	final q = normalizarTextoBusqueda(consulta).trim();
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
