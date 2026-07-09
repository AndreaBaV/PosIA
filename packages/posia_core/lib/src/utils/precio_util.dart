/// Validacion de precios de venta contra costo y utilidad minima.
library;

import '../constants/posia_constants.dart';
import '../enums/modo_calculo_utilidad.dart';
import '../enums/modulo_vertical.dart';
import '../enums/unidad_medida.dart';
import 'moneda_util.dart';

/// Calcula el precio minimo permitido segun costo y margen minimo.
double calcularPrecioMinimoVenta(double costoUnitario) {
	if (costoUnitario <= 0.0) {
		return 0.01;
	}
	final factor = 1.0 + (MARGEN_UTILIDAD_MINIMA_PORCENTAJE / 100.0);
	return redondearMonto(costoUnitario * factor);
}

/// Indica si el precio cumple costo y utilidad minima.
bool precioVentaEsValido(double precioUnitario, double costoUnitario) {
	if (precioUnitario <= 0.0) {
		return false;
	}
	return precioUnitario >= calcularPrecioMinimoVenta(costoUnitario);
}

/// Mensaje de error cuando el precio queda bajo costo o margen minimo.
String mensajePrecioMinimoInvalido(double costoUnitario) {
	final minimo = calcularPrecioMinimoVenta(costoUnitario);
	if (costoUnitario <= 0.0) {
		return 'El precio debe ser mayor a cero';
	}
	return 'El precio no puede ser menor a ${formatearMoneda(minimo)} '
		'(costo ${formatearMoneda(costoUnitario)} + '
		'utilidad mínima $MARGEN_UTILIDAD_MINIMA_PORCENTAJE%)';
}

/// Precio minimo total de una presentacion (precio por paquete).
double calcularPrecioMinimoPresentacion(
	double costoUnitario,
	double factorABase,
) {
	if (factorABase <= 0.0) {
		return calcularPrecioMinimoVenta(costoUnitario);
	}
	return redondearMonto(calcularPrecioMinimoVenta(costoUnitario) * factorABase);
}

/// Valida precio total de presentacion contra costo unitario y factor.
bool precioPresentacionEsValido(
	double precioPaquete,
	double costoUnitario,
	double factorABase,
) {
	if (precioPaquete <= 0.0) {
		return false;
	}
	if (factorABase <= 0.0) {
		return precioVentaEsValido(precioPaquete, costoUnitario);
	}
	return precioVentaEsValido(precioPaquete / factorABase, costoUnitario);
}

/// Mensaje de error para precio de presentacion bajo utilidad minima.
String mensajePrecioMinimoPresentacionInvalido(
	double costoUnitario,
	double factorABase,
) {
	final minimo = calcularPrecioMinimoPresentacion(costoUnitario, factorABase);
	final costoPaquete = factorABase > 0.0
		? redondearMonto(costoUnitario * factorABase)
		: costoUnitario;
	if (costoUnitario <= 0.0) {
		return 'El precio debe ser mayor a cero';
	}
	return 'El precio no puede ser menor a ${formatearMoneda(minimo)} '
		'(costo ${formatearMoneda(costoPaquete)} + '
		'utilidad mínima $MARGEN_UTILIDAD_MINIMA_PORCENTAJE%)';
}

/// Interpreta texto de captura de precio (acepta coma decimal).
double? parsearPrecioTexto(String texto) {
	final limpio = texto.trim().replaceAll(',', '.');
	if (limpio.isEmpty) {
		return null;
	}
	return double.tryParse(limpio);
}

/// Devuelve mensaje de error o null si el precio unitario es valido.
String? errorPrecioVentaDesdeTexto(
	String texto, {
	required double costoUnitario,
	bool obligatorio = true,
}) {
	final precio = parsearPrecioTexto(texto);
	if (precio == null) {
		return obligatorio ? 'Ingrese un precio válido' : null;
	}
	if (precio <= 0.0) {
		return 'Ingrese un precio válido';
	}
	if (!precioVentaEsValido(precio, costoUnitario)) {
		return mensajePrecioMinimoInvalido(costoUnitario);
	}
	return null;
}

