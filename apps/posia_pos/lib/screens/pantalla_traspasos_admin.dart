/// Gestion de traspasos entre sucursales con seleccion multiple e impresion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/traspaso_impresion_util.dart';

class PantallaTraspasosAdmin extends ConsumerStatefulWidget {
	const PantallaTraspasosAdmin({super.key});

	@override
	ConsumerState<PantallaTraspasosAdmin> createState() =>
		_PantallaTraspasosAdminState();
}

class _PantallaTraspasosAdminState extends ConsumerState<PantallaTraspasosAdmin>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	final _notasController = TextEditingController();
	final _busquedaHistorialController = TextEditingController();
	final _busquedaProductoController = TextEditingController();
	final _cantidadControllers = <String, TextEditingController>{};
	final _seleccionados = <String>{};
	String? _tiendaOrigenId;
	String? _tiendaDestinoId;
	String _filtroHistorial = '';
	String _filtroProducto = '';

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 2, vsync: this);
	}

	@override
	void dispose() {
		_tabs.dispose();
		_notasController.dispose();
		_busquedaHistorialController.dispose();
		_busquedaProductoController.dispose();
		for (final ctrl in _cantidadControllers.values) {
			ctrl.dispose();
		}
		super.dispose();
	}

	TextEditingController _controllerCantidad(String productoId) {
		return _cantidadControllers.putIfAbsent(
			productoId,
			() => TextEditingController(text: '1'),
		);
	}

	void _limpiarSeleccion() {
		setState(_seleccionados.clear);
	}

	void _alCambiarOrigen() {
		setState(() {
			_seleccionados.clear();
		});
	}

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(_traspasosDatosProvider);
		final operador = ref.watch(sesionUsuarioProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Traspasos'),
				bottom: TabBar(
					controller: _tabs,
					tabs: const [
						Tab(text: 'Nuevo traspaso'),
						Tab(text: 'Historial'),
					],
				),
			),
			body: datosAsync.when(
				data: (datos) => TabBarView(
					controller: _tabs,
					children: [
						_buildNuevoTraspaso(datos, operador),
						_buildHistorial(datos),
					],
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Widget _buildNuevoTraspaso(_DatosTraspasos datos, Usuario? operador) {
		final origenId = _resolverOrigenId(datos, operador);
		final destinos = datos.tiendas.where((t) => t.id != origenId).toList();
		final destinoId = _tiendaDestinoId ?? destinos.firstOrNull?.id;
		final productos = datos.productosPorTienda[origenId] ?? [];
		final productosFiltrados = productos.where((p) {
			if (_filtroProducto.isEmpty) {
				return true;
			}
			final q = _filtroProducto.toLowerCase();
			return p.nombre.toLowerCase().contains(q) ||
				p.codigoBarras.toLowerCase().contains(q);
		}).toList();

		return Column(
			children: [
				Padding(
					padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							DropdownButtonFormField<String>(
								initialValue: origenId,
								items: datos.origenes
									.map(
										(t) => DropdownMenuItem(
											value: t.id,
											child: Text(t.nombre),
										),
									)
									.toList(),
								onChanged: operador != null &&
									!PermisosUsuario.puedeGestionarTodasLasTiendas(operador)
									? null
									: (v) => setState(() {
										_tiendaOrigenId = v;
										_alCambiarOrigen();
									}),
								decoration: const InputDecoration(
									labelText: 'Tienda origen',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							DropdownButtonFormField<String>(
								initialValue: destinoId,
								items: destinos
									.map(
										(t) => DropdownMenuItem(
											value: t.id,
											child: Text(t.nombre),
										),
									)
									.toList(),
								onChanged: destinos.isEmpty
									? null
									: (v) => setState(() => _tiendaDestinoId = v),
								decoration: const InputDecoration(
									labelText: 'Tienda destino',
									border: OutlineInputBorder(),
								),
							),
						],
					),
				),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
					child: Row(
						children: [
							Expanded(
								child: Text(
									'${_seleccionados.length} producto(s) seleccionado(s)',
									style: const TextStyle(fontWeight: FontWeight.w600),
								),
							),
							if (_seleccionados.isNotEmpty)
								TextButton(
									onPressed: _limpiarSeleccion,
									child: const Text('Limpiar'),
								),
						],
					),
				),
				CampoBusqueda(
					controlador: _busquedaProductoController,
					sugerencia: 'Buscar producto...',
					alCambiar: (v) => setState(() => _filtroProducto = v.trim()),
				),
				Expanded(
					child: productosFiltrados.isEmpty
						? const Center(child: Text('Sin productos en la tienda origen'))
						: ListView.builder(
							itemCount: productosFiltrados.length,
							itemBuilder: (_, i) {
								final producto = productosFiltrados[i];
								final seleccionado = _seleccionados.contains(producto.id);
								final ctrl = _controllerCantidad(producto.id);
								return CheckboxListTile(
									value: seleccionado,
									onChanged: (v) {
										setState(() {
											if (v == true) {
												_seleccionados.add(producto.id);
											} else {
												_seleccionados.remove(producto.id);
											}
										});
									},
									title: Text(producto.nombre),
									subtitle: seleccionado
										? Row(
											children: [
												const Text('Cantidad: '),
												SizedBox(
													width: 80.0,
													child: TextField(
														controller: ctrl,
														keyboardType: TextInputType.number,
														decoration: const InputDecoration(
															isDense: true,
															border: OutlineInputBorder(),
														),
													),
												),
											],
										)
										: Text(
											producto.codigoBarras.isNotEmpty
												? producto.codigoBarras
												: 'Sin codigo',
											style: const TextStyle(fontSize: 12.0),
										),
								);
							},
						),
				),
				const Divider(height: 1.0),
				Padding(
					padding: const EdgeInsets.all(12.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							TextField(
								controller: _notasController,
								decoration: const InputDecoration(
									labelText: 'Notas (opcional)',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							FilledButton.icon(
								onPressed: origenId != null &&
									destinoId != null &&
									_seleccionados.isNotEmpty
									? () => _transferir(
										datos: datos,
										origenId: origenId,
										destinoId: destinoId,
										operador: operador,
									)
									: null,
								icon: const Icon(Icons.swap_horiz),
								label: Text(
									_seleccionados.isEmpty
										? 'Seleccione productos'
										: 'Transferir (${_seleccionados.length})',
								),
							),
						],
					),
				),
			],
		);
	}

	Widget _buildHistorial(_DatosTraspasos datos) {
		final filtrados = datos.traspasos.where((t) {
			if (_filtroHistorial.isEmpty) {
				return true;
			}
			final q = _filtroHistorial.toLowerCase();
			final origen = datos.nombresTienda[t.tiendaOrigenId] ?? '';
			final destino = datos.nombresTienda[t.tiendaDestinoId] ?? '';
			for (final linea in t.lineas) {
				if (linea.nombreProducto.toLowerCase().contains(q)) {
					return true;
				}
			}
			return origen.toLowerCase().contains(q) ||
				destino.toLowerCase().contains(q) ||
				t.notas.toLowerCase().contains(q);
		}).toList();

		return Column(
			children: [
				CampoBusqueda(
					controlador: _busquedaHistorialController,
					sugerencia: 'Buscar traspaso...',
					alCambiar: (v) => setState(() => _filtroHistorial = v.trim()),
				),
				Expanded(
					child: filtrados.isEmpty
						? const Center(child: Text('Sin traspasos registrados'))
						: ListView.builder(
							itemCount: filtrados.length,
							itemBuilder: (_, i) {
								final t = filtrados[i];
								final origen = datos.nombresTienda[t.tiendaOrigenId] ?? '?';
								final destino = datos.nombresTienda[t.tiendaDestinoId] ?? '?';
								final resumen = t.lineas.length == 1
									? '${t.lineas.first.nombreProducto} '
										'${_formatearCantidad(t.lineas.first.cantidadSolicitada)} u.'
									: '${t.lineas.length} productos';
								final pendiente = t.estado == EstadoTraspaso.enTransito;
								return Card(
									margin: const EdgeInsets.symmetric(
										horizontal: 12.0,
										vertical: 4.0,
									),
									child: ListTile(
										title: Text('$origen → $destino'),
										subtitle: Text(
											'${etiquetaEstadoTraspaso(t.estado)} · $resumen'
											'${t.notas.isNotEmpty ? ' · ${t.notas}' : ''}',
										),
										trailing: pendiente
											? FilledButton(
												onPressed: () => _recibirPendiente(t.id),
												child: const Text('Recibir'),
											)
											: const Icon(Icons.chevron_right),
										onTap: pendiente
											? null
											: () => _mostrarDetalleTraspaso(t, datos),
									),
								);
							},
						),
				),
			],
		);
	}

	String _formatearCantidad(double cantidad) {
		if (cantidad == cantidad.roundToDouble()) {
			return cantidad.toStringAsFixed(0);
		}
		return cantidad.toStringAsFixed(2);
	}

	String? _resolverOrigenId(_DatosTraspasos datos, Usuario? operador) {
		if (operador != null && !PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			return operador.tiendaId;
		}
		return _tiendaOrigenId ?? datos.origenes.firstOrNull?.id;
	}

	List<LineaTraspasoSolicitud> _construirLineas() {
		return _seleccionados.map((productoId) {
			final cantidad = double.tryParse(
				_cantidadControllers[productoId]?.text.replaceAll(',', '.') ?? '',
			) ?? 0.0;
			return LineaTraspasoSolicitud(
				productoId: productoId,
				cantidad: cantidad,
			);
		}).toList();
	}

	Future<void> _transferir({
		required _DatosTraspasos datos,
		required String origenId,
		required String destinoId,
		required Usuario? operador,
	}) async {
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final traspaso = await servicio.realizarTraspasoMultiple(
				tiendaOrigenId: origenId,
				tiendaDestinoId: destinoId,
				lineas: _construirLineas(),
				notas: _notasController.text.trim(),
				operador: operador,
			);
			ref.invalidate(_traspasosDatosProvider);
			_limpiarSeleccion();
			_notasController.clear();
			if (!mounted) {
				return;
			}
			await _mostrarDialogoImpresion(
				traspaso: traspaso,
				datos: datos,
				nombreOperador: operador?.nombre,
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _mostrarDialogoImpresion({
		required Traspaso traspaso,
		required _DatosTraspasos datos,
		String? nombreOperador,
	}) async {
		await showDialog<void>(
			context: context,
			builder: (ctx) => AlertDialog(
				icon: const Icon(Icons.check_circle, color: PosiaColors.cobrar),
				title: const Text('Traspaso realizado'),
				content: Text(
					'${traspaso.lineas.length} producto(s) transferidos.\n'
					'¿Desea imprimir documentos?',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx),
						child: const Text('Cerrar'),
					),
					TextButton(
						onPressed: () async {
							await _imprimirTicket(
								traspaso: traspaso,
								datos: datos,
								nombreOperador: nombreOperador,
							);
							if (ctx.mounted) {
								Navigator.pop(ctx);
							}
						},
						child: const Text('Ticket'),
					),
					TextButton(
						onPressed: () async {
							await _imprimirComprobante(
								traspaso: traspaso,
								datos: datos,
								nombreOperador: nombreOperador,
							);
							if (ctx.mounted) {
								Navigator.pop(ctx);
							}
						},
						child: const Text('Comprobante'),
					),
					FilledButton(
						onPressed: () async {
							await _imprimirTicket(
								traspaso: traspaso,
								datos: datos,
								nombreOperador: nombreOperador,
							);
							await _imprimirComprobante(
								traspaso: traspaso,
								datos: datos,
								nombreOperador: nombreOperador,
							);
							if (ctx.mounted) {
								Navigator.pop(ctx);
							}
						},
						child: const Text('Imprimir ambos'),
					),
				],
			),
		);
	}

	void _mostrarDetalleTraspaso(Traspaso traspaso, _DatosTraspasos datos) {
		final origen = datos.nombresTienda[traspaso.tiendaOrigenId] ?? '?';
		final destino = datos.nombresTienda[traspaso.tiendaDestinoId] ?? '?';
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.55,
				maxChildSize: 0.9,
				builder: (context, scrollController) => Padding(
					padding: const EdgeInsets.all(20.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								'$origen → $destino',
								style: Theme.of(context).textTheme.titleLarge,
							),
							Text('Folio ${traspaso.id.substring(0, 8).toUpperCase()}'),
							const SizedBox(height: 12.0),
							Expanded(
								child: ListView(
									controller: scrollController,
									children: [
										const Text(
											'Enviado',
											style: TextStyle(fontWeight: FontWeight.bold),
										),
										...traspaso.lineas.map(
											(l) => ListTile(
												contentPadding: EdgeInsets.zero,
												title: Text(l.nombreProducto),
												trailing: Text(
													'${_formatearCantidad(l.cantidadSolicitada)} u.',
												),
											),
										),
										const Divider(height: 24.0),
										const Text(
											'Recibido',
											style: TextStyle(fontWeight: FontWeight.bold),
										),
										...traspaso.lineas.map(
											(l) => ListTile(
												contentPadding: EdgeInsets.zero,
												title: Text(l.nombreProducto),
												trailing: Text(
													l.cantidadRecibida == null
														? 'Pendiente'
														: '${_formatearCantidad(l.cantidadRecibida!)} u.',
												),
											),
										),
									],
								),
							),
							Row(
								children: [
									TextButton.icon(
										onPressed: () => _imprimirTicket(
											traspaso: traspaso,
											datos: datos,
										),
										icon: const Icon(Icons.receipt),
										label: const Text('Ticket'),
									),
									TextButton.icon(
										onPressed: () => _imprimirComprobante(
											traspaso: traspaso,
											datos: datos,
										),
										icon: const Icon(Icons.description),
										label: const Text('Comprobante'),
									),
									const Spacer(),
									FilledButton(
										onPressed: () => Navigator.pop(ctx),
										child: const Text('Cerrar'),
									),
								],
							),
						],
					),
				),
			),
		);
	}

	Future<void> _imprimirTicket({
		required Traspaso traspaso,
		required _DatosTraspasos datos,
		String? nombreOperador,
	}) async {
		try {
			final hardware = await ref.read(hardwareRegistryProvider.future);
			final texto = construirTicketTraspaso(
				traspaso: traspaso,
				nombreTiendaOrigen: datos.nombresTienda[traspaso.tiendaOrigenId] ?? '?',
				nombreTiendaDestino: datos.nombresTienda[traspaso.tiendaDestinoId] ?? '?',
				nombreOperador: nombreOperador,
			);
			await imprimirDocumentoTraspaso(
				impresora: hardware.obtenerImpresora(),
				contenido: texto,
			);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Ticket enviado a impresora')),
			);
		} catch (_) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No se pudo imprimir el ticket'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}

	Future<void> _imprimirComprobante({
		required Traspaso traspaso,
		required _DatosTraspasos datos,
		String? nombreOperador,
	}) async {
		try {
			final hardware = await ref.read(hardwareRegistryProvider.future);
			final texto = construirComprobanteTraspaso(
				traspaso: traspaso,
				nombreTiendaOrigen: datos.nombresTienda[traspaso.tiendaOrigenId] ?? '?',
				nombreTiendaDestino: datos.nombresTienda[traspaso.tiendaDestinoId] ?? '?',
				nombreOperadorEnvio: nombreOperador,
			);
			await imprimirDocumentoTraspaso(
				impresora: hardware.obtenerImpresora(),
				contenido: texto,
			);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Comprobante enviado a impresora')),
			);
		} catch (_) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No se pudo imprimir el comprobante'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}

	Future<void> _recibirPendiente(String traspasoId) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final ok = await servicio.recibirTraspaso(traspasoId);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(ok ? 'Traspaso recibido' : 'No se pudo recibir'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(_traspasosDatosProvider);
	}
}

class _DatosTraspasos {
	const _DatosTraspasos({
		required this.traspasos,
		required this.tiendas,
		required this.origenes,
		required this.productosPorTienda,
		required this.nombresTienda,
	});

	final List<Traspaso> traspasos;
	final List<Tienda> tiendas;
	final List<Tienda> origenes;
	final Map<String, List<Producto>> productosPorTienda;
	final Map<String, String> nombresTienda;
}

final _traspasosDatosProvider = FutureProvider<_DatosTraspasos>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	final traspasos = await servicio.listarTraspasos();
	final tiendas = await servicio.obtenerTiendasPermitidas(operador: operador);
	final nombres = {for (final t in tiendas) t.id: t.nombre};
	final productosPorTienda = <String, List<Producto>>{};
	for (final tienda in tiendas) {
		productosPorTienda[tienda.id] =
			await servicio.listarProductosActivosPorTienda(tienda.id);
	}
	return _DatosTraspasos(
		traspasos: traspasos,
		tiendas: tiendas,
		origenes: tiendas,
		productosPorTienda: productosPorTienda,
		nombresTienda: nombres,
	);
});
