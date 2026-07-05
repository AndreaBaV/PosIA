/// UI para confirmar o corregir lineas ambiguas del ticket por voz.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_voice/posia_voice.dart';

/// Resumen de lineas resueltas manualmente tras dictado.
class ResultadoResolucionLineasVoz {
	const ResultadoResolucionLineasVoz({
		required this.lineas,
		required this.omitidas,
	});

	final List<LineaVozResuelta> lineas;
	final int omitidas;
}

/// Pide al usuario elegir producto para cada linea ambigua o sin match.
Future<ResultadoResolucionLineasVoz> resolverLineasPendientesVoz(
	BuildContext context, {
	required List<LineaVozAmbigua> ambiguas,
	required List<LineaVozSinCoincidencia> sinCoincidencia,
	required List<Producto> catalogoCompleto,
	required MotorComandosVoz motor,
}) async {
	final resueltas = <LineaVozResuelta>[];
	var omitidas = 0;

	for (final pendiente in ambiguas) {
		if (!context.mounted) {
			break;
		}
		final producto = await _mostrarElegirProductoVoz(
			context,
			consultaOriginal: pendiente.consultaOriginal,
			cantidadHablada: pendiente.cantidadHablada,
			candidatosIniciales: pendiente.candidatos,
			catalogoCompleto: catalogoCompleto,
			esAmbigua: true,
		);
		if (producto == null) {
			omitidas++;
			continue;
		}
		resueltas.add(
			motor.construirLineaDesdeSeleccion(
				pendiente: pendiente,
				producto: producto,
			),
		);
	}

	for (final pendiente in sinCoincidencia) {
		if (!context.mounted) {
			break;
		}
		final producto = await _mostrarElegirProductoVoz(
			context,
			consultaOriginal: pendiente.consultaOriginal,
			cantidadHablada: pendiente.cantidadHablada,
			candidatosIniciales: filtrarProductosPorBusqueda(
				catalogoCompleto,
				pendiente.consultaOriginal,
			).take(12).toList(),
			catalogoCompleto: catalogoCompleto,
			esAmbigua: false,
		);
		if (producto == null) {
			omitidas++;
			continue;
		}
		resueltas.add(
			motor.construirLineaDesdeSinCoincidencia(
				pendiente: pendiente,
				producto: producto,
			),
		);
	}

	return ResultadoResolucionLineasVoz(
		lineas: resueltas,
		omitidas: omitidas,
	);
}

Future<Producto?> _mostrarElegirProductoVoz(
	BuildContext context, {
	required String consultaOriginal,
	required double cantidadHablada,
	required List<Producto> candidatosIniciales,
	required List<Producto> catalogoCompleto,
	required bool esAmbigua,
}) {
	return showModalBottomSheet<Producto>(
		context: context,
		isScrollControlled: true,
		showDragHandle: true,
		builder: (sheetContext) {
			return _HojaElegirProductoVoz(
				consultaOriginal: consultaOriginal,
				cantidadHablada: cantidadHablada,
				candidatosIniciales: candidatosIniciales,
				catalogoCompleto: catalogoCompleto,
				esAmbigua: esAmbigua,
			);
		},
	);
}

class _HojaElegirProductoVoz extends StatefulWidget {
	const _HojaElegirProductoVoz({
		required this.consultaOriginal,
		required this.cantidadHablada,
		required this.candidatosIniciales,
		required this.catalogoCompleto,
		required this.esAmbigua,
	});

	final String consultaOriginal;
	final double cantidadHablada;
	final List<Producto> candidatosIniciales;
	final List<Producto> catalogoCompleto;
	final bool esAmbigua;

	@override
	State<_HojaElegirProductoVoz> createState() => _HojaElegirProductoVozState();
}

class _HojaElegirProductoVozState extends State<_HojaElegirProductoVoz> {
	final _busquedaController = TextEditingController();

	@override
	void initState() {
		super.initState();
		_busquedaController.text = widget.consultaOriginal;
	}

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	List<Producto> get _productosVisibles {
		final filtro = _busquedaController.text.trim();
		final base = widget.candidatosIniciales.isNotEmpty
			? widget.candidatosIniciales
			: widget.catalogoCompleto;
		if (filtro.isEmpty) {
			return base.take(20).toList();
		}
		final filtrados = filtrarProductosPorBusqueda(base, filtro);
		if (filtrados.isNotEmpty) {
			return filtrados.take(20).toList();
		}
		return filtrarProductosPorBusqueda(widget.catalogoCompleto, filtro)
			.take(20)
			.toList();
	}

	@override
	Widget build(BuildContext context) {
		final productos = _productosVisibles;
		final cantidadTexto = widget.cantidadHablada ==
				widget.cantidadHablada.roundToDouble()
			? widget.cantidadHablada.toStringAsFixed(0)
			: widget.cantidadHablada.toStringAsFixed(1);
		return DraggableScrollableSheet(
			expand: false,
			initialChildSize: 0.78,
			minChildSize: 0.45,
			maxChildSize: 0.95,
			builder: (_, scrollController) {
				return Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Padding(
							padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										widget.esAmbigua
											? 'Elige el producto correcto'
											: 'Producto no identificado',
										style: Theme.of(context).textTheme.titleMedium?.copyWith(
											fontWeight: FontWeight.bold,
										),
									),
									const SizedBox(height: 4.0),
									Text(
										'Dijiste: "${widget.consultaOriginal}" · Cant: $cantidadTexto',
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
											color: Colors.grey.shade700,
										),
									),
									if (widget.esAmbigua) ...[
										const SizedBox(height: 6.0),
										Text(
											'Hay varias coincidencias. Refina la búsqueda o toque el producto.',
											style: Theme.of(context).textTheme.bodySmall,
										),
									],
								],
							),
						),
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 16.0),
							child: TextField(
								controller: _busquedaController,
								autofocus: true,
								decoration: InputDecoration(
									hintText: 'Buscar en catálogo…',
									prefixIcon: const Icon(Icons.search),
									suffixIcon: _busquedaController.text.isNotEmpty
										? IconButton(
											icon: const Icon(Icons.clear),
											onPressed: () {
												_busquedaController.clear();
												setState(() {});
											},
										)
										: null,
									border: const OutlineInputBorder(),
									isDense: true,
								),
								onChanged: (_) => setState(() {}),
							),
						),
						const SizedBox(height: 8.0),
						Expanded(
							child: productos.isEmpty
								? Center(
									child: Text(
										'Sin resultados. Pruebe marca, presentación o código.',
										style: TextStyle(color: Colors.grey.shade600),
										textAlign: TextAlign.center,
									),
								)
								: ListView.builder(
									controller: scrollController,
									itemCount: productos.length,
									itemBuilder: (context, index) {
										final producto = productos[index];
										return ListTile(
											title: Text(producto.nombre),
											subtitle: Text(
												formatearMoneda(producto.precioBase),
											),
											trailing: const Icon(Icons.chevron_right),
											onTap: () => Navigator.pop(context, producto),
										);
									},
								),
						),
						Padding(
							padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
							child: OutlinedButton(
								onPressed: () => Navigator.pop(context),
								child: const Text('Omitir esta línea'),
							),
						),
					],
				);
			},
		);
	}
}