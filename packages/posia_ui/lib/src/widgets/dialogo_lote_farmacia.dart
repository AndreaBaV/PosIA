/// Dialogo de seleccion de lote FEFO para farmacia.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Resultado del dialogo de lote farmacia.
class ResultadoDialogoLote {
	/// Crea resultado del dialogo de lote.
	///
	/// [confirmado] Indica si se confirmo seleccion.
	/// [lote] Lote seleccionado opcional.
	/// [cantidad] Unidades a vender.
	const ResultadoDialogoLote({
		required this.confirmado,
		required this.lote,
		required this.cantidad,
	});

	/// Usuario confirmo accion.
	final bool confirmado;

	/// Lote farmaceutico elegido.
	final LoteFarmacia? lote;

	/// Cantidad de unidades.
	final double cantidad;
}

/// Presenta lotes disponibles con iconos de alerta de caducidad.
class DialogoLoteFarmacia extends StatefulWidget {
	/// Crea dialogo de seleccion de lote.
	///
	/// [producto] Medicamento o producto farmacia.
	/// [lotes] Lotes FEFO disponibles.
	/// [servicioFarmacia] Servicio para calcular alertas.
	const DialogoLoteFarmacia({
		required this.producto,
		required this.lotes,
		required this.servicioFarmacia,
		super.key,
	});

	/// Producto farmaceutico.
	final Producto producto;

	/// Lotes disponibles para venta.
	final List<LoteFarmacia> lotes;

	/// Servicio de reglas farmacia.
	final ServicioFarmacia servicioFarmacia;

	/// Presenta dialogo modal de seleccion de lote.
	///
	/// [context] Contexto de navegacion.
	/// [producto] Producto farmacia.
	/// [lotes] Lotes disponibles.
	/// [servicioFarmacia] Servicio de alertas.
	/// Retorna [ResultadoDialogoLote] con lote y cantidad.
	static Future<ResultadoDialogoLote> mostrar({
		required BuildContext context,
		required Producto producto,
		required List<LoteFarmacia> lotes,
		required ServicioFarmacia servicioFarmacia,
	}) async {
		final resultado = await showDialog<ResultadoDialogoLote>(
			context: context,
			builder: (_) => DialogoLoteFarmacia(
				producto: producto,
				lotes: lotes,
				servicioFarmacia: servicioFarmacia,
			),
		);
		return resultado ??
			const ResultadoDialogoLote(confirmado: false, lote: null, cantidad: 0.0);
	}

	@override
	State<DialogoLoteFarmacia> createState() => _DialogoLoteFarmaciaState();
}

/// Estado del dialogo de lote farmacia.
class _DialogoLoteFarmaciaState extends State<DialogoLoteFarmacia> {
	LoteFarmacia? _loteSeleccionado;
	double _cantidad = 1.0;

	@override
	void initState() {
		super.initState();
		if (widget.lotes.isNotEmpty) {
			_loteSeleccionado = widget.lotes.first;
		}
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: Row(
				children: [
					const Icon(Icons.medication, color: PosiaColors.cobrar, size: 32.0),
					const SizedBox(width: 8.0),
					Expanded(child: Text(widget.producto.nombre)),
				],
			),
			content: SizedBox(
				width: 400.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						if (widget.lotes.isEmpty)
							const Text('Sin lotes disponibles')
						else
							...widget.lotes.map(_construirOpcionLote),
						const SizedBox(height: 16.0),
						Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								IconButton(
									icon: const Icon(Icons.remove_circle, size: 40.0),
									onPressed: _disminuirCantidad,
								),
								Text(
									_cantidad.toStringAsFixed(0),
									style: Theme.of(context).textTheme.headlineLarge,
								),
								IconButton(
									icon: const Icon(Icons.add_circle, size: 40.0, color: PosiaColors.cobrar),
									onPressed: _aumentarCantidad,
								),
							],
						),
					],
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(
						const ResultadoDialogoLote(confirmado: false, lote: null, cantidad: 0.0),
					),
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: widget.lotes.isEmpty ? null : _confirmar,
					child: const Text('Agregar'),
				),
			],
		);
	}

	/// Construye opcion visual de lote con icono de alerta.
	///
	/// [lote] Lote disponible.
	/// Retorna tile seleccionable.
	Widget _construirOpcionLote(LoteFarmacia lote) {
		final alerta = widget.servicioFarmacia.calcularAlertaCaducidad(lote);
		final iconoAlerta = _resolverIconoAlerta(alerta);
		return ListTile(
			leading: Icon(iconoAlerta.icono, color: iconoAlerta.color),
			title: Text(lote.numeroLote),
			subtitle: Text(lote.generarEtiquetaVisible()),
			trailing: Text('Stock: ${lote.cantidad.toStringAsFixed(0)}'),
			selected: _loteSeleccionado?.id == lote.id,
			onTap: () {
				setState(() {
					_loteSeleccionado = lote;
				});
			},
		);
	}

	/// Resuelve icono y color segun nivel de alerta.
	///
	/// [alerta] Nivel de caducidad calculado.
	/// Retorna par icono-color para UI.
	_IconoAlerta _resolverIconoAlerta(NivelAlertaCaducidad alerta) {
		if (alerta == NivelAlertaCaducidad.critico) {
			return const _IconoAlerta(icono: Icons.warning, color: PosiaColors.cancelar);
		}
		if (alerta == NivelAlertaCaducidad.advertencia) {
			return const _IconoAlerta(icono: Icons.info, color: Colors.orange);
		}
		return const _IconoAlerta(icono: Icons.check_circle, color: PosiaColors.cobrar);
	}

	/// Incrementa cantidad en una unidad.
	void _aumentarCantidad() {
		setState(() {
			_cantidad = _cantidad + 1.0;
		});
	}

	/// Decrementa cantidad minimo en una unidad.
	void _disminuirCantidad() {
		if (_cantidad <= 1.0) {
			return;
		}
		setState(() {
			_cantidad = _cantidad - 1.0;
		});
	}

	/// Confirma lote y cantidad seleccionados.
	void _confirmar() {
		Navigator.of(context).pop(
			ResultadoDialogoLote(
				confirmado: true,
				lote: _loteSeleccionado,
				cantidad: _cantidad,
			),
		);
	}
}

/// Par icono-color para alertas de caducidad.
class _IconoAlerta {
	const _IconoAlerta({required this.icono, required this.color});

	final IconData icono;
	final Color color;
}
