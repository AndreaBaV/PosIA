/// Interpreta dictados de alta/edicion de producto en espanol mexicano.
library;

import 'package:posia_core/posia_core.dart';

import 'borrador_producto_voz.dart';

/// Convierte transcripcion STT a un borrador para el formulario de producto.
///
/// Frases tipicas:
/// - "Producto Coca Cola precio 25 costo 18 categoria refrescos stock 40"
/// - "Jitomate por kilo a 35 pesos medio kilo 20 cuarto 12"
/// - "Nombre arroz codigo 750123 precio 28.50 mayoreo desde 10 a 25"
class InterpretadorAltaProductoVoz {
	static const Map<String, double> _numerosHablados = {
		'cero': 0,
		'un': 1,
		'uno': 1,
		'una': 1,
		'dos': 2,
		'tres': 3,
		'cuatro': 4,
		'cinco': 5,
		'seis': 6,
		'siete': 7,
		'ocho': 8,
		'nueve': 9,
		'diez': 10,
		'once': 11,
		'doce': 12,
		'trece': 13,
		'catorce': 14,
		'quince': 15,
		'dieciseis': 16,
		'diecisiete': 17,
		'dieciocho': 18,
		'diecinueve': 19,
		'veinte': 20,
		'veintiuno': 21,
		'veintiun': 21,
		'veintidos': 22,
		'veintitres': 23,
		'veinticuatro': 24,
		'veinticinco': 25,
		'veintiseis': 26,
		'veintisiete': 27,
		'veintiocho': 28,
		'veintinueve': 29,
		'treinta': 30,
		'cuarenta': 40,
		'cincuenta': 50,
		'sesenta': 60,
		'setenta': 70,
		'ochenta': 80,
		'noventa': 90,
		'cien': 100,
		'ciento': 100,
	};

	static final RegExp _prefijos = RegExp(
		r'^(?:'
		r'alta\s+(?:de\s+)?(?:producto\s+)?|'
		r'registra(?:r)?\s+(?:producto\s+)?|'
		r'crea(?:r)?\s+(?:producto\s+)?|'
		r'nuevo\s+producto\s*:?\s*|'
		r'producto\s+nuevo\s*:?\s*|'
		r'producto\s*:?\s*'
		r')',
		caseSensitive: false,
	);

	/// Captura montos numericos o hablados: "25", "28.50", "veinticinco", "treinta y cinco".
	static final RegExp _valorMonto = RegExp(
		r'(?<valor>'
		r'[\d]+(?:[.,]\d{1,2})?'
		r'|'
		r'(?:veinti(?:un[oa]?|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)|'
		r'dieciseis|diecisiete|dieciocho|diecinueve|'
		r'cero|un[oa]?|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|'
		r'once|doce|trece|catorce|quince|veinte|treinta|cuarenta|cincuenta|'
		r'sesenta|setenta|ochenta|noventa|cien|ciento)'
		r'(?:\s+y\s+'
		r'(?:un[oa]?|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)'
		r')?'
		r')',
		caseSensitive: false,
	);

	static final RegExp _campoMonto = RegExp(
		r'(?<etiqueta>'
		r'precio(?:\s+(?:de\s+)?(?:venta|menudeo|base|unitario|publico))?'
		r'|cuesta|vale|sale(?:\s+a)?'
		r'|costo(?:\s+(?:de\s+)?(?:compra|unitario))?'
		r'|compre\s+(?:a|en)|compre|compreh?e'
		r'|stock(?:\s+inicial)?'
		r'|existencia(?:s)?'
		r'|cantidad(?:\s+inicial)?'
		r'|stock\s+minimo|minimo'
		r'|medio(?:\s+(?:kilo|kg))?'
		r'|cuarto(?:\s+(?:de\s+)?(?:kilo|kg))?'
		r')'
		r'\s*(?:es\s+|de\s+|a\s+|en\s+|por\s+|:?\s*)?'
		r'(?:pesos?\s+|\$\s*)?'
		r'(?<valor>'
		r'[\d]+(?:[.,]\d{1,2})?'
		r'|'
		r'(?:veinti(?:un[oa]?|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)|'
		r'dieciseis|diecisiete|dieciocho|diecinueve|'
		r'cero|un[oa]?|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|'
		r'once|doce|trece|catorce|quince|veinte|treinta|cuarenta|cincuenta|'
		r'sesenta|setenta|ochenta|noventa|cien|ciento)'
		r'(?:\s+y\s+'
		r'(?:un[oa]?|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)'
		r')?'
		r')'
		r'(?:\s*(?:pesos?|mxn|\$))?',
		caseSensitive: false,
	);

