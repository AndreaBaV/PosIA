/// Pantalla para que el empleado gestione su propia cuenta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaMiCuenta extends ConsumerStatefulWidget {
	const PantallaMiCuenta({super.key});

	@override
	ConsumerState<PantallaMiCuenta> createState() => _PantallaMiCuentaState();
}

class _PantallaMiCuentaState extends ConsumerState<PantallaMiCuenta> {
	final _nombreController = TextEditingController();
	final _pinActualController = TextEditingController();
	final _pinNuevoController = TextEditingController();
	bool _nombreInicializado = false;

	@override
	void dispose() {
		_nombreController.dispose();
		_pinActualController.dispose();
		_pinNuevoController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final usuario = ref.watch(sesionUsuarioProvider);
		if (usuario == null) {
			return const Scaffold(
				body: Center(child: Text('Sin sesión activa')),
			);
		}
		if (!_nombreInicializado) {
			_nombreController.text = usuario.nombre;
			_nombreInicializado = true;
		}
		return Scaffold(
			appBar: AppBar(title: const Text('Mi cuenta')),
			body: ListView(
				padding: const EdgeInsets.all(16.0),
				children: [
					Card(
						child: Padding(
							padding: const EdgeInsets.all(16.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										usuario.nombre,
										style: Theme.of(context).textTheme.titleLarge,
									),
									const SizedBox(height: 8.0),
									Text('Código: ${usuario.codigo}'),
									Text('Rol: ${PermisosUsuario.etiquetaRol(usuario.rol)}'),
								],
							),
						),
					),
					const SizedBox(height: 16.0),
					TextField(
						controller: _nombreController,
						decoration: const InputDecoration(
							labelText: 'Nombre para mostrar',
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 12.0),
					FilledButton(
						onPressed: () => _guardarNombre(usuario),
						child: const Text('Guardar nombre'),
					),
					const Divider(height: 32.0),
					const Text(
						'Cambiar PIN',
						style: TextStyle(fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 12.0),
					CampoSecreto(
						controller: _pinActualController,
						keyboardType: TextInputType.number,
						maxLength: LONGITUD_PIN_ADMIN,
						decoration: const InputDecoration(
							labelText: 'PIN actual',
							border: OutlineInputBorder(),
						),
					),
					CampoSecreto(
						controller: _pinNuevoController,
						keyboardType: TextInputType.number,
						maxLength: LONGITUD_PIN_ADMIN,
						decoration: const InputDecoration(
							labelText: 'PIN nuevo',
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 12.0),
					FilledButton.tonal(
						onPressed: () => _cambiarPin(usuario),
						child: const Text('Actualizar PIN'),
					),
				],
			),
		);
	}

	Future<void> _guardarNombre(Usuario usuario) async {
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final actualizado = usuario.copiarCon(nombre: _nombreController.text.trim());
			await servicio.actualizarUsuario(actualizado, operador: usuario);
			ref.read(sesionUsuarioProvider.notifier).iniciar(actualizado);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Nombre actualizado')),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _cambiarPin(Usuario usuario) async {
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.cambiarPinUsuario(
				usuarioId: usuario.id,
				pinActual: _pinActualController.text,
				pinNuevo: _pinNuevoController.text,
				operador: usuario,
			);
			final actualizado = usuario.copiarCon(pin: _pinNuevoController.text.trim());
			ref.read(sesionUsuarioProvider.notifier).iniciar(actualizado);
			_pinActualController.clear();
			_pinNuevoController.clear();
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('PIN actualizado')),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}