/// Devuelve mensaje de error o null si el precio de presentacion es valido.
String? errorPrecioPresentacionDesdeTexto(
	String texto, {
	required double costoUnitario,
	required double factorABase,
	bool obligatorio = false,
}) {
	final precio = parsearPrecioTexto(texto);
	if (precio == null) {
		return obligatorio ? 'Ingrese un precio válido' : null;
	}
	if (precio <= 0.0) {
		return 'Ingrese un precio válido';
	}
	if (!precioPresentacionEsValido(precio, costoUnitario, factorABase)) {
		return mensajePrecioMinimoPresentacionInvalido(costoUnitario, factorABase);
	}
	return null;
}

/// Texto de ayuda con el precio minimo permitido.
String? ayudaPrecioMinimoUnitario(double costoUnitario) {
	if (costoUnitario <= 0.0) {
		return null;
	}
	return 'Mínimo permitido: ${formatearMoneda(calcularPrecioMinimoVenta(costoUnitario))}';
}

/// Texto de ayuda con el precio minimo de una presentacion.
String? ayudaPrecioMinimoPresentacion(double costoUnitario, double factorABase) {
	if (costoUnitario <= 0.0 || factorABase <= 0.0) {
		return null;
	}
	return 'Mínimo permitido: ${formatearMoneda(calcularPrecioMinimoPresentacion(costoUnitario, factorABase))}';
}

/// Etiqueta legible del modo de calculo de utilidad.
String etiquetaModoCalculoUtilidad(ModoCalculoUtilidad modo) {
	switch (modo) {
		case ModoCalculoUtilidad.sobreCosto:
			return 'Utilidad sobre costo';
		case ModoCalculoUtilidad.sobrePrecioVenta:
			return 'Margen sobre venta';
	}
}

/// Calcula precio de venta segun costo, modo y porcentaje de utilidad.
double calcularPrecioVentaDesdeUtilidad({
	required double costoUnitario,
	required double porcentajeUtilidad,
	ModoCalculoUtilidad modo = ModoCalculoUtilidad.sobreCosto,
}) {
	if (costoUnitario <= 0.0) {
		return 0.01;
	}
	if (porcentajeUtilidad < 0.0) {
		return calcularPrecioMinimoVenta(costoUnitario);
	}
	switch (modo) {
		case ModoCalculoUtilidad.sobreCosto:
			return redondearMonto(costoUnitario * (1.0 + porcentajeUtilidad / 100.0));
		case ModoCalculoUtilidad.sobrePrecioVenta:
			if (porcentajeUtilidad >= 100.0) {
				throw ArgumentError('El margen sobre venta debe ser menor a 100%');
			}
			return redondearMonto(costoUnitario / (1.0 - porcentajeUtilidad / 100.0));
	}
}

/// Referencia de escala mayoreo para sugerir precio de presentacion.
typedef EscalaMayoreoRef = ({double cantidadMinima, double precioUnitario});

/// Precio total sugerido de una presentacion segun menudeo o escala mayoreo.
///
/// Si [factorABase] coincide con [cantidadMinima] de una escala, usa
/// `factor * precioUnitario` de esa escala; si no, `factor * precioMenudeo`.
double? calcularPrecioSugeridoPresentacion({
	required double factorABase,
	required double precioMenudeo,
	Iterable<EscalaMayoreoRef> escalasMayoreo = const [],
}) {
	if (factorABase <= 0.0) {
		return null;
	}
	for (final escala in escalasMayoreo) {
		final coincide = (escala.cantidadMinima - factorABase).abs() < 0.001;
		if (coincide && escala.precioUnitario > 0.0) {
			return redondearMonto(escala.precioUnitario * factorABase);
		}
	}
	if (precioMenudeo <= 0.0) {
		return null;
	}
	return redondearMonto(precioMenudeo * factorABase);
}

