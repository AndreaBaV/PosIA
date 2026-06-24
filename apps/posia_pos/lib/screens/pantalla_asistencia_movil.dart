/// Asistencia movil: PIN + GPS o geocerca + Face ID.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';

class PantallaAsistenciaMovil extends ConsumerStatefulWidget {
	const PantallaAsistenciaMovil({super.key});

	@override
	ConsumerState<PantallaAsistenciaMovil> createState() =>
		_PantallaAsistenciaMovilState();
}

class _PantallaAsistenciaMovilState extends ConsumerState<PantallaAsistenciaMovil> {
	final _pinController = TextEditingController();
	final _localAuth = LocalAuthentication();
	RegistroAsistencia? _entradaAbierta;
	bool _cargando = false;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _cargarEstado());
	}

	@override
	void dispose() {
		_pinController.dispose();
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
		final permiso = await Permission.locationWhenInUse.request();
		if (!permiso.isGranted) {
			throw StateError('Permiso de ubicación requerido');
		}
		final servicio = await Geolocator.isLocationServiceEnabled();
		if (!servicio) {
			throw StateError('Active el GPS del teléfono');
		}
		return Geolocator.getCurrentPosition(
			locationSettings: const LocationSettings(
				accuracy: LocationAccuracy.high,
				timeLimit: Duration(seconds: 15),
			),
		);
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
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Entrada registrada'),
					backgroundColor: PosiaColors.cobrar,
				),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
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
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Biometría no disponible en este dispositivo')),
			);
			return;
		}
		final ok = await _localAuth.authenticate(
			localizedReason: 'Confirme su identidad para marcar entrada',
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
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Entrada registrada'),
					backgroundColor: PosiaColors.cobrar,
				),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
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
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Salida registrada')),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
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
		return Scaffold(
			appBar: AppBar(title: const Text('Mi asistencia')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: abierta != null
					? Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							const Icon(Icons.check_circle, color: PosiaColors.cobrar, size: 72),
							const SizedBox(height: 16),
							Text(
								'Entrada: ${abierta.entradaEn.toLocal().toString().substring(11, 16)}',
								style: Theme.of(context).textTheme.titleLarge,
							),
							const SizedBox(height: 24),
							FilledButton.icon(
								onPressed: _cargando ? null : _registrarSalida,
								icon: const Icon(Icons.logout),
								label: const Text('Registrar salida'),
							),
						],
					)
					: ListView(
						children: [
							const Text(
								'Modo PIN',
								style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8),
							const Text(
								'Ingrese el PIN de 4 dígitos que muestra la laptop del administrador.',
							),
							const SizedBox(height: 12),
							TextField(
								controller: _pinController,
								keyboardType: TextInputType.number,
								maxLength: 4,
								decoration: const InputDecoration(
									labelText: 'PIN',
									border: OutlineInputBorder(),
									counterText: '',
								),
							),
							FilledButton(
								onPressed: _cargando ? null : _entradaConPin,
								child: _cargando
									? const SizedBox(
										height: 20,
										width: 20,
										child: CircularProgressIndicator(strokeWidth: 2),
									)
									: const Text('Marcar entrada con PIN'),
							),
							const Divider(height: 40),
							const Text(
								'Modo automático',
								style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8),
							const Text(
								'Use Face ID o huella del teléfono cuando esté cerca de la tienda.',
							),
							const SizedBox(height: 12),
							OutlinedButton.icon(
								onPressed: _cargando ? null : _entradaBiometrica,
								icon: const Icon(Icons.fingerprint),
								label: const Text('Entrada con biometría'),
							),
						],
					),
			),
		);
	}
}
