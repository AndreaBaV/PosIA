/// Pantalla de acceso administrativo mediante PIN numerico.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

/// Solicita PIN de 4 digitos antes de desbloquear panel admin.
class PantallaAccesoAdmin extends ConsumerStatefulWidget {
	/// Crea pantalla de acceso con teclado PIN.
	const PantallaAccesoAdmin({super.key});

	@override
	ConsumerState<PantallaAccesoAdmin> createState() => _PantallaAccesoAdminState();
}

/// Estado del teclado PIN administrativo.
class _PantallaAccesoAdminState extends ConsumerState<PantallaAccesoAdmin> {
	String _pinIngresado = '';
	bool _pinIncorrecto = false;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Acceso administrador'),
				leading: IconButton(
					icon: const Icon(Icons.arrow_back),
					onPressed: () => Navigator.of(context).pop(),
				),
			),
			body: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 360.0),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							const Icon(Icons.lock, size: 64.0, color: PosiaColors.neutro),
							const SizedBox(height: 16.0),
							const Text('Ingrese PIN de administrador'),
							const SizedBox(height: 8.0),
							Text(
								'Demo: $PIN_ADMIN_DEMO',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: Colors.grey,
								),
							),
							if (_pinIncorrecto) ...[
								const SizedBox(height: 8.0),
								const Text(
									'PIN incorrecto',
									style: TextStyle(color: PosiaColors.cancelar),
								),
							],
							const SizedBox(height: 24.0),
							TecladoPinAdmin(
								pinActual: _pinIngresado,
								alPresionarDigito: _agregarDigito,
								alBorrar: _borrarDigito,
							),
						],
					),
				),
			),
		);
	}

	/// Agrega digito al PIN y valida cuando alcanza longitud requerida.
	///
	/// [digito] Caracter numerico pulsado.
	void _agregarDigito(String digito) {
		if (_pinIngresado.length >= LONGITUD_PIN_ADMIN) {
			return;
		}
		setState(() {
			_pinIngresado = _pinIngresado + digito;
			_pinIncorrecto = false;
		});
		if (_pinIngresado.length < LONGITUD_PIN_ADMIN) {
			return;
		}
		_validarPin();
	}

	/// Elimina ultimo digito del PIN parcial.
	void _borrarDigito() {
		if (_pinIngresado.isEmpty) {
			return;
		}
		setState(() {
			_pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
			_pinIncorrecto = false;
		});
	}

	/// Compara PIN ingresado con PIN configurado y desbloquea admin.
	Future<void> _validarPin() async {
		final pinEsperado = await ref.read(pinAdminProvider.future);
		if (_pinIngresado == pinEsperado) {
			ref.read(sesionAdminProvider.notifier).desbloquear();
			if (!mounted) {
				return;
			}
			Navigator.of(context).pop();
			return;
		}
		setState(() {
			_pinIncorrecto = true;
			_pinIngresado = '';
		});
	}
}
