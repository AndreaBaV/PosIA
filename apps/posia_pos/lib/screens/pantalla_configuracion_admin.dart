/// Configuracion local del dispositivo POS.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_hardware/posia_hardware.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/imprimir_ticket_digital_util.dart';

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
	bool _abrirCajonAlCobrar = false;
	String _nombreImpresoraUsb = '';
	int _anchoRolloMm = 80;
	bool _impresoraInicializada = false;
	List<ImpresoraWindows>? _impresorasDetectadas;
	bool _cargandoImpresoras = false;
	AtajosCajaConfig _atajosCaja = AtajosCajaConfig.predeterminados();
	var _atajosInicializados = false;

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
		final atajosAsync = ref.watch(atajosCajaConfigProvider);
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
							Text(
								'Modo archivo guarda en Documents/$CARPETA_DOCUMENTOS_APP/tickets. '
								'Modo red usa ESC/POS por TCP (puerto 9100). '
								'Modo USB Windows envía al spooler de Windows (para impresoras conectadas por cable USB). '
								'El modo ambos intenta la red y respalda en archivo.',
							),
							const SizedBox(height: 16.0),
							impresoraAsync.when(
								data: (config) {
									if (!_impresoraInicializada) {
										_hostImpresoraController.text = config.hostRed;
										_puertoImpresoraController.text = config.puertoRed.toString();
										_modoImpresora = config.modo;
										_abrirCajonAlCobrar = config.abrirCajonAlCobrar;
										_nombreImpresoraUsb = config.nombreImpresoraUsb;
										_anchoRolloMm = config.anchoRolloMm;
										_impresoraInicializada = true;
									}
									return Column(
										children: [
											DropdownButtonFormField<String>(
												key: ValueKey(_modoImpresora),
												initialValue: _modoImpresora,
												items: const [
													DropdownMenuItem(value: 'archivo', child: Text('Solo archivo')),
													DropdownMenuItem(value: 'red', child: Text('Solo red')),
													DropdownMenuItem(value: 'ambos', child: Text('Red + archivo')),
													DropdownMenuItem(
														value: 'usb_windows',
														child: Text('USB Windows (impresora local)'),
													),
												],
												onChanged: (v) => setState(() {
													_modoImpresora = v ?? 'ambos';
													if (_modoImpresora == 'usb_windows' &&
														_impresorasDetectadas == null) {
														_refrescarImpresorasWindows();
													}
												}),
												decoration: const InputDecoration(
													labelText: 'Modo de impresión',
													border: OutlineInputBorder(),
												),
											),
											const SizedBox(height: 12.0),
											if (_modoImpresora == 'usb_windows') ...[
												_seccionImpresoraUsbWindows(),
											] else ...[
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
											const SizedBox(height: 12.0),
											SwitchListTile(
												title: const Text('Abrir cajón al cobrar'),
												subtitle: Text(
													_modoImpresora == 'usb_windows'
														? 'Envía el pulso ESC p 0 25 250 a la impresora seleccionada (cajón por RJ11/RJ12)'
														: 'Requiere impresora térmica con cajón conectado (modo red)',
												),
												value: _abrirCajonAlCobrar,
												onChanged: (v) => setState(
													() => _abrirCajonAlCobrar = v,
												),
											),
										],
									);
								},
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							const SizedBox(height: 12.0),
							Row(
								children: [
									Expanded(
										child: FilledButton(
											onPressed: _guardarImpresora,
											child: const Text('Guardar impresora'),
										),
									),
									const SizedBox(width: 12.0),
									Expanded(
										child: OutlinedButton.icon(
											onPressed: _probarImpresoraYCajon,
											icon: const Icon(Icons.print),
											label: const Text('Probar impresora + cajón'),
										),
									),
								],
							),
							const Divider(height: 40.0),
							const Text(
								'Atajos de caja',
								style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							const Text(
								'Combinaciones de teclado en la pantalla de venta. '
								'F12 suele estar bloqueada en Windows; prueba F2, ESCAPE o CTRL+ENTER.',
							),
							const SizedBox(height: 16.0),
							atajosAsync.when(
								data: (atajos) {
									if (!_atajosInicializados) {
										_atajosCaja = atajos;
										_atajosInicializados = true;
									}
									return Column(
										children: [
											for (final def in definicionesAtajosCaja) ...[
												Align(
													alignment: Alignment.centerLeft,
													child: Text(
														def.etiqueta,
														style: const TextStyle(fontWeight: FontWeight.w600),
													),
												),
												const SizedBox(height: 4.0),
												Text(
													def.descripcion,
													style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0),
												),
												const SizedBox(height: 8.0),
												CampoAtajoTeclado(
													valor: _atajosCaja.atajo(def.id),
													alCambiar: (nuevo) {
														setState(() {
															final valor = nuevo.trim().isEmpty
																? def.valorPredeterminado
																: nuevo;
															_atajosCaja = _atajosCaja.conAtajo(def.id, valor);
														});
													},
												),
												const SizedBox(height: 16.0),
											],
										],
									);
								},
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							const SizedBox(height: 8.0),
							OutlinedButton.icon(
								onPressed: () {
									setState(() {
										_atajosCaja = AtajosCajaConfig.predeterminados();
									});
								},
								icon: const Icon(Icons.restore),
								label: const Text('Restaurar atajos predeterminados'),
							),
							const SizedBox(height: 12.0),
							FilledButton(
								onPressed: _guardarAtajosCaja,
								child: const Text('Guardar atajos de caja'),
							),
							const Divider(height: 40.0),
							const Text(
								'PIN de administrador',
								style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							const Text('4 dígitos numéricos para acceder al panel Admin.'),
							const SizedBox(height: 16.0),
							CampoSecreto(
								controller: _pinController,
								keyboardType: TextInputType.number,
								maxLength: 4,
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
			PosiaNotificaciones.mostrarSnackBar(context, 
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
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(
				content: Text('Configuración guardada. Reinicia la app si cambiaste de tienda.'),
			),
		);
	}

	String _etiquetaImpresoraWindows(ImpresoraWindows imp) =>
		'${imp.nombre}  ·  ${imp.puerto}';

	Widget _seccionImpresoraUsbWindows() {
		if (!Platform.isWindows) {
			return Container(
				padding: const EdgeInsets.all(12.0),
				decoration: BoxDecoration(
					color: Colors.orange.shade50,
					border: Border.all(color: Colors.orange),
					borderRadius: BorderRadius.circular(4.0),
				),
				child: const Text(
					'El modo USB Windows solo funciona cuando la aplicación corre '
					'en Windows. En este dispositivo no está disponible.',
				),
			);
		}
		final impresoras = _impresorasDetectadas;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					children: [
						Expanded(
							child: _cargandoImpresoras
								? const LinearProgressIndicator()
								: DropdownButtonFormField<String>(
									key: ValueKey('usb_${impresoras?.length ?? 0}_$_nombreImpresoraUsb'),
									initialValue: _nombreImpresoraUsb.isEmpty ? null : _nombreImpresoraUsb,
									isExpanded: true,
									selectedItemBuilder: (context) => (impresoras ?? [])
										.map(
											(imp) => Align(
												alignment: AlignmentDirectional.centerStart,
												child: Text(
													_etiquetaImpresoraWindows(imp),
													overflow: TextOverflow.ellipsis,
													maxLines: 1,
												),
											),
										)
										.toList(),
									items: (impresoras ?? [])
										.map(
											(imp) => DropdownMenuItem<String>(
												value: imp.nombre,
												child: Text(
													_etiquetaImpresoraWindows(imp),
													overflow: TextOverflow.ellipsis,
												),
											),
										)
										.toList(),
									onChanged: (v) => setState(() => _nombreImpresoraUsb = v ?? ''),
									decoration: const InputDecoration(
										labelText: 'Impresora USB detectada en Windows',
										border: OutlineInputBorder(),
									),
								),
						),
						const SizedBox(width: 8.0),
						IconButton(
							tooltip: 'Volver a buscar impresoras',
							onPressed: _cargandoImpresoras ? null : _refrescarImpresorasWindows,
							icon: const Icon(Icons.refresh),
						),
					],
				),
				const SizedBox(height: 8.0),
				if (impresoras != null && impresoras.isEmpty)
					const Text(
						'Windows no reportó impresoras. Verifica que el equipo la '
						'reconozca en "Dispositivos e impresoras" y presiona el botón '
						'de recarga.',
						style: TextStyle(color: Colors.orange),
					),
				const SizedBox(height: 12.0),
				DropdownButtonFormField<int>(
					key: ValueKey('ancho_$_anchoRolloMm'),
					initialValue: _anchoRolloMm,
					items: const [
						DropdownMenuItem(value: 80, child: Text('80 mm (48 columnas)')),
						DropdownMenuItem(value: 58, child: Text('58 mm (32 columnas)')),
					],
					onChanged: (v) => setState(() => _anchoRolloMm = v ?? 80),
					decoration: const InputDecoration(
						labelText: 'Ancho del rollo térmico',
						border: OutlineInputBorder(),
					),
				),
			],
		);
	}

	Future<void> _refrescarImpresorasWindows() async {
		if (!Platform.isWindows) {
			return;
		}
		setState(() => _cargandoImpresoras = true);
		try {
			final lista = enumerarImpresorasWindows();
			if (!mounted) return;
			setState(() {
				_impresorasDetectadas = lista;
				if (_nombreImpresoraUsb.isEmpty && lista.isNotEmpty) {
					final usb = lista.firstWhere(
						(i) => i.esUsb,
						orElse: () => lista.first,
					);
					_nombreImpresoraUsb = usb.nombre;
				}
			});
		} finally {
			if (mounted) {
				setState(() => _cargandoImpresoras = false);
			}
		}
	}

	Future<void> _guardarImpresora() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarConfigImpresora(
			ConfigImpresora(
				modo: _modoImpresora,
				hostRed: _hostImpresoraController.text.trim(),
				puertoRed: int.tryParse(_puertoImpresoraController.text.trim()) ?? 9100,
				abrirCajonAlCobrar: _abrirCajonAlCobrar,
				nombreImpresoraUsb: _nombreImpresoraUsb.trim(),
				anchoRolloMm: _anchoRolloMm,
			),
		);
		ref.invalidate(configImpresoraProvider);
		ref.invalidate(hardwareRegistryProvider);
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('Impresora configurada')),
		);
	}

	Future<void> _probarImpresoraYCajon() async {
		try {
			await _guardarImpresora();
			final registro = await ref.read(hardwareRegistryProvider.future);
			final impresora = registro.obtenerImpresora();
			final servicio = await ref.read(servicioAdminProvider.future);
			final tienda = await servicio.obtenerTiendaActiva();
			final ticketPrueba = construirTicketDigitalPrueba(
				nombreTienda: tienda?.nombre ?? 'Tienda de prueba',
				nombreImpresoraUsb: _nombreImpresoraUsb,
				anchoRolloMm: _anchoRolloMm,
			);
			await imprimirTicketDigital(
				impresora: impresora,
				contenido: ticketPrueba,
			);
			final cajon = registro.obtenerCajon();
			if (cajon != null) {
				await cajon.abrir();
			}
			if (!mounted) return;
			PosiaNotificaciones.mostrarSnackBar(
				context,
				SnackBar(
					content: Text(
						cajon != null
							? 'Ticket de prueba enviado y cajón abierto.'
							: 'Ticket de prueba enviado (cajón no configurado).',
					),
				),
			);
		} catch (e) {
			if (!mounted) return;
			PosiaNotificaciones.mostrarSnackBar(
				context,
				SnackBar(content: Text('Falló la prueba: $e')),
			);
		}
	}

	Future<void> _guardarAtajosCaja() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarAtajosCajaJson(_atajosCaja.aJson());
		ref.invalidate(atajosCajaConfigProvider);
		ref.invalidate(teclaCobrarConfigProvider);
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('Atajos de caja guardados')),
		);
	}

	Future<void> _guardarPin() async {
		final pin = _pinController.text.trim();
		if (pin.length != 4) {
			PosiaNotificaciones.mostrarSnackBar(context, 
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
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('PIN actualizado')),
		);
	}
}

final _tiendasConfigProvider = FutureProvider<List<Tienda>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarTiendasActivas();
});