	static final RegExp _campoTexto = RegExp(
		r'(?<etiqueta>'
		r'nombre'
		r'|codigo(?:\s+de\s+barras)?'
		r'|barras|sku'
		r'|categoria|rubro|departamento'
		r'|proveedor'
		r'|notas?|comentario'
		r'|unidad(?:\s+de\s+venta)?'
		r'|se\s+vende(?:\s+por)?'
		r')'
		r'\s*:?\s+'
		r'(?<valor>.+?)'
		r'(?=\s+(?:'
		r'precio|cuesta|vale|sale|costo|compre|stock|existencia|cantidad|minimo|'
		r'medio|cuarto|nombre|codigo|barras|sku|categoria|rubro|departamento|'
		r'proveedor|nota|comentario|unidad|se\s+vende|mayoreo|escala'
		r')\b|$)',
		caseSensitive: false,
	);

	static final RegExp _mayoreo = RegExp(
		r'(?:mayoreo|escala)(?:\s+desde)?\s+(?<cant>[\d]+(?:[.,]\d+)?|'
		r'diez|doce|veinte|treinta|cincuenta|cien)\s+'
		r'(?:a|por|en|=|:|precio)\s*(?:pesos?\s+|\$\s*)?(?<precio>[\d]+(?:[.,]\d{1,2})?)',
		caseSensitive: false,
	);

	static final RegExp _precioImplicito = RegExp(
		r'(?:^|\s)(?:a|por)\s+(?:\$\s*)?(?<v>'
		r'[\d]+(?:[.,]\d{1,2})?'
		r'|'
		r'(?:veinti(?:un[oa]?|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)|'
		r'dieciseis|diecisiete|dieciocho|diecinueve|'
		r'cero|un[oa]?|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|'
		r'once|doce|trece|catorce|quince|veinte|treinta|cuarenta|cincuenta|'
		r'sesenta|setenta|ochenta|noventa|cien|ciento)'
		r'(?:\s+y\s+(?:un[oa]?|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve))?'
		r')'
		r'(?:\s*(?:pesos?|mxn))?(?:\s|$)',
		caseSensitive: false,
	);

