/// Caja minimalista movil centrada en comandos de voz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:posia_voice/posia_voice.dart';

import '../providers/app_providers.dart';
import '../voz/servicio_voz_dispositivo.dart';
import 'pantalla_caja.dart'
	show
		confirmarVaciarCarritoCaja,
		ejecutarCobroCaja,
		ejecutarCotizacionCaja,
		ejecutarPonerEnEspera,
		mostrarTicketsEnEspera;

class PantallaCajaMovil extends ConsumerStatefulWidget {
	const PantallaCajaMovil({super.key});

	@override
	ConsumerState<PantallaCajaMovil> createState() => _PantallaCajaMovilState();
}

class _PantallaCajaMovilState extends ConsumerState<PantallaCajaMovil> {
	final _motorVoz = MotorComandosVoz();
	final _servicioVoz = ServicioVozDispositivo();
	final _textoManualController = TextEditingController();
	final _mensajes = <String>[];

	bool _escuchando = false;
	bool _vozLista = false;
	String _transcripcion = '';
	String? _errorVoz;

	@override
	void initState() {
		super.initState();
		_prepararVoz();
	}

	@override
	void dispose() {
		_servicioVoz.detener();
		_textoManualController.dispose();
		super.dispose();
	}

	Future<void> _prepararVoz() async {
		final permiso = await Permission.microphone.request();
		if (!permiso.isGranted && mounted) {
			setState(() {
				_vozLista = false;
				_errorVoz = 'Permiso de microfono denegado';
			});
			return;
		}
		final ok = await _servicioVoz.inicializar();
		if (mounted) {
			setState(() {
				_vozLista = ok;
				_errorVoz = ok ? null : (_servicioVoz.ultimoError ?? 'Voz no disponible');
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		final estado = ref.watch(carritoNotifierProvider);
		final datos = estado.value;
		return Scaffold(
			appBar: AppBar(
				title: datos != null
					? Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Text('POSIA', style: TextStyle(fontSize: 14.0)),
							Text(datos.nombreTienda, style: const TextStyle(fontSize: 18.0)),
						],
					)
					: estado.when(
						data: (s) => Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const Text('POSIA', style: TextStyle(fontSize: 14.0)),
								Text(s.nombreTienda, style: const TextStyle(fontSize: 18.0)),
							],
						),
						loading: () => const Text('POSIA'),
						error: (_, _) => const Text('POSIA'),
					),
				actions: [
					if (datos != null)
						Padding(
							padding: const EdgeInsets.only(right: 12.0),
							child: Center(
								child: Icon(
									datos.turnoAbierto ? Icons.lock_open : Icons.lock,
									color: datos.turnoAbierto ? PosiaColors.cobrar : PosiaColors.cancelar,
								),
							),
						)
					else
						estado.when(
							data: (s) => Padding(
								padding: const EdgeInsets.only(right: 12.0),
								child: Center(
									child: Icon(
										s.turnoAbierto ? Icons.lock_open : Icons.lock,
										color: s.turnoAbierto ? PosiaColors.cobrar : PosiaColors.cancelar,
									),
								),
							),
							loading: () => const SizedBox(),
							error: (_, _) => const SizedBox(),
						),
				],
			),
			body: datos != null
				? _construirCuerpo(context, datos)
				: estado.when(
					data: (s) => _construirCuerpo(context, s),
					loading: () => const Center(child: CircularProgressIndicator()),
					error: (e, _) => Center(child: Text('$e')),
				),
		);
	}

	Widget _construirCuerpo(BuildContext context, EstadoCarrito estado) {
		return Column(
			children: [
				Expanded(
					child: ListView(
						padding: const EdgeInsets.all(16.0),
						children: [
							if (!estado.turnoAbierto)
								Card(
									color: PosiaColors.cancelar.withValues(alpha: 0.12),
									child: const ListTile(
										leading: Icon(Icons.warning_amber),
										title: Text('Abre turno en Admin → Corte de caja'),
									),
								),
							Text(
								'Habla o escribe tu venta',
								style: Theme.of(context).textTheme.titleMedium,
							),
							const SizedBox(height: 8.0),
							Text(
								'Ejemplo: "Genera el ticket: vendí un kilogramo de arroz, '
								'medio kilo de frijol peruano y 1 caja de leche"',
								style: Theme.of(context).textTheme.bodySmall,
							),
							const SizedBox(height: 12.0),
							if (_transcripcion.isNotEmpty)
								Card(
									child: Padding(
										padding: const EdgeInsets.all(12.0),
										child: Text(_transcripcion),
									),
								),
							const SizedBox(height: 8.0),
							TextField(
								controller: _textoManualController,
								maxLines: 2,
								decoration: const InputDecoration(
									labelText: 'Comando manual',
									border: OutlineInputBorder(),
									hintText: 'Genera el ticket: ...',
								),
							),
							const SizedBox(height: 8.0),
							FilledButton.icon(
								onPressed: () => _procesarTexto(_textoManualController.text),
								icon: const Icon(Icons.send),
								label: const Text('Procesar texto'),
							),
							const Divider(height: 24.0),
							Text('Carrito', style: Theme.of(context).textTheme.titleMedium),
							if (estado.lineas.isEmpty)
								const Padding(
									padding: EdgeInsets.symmetric(vertical: 12.0),
									child: Text('Sin productos'),
								)
							else
								...estado.lineas.map(
									(l) => ListTile(
										dense: true,
										title: Text(l.producto.nombre),
										trailing: Text(
											'${l.cantidad} · ${formatearMoneda(l.calcularSubtotal())}',
										),
									),
								),
							if (_mensajes.isNotEmpty) ...[
								const Divider(),
								..._mensajes.map((m) => Text('· $m', style: const TextStyle(fontSize: 13.0))),
							],
						],
					),
				),
				Container(
					padding: const EdgeInsets.all(16.0),
					decoration: BoxDecoration(
						color: Theme.of(context).colorScheme.surfaceContainerHighest,
						boxShadow: const [BoxShadow(blurRadius: 4.0, offset: Offset(0, -2))],
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								formatearMoneda(estado.total),
								style: Theme.of(context).textTheme.headlineMedium,
							),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceEvenly,
								children: [
									IconButton.filledTonal(
										tooltip: 'Poner en espera',
										onPressed: estado.lineas.isNotEmpty
											? () => ejecutarPonerEnEspera(context, ref)
											: null,
										icon: const Icon(Icons.pause_circle_outline),
									),
									Badge(
										isLabelVisible: estado.ticketsEnEspera > 0,
										label: Text('${estado.ticketsEnEspera}'),
										child: IconButton.filledTonal(
											tooltip: 'Recuperar ticket',
											onPressed: estado.ticketsEnEspera > 0
												? () => mostrarTicketsEnEspera(context, ref)
												: null,
											icon: const Icon(Icons.playlist_play),
										),
									),
									IconButton.filledTonal(
										tooltip: 'Cotización',
										onPressed: estado.lineas.isNotEmpty
											? () => ejecutarCotizacionCaja(context, ref)
											: null,
										icon: const Icon(Icons.request_quote),
									),
									IconButton.filledTonal(
										tooltip: 'Vaciar carrito',
										onPressed: estado.lineas.isNotEmpty
											? () => confirmarVaciarCarritoCaja(context, ref)
											: null,
										icon: const Icon(Icons.delete_sweep),
									),
								],
							),
							const SizedBox(height: 8.0),
							Row(
								children: [
									Expanded(
										child: FilledButton.icon(
											onPressed: _vozLista ? _alternarEscucha : null,
											style: FilledButton.styleFrom(
												backgroundColor:
													_escuchando ? PosiaColors.cancelar : PosiaColors.cobrar,
												minimumSize: const Size(0, 56.0),
											),
											icon: Icon(_escuchando ? Icons.stop : Icons.mic),
											label: Text(_escuchando ? 'Detener' : 'Hablar'),
										),
									),
									const SizedBox(width: 12.0),
									Expanded(
										child: FilledButton(
											onPressed: estado.turnoAbierto && estado.lineas.isNotEmpty
												? () => ejecutarCobroCaja(context, ref)
												: null,
											style: FilledButton.styleFrom(minimumSize: const Size(0, 56.0)),
											child: const Text('COBRAR'),
										),
									),
								],
							),
							if (!_vozLista)
								Padding(
									padding: const EdgeInsets.only(top: 8.0),
									child: Text(
										_errorVoz ?? 'Microfono no disponible. Usa texto manual.',
										style: const TextStyle(fontSize: 12.0, color: PosiaColors.cancelar),
										textAlign: TextAlign.center,
									),
								),
						],
					),
				),
			],
		);
	}

	Future<void> _alternarEscucha() async {
		if (_escuchando) {
			await _servicioVoz.detener();
			setState(() => _escuchando = false);
			return;
		}
		setState(() {
			_escuchando = true;
			_transcripcion = '';
		});
		await _servicioVoz.escuchar(
			onTranscripcion: (texto, esFinal) {
				if (!mounted) {
					return;
				}
				setState(() => _transcripcion = texto);
				if (esFinal && texto.trim().isNotEmpty) {
					_procesarTexto(texto);
				}
			},
		);
	}

	Future<List<Producto>> _expandirCatalogo(ServicioCaja servicio) async {
		final catalogo = await servicio.listarProductos();
		final expandido = <Producto>[];
		for (final producto in catalogo) {
			expandido.add(producto);
			final variantes = await servicio.listarVariantesActivas(producto.id);
			for (final variante in variantes) {
				expandido.add(
					producto.copiarCon(
						id: variante.id,
						nombre: '${producto.nombre} ${variante.nombre}',
						codigoBarras: variante.codigoBarras,
						precioBase: variante.precioBase,
					),
				);
			}
		}
		return expandido;
	}

	Future<String> _agregarLineaVoz(ServicioCaja servicio, LineaVozResuelta linea) async {
		if (linea.usarPeso) {
			return servicio.agregarProductoConPeso(linea.producto, linea.cantidad);
		}
		if (linea.producto.requiereLote()) {
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			final farmacia = servicio.obtenerServicioFarmacia();
			if (farmacia == null) {
				return 'Modulo farmacia no activo';
			}
			final lotes = await farmacia.listarLotesParaVenta(
				linea.producto.id,
				contenedor.servicioAdmin.tiendaActivaId,
			);
			if (lotes.isEmpty) {
				return 'Sin lotes para ${linea.producto.nombre}';
			}
			return servicio.agregarProductoConLote(
				linea.producto,
				lotes.first,
				linea.cantidad,
			);
		}
		await servicio.agregarProducto(linea.producto, cantidad: linea.cantidad);
		return '';
	}

	Future<void> _procesarTexto(String texto) async {
		final limpio = texto.trim();
		if (limpio.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		final catalogo = await _expandirCatalogo(servicio);
		final resultado = _motorVoz.procesar(texto: limpio, catalogo: catalogo);
		final mensajes = <String>[];

		if (resultado.intencion == IntencionComandoVoz.cobrar) {
			if (!mounted) {
				return;
			}
			await ejecutarCobroCaja(context, ref);
			return;
		}
		if (resultado.intencion == IntencionComandoVoz.vaciarCarrito) {
			servicio.vaciarCarrito();
			mensajes.add('Carrito vaciado');
		} else if (resultado.intencion == IntencionComandoVoz.agregarProductos) {
			for (final linea in resultado.lineas) {
				final error = await _agregarLineaVoz(servicio, linea);
				if (error.isNotEmpty) {
					mensajes.add(error);
				} else {
					mensajes.add(linea.descripcion);
				}
			}
			for (final nombre in resultado.noEncontrados) {
				mensajes.add('No encontrado: $nombre');
			}
			if (resultado.lineas.isEmpty && resultado.noEncontrados.isEmpty) {
				mensajes.add('No entendi productos en el comando');
			}
		} else {
			mensajes.add('Comando no reconocido');
		}

		await ref.read(carritoNotifierProvider.notifier).recargar();
		if (_escuchando) {
			await _servicioVoz.detener();
		}
		if (!mounted) {
			return;
		}
		setState(() {
			_escuchando = false;
			_mensajes
				..clear()
				..addAll(mensajes);
			_textoManualController.clear();
		});
	}

}
