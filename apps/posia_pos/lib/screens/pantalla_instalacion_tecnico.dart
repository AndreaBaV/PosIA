/// Asistente de instalacion para tecnico (tenant, hub Neon, sync inicial).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

/// Configura el dispositivo antes del primer uso operativo.
class PantallaInstalacionTecnico extends ConsumerStatefulWidget {
	const PantallaInstalacionTecnico({
		this.reconfiguracion = false,
		super.key,
	});

	/// Si es true, el tecnico entro desde login y puede cancelar.
	final bool reconfiguracion;

	@override
	ConsumerState<PantallaInstalacionTecnico> createState() =>
		_PantallaInstalacionTecnicoState();
}

class _PantallaInstalacionTecnicoState extends ConsumerState<PantallaInstalacionTecnico> {
	final _hubUrlController = TextEditingController();
	final _hubApiKeyController = TextEditingController();
	final _nombreNegocioController = TextEditingController();
	final _nombreTiendaController = TextEditingController(text: 'Principal');
	final _codigoAdminController = TextEditingController(text: '1001');
	String _pinTecnico = '';
	String _pinTecnicoConfirmacion = '';
	String _pinAdminNegocio = '';
	bool _conectarNube = true;
	bool _guardando = false;
	String? _mensaje;
	bool _datosCargados = false;

