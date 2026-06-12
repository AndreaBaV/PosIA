/// Barra horizontal de categorias para filtrar productos en caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../utils/iconos_categoria.dart';

/// Chips de categorias personalizables con opcion Todos.
class BarraCategorias extends StatelessWidget {
	const BarraCategorias({
		required this.categorias,
		required this.categoriaSeleccionadaId,
		required this.alSeleccionar,
		super.key,
	});

	final List<Categoria> categorias;
	final String categoriaSeleccionadaId;
	final ValueChanged<String> alSeleccionar;

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 52.0,
			child: ListView(
				scrollDirection: Axis.horizontal,
				padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
				children: [
					_ChipCategoria(
						etiqueta: 'Todos',
						icono: Icons.apps,
						color: Colors.blueGrey,
						seleccionado: categoriaSeleccionadaId == CATEGORIA_TODOS_ID,
						alPresionar: () => alSeleccionar(CATEGORIA_TODOS_ID),
					),
					...categorias.map(
						(categoria) => _ChipCategoria(
							etiqueta: categoria.nombre,
							icono: IconosCategoria.resolver(categoria.icono),
							color: IconosCategoria.resolverColor(categoria.colorHex),
							seleccionado: categoriaSeleccionadaId == categoria.id,
							alPresionar: () => alSeleccionar(categoria.id),
						),
					),
				],
			),
		);
	}
}

class _ChipCategoria extends StatelessWidget {
	const _ChipCategoria({
		required this.etiqueta,
		required this.icono,
		required this.color,
		required this.seleccionado,
		required this.alPresionar,
	});

	final String etiqueta;
	final IconData icono;
	final Color color;
	final bool seleccionado;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(right: 8.0),
			child: FilterChip(
				selected: seleccionado,
				label: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(icono, size: 18.0, color: seleccionado ? Colors.white : color),
						const SizedBox(width: 4.0),
						Text(etiqueta),
					],
				),
				selectedColor: color,
				labelStyle: TextStyle(
					color: seleccionado ? Colors.white : null,
					fontWeight: FontWeight.w600,
				),
				onSelected: (_) => alPresionar(),
			),
		);
	}
}
