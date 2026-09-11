/// Busqueda rapida de productos por nombre o codigo.
library;

import '../models/producto.dart';

/// Capas de relevancia: exacta > parcial > parecida.
const int _puntajeExactaCodigo = 1000;
const int _puntajeExactaNombre = 950;
const int _puntajePrefijoCodigo = 900;
const int _puntajePrefijoNombre = 850;
const int _puntajePalabraExacta = 800;
const int _puntajePrefijoPalabra = 700;
const int _puntajeSubstring = 500;
const int _puntajeParecidaMax = 220;
const int _puntajeCodigoContiene = 150;

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

/// Indica si [texto] contiene [consulta] ignorando mayúsculas y acentos.
bool textoContieneBusqueda(String texto, String consulta) {
	final q = normalizarTextoBusqueda(consulta).trim();
	if (q.isEmpty) {
		return true;
	}
	return normalizarTextoBusqueda(texto).contains(q);
}

/// Indica si el producto coincide con la consulta (mismo criterio que la caja).
bool productoCoincideBusqueda(Producto producto, String consulta) {
	final q = normalizarTextoBusqueda(consulta).trim();
	if (q.isEmpty) {
		return true;
	}
	return puntajeBusquedaProducto(producto, q) > 0;
}

/// Prefijo que marca un código de barras generado internamente por el sistema
/// para un producto sin código real (deduplicación por nombre).
///
/// Nunca se muestra al usuario final (ver [Producto.codigoBarrasVisible]).
const String PREFIJO_CODIGO_INTERNO = '#';

/// Genera un código interno idempotente derivado del nombre del producto.
///
/// Todos los dispositivos generan exactamente el mismo código para el mismo
/// nombre normalizado, así que dos altas separadas del mismo producto
/// (importaciones a granel, altas paralelas en distintas cajas) colisionan en
/// el índice único `(tienda_id, codigo_barras) WHERE activo=1` y no se
/// duplican en el catálogo.
///
/// Formato: `#nombre-normalizado` (minúsculas, sin acentos, solo letras y
/// dígitos separados por guiones). Cadena vacía si el nombre no contiene
/// caracteres alfanuméricos utilizables.
String generarCodigoInternoDesdeNombre(String nombre) {
	final normalizado = normalizarTextoBusqueda(nombre.trim());
	final buffer = StringBuffer();
	var ultimoFueGuion = true;
	for (final rune in normalizado.runes) {
		final c = String.fromCharCode(rune);
		final esAlfanumerico = RegExp(r'[a-z0-9]').hasMatch(c);
		if (esAlfanumerico) {
			buffer.write(c);
			ultimoFueGuion = false;
		} else if (!ultimoFueGuion) {
			buffer.write('-');
			ultimoFueGuion = true;
		}
	}
	var codigo = buffer.toString();
	while (codigo.endsWith('-')) {
		codigo = codigo.substring(0, codigo.length - 1);
	}
	if (codigo.isEmpty) {
		return '';
	}
	return '$PREFIJO_CODIGO_INTERNO$codigo';
}

