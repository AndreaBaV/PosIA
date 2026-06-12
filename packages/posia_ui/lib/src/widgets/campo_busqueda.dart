/// Campo de busqueda reutilizable para pantallas admin.
library;

import 'package:flutter/material.dart';

/// TextField con icono de lupa para filtrar listas.
class CampoBusqueda extends StatefulWidget {
	const CampoBusqueda({
		required this.controlador,
		required this.alCambiar,
		this.sugerencia = 'Buscar...',
		super.key,
	});

	final TextEditingController controlador;
	final ValueChanged<String> alCambiar;
	final String sugerencia;

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
			padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
			child: TextField(
				controller: widget.controlador,
				decoration: InputDecoration(
					labelText: widget.sugerencia,
					prefixIcon: const Icon(Icons.search),
					border: const OutlineInputBorder(),
					suffixIcon: widget.controlador.text.isNotEmpty
						? IconButton(
							icon: const Icon(Icons.clear),
							onPressed: () {
								widget.controlador.clear();
							},
						)
						: null,
				),
			),
		);
	}
}