	/// Analiza el texto dictado y construye un borrador parcial.
	BorradorProductoVoz interpretar(String textoOriginal) {
		var texto = _normalizar(textoOriginal);
		if (texto.isEmpty) {
			return const BorradorProductoVoz();
		}
		texto = texto.replaceFirst(_prefijos, '').trim();
		if (texto.isEmpty) {
			return const BorradorProductoVoz();
		}

		String? nombre;
		String? codigo;
		String? categoria;
		String? proveedor;
		String? notas;
		UnidadMedida? unidad;
		double? precio;
		double? costo;
		double? stock;
		double? minimo;
		double? medio;
		double? cuarto;
		final escalas = <EscalaMayoreoVoz>[];
		final campos = <String>[];

		unidad = _detectarUnidadEnFrase(texto);

		for (final m in _mayoreo.allMatches(texto)) {
			final cant = _parsearMonto(m.namedGroup('cant'));
			final prec = _parsearMonto(m.namedGroup('precio'));
			if (cant != null && prec != null && cant > 0 && prec > 0) {
				final yaExiste = escalas.any(
					(e) => e.cantidadMinima == cant && e.precioUnitario == prec,
				);
				if (!yaExiste) {
					escalas.add(
						EscalaMayoreoVoz(cantidadMinima: cant, precioUnitario: prec),
					);
				}
			}
		}
		if (escalas.isNotEmpty) {
			_marcar(campos, 'escalas');
		}

		for (final m in _campoMonto.allMatches(texto)) {
			final etiqueta = (m.namedGroup('etiqueta') ?? '').toLowerCase().trim();
			final valor = _parsearMonto(m.namedGroup('valor'));
			if (valor == null) {
				continue;
			}
			if (_empiezaCon(etiqueta, const [
				'precio',
				'cuesta',
				'vale',
				'sale',
			])) {
				precio = valor;
				_marcar(campos, 'precio');
			} else if (_empiezaCon(etiqueta, const ['costo', 'compre'])) {
				costo = valor;
				_marcar(campos, 'costo');
			} else if (_empiezaCon(etiqueta, const ['stock minimo', 'minimo'])) {
				minimo = valor;
				_marcar(campos, 'minimo');
			} else if (_empiezaCon(etiqueta, const [
				'stock',
				'existencia',
				'cantidad',
			])) {
				stock = valor;
				_marcar(campos, 'stock');
			} else if (_empiezaCon(etiqueta, const ['medio'])) {
				medio = valor;
				_marcar(campos, 'medio');
			} else if (_empiezaCon(etiqueta, const ['cuarto'])) {
				cuarto = valor;
				_marcar(campos, 'cuarto');
			}
		}

		for (final m in _campoTexto.allMatches(texto)) {
			final etiqueta = (m.namedGroup('etiqueta') ?? '').toLowerCase().trim();
			var valor = (m.namedGroup('valor') ?? '').trim();
			valor = valor.replaceAll(RegExp(r'[.,;:]+$'), '').trim();
			if (valor.isEmpty) {
				continue;
			}
			if (_empiezaCon(etiqueta, const ['nombre'])) {
				nombre = _capitalizarNombre(valor);
				_marcar(campos, 'nombre');
			} else if (_empiezaCon(etiqueta, const ['codigo', 'barras', 'sku'])) {
				codigo = valor.replaceAll(RegExp(r'\s+'), '');
				_marcar(campos, 'codigo');
			} else if (_empiezaCon(etiqueta, const [
				'categoria',
				'rubro',
				'departamento',
			])) {
				categoria = _capitalizarNombre(valor);
				_marcar(campos, 'categoria');
			} else if (_empiezaCon(etiqueta, const ['proveedor'])) {
				proveedor = _capitalizarNombre(valor);
				_marcar(campos, 'proveedor');
			} else if (_empiezaCon(etiqueta, const ['nota', 'comentario'])) {
				notas = valor;
				_marcar(campos, 'notas');
			} else if (_empiezaCon(etiqueta, const ['unidad', 'se vende'])) {
				final detectada = _parsearUnidad(valor);
				if (detectada != null) {
					unidad = detectada;
				}
			}
		}

		if (unidad != null) {
			_marcar(campos, 'unidad');
		}

		if (nombre == null) {
			nombre = _extraerNombreImplicito(texto);
			if (nombre != null && nombre.isNotEmpty) {
				_marcar(campos, 'nombre');
			} else {
				nombre = null;
			}
		}

		if (precio == null) {
			final m = _precioImplicito.firstMatch(texto);
			final v = _parsearMonto(m?.namedGroup('v'));
			if (v != null) {
				precio = v;
				_marcar(campos, 'precio');
			}
		}

		return BorradorProductoVoz(
			nombre: nombre,
			codigoBarras: codigo,
			precioBase: precio,
			costoUnitario: costo,
			nombreCategoria: categoria,
			unidadMedida: unidad,
			nombreProveedor: proveedor,
			stockInicial: stock,
			stockMinimo: minimo,
			notas: notas,
			precioMedioKilo: medio,
			precioCuartoKilo: cuarto,
			escalasMayoreo: escalas,
			textoLimpio: texto,
			camposDetectados: List<String>.unmodifiable(campos),
		);
	}

	String? _extraerNombreImplicito(String texto) {
		final corte = RegExp(
			r'\s+(?:'
			r'precio|cuesta|vale|sale|costo|compre|stock|existencia|cantidad|'
			r'minimo|medio|cuarto|codigo|barras|sku|categoria|rubro|departamento|'
			r'proveedor|nota|comentario|unidad|se\s+vende|mayoreo|escala|'
			r'a\s+(?:[\d]|veinte|treinta|cuarenta|cincuenta|sesenta|setenta|'
			r'ochenta|noventa|cien|un[oa]?|dos|tres)|'
			r'por\s+(?:kilo|kg|litro|pieza|caja)|'
			r'al\s+kilo'
			r')\b',
			caseSensitive: false,
		);
		final m = corte.firstMatch(texto);
		final raw = (m == null ? texto : texto.substring(0, m.start)).trim();
		if (raw.isEmpty) {
			return null;
		}
		if (_valorMonto.hasMatch(raw) &&
			raw.replaceAll(_valorMonto, '').trim().isEmpty) {
			return null;
		}
		final limpio = raw
			.replaceFirst(
				RegExp(r'^(?:el|la|los|las|un|una)\s+', caseSensitive: false),
				'',
			)
			.trim();
		if (limpio.length < 2) {
			return null;
		}
		return _capitalizarNombre(limpio);
	}

