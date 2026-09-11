/// Campo de busqueda y escaneo en pantalla de caja.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// TextField con autofocus para filtrar productos y recibir escaneos USB.
///
/// Tras perder el foco con texto, la proxima vez que se enfoca selecciona todo
/// (estilo traductor de Google): la primera tecla reemplaza la busqueda previa
/// salvo que el usuario pulse de nuevo el campo para editar.
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
	/// Tras unblur con texto: al volver a enfocar se selecciona todo.
	bool _reemplazarAlEscribir = false;

	/// Evita tratar el primer toque de foco como "editar" (quita la seleccion).
	bool _ignorarTapDeEnfoque = false;

	@override
	void initState() {
		super.initState();
		widget.controlador.addListener(_actualizar);
		widget.focusNode.addListener(_alCambiarFoco);
	}

	@override
	void didUpdateWidget(CampoBusquedaCaja oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.controlador != widget.controlador) {
			oldWidget.controlador.removeListener(_actualizar);
			widget.controlador.addListener(_actualizar);
		}
		if (oldWidget.focusNode != widget.focusNode) {
			oldWidget.focusNode.removeListener(_alCambiarFoco);
			widget.focusNode.addListener(_alCambiarFoco);
		}
	}

	@override
	void dispose() {
		widget.controlador.removeListener(_actualizar);
		widget.focusNode.removeListener(_alCambiarFoco);
		super.dispose();
	}

	void _actualizar() {
		setState(() {});
	}

	void _alCambiarFoco() {
		if (!widget.focusNode.hasFocus) {
			if (widget.controlador.text.trim().isNotEmpty) {
				_reemplazarAlEscribir = true;
			}
			return;
		}
		if (!_reemplazarAlEscribir || widget.controlador.text.isEmpty) {
			return;
		}
		_ignorarTapDeEnfoque = true;
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted || !widget.focusNode.hasFocus) {
				return;
			}
			final texto = widget.controlador.text;
			if (texto.isEmpty) {
				return;
			}
			widget.controlador.selection = TextSelection(
				baseOffset: 0,
				extentOffset: texto.length,
			);
		});
	}

	void _alPulsarCampo() {
		if (_ignorarTapDeEnfoque) {
			_ignorarTapDeEnfoque = false;
			return;
		}
		// Segundo toque: el usuario quiere editar el texto actual.
		if (_reemplazarAlEscribir) {
			_reemplazarAlEscribir = false;
		}
	}

	void _ocultarTecladoFuera(PointerDownEvent event) {
		widget.focusNode.unfocus();
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
				onTap: _alPulsarCampo,
				onTapOutside: _ocultarTecladoFuera,
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
										_reemplazarAlEscribir = false;
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
				onChanged: (valor) {
					_reemplazarAlEscribir = false;
					widget.alCambiar(valor);
				},
				onSubmitted: (valor) {
					if (valor.trim().isNotEmpty) {
						_reemplazarAlEscribir = true;
					}
					widget.alEnviar(valor);
				},
			),
		);
	}
}
