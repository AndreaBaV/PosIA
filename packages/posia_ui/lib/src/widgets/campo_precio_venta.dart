/// Campo reutilizable para captura de precios con validacion de utilidad minima.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// TextField con ayuda de minimo y validacion contra costo y utilidad.
class CampoPrecioVenta extends StatefulWidget {
	const CampoPrecioVenta({
		required this.controller,
		required this.costoUnitario,
		this.labelText = 'Precio (MXN)',
		this.factorABase = 1.0,
		this.obligatorio = true,
		this.mostrarAyudaMinimo = true,
		this.isDense = false,
		this.prefixText = r'$ ',
		this.border = const OutlineInputBorder(),
		this.onChanged,
		super.key,
	});

	final TextEditingController controller;
	final double costoUnitario;

	/// Si es mayor a 1, el precio capturado es total del paquete/presentacion.
	final double factorABase;
	final String labelText;
	final bool obligatorio;
	final bool mostrarAyudaMinimo;
	final bool isDense;
	final String? prefixText;
	final InputBorder? border;
	final ValueChanged<String>? onChanged;

	/// Valida el contenido actual; devuelve mensaje de error o null si es valido.
	static String? validarController(
		TextEditingController controller, {
		required double costoUnitario,
		double factorABase = 1.0,
		bool obligatorio = true,
	}) {
		if (factorABase > 1.0) {
			return errorPrecioPresentacionDesdeTexto(
				controller.text,
				costoUnitario: costoUnitario,
				factorABase: factorABase,
				obligatorio: obligatorio,
			);
		}
		return errorPrecioVentaDesdeTexto(
			controller.text,
			costoUnitario: costoUnitario,
			obligatorio: obligatorio,
		);
	}

	@override
	State<CampoPrecioVenta> createState() => _CampoPrecioVentaState();
}

class _CampoPrecioVentaState extends State<CampoPrecioVenta> {
	String? _error;

	bool get _esPresentacion => widget.factorABase > 1.0;

	String? _validar(String texto) {
		if (_esPresentacion) {
			return errorPrecioPresentacionDesdeTexto(
				texto,
				costoUnitario: widget.costoUnitario,
				factorABase: widget.factorABase,
				obligatorio: widget.obligatorio,
			);
		}
		return errorPrecioVentaDesdeTexto(
			texto,
			costoUnitario: widget.costoUnitario,
			obligatorio: widget.obligatorio,
		);
	}

	String? get _ayudaMinimo {
		if (!widget.mostrarAyudaMinimo || widget.costoUnitario <= 0.0) {
			return null;
		}
		if (_esPresentacion) {
			return ayudaPrecioMinimoPresentacion(
				widget.costoUnitario,
				widget.factorABase,
			);
		}
		return ayudaPrecioMinimoUnitario(widget.costoUnitario);
	}

	void _actualizarValidacion([String? texto]) {
		setState(() {
			_error = _validar(texto ?? widget.controller.text);
		});
	}

	@override
	void initState() {
		super.initState();
		widget.controller.addListener(_actualizarValidacion);
	}

	@override
	void didUpdateWidget(covariant CampoPrecioVenta oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.costoUnitario != widget.costoUnitario ||
			oldWidget.factorABase != widget.factorABase ||
			oldWidget.obligatorio != widget.obligatorio) {
			_actualizarValidacion();
		}
	}

	@override
	void dispose() {
		widget.controller.removeListener(_actualizarValidacion);
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return TextField(
			controller: widget.controller,
			keyboardType: const TextInputType.numberWithOptions(decimal: true),
			decoration: InputDecoration(
				labelText: widget.labelText,
				border: widget.border,
				prefixText: widget.prefixText,
				helperText: _error == null ? _ayudaMinimo : null,
				errorText: _error,
				isDense: widget.isDense,
			),
			onChanged: (valor) {
				_actualizarValidacion(valor);
				widget.onChanged?.call(valor);
			},
		);
	}
}