	UnidadMedida? _detectarUnidadEnFrase(String texto) {
		if (RegExp(
			r'\b(?:por\s+kilo|por\s+kg|al\s+kilo|se\s+vende\s+por\s+kilo|'
			r'medio(?:\s+(?:kilo|kg))|cuarto(?:\s+(?:de\s+)?(?:kilo|kg))|'
			r'kilogramos?)\b',
			caseSensitive: false,
		).hasMatch(texto)) {
			return UnidadMedida.kilogramo;
		}
		if (RegExp(
			r'\b(?:por\s+litro|se\s+vende\s+por\s+litro|litros)\b',
			caseSensitive: false,
		).hasMatch(texto)) {
			return UnidadMedida.litro;
		}
		if (RegExp(
			r'\b(?:por\s+caja|se\s+vende\s+por\s+caja|cajas)\b',
			caseSensitive: false,
		).hasMatch(texto)) {
			return UnidadMedida.caja;
		}
		if (RegExp(
			r'\b(?:por\s+pieza|se\s+vende\s+por\s+pieza|piezas|pza)\b',
			caseSensitive: false,
		).hasMatch(texto)) {
			return UnidadMedida.pieza;
		}
		return null;
	}

	UnidadMedida? _parsearUnidad(String raw) {
		final u = raw.toLowerCase().trim();
		if (u.contains('kilo') || u == 'kg' || u.startsWith('gram')) {
			return UnidadMedida.kilogramo;
		}
		if (u.contains('litro') || u == 'l') {
			return UnidadMedida.litro;
		}
		if (u.contains('caja') || u.contains('carton')) {
			return UnidadMedida.caja;
		}
		if (u.contains('pieza') || u.contains('pza') || u.contains('unidad')) {
			return UnidadMedida.pieza;
		}
		return null;
	}

	double? _parsearMonto(String? raw) {
		if (raw == null || raw.trim().isEmpty) {
			return null;
		}
		final limpio = raw.toLowerCase().trim();
		final numerico = double.tryParse(limpio.replaceAll(',', '.'));
		if (numerico != null) {
			return numerico;
		}
		final partes = limpio.split(RegExp(r'\s+y\s+'));
		if (partes.length == 2) {
			final a = _numerosHablados[partes[0].trim()];
			final b = _numerosHablados[partes[1].trim()];
			if (a != null && b != null) {
				return a + b;
			}
		}
		return _numerosHablados[limpio];
	}

	bool _empiezaCon(String etiqueta, List<String> claves) {
		final e = etiqueta.toLowerCase().trim();
		for (final c in claves) {
			if (e == c || e.startsWith('$c ')) {
				return true;
			}
		}
		return false;
	}

	void _marcar(List<String> campos, String campo) {
		if (!campos.contains(campo)) {
			campos.add(campo);
		}
	}

	String _capitalizarNombre(String valor) {
		final partes = valor.split(RegExp(r'\s+'));
		return partes
			.map((p) {
				if (p.isEmpty) {
					return p;
				}
				if (RegExp(r'^\d').hasMatch(p)) {
					return p;
				}
				return '${p[0].toUpperCase()}${p.substring(1)}';
			})
			.join(' ');
	}

	String _normalizar(String texto) {
		return texto
			.toLowerCase()
			.replaceAll('á', 'a')
			.replaceAll('é', 'e')
			.replaceAll('í', 'i')
			.replaceAll('ó', 'o')
			.replaceAll('ú', 'u')
			.replaceAll('ñ', 'n')
			.replaceAll(RegExp(r'\s+'), ' ')
			.trim();
	}
}
