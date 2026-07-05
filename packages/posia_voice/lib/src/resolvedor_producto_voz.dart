/// Resolucion de productos hablados contra catalogo con deteccion de ambiguedad.
library;

import 'package:posia_core/posia_core.dart';

/// Estado de la coincidencia de un producto hablado.
enum EstadoResolucionProductoVoz {
	/// Un solo candidato claro.
	unico,

	/// Varios candidatos con puntaje similar o termino generico.
	ambiguo,

	/// Ningun candidato aceptable.
	noEncontrado,
}

/// Candidato rankeado para desambiguacion.
class CandidatoProductoVoz {
	const CandidatoProductoVoz({
		required this.producto,
		required this.puntaje,
	});

	final Producto producto;
	final int puntaje;
}

/// Resultado de buscar un producto en el catalogo por voz.
class ResolucionProductoVoz {
	const ResolucionProductoVoz({
		required this.estado,
		required this.consulta,
		this.producto,
		this.candidatos = const [],
	});

	final EstadoResolucionProductoVoz estado;
	final String consulta;
	final Producto? producto;
	final List<CandidatoProductoVoz> candidatos;

	List<Producto> get productosCandidatos =>
		candidatos.map((c) => c.producto).toList();
}

/// Empareja texto hablado con productos evitando falsos positivos genericos.
class ResolvedorProductoVoz {
	const ResolvedorProductoVoz({
		this.maxCandidatosAmbiguos = 12,
		this.minimaVentajaPuntaje = 2,
	});

	final int maxCandidatosAmbiguos;
	final int minimaVentajaPuntaje;

	ResolucionProductoVoz resolver({
		required String consulta,
		required List<Producto> catalogo,
	}) {
		final tokens = _tokens(consulta);
		if (tokens.isEmpty) {
			return ResolucionProductoVoz(
				estado: EstadoResolucionProductoVoz.noEncontrado,
				consulta: consulta,
			);
		}

		final candidatos = <CandidatoProductoVoz>[];
		for (final producto in catalogo) {
			final puntaje = _puntaje(tokens, producto.nombre);
			if (puntaje > 0) {
				candidatos.add(CandidatoProductoVoz(producto: producto, puntaje: puntaje));
			}
		}
		if (candidatos.isEmpty) {
			return ResolucionProductoVoz(
				estado: EstadoResolucionProductoVoz.noEncontrado,
				consulta: consulta,
			);
		}

		candidatos.sort((a, b) {
			final diff = b.puntaje.compareTo(a.puntaje);
			if (diff != 0) {
				return diff;
			}
			return a.producto.nombre.length.compareTo(b.producto.nombre.length);
		});

		final mejor = candidatos.first;
		final empateSuperior = candidatos
			.where((c) => c.puntaje == mejor.puntaje)
			.length;

		if (empateSuperior > 1) {
			return ResolucionProductoVoz(
				estado: EstadoResolucionProductoVoz.ambiguo,
				consulta: consulta,
				candidatos: candidatos
					.where((c) => c.puntaje == mejor.puntaje)
					.take(maxCandidatosAmbiguos)
					.toList(),
			);
		}

		if (tokens.length == 1 && candidatos.length > 1) {
			return ResolucionProductoVoz(
				estado: EstadoResolucionProductoVoz.ambiguo,
				consulta: consulta,
				candidatos: candidatos.take(maxCandidatosAmbiguos).toList(),
			);
		}

		if (candidatos.length > 1) {
			final segundo = candidatos[1];
			final ventaja = mejor.puntaje - segundo.puntaje;
			final cubreTodosLosTokens = _cubreTodosLosTokens(tokens, mejor.producto.nombre);
			if (ventaja < minimaVentajaPuntaje && !cubreTodosLosTokens) {
				return ResolucionProductoVoz(
					estado: EstadoResolucionProductoVoz.ambiguo,
					consulta: consulta,
					candidatos: candidatos.take(maxCandidatosAmbiguos).toList(),
				);
			}
		}

		if (!_cubreTodosLosTokens(tokens, mejor.producto.nombre) &&
			candidatos.length > 1) {
			return ResolucionProductoVoz(
				estado: EstadoResolucionProductoVoz.ambiguo,
				consulta: consulta,
				candidatos: candidatos.take(maxCandidatosAmbiguos).toList(),
			);
		}

		return ResolucionProductoVoz(
			estado: EstadoResolucionProductoVoz.unico,
			consulta: consulta,
			producto: mejor.producto,
			candidatos: [mejor],
		);
	}

	bool _cubreTodosLosTokens(List<String> tokens, String nombreProducto) {
		final nombre = _tokens(nombreProducto);
		for (final token in tokens) {
			final coincide = nombre.any(
				(n) => n == token || n.contains(token) || token.contains(n),
			);
			if (!coincide) {
				return false;
			}
		}
		return true;
	}

	int _puntaje(List<String> tokens, String nombreProducto) {
		final nombre = _tokens(nombreProducto);
		var puntaje = 0;
		for (final token in tokens) {
			if (token.length < 3) {
				continue;
			}
			for (final palabra in nombre) {
				if (palabra == token) {
					puntaje += 12;
				} else if (palabra.startsWith(token) || token.startsWith(palabra)) {
					puntaje += 8;
				} else if (palabra.contains(token) || token.contains(palabra)) {
					puntaje += 4;
				}
			}
		}
		return puntaje;
	}

	List<String> _tokens(String texto) {
		return texto
			.toLowerCase()
			.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
			.split(RegExp(r'\s+'))
			.where((t) => t.length >= 2 && t.isNotEmpty && !_stopWords.contains(t))
			.toList();
	}

	static const Set<String> _stopWords = {
		'de',
		'del',
		'la',
		'el',
		'los',
		'las',
		'un',
		'una',
		'con',
		'sin',
		'litro',
		'litros',
		'pza',
		'pzas',
		'pieza',
		'piezas',
	};
}
