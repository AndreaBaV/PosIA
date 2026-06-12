/// Motor principal: interpreta voz y resuelve contra catalogo.
library;

import 'package:posia_core/posia_core.dart';

import 'intencion_comando_voz.dart';
import 'interpretador_comandos_voz.dart';
import 'resolvedor_cantidad_voz.dart';
import 'resultado_comando_voz.dart';

/// Convierte transcripcion de voz en lineas de carrito.
class MotorComandosVoz {
	MotorComandosVoz({
		InterpretadorComandosVoz? interpretador,
		ResolvedorCantidadVoz? resolvedor,
	}) : _interpretador = interpretador ?? InterpretadorComandosVoz(),
	     _resolvedor = resolvedor ?? ResolvedorCantidadVoz();

	final InterpretadorComandosVoz _interpretador;
	final ResolvedorCantidadVoz _resolvedor;

	/// Procesa texto hablado contra catalogo activo.
	ResultadoComandoVoz procesar({
		required String texto,
		required List<Producto> catalogo,
	}) {
		final interpretacion = _interpretador.interpretar(texto);
		if (interpretacion.intencion != IntencionComandoVoz.agregarProductos) {
			return ResultadoComandoVoz(
				intencion: interpretacion.intencion,
				lineas: const [],
				noEncontrados: const [],
				textoOriginal: texto,
			);
		}

		final resueltas = <LineaVozResuelta>[];
		final noEncontrados = <String>[];
		for (final linea in interpretacion.lineas) {
			final producto = _buscarProducto(linea.nombreProducto, catalogo);
			if (producto == null) {
				noEncontrados.add(linea.nombreProducto);
				continue;
			}
			final cantidad = _resolvedor.resolver(
				cantidadHablada: linea.cantidadHablada,
				unidadHablada: linea.unidadHablada,
				producto: producto,
			);
			final usarPeso = producto.requierePeso() &&
				(linea.unidadHablada == UnidadMedida.kilogramo ||
					producto.unidadMedida == UnidadMedida.kilogramo);
			resueltas.add(
				LineaVozResuelta(
					producto: producto,
					cantidad: cantidad.cantidadVenta,
					descripcion: '${producto.nombre}: ${cantidad.descripcion}',
					usarPeso: usarPeso,
				),
			);
		}

		return ResultadoComandoVoz(
			intencion: interpretacion.intencion,
			lineas: resueltas,
			noEncontrados: noEncontrados,
			textoOriginal: texto,
		);
	}

	Producto? _buscarProducto(String consulta, List<Producto> catalogo) {
		final tokens = _tokens(consulta);
		if (tokens.isEmpty) {
			return null;
		}
		Producto? mejor;
		var mejorPuntaje = 0;
		for (final producto in catalogo) {
			final puntaje = _puntaje(tokens, producto.nombre);
			if (puntaje > mejorPuntaje) {
				mejorPuntaje = puntaje;
				mejor = producto;
			}
		}
		return mejorPuntaje >= 1 ? mejor : null;
	}

	int _puntaje(List<String> tokens, String nombreProducto) {
		final nombre = _tokens(nombreProducto);
		var puntaje = 0;
		for (final token in tokens) {
			if (token.length < 3) {
				continue;
			}
			if (nombre.any((n) => n == token || n.contains(token) || token.contains(n))) {
				puntaje++;
			}
		}
		return puntaje;
	}

	List<String> _tokens(String texto) {
		return texto
			.toLowerCase()
			.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
			.split(RegExp(r'\s+'))
			.where((t) => t.isNotEmpty && !_stopWords.contains(t))
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
	};
}
