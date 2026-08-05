/// Dialogo de captura de peso para venta por kilogramo o gramos.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';
import 'banner_mensaje_dialogo.dart';
import 'contenido_dialogo_teclado.dart';

/// Resultado del dialogo de peso.
class ResultadoDialogoPeso {
	const ResultadoDialogoPeso({
		required this.confirmado,
		required this.pesoKg,
	});

	final bool confirmado;
	final double pesoKg;
}

enum _UnidadCapturaPeso { kilogramos, gramos, importe }

/// Muestra dialogo para capturar peso en kg o gramos.
class DialogoPesoCarniceria extends StatefulWidget {
	const DialogoPesoCarniceria({
		required this.producto,
		this.resolverPrecio,
		super.key,
	});

	final Producto producto;

	/// Resuelve precio por kg segun peso capturado (escalas, cliente, etc.).
	final Future<ResultadoPrecio> Function(double pesoKg)? resolverPrecio;

	static Future<ResultadoDialogoPeso> mostrar(
		BuildContext context,
		Producto producto, {
		Future<ResultadoPrecio> Function(double pesoKg)? resolverPrecio,
	}) async {
		final resultado = await showDialog<ResultadoDialogoPeso>(
			context: context,
			builder: (_) => DialogoPesoCarniceria(
				producto: producto,
				resolverPrecio: resolverPrecio,
			),
		);
		return resultado ?? const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0);
	}

	@override
	State<DialogoPesoCarniceria> createState() => _DialogoPesoCarniceriaState();
}

class _DialogoPesoCarniceriaState extends State<DialogoPesoCarniceria> {
	final _pesoController = TextEditingController();
	late final FocusNode _pesoFocus;
	String _valorPeso = '';
	_UnidadCapturaPeso _unidad = _UnidadCapturaPeso.kilogramos;
	var _cerrado = false;
	ResultadoPrecio? _precioResuelto;
	var _resolviendoPrecio = false;
	String? _mensajeError;

	/// Numero de la ultima resolucion de precio pedida.
	///
	/// Cada tecleo dispara su propia llamada async a [resolverPrecio] (posible
	/// consulta a SQLite/hub), y no hay garantia de que resuelvan en el mismo
	/// orden en que se pidieron. Sin este guardia, una respuesta lenta de un
	/// monto ya obsoleto (p. ej. "4" mientras el usuario ya escribio "40")
	/// puede llegar despues de la respuesta correcta y sobreescribir el precio
	/// y el peso mostrados con una combinacion que no corresponde al importe
	/// que el usuario realmente capturo.
	var _tokenResolucion = 0;

	/// Peso convergido en modo importe, una vez resuelto el precio real del
	/// tramo (ver [_actualizarPrecioResuelto]). Null fuera de ese modo o antes
	/// de la primera resolucion, momento en que se usa la estimacion con
	/// [Producto.precioBase] de [_pesoKgCapturado].
	double? _pesoKgImporteResuelto;