/// `true` cuando el código proporcionado fue generado por el sistema y no
/// corresponde a un código de barras real capturado o escaneado.
bool esCodigoBarrasInterno(String codigo) {
	return codigo.startsWith(PREFIJO_CODIGO_INTERNO);
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

/// Distancia de edición acotada; -1 si supera [maxDistancia].
int _distanciaLevenshteinAcotada(String a, String b, int maxDistancia) {
	if (a == b) {
		return 0;
	}
	if ((a.length - b.length).abs() > maxDistancia) {
		return -1;
	}
	if (a.isEmpty) {
		return b.length <= maxDistancia ? b.length : -1;
	}
	if (b.isEmpty) {
		return a.length <= maxDistancia ? a.length : -1;
	}
	var previa = List<int>.generate(b.length + 1, (i) => i);
	for (var i = 1; i <= a.length; i++) {
		final actual = List<int>.filled(b.length + 1, 0);
		actual[0] = i;
		var filaMin = actual[0];
		for (var j = 1; j <= b.length; j++) {
			final costo = a[i - 1] == b[j - 1] ? 0 : 1;
			actual[j] = [
				previa[j] + 1,
				actual[j - 1] + 1,
				previa[j - 1] + costo,
			].reduce((x, y) => x < y ? x : y);
			if (actual[j] < filaMin) {
				filaMin = actual[j];
			}
		}
		if (filaMin > maxDistancia) {
			return -1;
		}
		previa = actual;
	}
	final dist = previa[b.length];
	return dist <= maxDistancia ? dist : -1;
}

/// Puntaje de un token contra las palabras del nombre (exacta > parcial > parecida).
int _puntajeTokenEnNombre(String token, List<String> palabras) {
	var mejor = 0;
	for (final palabra in palabras) {
		if (palabra == token) {
			mejor = mejor < _puntajePalabraExacta ? _puntajePalabraExacta : mejor;
			continue;
		}
		if (palabra.startsWith(token)) {
			mejor = mejor < _puntajePrefijoPalabra ? _puntajePrefijoPalabra : mejor;
			continue;
		}
		if (palabra.contains(token)) {
			mejor = mejor < _puntajeSubstring ? _puntajeSubstring : mejor;
			continue;
		}
		final dist = _distanciaLevenshteinAcotada(token, palabra, 2);
		if (dist >= 0 && dist <= 2) {
			final parecida = _puntajeParecidaMax - (dist * 40);
			mejor = mejor < parecida ? parecida : mejor;
			continue;
		}
		if (_tokenCoincideConPalabra(token, palabra)) {
			const abreviatura = 120;
			mejor = mejor < abreviatura ? abreviatura : mejor;
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
		// Penaliza huecos largos para no competir con coincidencias parciales.
		final hueco = hallado - indice;
		acumulado = acumulado + (40 - hueco).clamp(1, 40);
		indice = hallado + 1;
	}
	return acumulado.clamp(1, _puntajeParecidaMax);
}

/// Puntua coincidencia: exacta > parcial > parecida.
///
/// Soporta consultas multi-token (`sam 1k` → "Saman arroz 1kg") e ignora acentos.
int puntajeBusquedaProducto(Producto producto, String consulta) {
	final q = normalizarTextoBusqueda(consulta).trim();
	if (q.isEmpty) {
		return 0;
	}
	final nombre = normalizarTextoBusqueda(producto.nombre);
	// El código interno es un espejo del nombre; ignorarlo en el puntaje evita
	// dobles conteos cuando el usuario escribe parte del nombre.
	final codigo = esCodigoBarrasInterno(producto.codigoBarras)
		? ''
		: normalizarTextoBusqueda(producto.codigoBarras);
	if (codigo.isNotEmpty && codigo == q) {
		return _puntajeExactaCodigo;
	}
	if (nombre == q) {
		return _puntajeExactaNombre;
	}
	if (codigo.startsWith(q)) {
		return _puntajePrefijoCodigo;
	}
	if (nombre.startsWith(q)) {
		return _puntajePrefijoNombre;
	}

	final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
	final palabras = nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

	if (tokens.length == 1) {
		final token = tokens.first;
		final puntajePalabra = _puntajeTokenEnNombre(token, palabras);
		if (puntajePalabra >= _puntajeSubstring) {
			return puntajePalabra;
		}
		if (nombre.contains(token)) {
			return _puntajeSubstring;
		}
		if (puntajePalabra > 0) {
			return puntajePalabra;
		}
		final secuencia = _puntajeSecuencia(token, nombre);
		if (secuencia > 0) {
			return secuencia;
		}
		if (codigo.contains(token)) {
			return _puntajeCodigoContiene;
		}
		return 0;
	}

	// Multi-token: cada token debe coincidir con alguna palabra del nombre.
	if (!_todosLosTokensCoinciden(tokens, palabras)) {
		final secuencia = _puntajeSecuencia(q, nombre);
		if (secuencia > 0) {
			return secuencia;
		}
		if (codigo.contains(q.replaceAll(' ', ''))) {
			return _puntajeCodigoContiene;
		}
		return 0;
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
		acumulado = acumulado + 80;
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
	puntuados.sort((a, b) {
		final porPuntaje = b.puntaje.compareTo(a.puntaje);
		if (porPuntaje != 0) {
			return porPuntaje;
		}
		// A igualdad, nombres mas cortos (mas especificos) primero.
		final porLongitud =
			a.producto.nombre.length.compareTo(b.producto.nombre.length);
		if (porLongitud != 0) {
			return porLongitud;
		}
		return a.producto.nombre.toLowerCase().compareTo(
			b.producto.nombre.toLowerCase(),
		);
	});
	return puntuados.map((e) => e.producto).toList();
}
