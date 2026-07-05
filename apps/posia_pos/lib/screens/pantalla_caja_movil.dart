/// Caja movil con catalogo tactil, categorias y carrito deslizable.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:posia_voice/posia_voice.dart';

import '../providers/app_providers.dart';
import '../util/teclado_util.dart';
import '../utils/existencias_caja_util.dart';
import '../voz/servicio_voz_dispositivo.dart';
import '../widgets/resolucion_lineas_voz.dart';
import '../widgets/selector_cliente_caja.dart';
import 'pantalla_caja.dart'
	show
		confirmarVaciarCarritoCaja,
		ejecutarCobroCaja,
		ejecutarCotizacionCaja,
		ejecutarPonerEnEspera,
		intentarSeleccionarEmpaqueEnCaja,
		mostrarTicketsEnEspera,
		seleccionarProductoEnCaja;

/// Pantalla de venta optimizada para telefonos y tablets.
class PantallaCajaMovil extends ConsumerStatefulWidget {
	const PantallaCajaMovil({
		this.alAbrirMiCuenta,
		this.alCerrarSesion,
		super.key,
	});

	final VoidCallback? alAbrirMiCuenta;
	final VoidCallback? alCerrarSesion;

	@override
	ConsumerState<PantallaCajaMovil> createState() => _PantallaCajaMovilState();
}

class _PantallaCajaMovilState extends ConsumerState<PantallaCajaMovil> {
	final _motorVoz = MotorComandosVoz();
	final _servicioVoz = ServicioVozDispositivo();
	final _busquedaController = TextEditingController();
	final _busquedaFocus = FocusNode();

	bool _escuchando = false;
	bool _procesandoVoz = false;
	bool _vozInicializada = false;
	bool _ocultarAvisoTurno = false;
	String _transcripcionVoz = '';
	bool _finalizandoVoz = false;
	List<Producto>? _catalogoVozCache;