/// Selecciona la escala con mayor [cantidadMinima] que califica para [cantidad].
///
/// Sirve para mayoreo por piezas y para precios por peso (kg): por ejemplo,
/// desde 0 kg a \$80/kg y desde 1 kg a \$70/kg.
EscalaMayoreoRef? seleccionarEscalaMayoreoPorCantidad(
	Iterable<EscalaMayoreoRef> escalas,
	double cantidad,
) {
	EscalaMayoreoRef? mejorEscala;
	for (final escala in escalas) {
		if (cantidad < escala.cantidadMinima) {
			continue;
		}
		if (mejorEscala == null ||
			escala.cantidadMinima > mejorEscala.cantidadMinima) {
			mejorEscala = escala;
		}
	}
	return mejorEscala;
}

/// Resuelve precio unitario aplicando escalas por cantidad o [precioBase].
double resolverPrecioConEscalas({
	required double precioBase,
	required double cantidad,
	Iterable<EscalaMayoreoRef> escalas = const [],
}) {
	final escala = seleccionarEscalaMayoreoPorCantidad(escalas, cantidad);
	if (escala != null) {
		return redondearMonto(escala.precioUnitario);
	}
	return redondearMonto(precioBase);
}

/// Indica si al fusionar pesajes conviene promediar (cortes fraccionados).
///
/// Carnicería y productos con tramos bajo 1 kg (medio/cuarto) conservan el
/// total de cada pesaje. Granel con bulto (ej. 20 kg) recalcula al sumar.
bool productoUsaFusionPromedioPeso({
	required ModuloVertical moduloVertical,
	Iterable<EscalaMayoreoRef> escalas = const [],
}) {
	if (moduloVertical == ModuloVertical.carniceria) {
		return true;
	}
	final lista = escalas.toList();
	final tieneTramoKilo = lista.any(
		(e) => e.cantidadMinima >= pesoKiloCompleto,
	);
	if (!tieneTramoKilo) {
		return false;
	}
	return lista.any(
		(e) =>
			(e.cantidadMinima > 0.0 &&
				e.cantidadMinima < pesoKiloCompleto) ||
			e.cantidadMinima <= 0.001,
	);
}

/// Combina escalas de mayoreo con las derivadas de empaques.
///
/// Si comparten [cantidadMinima], gana la escala de empaque (precio explícito).
List<EscalaMayoreoRef> fusionarEscalasMayoreo({
	required Iterable<EscalaMayoreoRef> escalasMayoreo,
	required Iterable<EscalaMayoreoRef> escalasEmpaque,
}) {
	final porUmbral = <double, EscalaMayoreoRef>{};
	for (final escala in escalasMayoreo) {
		porUmbral[escala.cantidadMinima] = escala;
	}
	for (final escala in escalasEmpaque) {
		porUmbral[escala.cantidadMinima] = escala;
	}
	return porUmbral.values.toList()
		..sort((a, b) => a.cantidadMinima.compareTo(b.cantidadMinima));
}

/// Peso de un cuarto de kilo.
const double pesoCuartoKilo = 0.25;

/// Peso de medio kilo.
const double pesoMedioKilo = 0.5;

/// Peso de un kilo completo.
const double pesoKiloCompleto = 1.0;

/// Convierte el precio que paga el cliente por un corte a precio por kg.
double precioPorKgDesdePrecioCorte({
	required double precioCorte,
	required double pesoKg,
}) {
	if (pesoKg <= 0.0) {
		return 0.0;
	}
	return redondearMonto(precioCorte / pesoKg);
}

/// Precio que paga el cliente por un corte a partir del precio por kg.
double precioCorteDesdePrecioPorKg({
	required double precioPorKg,
	required double pesoKg,
}) {
	if (pesoKg <= 0.0) {
		return 0.0;
	}
	return redondearMonto(precioPorKg * pesoKg);
}

