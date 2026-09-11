/// Visual de producto: foto si existe, icono heuristico como respaldo.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// Muestra la foto del producto ([Producto.rutaImagen]) o un icono de respaldo.
class VisualProducto extends StatelessWidget {
	const VisualProducto({
		required this.producto,
		required this.colorAcento,
		this.tamano = 40.0,
		this.radio = 12.0,
		this.padding = 10.0,
		this.circular = false,
		super.key,
	});

	final Producto producto;
	final Color colorAcento;
	final double tamano;
	final double radio;
	final double padding;
	final bool circular;

	String get _ruta => producto.rutaImagen.trim();

	bool get _tieneFoto => _ruta.isNotEmpty;

	@override
	Widget build(BuildContext context) {
		final borde = circular
			? null
			: BorderRadius.circular(radio);
		final decoracionFondo = BoxDecoration(
			color: colorAcento.withValues(alpha: 0.1),
			borderRadius: circular ? null : borde,
			shape: circular ? BoxShape.circle : BoxShape.rectangle,
		);
		if (!_tieneFoto) {
			return Container(
				padding: EdgeInsets.all(padding),
				decoration: decoracionFondo,
				child: Icon(
					iconoProductoHeuristico(producto),
					size: tamano,
					color: colorAcento,
				),
			);
		}
		final lado = tamano + (padding * 2);
		final imagen = Image.network(
			_ruta,
			width: lado,
			height: lado,
			fit: BoxFit.cover,
			errorBuilder: (_, _, _) => Container(
				width: lado,
				height: lado,
				padding: EdgeInsets.all(padding),
				decoration: decoracionFondo,
				alignment: Alignment.center,
				child: Icon(
					iconoProductoHeuristico(producto),
					size: tamano,
					color: colorAcento,
				),
			),
			loadingBuilder: (context, child, progreso) {
				if (progreso == null) {
					return child;
				}
				return Container(
					width: lado,
					height: lado,
					decoration: decoracionFondo,
					alignment: Alignment.center,
					child: SizedBox(
						width: tamano * 0.45,
						height: tamano * 0.45,
						child: CircularProgressIndicator(
							strokeWidth: 2.0,
							color: colorAcento,
						),
					),
				);
			},
		);
		if (circular) {
			return ClipOval(child: imagen);
		}
		return ClipRRect(
			borderRadius: BorderRadius.circular(radio),
			child: imagen,
		);
	}
}

/// Icono de respaldo segun nombre o modulo del producto.
IconData iconoProductoHeuristico(Producto producto) {
	final nombre = producto.nombre.toLowerCase();
	if (nombre.contains('coca')) {
		return Icons.local_drink;
	}
	if (nombre.contains('arroz')) {
		return Icons.rice_bowl;
	}
	if (nombre.contains('leche')) {
		return Icons.water_drop;
	}
	if (nombre.contains('huevo')) {
		return Icons.egg;
	}
	if (nombre.contains('aceite')) {
		return Icons.opacity;
	}
	if (nombre.contains('azucar')) {
		return Icons.grain;
	}
	if (nombre.contains('frijol')) {
		return Icons.grass;
	}
	if (nombre.contains('atun')) {
		return Icons.set_meal;
	}
	if (producto.moduloVertical == ModuloVertical.carniceria) {
		return Icons.set_meal;
	}
	if (producto.moduloVertical == ModuloVertical.farmacia) {
		return Icons.medication;
	}
	return Icons.shopping_basket;
}
