/// Campo de texto con toggle para mostrar u ocultar el valor.
library;

import 'package:flutter/material.dart';

/// TextField con icono de visibilidad (PIN, contraseña, API key, etc.).
class CampoSecreto extends StatefulWidget {
	const CampoSecreto({
		required this.controller,
		this.decoration,
		this.keyboardType,
		this.maxLength,
		this.autofocus = false,
		super.key,
	});

	final TextEditingController controller;
	final InputDecoration? decoration;
	final TextInputType? keyboardType;
	final int? maxLength;
	final bool autofocus;

	@override
	State<CampoSecreto> createState() => _CampoSecretoState();
}

class _CampoSecretoState extends State<CampoSecreto> {
	var _oculto = true;

	@override
	Widget build(BuildContext context) {
		return TextField(
			controller: widget.controller,
			autofocus: widget.autofocus,
			keyboardType: widget.keyboardType,
			maxLength: widget.maxLength,
			obscureText: _oculto,
			decoration: (widget.decoration ?? const InputDecoration()).copyWith(
				suffixIcon: IconButton(
					tooltip: _oculto ? 'Mostrar' : 'Ocultar',
					icon: Icon(
						_oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
					),
					onPressed: () => setState(() => _oculto = !_oculto),
				),
			),
		);
	}
}