/// Construye escalas internas ($/kg) a partir de precios de corte del negocio.
///
/// [precioKilo] Es lo que se cobra por 1 kg completo.
/// [precioMedio] Opcional: lo que paga el cliente por medio kilo (ej. $20).
/// [precioCuarto] Opcional: lo que paga el cliente por un cuarto (ej. $22).
List<EscalaMayoreoRef> construirEscalasDesdePreciosCorte({
	required double precioKilo,
	double? precioMedio,
	double? precioCuarto,
}) {
	final escalas = <EscalaMayoreoRef>[];
	final medio = precioMedio != null && precioMedio > 0.0 ? precioMedio : null;
	final cuarto = precioCuarto != null && precioCuarto > 0.0 ? precioCuarto : null;

	if (cuarto != null && medio != null) {
		escalas.add((
			cantidadMinima: 0.0,
			precioUnitario: precioPorKgDesdePrecioCorte(
				precioCorte: cuarto,
				pesoKg: pesoCuartoKilo,
			),
		));
		escalas.add((
			cantidadMinima: pesoMedioKilo,
			precioUnitario: precioPorKgDesdePrecioCorte(
				precioCorte: medio,
				pesoKg: pesoMedioKilo,
			),
		));
	} else if (cuarto != null) {
		escalas.add((
			cantidadMinima: 0.0,
			precioUnitario: precioPorKgDesdePrecioCorte(
				precioCorte: cuarto,
				pesoKg: pesoCuartoKilo,
			),
		));
	} else if (medio != null) {
		escalas.add((
			cantidadMinima: 0.0,
			precioUnitario: precioPorKgDesdePrecioCorte(
				precioCorte: medio,
				pesoKg: pesoMedioKilo,
			),
		));
	}

	if (precioKilo > 0.0) {
		escalas.add((
			cantidadMinima: pesoKiloCompleto,
			precioUnitario: redondearMonto(precioKilo),
		));
	}
	return escalas;
}

/// Precios de corte legibles a partir de escalas almacenadas ($/kg).
({double? precioKilo, double? precioMedio, double? precioCuarto})
	extraerPreciosCorteDesdeEscalas({
	required Iterable<EscalaMayoreoRef> escalas,
	required double precioBase,
}) {
	final lista = escalas.toList()
		..sort((a, b) => a.cantidadMinima.compareTo(b.cantidadMinima));
	final precioPorKgKilo = resolverPrecioConEscalas(
		precioBase: precioBase,
		cantidad: pesoKiloCompleto,
		escalas: lista,
	);
	final precioKilo = precioPorKgKilo > 0.0 ? precioPorKgKilo : null;

	final tramosFraccion =
		lista.where((e) => e.cantidadMinima < pesoKiloCompleto).toList();
	if (tramosFraccion.isEmpty) {
		return (precioKilo: precioKilo ?? precioBase, precioMedio: null, precioCuarto: null);
	}

	final tramoDesdeCero = tramosFraccion.cast<EscalaMayoreoRef?>().firstWhere(
		(e) => e!.cantidadMinima <= 0.001,
		orElse: () => null,
	);
	final tramoDesdeMedio = tramosFraccion.cast<EscalaMayoreoRef?>().firstWhere(
		(e) => (e!.cantidadMinima - pesoMedioKilo).abs() < 0.001,
		orElse: () => null,
	);

	double? precioMedio;
	double? precioCuarto;

	if (tramoDesdeCero != null && tramoDesdeMedio != null) {
		precioCuarto = precioCorteDesdePrecioPorKg(
			precioPorKg: tramoDesdeCero.precioUnitario,
			pesoKg: pesoCuartoKilo,
		);
		precioMedio = precioCorteDesdePrecioPorKg(
			precioPorKg: tramoDesdeMedio.precioUnitario,
			pesoKg: pesoMedioKilo,
		);
	} else if (tramoDesdeCero != null) {
		// Un solo tramo de fraccion: se interpreta como precio del medio kilo.
		precioMedio = precioCorteDesdePrecioPorKg(
			precioPorKg: tramoDesdeCero.precioUnitario,
			pesoKg: pesoMedioKilo,
		);
	} else if (tramoDesdeMedio != null) {
		precioMedio = precioCorteDesdePrecioPorKg(
			precioPorKg: tramoDesdeMedio.precioUnitario,
			pesoKg: pesoMedioKilo,
		);
	}

	return (
		precioKilo: precioKilo ?? precioBase,
		precioMedio: (precioMedio != null && precioMedio > 0.0) ? precioMedio : null,
		precioCuarto:
			(precioCuarto != null && precioCuarto > 0.0) ? precioCuarto : null,
	);
}