	@override
	void dispose() {
		_hubUrlController.dispose();
		_hubApiKeyController.dispose();
		_nombreNegocioController.dispose();
		_nombreTiendaController.dispose();
		_codigoAdminController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final hubAsync = ref.watch(_hubInstalacionProvider);
		return Scaffold(
			backgroundColor: PosiaColors.fondo,
			appBar: widget.reconfiguracion
				? AppBar(title: const Text('Configuración técnica'))
				: null,
			body: hubAsync.when(
				data: (hub) {
					_cargarDatosIniciales(hub);
					return MarcoAutenticacion(
						titulo: 'Instalación POSIA',
						subtitulo: widget.reconfiguracion
							? 'Actualiza la conexión con el hub en la nube'
							: 'Configuración inicial del dispositivo (solo técnico)',
						icono: Icons.engineering,
						contenido: _formulario(context),
						pie: _pieAcciones(context),
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	void _cargarDatosIniciales(_HubInstalacion? hub) {
		if (_datosCargados) {
			return;
		}
		if (hub != null) {
			_hubUrlController.text = hub.url;
			_hubApiKeyController.text = hub.apiKey;
			_conectarNube = hub.url.isNotEmpty;
		}
		_datosCargados = true;
	}

	Widget _formulario(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Text(
					_conectarNube
						? 'El tenant se resuelve al iniciar sesión contra el hub.'
						: 'Modo sin costo: todo queda en este dispositivo. '
							'No necesitas servidor en la nube.',
					style: const TextStyle(color: Colors.black54),
				),
				const SizedBox(height: 20.0),
				SwitchListTile(
					contentPadding: EdgeInsets.zero,
					title: const Text('Conectar al hub en la nube'),
					subtitle: const Text(
						'Desactiva si la caja operará solo offline',
					),
					value: _conectarNube,
					onChanged: (v) => setState(() => _conectarNube = v),
				),
				if (_conectarNube) ...[
					const SizedBox(height: 8.0),
					TextField(
						controller: _hubUrlController,
						decoration: const InputDecoration(
							labelText: 'URL del hub',
							hintText: 'https://tu-api.onrender.com',
							border: OutlineInputBorder(),
							prefixIcon: Icon(Icons.cloud_outlined),
						),
					),
					const SizedBox(height: 12.0),
					CampoSecreto(
						controller: _hubApiKeyController,
						decoration: const InputDecoration(
							labelText: 'API Key del hub',
							border: OutlineInputBorder(),
							prefixIcon: Icon(Icons.key_outlined),
						),
					),
				],
				if (!_conectarNube && !widget.reconfiguracion) ...[
					const SizedBox(height: 16.0),
					const Text(
						'Cuenta administrador del negocio',
						style: TextStyle(fontWeight: FontWeight.w600),
					),
					const SizedBox(height: 12.0),
					TextField(
						controller: _nombreNegocioController,
						decoration: const InputDecoration(
							labelText: 'Nombre del negocio',
							border: OutlineInputBorder(),
							prefixIcon: Icon(Icons.storefront_outlined),
						),
					),
					const SizedBox(height: 12.0),
					TextField(
						controller: _nombreTiendaController,
						decoration: const InputDecoration(
							labelText: 'Nombre de la tienda',
							border: OutlineInputBorder(),
							prefixIcon: Icon(Icons.store_outlined),
						),
					),
					const SizedBox(height: 12.0),
					TextField(
						controller: _codigoAdminController,
						keyboardType: TextInputType.number,
						decoration: const InputDecoration(
							labelText: 'Código del administrador',
							hintText: '1001',
							border: OutlineInputBorder(),
							prefixIcon: Icon(Icons.person_outline),
						),
					),
					const SizedBox(height: 12.0),
					const Text('PIN del administrador', style: TextStyle(fontWeight: FontWeight.w600)),
					const SizedBox(height: 8.0),
					TecladoPinAdmin(
						pinActual: _pinAdminNegocio,
						alPresionarDigito: (d) {
							if (_pinAdminNegocio.length >= LONGITUD_PIN_ADMIN) {
								return;
							}
							setState(() => _pinAdminNegocio = _pinAdminNegocio + d);
						},
						alBorrar: () {
							if (_pinAdminNegocio.isEmpty) {
								return;
							}
							setState(() =>
								_pinAdminNegocio = _pinAdminNegocio.substring(0, _pinAdminNegocio.length - 1),
							);
						},
					),
				],
				if (!widget.reconfiguracion) ...[
					const SizedBox(height: 24.0),
					const Text(
						'PIN técnico del dispositivo',
						style: TextStyle(fontWeight: FontWeight.w600),
					),
					const SizedBox(height: 8.0),
					const Text(
						'Protege el acceso a Configuración técnica desde el login.',
						style: TextStyle(color: Colors.black54, fontSize: 13.0),
					),
					const SizedBox(height: 12.0),
					TecladoPinAdmin(
						pinActual: _pinTecnico,
						alPresionarDigito: (d) {
							if (_pinTecnico.length >= LONGITUD_PIN_ADMIN) {
								return;
							}
							setState(() => _pinTecnico = _pinTecnico + d);
						},
						alBorrar: () {
							if (_pinTecnico.isEmpty) {
								return;
							}
							setState(() => _pinTecnico = _pinTecnico.substring(0, _pinTecnico.length - 1));
						},
					),
					const SizedBox(height: 16.0),
					const Text(
						'Confirma el PIN',
						style: TextStyle(fontWeight: FontWeight.w600),
					),
					const SizedBox(height: 12.0),
					TecladoPinAdmin(
						pinActual: _pinTecnicoConfirmacion,
						alPresionarDigito: (d) {
							if (_pinTecnicoConfirmacion.length >= LONGITUD_PIN_ADMIN) {
								return;
							}
							setState(() => _pinTecnicoConfirmacion = _pinTecnicoConfirmacion + d);
						},
						alBorrar: () {
							if (_pinTecnicoConfirmacion.isEmpty) {
								return;
							}
							setState(() =>
								_pinTecnicoConfirmacion =
									_pinTecnicoConfirmacion.substring(0, _pinTecnicoConfirmacion.length - 1),
							);
						},
					),
				],
				if (_mensaje != null) ...[
					const SizedBox(height: 16.0),
					Text(
						_mensaje!,
						style: TextStyle(
							color: _mensaje!.startsWith('Listo')
								? PosiaColors.cobrar
								: PosiaColors.cancelar,
						),
					),
				],
			],
		);
	}

	Widget _pieAcciones(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				SizedBox(
					height: 52.0,
					child: FilledButton.icon(
						onPressed: _guardando ? null : _finalizarInstalacion,
						icon: _guardando
							? const SizedBox(
								width: 20.0,
								height: 20.0,
								child: CircularProgressIndicator(
									strokeWidth: 2.0,
									color: Colors.white,
								),
							)
							: const Icon(Icons.check_circle_outline),
						label: Text(_guardando ? 'Configurando...' : 'Finalizar instalación'),
					),
				),
				if (widget.reconfiguracion) ...[
					const SizedBox(height: 8.0),
					TextButton(
						onPressed: _guardando ? null : () => Navigator.of(context).pop(),
						child: const Text('Cancelar'),
					),
				],
			],
		);
	}

	Future<void> _finalizarInstalacion() async {
		if (_conectarNube && _hubUrlController.text.trim().isEmpty) {
			setState(() => _mensaje = 'Ingresa la URL del hub o desactiva la nube');
			return;
		}
		if (!widget.reconfiguracion) {
			if (_pinTecnico.length != LONGITUD_PIN_ADMIN) {
				setState(() => _mensaje = 'Define un PIN técnico de $LONGITUD_PIN_ADMIN dígitos');
				return;
			}
			if (_pinTecnico != _pinTecnicoConfirmacion) {
				setState(() => _mensaje = 'Los PIN no coinciden');
				return;
			}
			if (!_conectarNube) {
				if (_nombreNegocioController.text.trim().isEmpty) {
					setState(() => _mensaje = 'Ingresa el nombre del negocio');
					return;
				}
				if (_pinAdminNegocio.length != LONGITUD_PIN_ADMIN) {
					setState(() => _mensaje = 'Define el PIN del administrador ($LONGITUD_PIN_ADMIN dígitos)');
					return;
				}
			}
		}
		setState(() {
			_guardando = true;
			_mensaje = null;
		});
		try {
			final servicio = await ref.read(servicioConfigDispositivoProvider.future);
			final usarHub = await servicio.guardarConexionHub(
				hubUrl: _hubUrlController.text,
				hubApiKey: _hubApiKeyController.text,
				soloOffline: !_conectarNube,
				pinTecnico: widget.reconfiguracion ? '' : _pinTecnico,
				nombreNegocio: _nombreNegocioController.text,
				nombreTienda: _nombreTiendaController.text,
				nombreAdmin: 'Administrador',
				codigoAdmin: _codigoAdminController.text,
				pinAdmin: _pinAdminNegocio,
			);
			ref.invalidate(servicioAutenticacionProvider);
			ref.invalidate(instalacionCompletaProvider);
			ref.invalidate(configDispositivoProvider);
			var mensaje = usarHub
				? 'Listo. El dispositivo quedó configurado.'
				: 'Listo. Modo offline. Inicie sesión con código '
					'${_codigoAdminController.text.trim()} y su PIN.';
			if (usarHub && ref.read(sesionUsuarioProvider) != null) {
				ref.invalidate(contenedorServiciosProvider);
				final servicioAdmin = await ref.read(servicioAdminProvider.future);
				final resultado = await servicioAdmin.sincronizarManual();
				mensaje = resultado.hubDisponible
					? 'Listo. Sync: ${resultado.eventosRecibidos} eventos recibidos.'
					: 'Listo. Hub guardado; la sync se reintentará automáticamente.';
			}
			if (!mounted) {
				return;
			}
			if (widget.reconfiguracion) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(mensaje)),
				);
				Navigator.of(context).pop();
				return;
			}
			ref.invalidate(instalacionCompletaProvider);
		} on Object catch (error) {
			if (!mounted) {
				return;
			}
			setState(() {
				_guardando = false;
				_mensaje = '$error';
			});
		}
	}
}

