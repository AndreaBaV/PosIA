/// Campo de busqueda reutilizable para pantallas admin.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// TextField con icono de lupa para filtrar listas.
class CampoBusqueda extends StatefulWidget {
	const CampoBusqueda({
		required this.controlador,
		required this.alCambiar,
		this.sugerencia = 'Buscar...',
		this.padding = const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
		this.autofocus = false,
		super.key,
	});

	final TextEditingController controlador;
	final ValueChanged<String> alCambiar;
	final String sugerencia;
	final EdgeInsetsGeometry padding;
	final bool autofocus;

	@override
	State<CampoBusqueda> createState() => _CampoBusquedaState();
}

class _CampoBusquedaState extends State<CampoBusqueda> {
	@override
	void initState() {
		super.initState();
		widget.controlador.addListener(_notificar);
	}

	@override
	void dispose() {
		widget.controlador.removeListener(_notificar);
		super.dispose();
	}

	void _notificar() {
		widget.alCambiar(widget.controlador.text);
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: widget.padding,
			child: TextField(
				controller: widget.controlador,
				autofocus: widget.autofocus,
				textInputAction: TextInputAction.search,
				decoration: InputDecoration(
					hintText: widget.sugerencia,
					prefixIcon: Icon(
						Icons.search,
						color: PosiaColors.cobrar.withValues(alpha: 0.85),
					),
					suffixIcon: widget.controlador.text.isNotEmpty
						? IconButton(
							icon: const Icon(Icons.clear),
							tooltip: 'Limpiar búsqueda',
							onPressed: widget.controlador.clear,
						)
						: null,
					border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
					enabledBorder: OutlineInputBorder(
						borderRadius: BorderRadius.circular(12.0),
						borderSide: BorderSide(color: Colors.grey.shade300),
					),
					focusedBorder: OutlineInputBorder(
						borderRadius: BorderRadius.circular(12.0),
						borderSide: const BorderSide(color: PosiaColors.cobrar, width: 2.0),
					),
					filled: true,
					fillColor: PosiaColors.tarjeta,
					isDense: true,
					contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
				),
			),
		);
	}
}
