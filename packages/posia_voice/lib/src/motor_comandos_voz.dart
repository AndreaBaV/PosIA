/// Motor principal: interpreta voz y resuelve contra catalogo.
library;

import 'package:posia_core/posia_core.dart';

import 'intencion_comando_voz.dart';
import 'interpretador_comandos_voz.dart';
import 'linea_comando_voz.dart';
import 'resolvedor_cantidad_voz.dart';
import 'resolvedor_producto_voz.dart';
import 'resultado_comando_voz.dart';

/// Convierte transcripcion de voz en lineas de carrito.
class MotorComandosVoz {
	MotorComandosVoz({
		InterpretadorComandosVoz? interpretador,
		ResolvedorCantidadVoz? resolvedor,
		ResolvedorProductoVoz? resolvedorProducto,
	}) : _interpretador = interpretador ?? InterpretadorComandosVoz(),
	     _resolvedor = resolvedor ?? ResolvedorCantidadVoz(),
	     _resolvedorProducto = resolvedorProducto ?? const ResolvedorProductoVoz();

	final InterpretadorComandosVoz _interpretador;
	final ResolvedorCantidadVoz _resolvedor;
	final ResolvedorProductoVoz _resolvedorProducto;

	/// Procesa texto hablado contra catalogo activo.
	ResultadoComandoVoz procesar({
		required String texto,
		required List<Producto> catalogo,
		List<Cliente> clientes = const [],
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

		Cliente? cliente;
		String? clienteNoEncontrado;
		if (interpretacion.usarMostrador) {
			// Sin cliente asignado.
		} else if (interpretacion.nombreClienteSolicitado != null) {
			cliente = _buscarCliente(interpretacion.nombreClienteSolicitado!, clientes);
			if (cliente == null) {
				clienteNoEncontrado = interpretacion.nombreClienteSolicitado;
			}
		}

		final resueltas = <LineaVozResuelta>[];
		final ambiguas = <LineaVozAmbigua>[];
		final sinCoincidencia = <LineaVozSinCoincidencia>[];
		final noEncontrados = <String>[];
		for (final linea in interpretacion.lineas) {
			final resolucion = _resolvedorProducto.resolver(
				consulta: linea.nombreProducto,
				catalogo: catalogo,
			);
			switch (resolucion.estado) {
				case EstadoResolucionProductoVoz.unico:
					final producto = resolucion.producto!;
					resueltas.add(
						_construirLineaResuelta(
							linea: linea,
							producto: producto,
						),
					);
				case EstadoResolucionProductoVoz.ambiguo:
					ambiguas.add(
						LineaVozAmbigua(
							consultaOriginal: linea.nombreProducto,
							cantidadHablada: linea.cantidadHablada,
							unidadHablada: linea.unidadHablada,
							candidatos: resolucion.productosCandidatos,
						),
					);
				case EstadoResolucionProductoVoz.noEncontrado:
					noEncontrados.add(linea.nombreProducto);
					sinCoincidencia.add(
						LineaVozSinCoincidencia(
							consultaOriginal: linea.nombreProducto,
							cantidadHablada: linea.cantidadHablada,
							unidadHablada: linea.unidadHablada,
						),
					);
			}
		}

		return ResultadoComandoVoz(
			intencion: interpretacion.intencion,
			lineas: resueltas,
			noEncontrados: noEncontrados,
			textoOriginal: texto,
			lineasAmbiguas: ambiguas,
			lineasSinCoincidencia: sinCoincidencia,
			cliente: cliente,
			clienteNoEncontrado: clienteNoEncontrado,
			usarMostrador: interpretacion.usarMostrador,
		);
	}

	LineaVozResuelta _construirLineaResuelta({
		required LineaComandoVoz linea,
		required Producto producto,
	}) {
		final cantidad = _resolvedor.resolver(
			cantidadHablada: linea.cantidadHablada,
			unidadHablada: linea.unidadHablada,
			producto: producto,
		);
		final usarPeso = producto.requierePeso() &&
			(linea.unidadHablada == UnidadMedida.kilogramo ||
				producto.unidadMedida == UnidadMedida.kilogramo);
		return LineaVozResuelta(
			producto: producto,
			cantidad: cantidad.cantidadVenta,
			descripcion: '${producto.nombre}: ${cantidad.descripcion}',
			usarPeso: usarPeso,
			consultaOriginal: linea.nombreProducto,
		);
	}

	/// Construye linea resuelta tras elegir producto manualmente.
	LineaVozResuelta construirLineaDesdeSeleccion({
		required LineaVozAmbigua pendiente,
		required Producto producto,
	}) {
		return _construirLineaResuelta(
			linea: LineaComandoVoz(
				nombreProducto: pendiente.consultaOriginal,
				cantidadHablada: pendiente.cantidadHablada,
				unidadHablada: pendiente.unidadHablada,
			),
			producto: producto,
		);
	}

	LineaVozResuelta construirLineaDesdeSinCoincidencia({
		required LineaVozSinCoincidencia pendiente,
		required Producto producto,
	}) {
		return _construirLineaResuelta(
			linea: LineaComandoVoz(
				nombreProducto: pendiente.consultaOriginal,
				cantidadHablada: pendiente.cantidadHablada,
				unidadHablada: pendiente.unidadHablada,
			),
			producto: producto,
		);
	}

	Cliente? _buscarCliente(String consulta, List<Cliente> clientes) {
		final tokens = _tokens(consulta, longitudMinima: 2);
		if (tokens.isEmpty) {
			return null;
		}
		Cliente? mejor;
		var mejorPuntaje = 0;
		for (final cliente in clientes) {
			if (!cliente.activo) {
				continue;
			}
			final puntaje = _puntajeNombre(tokens, cliente.nombre);
			if (puntaje > mejorPuntaje) {
				mejorPuntaje = puntaje;
				mejor = cliente;
			}
		}
		return mejorPuntaje >= 1 ? mejor : null;
	}

	int _puntajeNombre(List<String> tokens, String nombreCliente) {
		final nombre = _tokens(nombreCliente, longitudMinima: 2);
		var puntaje = 0;
		for (final token in tokens) {
			if (nombre.any((n) => n == token || n.contains(token) || token.contains(n))) {
				puntaje++;
			}
		}
		return puntaje;
	}

	List<String> _tokens(String texto, {int longitudMinima = 3}) {
		return texto
			.toLowerCase()
			.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
			.split(RegExp(r'\s+'))
			.where(
				(t) => t.length >= longitudMinima &&
					t.isNotEmpty &&
					!_stopWords.contains(t),
			)
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
