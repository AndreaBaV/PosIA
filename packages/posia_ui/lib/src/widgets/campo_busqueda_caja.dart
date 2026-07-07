/// Campo de busqueda y escaneo en pantalla de caja.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// TextField con autofocus para filtrar productos y recibir escaneos USB.
class CampoBusquedaCaja extends StatefulWidget {
	const CampoBusquedaCaja({
		required this.controlador,
		required this.focusNode,
		required this.alCambiar,
		required this.alEnviar,
		this.hintText = 'Buscar…',
		this.autofocus = true,
		this.mostrarIconoEscaneo = true,
		super.key,
	});

	final TextEditingController controlador;
	final FocusNode focusNode;
	final ValueChanged<String> alCambiar;
	final ValueChanged<String> alEnviar;
	final String hintText;
	final bool autofocus;
	final bool mostrarIconoEscaneo;

	@override
	State<CampoBusquedaCaja> createState() => _CampoBusquedaCajaState();
}

class _CampoBusquedaCajaState extends State<CampoBusquedaCaja> {
	@override
	void initState() {
		super.initState();
		widget.controlador.addListener(_actualizar);
	}

	@override
	void dispose() {
		widget.controlador.removeListener(_actualizar);
		super.dispose();
	}

	void _actualizar() {
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 4.0),
			child: TextField(
				controller: widget.controlador,
				focusNode: widget.focusNode,
				autofocus: widget.autofocus,
				textInputAction: TextInputAction.search,
				decoration: InputDecoration(
					hintText: widget.hintText,
					prefixIcon: Icon(
						Icons.search,
						color: PosiaColors.cobrar.withValues(alpha: 0.85),
					),
					suffixIcon: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (widget.mostrarIconoEscaneo)
								Tooltip(
									message: 'Escaneo automático activo',
									child: Icon(
										Icons.qr_code_scanner,
										color: PosiaColors.cobrar.withValues(alpha: 0.85),
										size: 22.0,
									),
								),
							if (widget.controlador.text.isNotEmpty)
								IconButton(
									icon: const Icon(Icons.clear),
									tooltip: 'Limpiar búsqueda',
									onPressed: () {
										widget.controlador.clear();
										widget.alCambiar('');
									},
								),
						],
					),
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
				onChanged: widget.alCambiar,
				onSubmitted: widget.alEnviar,
			),
		);
	}
}