/// Texto de vista previa de cobros por peso habituales.
String describirVistaPreviaPreciosPeso({
	required double precioKilo,
	double? precioMedio,
	double? precioCuarto,
}) {
	final escalas = construirEscalasDesdePreciosCorte(
		precioKilo: precioKilo,
		precioMedio: precioMedio,
		precioCuarto: precioCuarto,
	);
	String linea(double peso) {
		final porKg = resolverPrecioConEscalas(
			precioBase: precioKilo,
			cantidad: peso,
			escalas: escalas,
		);
		final total = redondearMonto(porKg * peso);
		return '${_formatearCantidadTramo(peso)} kg → ${formatearMoneda(total)} '
			'(${formatearMoneda(porKg)}/kg)';
	}

	return [
		if (precioCuarto != null && precioCuarto > 0.0) linea(pesoCuartoKilo),
		if (precioMedio != null && precioMedio > 0.0) linea(pesoMedioKilo),
		if (precioKilo > 0.0) linea(pesoKiloCompleto),
	].join('\n');
}

/// Etiqueta legible de un tramo de precio por peso o cantidad.
String describirTramoPrecio({
	required double cantidadMinima,
	required double precioUnitario,
	required UnidadMedida unidadMedida,
}) {
	final precio = formatearMoneda(precioUnitario);
	if (unidadMedida == UnidadMedida.kilogramo) {
		final desde = _formatearCantidadTramo(cantidadMinima);
		final medio = precioCorteDesdePrecioPorKg(
			precioPorKg: precioUnitario,
			pesoKg: pesoMedioKilo,
		);
		final cuarto = precioCorteDesdePrecioPorKg(
			precioPorKg: precioUnitario,
			pesoKg: pesoCuartoKilo,
		);
		if (cantidadMinima < pesoKiloCompleto) {
			return 'Desde $desde kg: $precio/kg '
				'(½ kg = ${formatearMoneda(medio)}, ¼ kg = ${formatearMoneda(cuarto)})';
		}
		return 'Desde $desde kg: $precio/kg';
	}
	final desde = _formatearCantidadTramo(cantidadMinima);
	return 'Desde $desde u.: $precio c/u';
}

String _formatearCantidadTramo(double cantidad) {
	if (cantidad == cantidad.roundToDouble()) {
		return cantidad.toStringAsFixed(0);
	}
	return cantidad.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// Porcentaje de utilidad implicito entre costo y precio de venta.
double calcularUtilidadPorcentaje({
	required double costoUnitario,
	required double precioVenta,
	ModoCalculoUtilidad modo = ModoCalculoUtilidad.sobreCosto,
}) {
	if (costoUnitario <= 0.0 || precioVenta <= 0.0) {
		return 0.0;
	}
	switch (modo) {
		case ModoCalculoUtilidad.sobreCosto:
			return redondearMonto(((precioVenta - costoUnitario) / costoUnitario) * 100.0);
		case ModoCalculoUtilidad.sobrePrecioVenta:
			return redondearMonto(((precioVenta - costoUnitario) / precioVenta) * 100.0);
	}
}
