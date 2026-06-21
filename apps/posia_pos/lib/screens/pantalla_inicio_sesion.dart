/// Inicio de sesion: codigo de usuario y contrasena (PIN).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

/// Pantalla de autenticacion con usuario y contrasena.
class PantallaInicioSesion extends ConsumerStatefulWidget {
	const PantallaInicioSesion({super.key});

	@override
	ConsumerState<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends ConsumerState<PantallaInicioSesion> {
	final _codigoController = TextEditingController();
	final _codigoFocus = FocusNode();
	String _pinIngresado = '';
	String? _mensajeError;
	bool _validando = false;

	@override
	void dispose() {
		_codigoController.dispose();
		_codigoFocus.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final tiendaAsync = ref.watch(_tiendaSesionProvider);
		return Scaffold(
			backgroundColor: PosiaColors.fondo,
			body: tiendaAsync.when(
				data: (tienda) => MarcoAutenticacion(
					titulo: 'Iniciar sesión',
					subtitulo: 'Ingresa tu usuario y contraseña para operar la caja',
					etiquetaTienda: tienda?.nombre,
					icono: Icons.lock_person,
					contenido: _tarjetaCredenciales(context),
					pie: TextButton.icon(
						onPressed: _cambiarTienda,
						icon: const Icon(Icons.store_outlined, size: 20.0),
						label: const Text('Cambiar tienda'),
					),
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Widget _tarjetaCredenciales(BuildContext context) {
		final dosColumnas = LayoutResponsivo.usarPanelLateral(
			MediaQuery.sizeOf(context).width,
			MediaQuery.sizeOf(context).height,
		);
		return Card(
			elevation: dosColumnas ? 0.0 : 1.0,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(16.0),
				side: dosColumnas
					? BorderSide(color: Colors.grey.shade200)
					: BorderSide.none,
			),
			child: Padding(
				padding: EdgeInsets.all(dosColumnas ? 24.0 : 20.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							'Credenciales',
							style: Theme.of(context).textTheme.titleLarge?.copyWith(
								fontWeight: FontWeight.w600,
							),
						),
						const SizedBox(height: 6.0),
						Text(
							'Usuario y contraseña de 4 dígitos',
							style: Theme.of(context).textTheme.bodyMedium?.copyWith(
								color: Theme.of(context).colorScheme.outline,
							),
						),
						const SizedBox(height: 24.0),
						TextField(
							controller: _codigoController,
							focusNode: _codigoFocus,
							keyboardType: TextInputType.number,
							textInputAction: TextInputAction.next,
							style: Theme.of(context).textTheme.titleMedium,
							inputFormatters: [FilteringTextInputFormatter.digitsOnly],
							decoration: InputDecoration(
								labelText: 'Usuario',
								hintText: 'Código numérico',
								prefixIcon: const Icon(Icons.person_outline),
								border: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12.0),
								),
								filled: true,
							),
							onChanged: (_) => setState(() => _mensajeError = null),
						),
						const SizedBox(height: 24.0),
						Text(
							'Contraseña',
							style: Theme.of(context).textTheme.titleSmall?.copyWith(
								fontWeight: FontWeight.w600,
							),
						),
						const SizedBox(height: 12.0),
						DecoratedBox(
							decoration: BoxDecoration(
								color: PosiaColors.cobrar.withValues(alpha: 0.04),
								borderRadius: BorderRadius.circular(16.0),
								border: Border.all(
									color: PosiaColors.cobrar.withValues(alpha: 0.15),
								),
							),
							child: Padding(
								padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
								child: Column(
									children: [
										if (_mensajeError != null)
											Padding(
												padding: const EdgeInsets.only(bottom: 12.0),
												child: Row(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														const Icon(
															Icons.error_outline,
															color: PosiaColors.cancelar,
															size: 18.0,
														),
														const SizedBox(width: 8.0),
														Flexible(
															child: Text(
																_mensajeError!,
																style: const TextStyle(color: PosiaColors.cancelar),
																textAlign: TextAlign.center,
															),
														),
													],
												),
											),
										if (_validando)
											const Padding(
												padding: EdgeInsets.symmetric(vertical: 56.0),
												child: CircularProgressIndicator(),
											)
										else
											TecladoPinAdmin(
												pinActual: _pinIngresado,
												alPresionarDigito: _agregarDigito,
												alBorrar: _borrarDigito,
											),
									],
								),
							),
						),
					],
				),
			),
		);
	}

	void _cambiarTienda() {
		ref.read(sesionTiendaProvider.notifier).cerrar();
		ref.read(sesionUsuarioProvider.notifier).cerrar();
	}

	void _agregarDigito(String digito) {
		if (_validando || _pinIngresado.length >= LONGITUD_PIN_ADMIN) {
			return;
		}
		setState(() {
			_pinIngresado = _pinIngresado + digito;
			_mensajeError = null;
		});
		if (_pinIngresado.length < LONGITUD_PIN_ADMIN) {
			return;
		}
		_validarAcceso();
	}

	void _borrarDigito() {
		if (_pinIngresado.isEmpty || _validando) {
			return;
		}
		setState(() {
			_pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
			_mensajeError = null;
		});
	}

	Future<void> _validarAcceso() async {
		final codigo = _codigoController.text.trim();
		final pin = _pinIngresado;

		if (codigo.isEmpty) {
			setState(() {
				_pinIngresado = '';
				_mensajeError = 'Ingresa tu código de usuario';
			});
			_codigoFocus.requestFocus();
			return;
		}

		setState(() => _validando = true);
		final servicio = await ref.read(servicioAdminProvider.future);
		final tiendaId = ref.read(sesionTiendaProvider);
		var usuario = await servicio.autenticarUsuario(codigo, pin);

		if (usuario == null && codigo == '0000') {
			final pinDispositivo = await ref.read(pinAdminProvider.future);
			if (pin == pinDispositivo) {
				usuario = Usuario(
					id: 'device-admin',
					nombre: 'Administrador dispositivo',
					codigo: '0000',
					pin: pinDispositivo,
					rol: RolUsuario.administrador,
					activo: true,
				);
			}
		}

		String? mensajeError;
		if (usuario != null &&
			tiendaId != null &&
			usuario.rol != RolUsuario.administrador &&
			usuario.tiendaId != null &&
			usuario.tiendaId != tiendaId) {
			mensajeError = 'Este usuario no está asignado a la tienda seleccionada';
			usuario = null;
		}

		if (!mounted) {
			return;
		}
		if (usuario != null) {
			ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);
			final servicioCaja = await ref.read(servicioCajaProvider.future);
			await servicioCaja.asegurarVendedorDesdeUsuario(usuario);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						'Sesión iniciada · ${usuario.nombre} '
						'(${PermisosUsuario.etiquetaRol(usuario.rol)})',
					),
					backgroundColor: PresentacionRol.color(usuario.rol),
				),
			);
			return;
		}

		setState(() {
			_validando = false;
			_pinIngresado = '';
			_mensajeError = mensajeError ?? 'Usuario o contraseña incorrectos';
		});
	}
}

final _tiendaSesionProvider = FutureProvider<Tienda?>((ref) async {
	final tiendaId = ref.watch(sesionTiendaProvider);
	if (tiendaId == null) {
		return null;
	}
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerTiendaActiva();
});