final _hubInstalacionProvider = FutureProvider<_HubInstalacion>((ref) async {
	final servicio = await ref.watch(servicioConfigDispositivoProvider.future);
	return _HubInstalacion(
		url: await servicio.obtenerHubUrl() ?? '',
		apiKey: await servicio.obtenerHubApiKey(),
	);
});

class _HubInstalacion {
	const _HubInstalacion({required this.url, required this.apiKey});

	final String url;
	final String apiKey;
}

/// Abre el asistente tecnico tras validar el PIN del dispositivo.
Future<void> abrirInstalacionTecnica(
	BuildContext context,
	WidgetRef ref,
) async {
	final pinDispositivo = await ref.read(pinAdminProvider.future);
	if (!context.mounted) {
		return;
	}
	final pinIngresado = await showDialog<String>(
		context: context,
		builder: (ctx) => _DialogoPinTecnico(pinEsperado: pinDispositivo),
	);
	if (pinIngresado == null || !context.mounted) {
		return;
	}
	await Navigator.of(context).push<void>(
		MaterialPageRoute<void>(
			builder: (_) => const PantallaInstalacionTecnico(reconfiguracion: true),
		),
	);
}

class _DialogoPinTecnico extends StatefulWidget {
	const _DialogoPinTecnico({required this.pinEsperado});

	final String pinEsperado;

	@override
	State<_DialogoPinTecnico> createState() => _DialogoPinTecnicoState();
}

class _DialogoPinTecnicoState extends State<_DialogoPinTecnico> {
	var _pin = '';
	String? _error;

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text('PIN técnico'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const Text('Ingresa el PIN de administrador del dispositivo.'),
					const SizedBox(height: 12.0),
					TecladoPinAdmin(
						pinActual: _pin,
						alPresionarDigito: (d) {
							if (_pin.length >= LONGITUD_PIN_ADMIN) {
								return;
							}
							setState(() {
								_pin = _pin + d;
								_error = null;
							});
							if (_pin.length == LONGITUD_PIN_ADMIN) {
								_validar();
							}
						},
						alBorrar: () {
							if (_pin.isEmpty) {
								return;
							}
							setState(() {
								_pin = _pin.substring(0, _pin.length - 1);
								_error = null;
							});
						},
					),
					if (_error != null) ...[
						const SizedBox(height: 8.0),
						Text(_error!, style: const TextStyle(color: PosiaColors.cancelar)),
					],
				],
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(),
					child: const Text('Cancelar'),
				),
			],
		);
	}

	void _validar() {
		if (widget.pinEsperado.isEmpty) {
			setState(() {
				_pin = '';
				_error = 'PIN técnico no configurado. Complete la instalación inicial.';
			});
			return;
		}
		if (_pin == widget.pinEsperado) {
			Navigator.of(context).pop(_pin);
			return;
		}
		setState(() {
			_pin = '';
			_error = 'PIN incorrecto';
		});
	}
}