	@override
	void dispose() {
		_servicioVoz.detener();
		_busquedaController.dispose();
		_busquedaFocus.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final estadoCarrito = ref.watch(carritoNotifierProvider);
		return estadoCarrito.when(
			data: (estado) => _construirScaffold(context, estado),
			loading: () => const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			),
			error: (error, _) => Scaffold(
				body: Center(child: Text('$error')),
			),
		);
	}

	Widget _construirScaffold(BuildContext context, EstadoCarrito estado) {
		final size = MediaQuery.sizeOf(context);
		final esHorizontal = size.width > size.height && size.width >= 560;
		final columnasGrilla = _resolverColumnasGrilla(size, esHorizontal);
		return Scaffold(
			backgroundColor: PosiaColors.fondo,
			resizeToAvoidBottomInset: true,
			appBar: AppBar(
				title: Text(
					estado.nombreTienda,
					style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600),
				),
				centerTitle: false,
				actions: [
					Icon(
						estado.turnoAbierto ? Icons.lock_open : Icons.lock_outline,
						color: estado.turnoAbierto ? PosiaColors.cobrar : PosiaColors.cancelar,
					),
					const SizedBox(width: 4.0),
					if (widget.alCerrarSesion != null)
						PopupMenuButton<String>(
							icon: const Icon(Icons.account_circle_outlined),
							tooltip: 'Cuenta',
							onSelected: (valor) {
								switch (valor) {
									case 'cuenta':
										widget.alAbrirMiCuenta?.call();
									case 'salir':
										widget.alCerrarSesion?.call();
								}
							},
							itemBuilder: (context) => [
								if (widget.alAbrirMiCuenta != null)
									const PopupMenuItem(
										value: 'cuenta',
										child: ListTile(
											leading: Icon(Icons.account_circle_outlined),
											title: Text('Mi cuenta'),
											contentPadding: EdgeInsets.zero,
											dense: true,
										),
									),
								const PopupMenuItem(
									value: 'salir',
									child: ListTile(
										leading: Icon(Icons.logout, color: PosiaColors.cancelar),
										title: Text('Cerrar sesión'),
										contentPadding: EdgeInsets.zero,
										dense: true,
									),
								),
							],
						),
					const SizedBox(width: 8.0),
				],
			),
			body: Stack(
				children: [
					GestureDetector(
						onTap: () => ocultarTeclado(context),
						child: esHorizontal
							? _layoutHorizontal(context, estado, columnasGrilla)
							: _layoutVertical(context, estado, columnasGrilla),
					),
					if (_escuchando || _procesandoVoz)
						_overlayVoz(context),
				],
			),
			bottomNavigationBar: esHorizontal
				? null
				: _BarraInferiorCajaMovil(
					estado: estado,
					escuchando: _escuchando,
					alAbrirCarrito: () => _mostrarHojaCarrito(context, estado),
					alCobrar: estado.turnoAbierto && estado.lineas.isNotEmpty
						? () => ejecutarCobroCaja(context, ref)
						: null,
					alAlternarVoz: _alternarEscucha,
				),
		);
	}

	int _resolverColumnasGrilla(Size size, bool esHorizontal) {
		if (esHorizontal) {
			if (size.width >= 1000) {
				return 4;
			}
			return 3;
		}
		if (size.width < 380) {
			return 2;
		}
		return 3;
	}

	Widget _avisoTurnoCerrado(EstadoCarrito estado) {
		if (estado.turnoAbierto || _ocultarAvisoTurno) {
			return const SizedBox.shrink();
		}
		return Padding(
			padding: const EdgeInsets.fromLTRB(12.0, 4.0, 4.0, 0.0),
			child: Row(
				children: [
					Icon(Icons.lock_outline, size: 16.0, color: Colors.orange.shade800),
					const SizedBox(width: 6.0),
					Expanded(
						child: Text(
							'Turno cerrado',
							style: TextStyle(
								fontSize: 12.0,
								fontWeight: FontWeight.w600,
								color: Colors.orange.shade900,
							),
						),
					),
					IconButton(
						icon: const Icon(Icons.close, size: 18.0),
						tooltip: 'Ocultar aviso',
						padding: EdgeInsets.zero,
						constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
						onPressed: () => setState(() => _ocultarAvisoTurno = true),
					),
				],
			),
		);
	}

	Widget _barraBusquedaYCategorias(EstadoCarrito estado) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				_avisoTurnoCerrado(estado),
				Padding(
					padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 0.0),
					child: Material(
						color: PosiaColors.tarjeta,
						borderRadius: BorderRadius.circular(12.0),
						child: InkWell(
							borderRadius: BorderRadius.circular(12.0),
							onTap: () => mostrarSelectorClienteCaja(context, ref),
							child: Padding(
								padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
								child: Row(
									children: [
										Icon(
											estado.nombreCliente != null
												? Icons.person
												: Icons.storefront_outlined,
											size: 20.0,
											color: estado.nombreCliente != null
												? PosiaColors.cobrar
												: Colors.grey.shade600,
										),
										const SizedBox(width: 8.0),
										Expanded(
											child: Text(
												estado.nombreCliente ?? 'Mostrador · toque para cliente',
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
												style: TextStyle(
													fontWeight: estado.nombreCliente != null
														? FontWeight.w600
														: FontWeight.normal,
													color: estado.nombreCliente != null
														? null
														: Colors.grey.shade700,
												),
											),
										),
										const Icon(Icons.chevron_right, size: 20.0),
									],
								),
							),
						),
					),
				),
				const SizedBox(height: 6.0),
				if (estado.categorias.isNotEmpty)
					BarraCategorias(
						categorias: estado.categorias,
						categoriaSeleccionadaId: estado.categoriaSeleccionadaId,
						alSeleccionar: (id) {
							ref.read(carritoNotifierProvider.notifier).seleccionarCategoria(id);
						},
					),
				CampoBusquedaCaja(
					controlador: _busquedaController,
					focusNode: _busquedaFocus,
					autofocus: false,
					mostrarIconoEscaneo: false,
					hintText: 'Buscar…',
					alCambiar: (texto) =>
						ref.read(carritoNotifierProvider.notifier).establecerBusqueda(texto),
					alEnviar: _procesarEntradaBusqueda,
				),
			],
		);
	}

	Widget _grillaProductos(BuildContext context, EstadoCarrito estado, int columnas) {
		return GrillaProductos(
			columnas: columnas,
			categoriaId: estado.categoriaSeleccionadaId,
			productos: estado.productos,
			stockLocalPorProducto: estado.stockLocalPorProducto,
			mensajeVacio: _busquedaController.text.trim().isNotEmpty
				? 'Sin resultados'
				: 'Sin productos',
			alVerExistencias: (producto) =>
				mostrarExistenciasProductoEnCaja(context, ref, producto),
			alPresionarLargo: (producto) =>
				intentarSeleccionarEmpaqueEnCaja(context, ref, producto),
			alSeleccionar: (producto) async {
				ocultarTeclado(context);
				final agregado = await seleccionarProductoEnCaja(context, ref, producto);
				if (agregado && mounted) {
					_busquedaController.clear();
					ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
				}
			},
		);
	}

	Widget _layoutVertical(BuildContext context, EstadoCarrito estado, int columnas) {
		return Column(
			children: [
				_barraBusquedaYCategorias(estado),
				Expanded(child: _grillaProductos(context, estado, columnas)),
			],
		);
	}

	Widget _layoutHorizontal(BuildContext context, EstadoCarrito estado, int columnas) {
		return Row(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Expanded(
					flex: 3,
					child: Column(
						children: [
							_barraBusquedaYCategorias(estado),
							Expanded(child: _grillaProductos(context, estado, columnas)),
						],
					),
				),
				const VerticalDivider(width: 1.0),
				Expanded(
					flex: 2,
					child: Column(
						children: [
							Expanded(
								child: PanelCarrito(
									lineas: estado.lineas,
									total: estado.total,
									alEliminarLinea: (indice) {
										ref.read(carritoNotifierProvider.notifier).eliminarLinea(indice);
									},
								),
							),
							_BarraInferiorCajaMovil(
								estado: estado,
								escuchando: _escuchando,
								alAbrirCarrito: () => _mostrarHojaCarrito(context, estado),
								alCobrar: estado.turnoAbierto && estado.lineas.isNotEmpty
									? () => ejecutarCobroCaja(context, ref)
									: null,
								alAlternarVoz: _alternarEscucha,
								compacta: true,
							),
						],
					),
				),
			],
		);
	}

	Future<void> _procesarEntradaBusqueda(String texto) async {
		final agregado = await _intentarAgregarCodigo(texto);
		if (agregado) {
			return;
		}
		final estado = ref.read(carritoNotifierProvider).value;
		final productos = estado?.productos ?? [];
		if (!mounted || productos.isEmpty) {
			if (texto.trim().isNotEmpty && mounted) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					const SnackBar(
						content: Text('Sin resultados'),
						backgroundColor: PosiaColors.cancelar,
						duration: Duration(seconds: 2),
					),
				);
			}
			return;
		}
		final agregadoProducto = await seleccionarProductoEnCaja(context, ref, productos.first);
		if (agregadoProducto) {
			_busquedaController.clear();
			ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
		}
	}

	Future<bool> _intentarAgregarCodigo(String codigo) async {
		final normalizado = codigo.trim();
		if (normalizado.isEmpty) {
			return false;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		final agregado = await servicio.agregarPorCodigoBarras(normalizado);
		if (agregado) {
			_busquedaController.clear();
			ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
			await ref.read(carritoNotifierProvider.notifier).recargar();
			return true;
		}
		return false;
	}

	Future<void> _mostrarHojaCarrito(BuildContext context, EstadoCarrito estado) {
		return showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			showDragHandle: true,
			builder: (sheetContext) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: estado.lineas.isEmpty ? 0.35 : 0.55,
				minChildSize: 0.3,
				maxChildSize: 0.9,
				builder: (_, scrollController) => Consumer(
					builder: (context, ref, _) {
						final estadoActual = ref.watch(carritoNotifierProvider).value ?? estado;
						return Column(
							children: [
								Expanded(
									child: PanelCarrito(
										lineas: estadoActual.lineas,
										total: estadoActual.total,
										alEliminarLinea: (indice) {
											ref.read(carritoNotifierProvider.notifier).eliminarLinea(indice);
										},
									),
								),
								Padding(
									padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceEvenly,
												children: [
													IconButton.filledTonal(
														tooltip: 'Cliente',
														onPressed: () {
															Navigator.pop(sheetContext);
															mostrarSelectorClienteCaja(context, ref);
														},
														icon: const Icon(Icons.person_outline),
													),
													IconButton.filledTonal(
														tooltip: 'Poner en espera',
														onPressed: estadoActual.lineas.isNotEmpty
															? () {
																Navigator.pop(sheetContext);
																ejecutarPonerEnEspera(context, ref);
															}
															: null,
														icon: const Icon(Icons.pause_circle_outline),
													),
													Badge(
														isLabelVisible: estadoActual.ticketsEnEspera > 0,
														label: Text('${estadoActual.ticketsEnEspera}'),
														child: IconButton.filledTonal(
															tooltip: 'Recuperar ticket',
															onPressed: estadoActual.ticketsEnEspera > 0
																? () {
																	Navigator.pop(sheetContext);
																	mostrarTicketsEnEspera(context, ref);
																}
																: null,
															icon: const Icon(Icons.playlist_play),
														),
													),
													IconButton.filledTonal(
														tooltip: 'Cotización',
														onPressed: estadoActual.lineas.isNotEmpty
															? () {
																Navigator.pop(sheetContext);
																ejecutarCotizacionCaja(context, ref);
															}
															: null,
														icon: const Icon(Icons.request_quote),
													),
													IconButton.filledTonal(
														tooltip: 'Vaciar carrito',
														onPressed: estadoActual.lineas.isNotEmpty
															? () {
																Navigator.pop(sheetContext);
																confirmarVaciarCarritoCaja(context, ref);
															}
															: null,
														icon: const Icon(Icons.delete_sweep),
													),
												],
											),
											const SizedBox(height: 8.0),
											SizedBox(
												width: double.infinity,
												height: 48.0,
												child: FilledButton(
													onPressed: estadoActual.turnoAbierto &&
															estadoActual.lineas.isNotEmpty
														? () {
															Navigator.pop(sheetContext);
															ejecutarCobroCaja(context, ref);
														}
														: null,
													child: Text(
														'COBRAR ${formatearMoneda(estadoActual.total)}',
													),
												),
											),
										],
									),
								),
							],
						);
					},
				),
			),
		);
	}

	Widget _overlayVoz(BuildContext context) {
		return Positioned(
			left: 12.0,
			right: 12.0,
			bottom: 88.0,
			child: Material(
				elevation: 8.0,
				borderRadius: BorderRadius.circular(16.0),
				color: Theme.of(context).colorScheme.surface,
				child: Padding(
					padding: const EdgeInsets.all(14.0),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Icon(
										_procesandoVoz ? Icons.hourglass_top : Icons.mic,
										color: _procesandoVoz ? Colors.orange : PosiaColors.cobrar,
									),
									const SizedBox(width: 8.0),
									Expanded(
										child: Text(
											_procesandoVoz
												? 'Procesando ticket…'
												: 'Escuchando — cliente y productos en un solo dictado',
											style: const TextStyle(fontWeight: FontWeight.w600),
										),
									),
									if (_escuchando)
										TextButton(
											onPressed: _finalizarEscuchaVoz,
											child: const Text('Listo'),
										),
								],
							),
							if (_transcripcionVoz.isNotEmpty) ...[
								const SizedBox(height: 8.0),
								Text(
									_transcripcionVoz,
									maxLines: 4,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0),
								),
							],
						],
					),
				),
			),
		);
	}

	Future<bool> _asegurarPermisosVozAndroid() async {
		var mic = await Permission.microphone.status;
		if (!mic.isGranted) {
			mic = await Permission.microphone.request();
		}
		if (!mic.isGranted) {
			if (!mounted) {
				return false;
			}
			if (mic.isPermanentlyDenied) {
				await _mostrarDialogoIrAjustes(
					'Micrófono bloqueado',
					'Actívalo en Ajustes → Aplicaciones → La Fortuna → Micrófono.',
				);
			} else {
				PosiaNotificaciones.mostrarSnackBar(context, 
					const SnackBar(
						content: Text('Micrófono requerido'),
						duration: Duration(seconds: 2),
					),
				);
			}
			return false;
		}
		return true;
	}

	Future<void> _mostrarAyudaPermisosVozIos() async {
		await _mostrarDialogoIrAjustes(
			'Micrófono bloqueado',
			'Para dictar ventas, La Fortuna necesita acceso al micrófono y al '
			'reconocimiento de voz.\n\n'
			'1. Toca el botón de voz otra vez y acepta cuando iOS lo pida.\n'
			'2. Si ya lo rechazaste: Ajustes → La Fortuna → activa Micrófono y '
			'Reconocimiento de voz.\n'
			'3. Si esas opciones no aparecen, desinstala la app, reinstálala y '
			'vuelve a intentar.',
		);
	}

	Future<void> _mostrarDialogoIrAjustes(String titulo, String mensaje) async {
		await showDialog<void>(
			context: context,
			builder: (dialogContext) => AlertDialog(
				title: Text(titulo),
				content: Text(mensaje),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(dialogContext),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () {
							Navigator.pop(dialogContext);
							openAppSettings();
						},
						child: const Text('Abrir ajustes'),
					),
				],
			),
		);
	}

	Future<void> _alternarEscucha() async {
		if (_escuchando) {
			await _finalizarEscuchaVoz();
			return;
		}
		if (!Platform.isIOS) {
			final permisosOk = await _asegurarPermisosVozAndroid();
			if (!permisosOk) {
				return;
			}
		}
		if (!_vozInicializada) {
			final ok = await _servicioVoz.inicializar();
			_vozInicializada = ok;
			if (!ok) {
				if (!mounted) {
					return;
				}
				if (Platform.isIOS) {
					await _mostrarAyudaPermisosVozIos();
				} else {
					PosiaNotificaciones.mostrarSnackBar(context, 
						SnackBar(
							content: Text(
								_servicioVoz.ultimoError ?? 'Voz no disponible en este dispositivo',
							),
						),
					);
				}
				return;
			}
		}
		if (!mounted) {
			return;
		}
		setState(() {
			_escuchando = true;
			_transcripcionVoz = '';
		});
		final servicio = await ref.read(servicioCajaProvider.future);
		unawaited(_expandirCatalogo(servicio));
		await _servicioVoz.escuchar(
			onTranscripcion: (texto, esFinal) {
				if (!mounted) {
					return;
				}
				setState(() => _transcripcionVoz = texto);
				if (esFinal && texto.trim().isNotEmpty) {
					unawaited(_finalizarEscuchaVoz(procesarTexto: texto));
				}
			},
		);
	}

	Future<void> _finalizarEscuchaVoz({String? procesarTexto}) async {
		if (_finalizandoVoz) {
			return;
		}
		_finalizandoVoz = true;
		try {
			final texto = (procesarTexto ?? _transcripcionVoz).trim();
			await _servicioVoz.detener();
			if (!mounted) {
				return;
			}
			setState(() {
				_escuchando = false;
				_transcripcionVoz = texto;
			});
			if (texto.isNotEmpty) {
				await _procesarComandoVoz(texto);
			} else if (mounted) {
				setState(() => _transcripcionVoz = '');
			}
		} finally {
			_finalizandoVoz = false;
		}
	}

	Future<List<Producto>> _expandirCatalogo(ServicioCaja servicio) async {
		if (_catalogoVozCache != null) {
			return _catalogoVozCache!;
		}
		final catalogo = await servicio.listarProductos();
		final variantesPorProducto = await Future.wait(
			catalogo.map((producto) => servicio.listarVariantesActivas(producto.id)),
		);
		final expandido = <Producto>[];
		for (var i = 0; i < catalogo.length; i++) {
			final producto = catalogo[i];
			expandido.add(producto);
			for (final variante in variantesPorProducto[i]) {
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
		_catalogoVozCache = expandido;
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
				return 'Módulo farmacia no activo';
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

	Future<void> _procesarComandoVoz(String texto) async {
		final limpio = texto.trim();
		if (limpio.isEmpty) {
			return;
		}
		if (!mounted) {
			return;
		}
		setState(() => _procesandoVoz = true);
		try {
			final servicio = await ref.read(servicioCajaProvider.future);
			final catalogo = await _expandirCatalogo(servicio);
			final clientes = await servicio.listarClientes();
			final resultado = _motorVoz.procesar(
				texto: limpio,
				catalogo: catalogo,
				clientes: clientes,
			);
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
				if (resultado.usarMostrador) {
					await servicio.seleccionarCliente(null);
					mensajes.add('Cliente: mostrador');
				} else if (resultado.cliente != null) {
					await servicio.seleccionarCliente(resultado.cliente);
					mensajes.add('Cliente: ${resultado.cliente!.nombre}');
				} else if (resultado.clienteNoEncontrado != null) {
					mensajes.add('Cliente no encontrado: ${resultado.clienteNoEncontrado}');
				}
				var agregadasAuto = 0;
				for (final linea in resultado.lineas) {
					final error = await _agregarLineaVoz(servicio, linea);
					if (error.isNotEmpty) {
						mensajes.add(error);
					} else {
						agregadasAuto++;
					}
				}
				if (agregadasAuto > 0) {
					mensajes.add('$agregadasAuto producto(s) agregado(s)');
				}

				if (resultado.requiereConfirmacion && mounted) {
					final resolucion = await resolverLineasPendientesVoz(
						context,
						ambiguas: resultado.lineasAmbiguas,
						sinCoincidencia: resultado.lineasSinCoincidencia,
						catalogoCompleto: catalogo,
						motor: _motorVoz,
					);
					var agregadasManual = 0;
					for (final linea in resolucion.lineas) {
						final error = await _agregarLineaVoz(servicio, linea);
						if (error.isNotEmpty) {
							mensajes.add(error);
						} else {
							agregadasManual++;
						}
					}
					if (agregadasManual > 0) {
						mensajes.add('$agregadasManual corregido(s) manualmente');
					}
					if (resolucion.omitidas > 0) {
						mensajes.add('${resolucion.omitidas} línea(s) omitida(s)');
					}
				} else {
					for (final nombre in resultado.noEncontrados) {
						mensajes.add('No encontrado: $nombre');
					}
				}
				if (resultado.lineas.isEmpty &&
					!resultado.requiereConfirmacion &&
					resultado.cliente == null &&
					!resultado.usarMostrador &&
					resultado.clienteNoEncontrado == null) {
					mensajes.add('No entendí productos en: "$limpio"');
				}
			}

			await ref.read(carritoNotifierProvider.notifier).recargar(
				invalidarCatalogo: true,
			);
			if (!mounted) {
				return;
			}
			if (mensajes.isNotEmpty) {
				PosiaNotificaciones.mostrarSnackBar(
					context,
					SnackBar(
						content: Text(mensajes.join('\n')),
						duration: Duration(
							seconds: mensajes.length > 3 ? 8 : 5,
						),
					),
				);
			}
		} finally {
			if (mounted) {
				setState(() {
					_procesandoVoz = false;
					_transcripcionVoz = '';
				});
			}
		}
	}
}

class _BarraInferiorCajaMovil extends StatelessWidget {
	const _BarraInferiorCajaMovil({
		required this.estado,
		required this.escuchando,
		required this.alAbrirCarrito,
		required this.alCobrar,
		required this.alAlternarVoz,
		this.compacta = false,
	});

	final EstadoCarrito estado;
	final bool escuchando;
	final VoidCallback alAbrirCarrito;
	final VoidCallback? alCobrar;
	final VoidCallback alAlternarVoz;
	final bool compacta;

	@override
	Widget build(BuildContext context) {
		return Material(
			elevation: compacta ? 0.0 : 8.0,
			color: Theme.of(context).colorScheme.surface,
			child: SafeArea(
				top: false,
				child: Padding(
					padding: EdgeInsets.fromLTRB(12.0, compacta ? 4.0 : 8.0, 12.0, compacta ? 4.0 : 8.0),
					child: Row(
						children: [
							if (!compacta)
								IconButton.filledTonal(
									tooltip: escuchando ? 'Detener' : 'Voz',
									style: IconButton.styleFrom(
										backgroundColor: escuchando
											? PosiaColors.cancelar.withValues(alpha: 0.15)
											: null,
									),
									onPressed: alAlternarVoz,
									icon: Icon(escuchando ? Icons.stop : Icons.mic_none),
								),
							if (!compacta) const SizedBox(width: 8.0),
							Expanded(
								child: InkWell(
									onTap: compacta ? null : alAbrirCarrito,
									borderRadius: BorderRadius.circular(12.0),
									child: Container(
										padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
										decoration: BoxDecoration(
											color: PosiaColors.cobrar.withValues(alpha: 0.08),
											borderRadius: BorderRadius.circular(12.0),
										),
										child: Row(
											children: [
												Badge(
													isLabelVisible: estado.lineas.isNotEmpty,
													label: Text('${estado.lineas.length}'),
													child: const Icon(Icons.shopping_cart_outlined),
												),
												const SizedBox(width: 10.0),
												Expanded(
													child: Text(
														formatearMoneda(estado.total),
														style: Theme.of(context).textTheme.titleMedium?.copyWith(
															fontWeight: FontWeight.bold,
															color: PosiaColors.cobrar,
														),
													),
												),
												if (!compacta)
													const Icon(Icons.keyboard_arrow_up, size: 20.0),
											],
										),
									),
								),
							),
							const SizedBox(width: 8.0),
							if (compacta)
								IconButton.filledTonal(
									tooltip: escuchando ? 'Detener voz' : 'Voz',
									onPressed: alAlternarVoz,
									icon: Icon(escuchando ? Icons.stop : Icons.mic_none),
								),
							SizedBox(
								height: 44.0,
								child: FilledButton(
									onPressed: alCobrar,
									child: const Text('COBRAR'),
								),
							),
						],
					),
				),
			),
		);
	}
}
