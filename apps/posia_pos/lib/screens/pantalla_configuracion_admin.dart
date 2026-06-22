/// Configuracion local del dispositivo POS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaConfiguracionAdmin extends ConsumerStatefulWidget {
	const PantallaConfiguracionAdmin({super.key});

	@override
	ConsumerState<PantallaConfiguracionAdmin> createState() =>
		_PantallaConfiguracionAdminState();
}

	class _PantallaConfiguracionAdminState extends ConsumerState<PantallaConfiguracionAdmin> {
	final _pinController = TextEditingController();
	final _nombreCajaController = TextEditingController();
	final _hostImpresoraController = TextEditingController();
	final _puertoImpresoraController = TextEditingController(text: '9100');
	String? _tiendaSeleccionadaId;
	String _modoImpresora = 'ambos';

	@override
	void dispose() {
		_pinController.dispose();
		_nombreCajaController.dispose();
		_hostImpresoraController.dispose();
		_puertoImpresoraController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final pinAsync = ref.watch(pinAdminProvider);
		final configAsync = ref.watch(configDispositivoProvider);
		final impresoraAsync = ref.watch(configImpresoraProvider);
		final tiendasAsync = ref.watch(_tiendasConfigProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Configuración')),
			body: pinAsync.when(
				data: (pinActual) {
					if (_pinController.text.isEmpty) {
						_pinController.text = pinActual;
					}
					return ListView(
						padding: const EdgeInsets.all(24.0),
						children: [
							const Text(
								'Dispositivo',
								style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							const Text(
								'Define tienda y caja de este equipo. '
								'La conexión a la nube se configura solo en la instalación técnica.',
							),
							const SizedBox(height: 16.0),
							configAsync.when(
								data: (config) {
									return Card(
										child: ListTile(
											leading: const Icon(Icons.badge_outlined),
											title: const Text('Tenant del negocio'),
											subtitle: Text(
												config.tenantId,
												maxLines: 2,
												overflow: TextOverflow.ellipsis,
											),
										),
									);
								},
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							const SizedBox(height: 12.0),
							tiendasAsync.when(
								data: (tiendas) {
									_tiendaSeleccionadaId ??= configAsync.value?.tiendaId;
									return DropdownButtonFormField<String>(
										initialValue: _tiendaSeleccionadaId,
										items: tiendas
											.map(
												(t) => DropdownMenuItem(
													value: t.id,
													child: Text(t.nombre),
												),
											)
											.toList(),
										onChanged: (v) => setState(() => _tiendaSeleccionadaId = v),
										decoration: const InputDecoration(
											labelText: 'Tienda activa',
											border: OutlineInputBorder(),
										),
									);
								},
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							const SizedBox(height: 12.0),
							configAsync.when(
								data: (config) {
									if (_nombreCajaController.text.isEmpty &&
										config.nombreCaja != null) {
										_nombreCajaController.text = config.nombreCaja!;
									}
									return Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											TextField(
												controller: _nombreCajaController,
												decoration: const InputDecoration(
													labelText: 'Nombre de caja (opcional)',
													border: OutlineInputBorder(),
												),
											),
											const SizedBox(height: 8.0),
											Text(
												'ID caja: ${config.cajaId}',
												style: Theme.of(context).textTheme.bodySmall,
											),
										],
									);
								},
								loading: () => const SizedBox(),
								error: (e, _) => Text('$e'),
							),
							const SizedBox(height: 12.0),
							FilledButton(
								onPressed: _guardarDispositivo,
								child: const Text('Guardar dispositivo'),
							),
							const Divider(height: 40.0),
							const Text(
								'Impresora de tickets',
								style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							const Text(
								'Modo archivo guarda en Documents/POSIA/tickets. '
								'Modo red usa ESC/POS por TCP (puerto 9100). '
								'El modo ambos intenta la red y respalda en archivo.',
							),
							const SizedBox(height: 16.0),
							impresoraAsync.when(
								data: (config) {
									if (_hostImpresoraController.text.isEmpty) {
										_hostImpresoraController.text = config.hostRed;
									}
									if (_puertoImpresoraController.text == '9100' &&
										config.puertoRed != 9100) {
										_puertoImpresoraController.text = config.puertoRed.toString();
									}
									_modoImpresora = config.modo;
									return Column(
										children: [
											DropdownButtonFormField<String>(
												key: ValueKey(_modoImpresora),
												initialValue: _modoImpresora,
												items: const [
													DropdownMenuItem(value: 'archivo', child: Text('Solo archivo')),
													DropdownMenuItem(value: 'red', child: Text('Solo red')),
													DropdownMenuItem(value: 'ambos', child: Text('Red + archivo')),
												],
												onChanged: (v) => setState(() => _modoImpresora = v ?? 'ambos'),
												decoration: const InputDecoration(
													labelText: 'Modo de impresión',
													border: OutlineInputBorder(),
												),
											),
											const SizedBox(height: 12.0),
											TextField(
												controller: _hostImpresoraController,
												decoration: const InputDecoration(
													labelText: 'IP o hostname impresora',
													border: OutlineInputBorder(),
												),
											),
											const SizedBox(height: 12.0),
											TextField(
												controller: _puertoImpresoraController,
												keyboardType: TextInputType.number,
												decoration: const InputDecoration(
													labelText: 'Puerto TCP',
													border: OutlineInputBorder(),
												),
											),
										],
									);
								},
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							const SizedBox(height: 12.0),
							FilledButton(
								onPressed: _guardarImpresora,
								child: const Text('Guardar impresora'),
							),
							const Divider(height: 40.0),
							const Text(
								'PIN de administrador',
								style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							const Text('4 dígitos numéricos para acceder al panel Admin.'),
							const SizedBox(height: 16.0),
							TextField(
								controller: _pinController,
								keyboardType: TextInputType.number,
								maxLength: 4,
								obscureText: true,
								decoration: const InputDecoration(
									labelText: 'Nuevo PIN',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 16.0),
							FilledButton(
								onPressed: _guardarPin,
								child: const Text('Guardar PIN'),
							),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _guardarDispositivo() async {
		final tiendaId = _tiendaSeleccionadaId;
		if (tiendaId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Selecciona una tienda')),
			);
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarConfigDispositivo(
			tiendaId: tiendaId,
			nombreCaja: _nombreCajaController.text.trim(),
		);
		ref.invalidate(configDispositivoProvider);
		ref.invalidate(licenciaProvider);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(
				content: Text('Configuración guardada. Reinicia la app si cambiaste de tienda.'),
			),
		);
	}

	Future<void> _guardarImpresora() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarConfigImpresora(
			ConfigImpresora(
				modo: _modoImpresora,
				hostRed: _hostImpresoraController.text.trim(),
				puertoRed: int.tryParse(_puertoImpresoraController.text.trim()) ?? 9100,
			),
		);
		ref.invalidate(configImpresoraProvider);
		ref.invalidate(hardwareRegistryProvider);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Impresora configurada')),
		);
	}

	Future<void> _guardarPin() async {
		final pin = _pinController.text.trim();
		if (pin.length != 4) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('El PIN debe tener 4 dígitos')),
			);
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarPinAdmin(pin);
		ref.invalidate(pinAdminProvider);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('PIN actualizado')),
		);
	}
}

final _tiendasConfigProvider = FutureProvider<List<Tienda>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarTiendasActivas();
});