	@override
	void initState() {
		super.initState();
		_pesoFocus = FocusNode(onKeyEvent: _manejarTeclaPeso);
		_solicitarFocoPeso();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_actualizarPrecioResuelto();
		});
	}

	/// Pide el foco del campo de captura tras el cambio de unidad/apertura.
	///
	/// Un solo `addPostFrameCallback` no basta: el propio `SegmentedButton`
	/// tocado tambien reclama el foco para si al manejar el tap, y puede
	/// resolverlo despues de nuestro primer callback. Encadenar un segundo
	/// post-frame lo pide de nuevo una vez que ese foco "de por si" ya se
	/// asento, para que el usuario pueda teclear el importe sin tener que
	/// tocar el campo de nuevo.
	void _solicitarFocoPeso() {
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) {
				return;
			}
			if (_pesoFocus.canRequestFocus) {
				_pesoFocus.requestFocus();
			}
			WidgetsBinding.instance.addPostFrameCallback((_) {
				if (mounted && _pesoFocus.canRequestFocus) {
					_pesoFocus.requestFocus();
				}
			});
		});
	}

	@override
	void dispose() {
		_pesoController.dispose();
		_pesoFocus.dispose();
		super.dispose();
	}

	KeyEventResult _manejarTeclaPeso(FocusNode node, KeyEvent event) {
		if (event is! KeyDownEvent) {
			return KeyEventResult.ignored;
		}
		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			_confirmar();
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.escape) {
			_cancelar();
			return KeyEventResult.handled;
		}
		return KeyEventResult.ignored;
	}

	/// Estimacion inicial de peso a partir del texto capturado.
	///
	/// En modo importe usa [Producto.precioBase] (precio del kilo completo)
	/// solo como punto de partida: [_actualizarPrecioResuelto] la refina contra
	/// el precio real del tramo de peso que aplique. Usar [_pesoFinal] para el
	/// peso a mostrar o confirmar.
	double? _pesoKgCapturado() {
		final cantidad = _montoCapturado();
		if (cantidad <= 0.0) {
			return null;
		}
		switch (_unidad) {
			case _UnidadCapturaPeso.gramos:
				return cantidad / 1000.0;
			case _UnidadCapturaPeso.importe:
				final precioKg = widget.producto.precioBase;
				return precioKg > 0.0 ? cantidad / precioKg : null;
			case _UnidadCapturaPeso.kilogramos:
				return cantidad;
		}
	}

	double _montoCapturado() =>
		double.tryParse(_valorPeso.isEmpty ? '0' : _valorPeso) ?? 0.0;

	/// Peso a usar para mostrar el resumen y para confirmar el pesaje.
	///
	/// En modo importe es el peso ya convergido contra el precio real del
	/// tramo (ver [_actualizarPrecioResuelto]); en los demas modos coincide
	/// con la estimacion directa.
	double? _pesoFinal() {
		if (_unidad == _UnidadCapturaPeso.importe) {
			return _pesoKgImporteResuelto ?? _pesoKgCapturado();
		}
		return _pesoKgCapturado();
	}

	Future<void> _actualizarPrecioResuelto() async {
		final pesoInicial = _pesoKgCapturado();
		final resolver = widget.resolverPrecio;
		final miToken = ++_tokenResolucion;
		if (pesoInicial == null || resolver == null) {
			if (!mounted || miToken != _tokenResolucion) {
				return;
			}
			setState(() {
				_precioResuelto = null;
				_pesoKgImporteResuelto = null;
				_resolviendoPrecio = false;
			});
			return;
		}
		setState(() => _resolviendoPrecio = true);
		try {
			var pesoKg = pesoInicial;
			var resultado = await resolver(pesoKg);
			if (_unidad == _UnidadCapturaPeso.importe) {
				// El precio por kg puede variar segun el tramo de peso (p. ej. un
				// corte bajo 1 kg cobra distinto que el kilo completo): al mover
				// el peso al precio recien resuelto puede caer en otro tramo.
				// Los tramos son pocos y monotonos, asi que converge en pocas
				// vueltas; se acota por si acaso para no colgar la UI.
				final monto = _montoCapturado();
				for (var i = 0; i < 4; i++) {
					final precioKg = resultado.precioUnitario;
					if (precioKg <= 0.0) {
						break;
					}
					final nuevoPeso = monto / precioKg;
					if ((nuevoPeso - pesoKg).abs() < 0.0005) {
						pesoKg = nuevoPeso;
						break;
					}
					pesoKg = nuevoPeso;
					resultado = await resolver(pesoKg);
				}
			}
			if (!mounted || miToken != _tokenResolucion) {
				return;
			}
			setState(() {
				_precioResuelto = resultado;
				_pesoKgImporteResuelto =
					_unidad == _UnidadCapturaPeso.importe ? pesoKg : null;
				_resolviendoPrecio = false;
			});
		} catch (_) {
			if (!mounted || miToken != _tokenResolucion) {
				return;
			}
			setState(() {
				_precioResuelto = null;
				_pesoKgImporteResuelto = null;
				_resolviendoPrecio = false;
			});
		}
	}

	Widget _buildResumenPrecio() {
		final pesoKg = _pesoFinal();
		if (pesoKg == null) {
			return Text(
				'${formatearMoneda(widget.producto.precioBase)} / kg',
				style: Theme.of(context).textTheme.titleMedium?.copyWith(
					color: PosiaColors.cobrar,
					fontWeight: FontWeight.w600,
				),
			);
		}
		if (_resolviendoPrecio) {
			return const SizedBox(
				height: 24.0,
				width: 24.0,
				child: CircularProgressIndicator(strokeWidth: 2.0),
			);
		}
		final precioKg = _precioResuelto?.precioUnitario ?? widget.producto.precioBase;
		final total = redondearMonto(precioKg * pesoKg);
		final regla = _precioResuelto?.reglaAplicada;
		return Column(
			children: [
				Text(
					'${formatearMoneda(precioKg)} / kg',
					style: Theme.of(context).textTheme.titleMedium?.copyWith(
						color: PosiaColors.cobrar,
						fontWeight: FontWeight.w600,
					),
				),
				const SizedBox(height: 4.0),
				Text(
					'${formatearPesoKg(pesoKg)} · Total ${formatearMoneda(total)}',
					style: Theme.of(context).textTheme.bodyLarge?.copyWith(
						fontWeight: FontWeight.w600,
					),
				),
				if (regla == ReglaPrecio.escalaMayoreo) ...[
					const SizedBox(height: 4.0),
					Text(
						'Precio según tramo de peso',
						style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
					),
				],
			],
		);
	}

	@override
	Widget build(BuildContext context) {
		final etiquetaUnidad = switch (_unidad) {
			_UnidadCapturaPeso.kilogramos => 'kg',
			_UnidadCapturaPeso.gramos => 'g',
			_UnidadCapturaPeso.importe => '\$',
		};
		final esImporte = _unidad == _UnidadCapturaPeso.importe;
		return AlertDialog(
			title: Row(
				children: [
					const Icon(Icons.scale, color: PosiaColors.cobrar, size: 32.0),
					const SizedBox(width: 8.0),
					Expanded(child: Text(widget.producto.nombre)),
				],
			),
			content: ContenidoDialogoTeclado(
				ancho: 320.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						SegmentedButton<_UnidadCapturaPeso>(
							segments: const [
								ButtonSegment(
									value: _UnidadCapturaPeso.kilogramos,
									label: Text('Kg'),
								),
								ButtonSegment(
									value: _UnidadCapturaPeso.gramos,
									label: Text('Gramos'),
								),
								ButtonSegment(
									value: _UnidadCapturaPeso.importe,
									label: Text('Importe \$'),
								),
							],
							selected: {_unidad},
							onSelectionChanged: (s) => setState(() {
								_unidad = s.first;
								_establecerValor('');
								_solicitarFocoPeso();
							}),
						),
						const SizedBox(height: 12.0),
						_buildResumenPrecio(),
						const SizedBox(height: 12.0),
						TextField(
							controller: _pesoController,
							focusNode: _pesoFocus,
							autofocus: true,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							showCursor: true,
							textInputAction: TextInputAction.done,
							decoration: InputDecoration(
								labelText: esImporte ? 'Importe' : 'Peso',
								suffixText: etiquetaUnidad,
								hintText: switch (_unidad) {
									_UnidadCapturaPeso.gramos => '250',
									_UnidadCapturaPeso.importe => '50',
									_UnidadCapturaPeso.kilogramos => '0.250',
								},
								border: const OutlineInputBorder(),
								helperText: esImporte
									? 'Peso = importe ÷ precio/kg · Enter agrega'
									: 'Enter agrega · Esc cancela',
							),
							onChanged: (texto) {
								_limpiarError();
								_establecerValor(_normalizarEntradaPeso(texto));
								_actualizarPrecioResuelto();
							},
						),
						if (_mensajeError != null)
							BannerMensajeDialogo(
								mensaje: _mensajeError!,
								padding: const EdgeInsets.only(top: 8.0),
							),
					],
				),
			),
			actions: [
				TextButton(
					onPressed: _cancelar,
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: _resolviendoPrecio ? null : _confirmar,
					child: const Text('Agregar'),
				),
			],
		);
	}

	void _establecerValor(String valor) {
		setState(() {
			_valorPeso = valor;
			_pesoKgImporteResuelto = null;
		});
		if (_pesoController.text == valor) {
			return;
		}
		_pesoController.value = TextEditingValue(
			text: valor,
			selection: TextSelection.collapsed(offset: valor.length),
		);
	}

	String _normalizarEntradaPeso(String raw) {
		final texto = raw.replaceAll(',', '.');
		final buffer = StringBuffer();
		var puntoVisto = false;
		for (final caracter in texto.split('')) {
			if (caracter == '.' && !puntoVisto) {
				puntoVisto = true;
				buffer.write(caracter);
			} else if (RegExp(r'\d').hasMatch(caracter)) {
				buffer.write(caracter);
			}
		}
		return buffer.toString();
	}

	void _cancelar() {
		if (_cerrado || !mounted) {
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0),
		);
	}

	void _confirmar() {
		if (_cerrado || !mounted) {
			return;
		}
		if (_resolviendoPrecio) {
			// Aun convergiendo peso/precio en modo importe (consulta en curso):
			// confirmar ahora agregaria el estimado con el precio base, no el
			// precio real del tramo. Enter/Agregar quedan en espera hasta que
			// termine, en vez de agregar una cantidad distinta a la mostrada.
			return;
		}
		final pesoKg = _pesoFinal();
		if (pesoKg == null) {
			_mostrarError('Indique un peso mayor a cero');
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			ResultadoDialogoPeso(confirmado: true, pesoKg: pesoKg),
		);
	}

	void _mostrarError(String mensaje) {
		if (!mounted) {
			return;
		}
		setState(() => _mensajeError = mensaje);
	}

	void _limpiarError() {
		if (_mensajeError == null) {
			return;
		}
		setState(() => _mensajeError = null);
	}
}
