/// Asistencia móvil: PIN, GPS y biometría.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';
import '../util/teclado_util.dart';
import '../util/ubicacion_util.dart';

class PantallaAsistenciaMovil extends ConsumerStatefulWidget {
	const PantallaAsistenciaMovil({super.key});

	@override
	ConsumerState<PantallaAsistenciaMovil> createState() =>
		_PantallaAsistenciaMovilState();
}

class _PantallaAsistenciaMovilState extends ConsumerState<PantallaAsistenciaMovil> {
	final _pinController = TextEditingController();
	final _pinFocus = FocusNode();
	final _localAuth = LocalAuthentication();
	RegistroAsistencia? _entradaAbierta;
	bool _cargando = false;

	@override
	void initState() {
		super.initState();
		_pinFocus.addListener(() => setState(() {}));
		WidgetsBinding.instance.addPostFrameCallback((_) => _cargarEstado());
	}

	@override
	void dispose() {
		_pinController.dispose();
		_pinFocus.dispose();
		super.dispose();
	}

	Future<void> _cargarEstado() async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final abierta = await contenedor.servicioAsistencia?.obtenerEntradaAbierta(
			usuario.id,
		);
		if (mounted) {
			setState(() => _entradaAbierta = abierta);
		}
	}

	Future<Position?> _obtenerUbicacion() async {
		try {
			return await obtenerUbicacionActual();
		} on StateError {
			rethrow;
		}
	}

	Future<void> _entradaConPin() async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		setState(() => _cargando = true);
		try {
			final pos = await _obtenerUbicacion();
			if (pos == null) {
				return;
			}
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			await contenedor.servicioAsistencia?.registrarEntradaConPin(
				usuarioId: usuario.id,
				pin: _pinController.text.trim(),
				latitud: pos.latitude,
				longitud: pos.longitude,
			);
			_pinController.clear();
			await _cargarEstado();
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(
					content: Text('Entrada registrada'),
					backgroundColor: PosiaColors.cobrar,
					duration: Duration(seconds: 2),
				),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _cargando = false);
			}
		}
	}

	Future<void> _entradaBiometrica() async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		final puede = await _localAuth.canCheckBiometrics;
		if (!puede) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Biometría no disponible')),
			);
			return;
		}
		final ok = await _localAuth.authenticate(
			localizedReason: 'Confirma tu identidad',
		);
		if (!ok) {
			return;
		}
		setState(() => _cargando = true);
		try {
			final pos = await _obtenerUbicacion();
			if (pos == null) {
				return;
			}
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			await contenedor.servicioAsistencia?.registrarEntradaBiometrica(
				usuarioId: usuario.id,
				latitud: pos.latitude,
				longitud: pos.longitude,
			);
			await _cargarEstado();
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(
					content: Text('Entrada registrada'),
					backgroundColor: PosiaColors.cobrar,
					duration: Duration(seconds: 2),
				),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _cargando = false);
			}
		}
	}

	Future<void> _registrarSalida() async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		setState(() => _cargando = true);
		try {
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			await contenedor.servicioAsistencia?.registrarSalida(usuario.id);
			await _cargarEstado();
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(
					content: Text('Salida registrada'),
					duration: Duration(seconds: 2),
				),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _cargando = false);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final abierta = _entradaAbierta;
		return GestureDetector(
			onTap: () => ocultarTeclado(context),
			child: Scaffold(
				resizeToAvoidBottomInset: true,
				appBar: AppBar(title: const Text('Asistencia')),
				body: CuerpoScrollTeclado(
					padding: const EdgeInsets.all(16.0),
					alinearAlCentroCuandoCabe: true,
					child: abierta != null
						? Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								const Icon(Icons.check_circle, color: PosiaColors.cobrar, size: 72.0),
								const SizedBox(height: 12.0),
								Text(
									abierta.entradaEn.toLocal().toString().substring(11, 16),
									style: Theme.of(context).textTheme.headlineMedium?.copyWith(
										fontWeight: FontWeight.bold,
									),
								),
								const SizedBox(height: 24.0),
								FilledButton.icon(
									onPressed: _cargando ? null : _registrarSalida,
									icon: const Icon(Icons.logout),
									label: const Text('Salida'),
								),
							],
						)
						: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								OutlinedButton.icon(
									onPressed: _cargando ? null : _entradaBiometrica,
									icon: const Icon(Icons.fingerprint, size: 28.0),
									label: const Text('Entrada biométrica'),
									style: OutlinedButton.styleFrom(
										minimumSize: const Size(double.infinity, 56.0),
									),
								),
								const SizedBox(height: 24.0),
								const Row(
									children: [
										Expanded(child: Divider()),
										Padding(
											padding: EdgeInsets.symmetric(horizontal: 10.0),
											child: Text('o', style: TextStyle(color: Colors.grey)),
										),
										Expanded(child: Divider()),
									],
								),
								const SizedBox(height: 24.0),
								TextField(
									controller: _pinController,
									focusNode: _pinFocus,
									keyboardType: TextInputType.number,
									maxLength: 4,
									textAlign: TextAlign.center,
									style: const TextStyle(
										fontSize: 24.0,
										letterSpacing: 8.0,
										fontWeight: FontWeight.bold,
									),
									scrollPadding: const EdgeInsets.only(bottom: 120.0),
									decoration: const InputDecoration(
										labelText: 'PIN',
										border: OutlineInputBorder(),
										counterText: '',
									),
								),
								const SizedBox(height: 24.0),
								SizedBox(
									width: double.infinity,
									height: 48.0,
									child: FilledButton(
										onPressed: _cargando ? null : _entradaConPin,
										child: _cargando
											? const SizedBox(
												height: 20.0,
												width: 20.0,
												child: CircularProgressIndicator(strokeWidth: 2.0),
											)
											: const Text('Entrada con PIN'),
									),
								),
							],
						),
				),
			),
		);
	}
}
