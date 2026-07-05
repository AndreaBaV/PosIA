/// Resultado de aplicar un comando de voz al catalogo.
library;

import 'package:posia_core/posia_core.dart';

import 'intencion_comando_voz.dart';

/// Linea lista para agregar al carrito.
class LineaVozResuelta {
	const LineaVozResuelta({
		required this.producto,
		required this.cantidad,
		required this.descripcion,
		required this.usarPeso,
		this.consultaOriginal,
	});

	final Producto producto;
	final double cantidad;
	final String descripcion;
	final bool usarPeso;
	final String? consultaOriginal;
}

/// Linea que requiere que el usuario elija producto entre candidatos.
class LineaVozAmbigua {
	const LineaVozAmbigua({
		required this.consultaOriginal,
		required this.cantidadHablada,
		required this.unidadHablada,
		required this.candidatos,
	});

	final String consultaOriginal;
	final double cantidadHablada;
	final UnidadMedida? unidadHablada;
	final List<Producto> candidatos;
}

/// Linea sin coincidencia clara; el usuario puede buscar manualmente.
class LineaVozSinCoincidencia {
	const LineaVozSinCoincidencia({
		required this.consultaOriginal,
		required this.cantidadHablada,
		required this.unidadHablada,
	});

	final String consultaOriginal;
	final double cantidadHablada;
	final UnidadMedida? unidadHablada;
}

/// Resultado completo del motor de voz.
class ResultadoComandoVoz {
	const ResultadoComandoVoz({
		required this.intencion,
		required this.lineas,
		required this.noEncontrados,
		required this.textoOriginal,
		this.lineasAmbiguas = const [],
		this.lineasSinCoincidencia = const [],
		this.cliente,
		this.clienteNoEncontrado,
		this.usarMostrador = false,
	});

	final IntencionComandoVoz intencion;
	final List<LineaVozResuelta> lineas;
	final List<String> noEncontrados;
	final String textoOriginal;

	/// Productos con varias coincidencias plausibles (ej. muchas leches).
	final List<LineaVozAmbigua> lineasAmbiguas;

	/// Productos sin match; el usuario puede buscar en catalogo completo.
	final List<LineaVozSinCoincidencia> lineasSinCoincidencia;

	/// Cliente resuelto contra el catalogo de clientes activos.
	final Cliente? cliente;

	/// Nombre hablado que no coincidio con ningun cliente.
	final String? clienteNoEncontrado;

	/// Venta a mostrador (sin cliente).
	final bool usarMostrador;

	bool get tieneLineas => lineas.isNotEmpty;

	bool get requiereConfirmacion =>
		lineasAmbiguas.isNotEmpty || lineasSinCoincidencia.isNotEmpty;
}
