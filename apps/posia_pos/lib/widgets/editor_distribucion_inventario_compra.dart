/// Editor de distribucion de inventario por tienda/almacen tras una compra.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// Fila editable de asignacion de stock.
class FilaAsignacionCompra {
	FilaAsignacionCompra({
		required this.destinoTipo,
		this.destinoId,
		TextEditingController? cantidad,
	}) : cantidad = cantidad ?? TextEditingController(text: '0');

	String destinoTipo;
	String? destinoId;
	final TextEditingController cantidad;
}

/// Permite repartir la cantidad comprada entre tiendas y almacenes.
class EditorDistribucionInventarioCompra extends StatelessWidget {
	const EditorDistribucionInventarioCompra({
		super.key,
		required this.productoNombre,
		required this.cantidadTotal,
		required this.tiendas,
		required this.almacenes,
		required this.filas,
		required this.alAgregar,
		required this.alEliminar,
		required this.alCambiar,
	});

	final String productoNombre;
	final double cantidadTotal;
	final List<Tienda> tiendas;
	final List<Almacen> almacenes;
	final List<FilaAsignacionCompra> filas;
	final VoidCallback alAgregar;
	final ValueChanged<int> alEliminar;
	final VoidCallback alCambiar;

	double get _sumaAsignada {
		var total = 0.0;
		for (final fila in filas) {
			total = total +
				(double.tryParse(fila.cantidad.text.replaceAll(',', '.')) ?? 0.0);
		}
		return total;
	}

	@override
	Widget build(BuildContext context) {
		final suma = _sumaAsignada;
		final completo = (suma - cantidadTotal).abs() <= 0.001;
		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							'Distribución: $productoNombre',
							style: const TextStyle(fontWeight: FontWeight.w600),
						),
						const SizedBox(height: 4.0),
						Text(
							'Total comprado: ${cantidadTotal.toStringAsFixed(0)} · '
							'Asignado: ${suma.toStringAsFixed(0)}',
							style: TextStyle(
								color: completo ? Colors.green.shade700 : Colors.orange.shade800,
								fontSize: 12.0,
							),
						),
						const SizedBox(height: 8.0),
						for (var i = 0; i < filas.length; i++)
							Padding(
								padding: const EdgeInsets.only(bottom: 8.0),
								child: Row(
									children: [
										SizedBox(
											width: 108.0,
											child: DropdownButtonFormField<String>(
												initialValue: filas[i].destinoTipo,
												decoration: const InputDecoration(
													labelText: 'Tipo',
													isDense: true,
													border: OutlineInputBorder(),
												),
												items: const [
													DropdownMenuItem(
														value: AsignacionInventarioCompra.destinoTienda,
														child: Text('Tienda'),
													),
													DropdownMenuItem(
														value: AsignacionInventarioCompra.destinoAlmacen,
														child: Text('Almacén'),
													),
												],
												onChanged: (v) {
													if (v == null) {
														return;
													}
													filas[i].destinoTipo = v;
													filas[i].destinoId = null;
													alCambiar();
												},
											),
										),
										const SizedBox(width: 8.0),
										Expanded(
											child: DropdownButtonFormField<String>(
												initialValue: _destinoValido(filas[i]),
												decoration: InputDecoration(
													labelText: filas[i].destinoTipo ==
														AsignacionInventarioCompra.destinoAlmacen
														? 'Almacén'
														: 'Tienda',
													isDense: true,
													border: const OutlineInputBorder(),
												),
												items: _opcionesDestino(filas[i]),
												onChanged: (v) {
													filas[i].destinoId = v;
													alCambiar();
												},
											),
										),
										const SizedBox(width: 8.0),
										SizedBox(
											width: 72.0,
											child: TextField(
												controller: filas[i].cantidad,
												keyboardType: TextInputType.number,
												decoration: const InputDecoration(
													labelText: 'Cant.',
													isDense: true,
													border: OutlineInputBorder(),
												),
												onChanged: (_) => alCambiar(),
											),
										),
										if (filas.length > 1)
											IconButton(
												icon: const Icon(Icons.remove_circle_outline),
												onPressed: () => alEliminar(i),
											),
									],
								),
							),
						Align(
							alignment: Alignment.centerLeft,
							child: TextButton.icon(
								onPressed: alAgregar,
								icon: const Icon(Icons.add),
								label: const Text('Agregar destino'),
							),
						),
					],
				),
			),
		);
	}

	String? _destinoValido(FilaAsignacionCompra fila) {
		final id = fila.destinoId;
		if (id == null) {
			return null;
		}
		final opciones = _opcionesDestino(fila);
		if (opciones.any((item) => item.value == id)) {
			return id;
		}
		return null;
	}

	List<DropdownMenuItem<String>> _opcionesDestino(FilaAsignacionCompra fila) {
		if (fila.destinoTipo == AsignacionInventarioCompra.destinoAlmacen) {
			return almacenes
				.where((a) => a.activo)
				.map(
					(a) => DropdownMenuItem(value: a.id, child: Text(a.nombre)),
				)
				.toList();
		}
		return tiendas
			.where((t) => t.activa)
			.map(
				(t) => DropdownMenuItem(value: t.id, child: Text(t.nombre)),
			)
			.toList();
	}
}

List<AsignacionInventarioCompra> asignacionesDesdeFilas(
	List<FilaAsignacionCompra> filas,
	String productoId,
) {
	return filas
		.where((f) => f.destinoId != null && f.destinoId!.isNotEmpty)
		.map(
			(f) => AsignacionInventarioCompra(
				productoId: productoId,
				destinoTipo: f.destinoTipo,
				destinoId: f.destinoId!,
				cantidad: double.tryParse(f.cantidad.text.replaceAll(',', '.')) ?? 0.0,
			),
		)
		.toList();
}
