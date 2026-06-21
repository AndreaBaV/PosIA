/// Gestion de traspasos entre sucursales.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaTraspasosAdmin extends ConsumerStatefulWidget {
	const PantallaTraspasosAdmin({super.key});

	@override
	ConsumerState<PantallaTraspasosAdmin> createState() =>
		_PantallaTraspasosAdminState();
}

class _PantallaTraspasosAdminState extends ConsumerState<PantallaTraspasosAdmin> {
	final _cantidadController = TextEditingController(text: '10');
	final _notasController = TextEditingController();
	final _busquedaController = TextEditingController();
	String? _tiendaOrigenId;
	String? _tiendaDestinoId;
	String? _productoId;
	String _filtro = '';

	@override
	void dispose() {
		_cantidadController.dispose();
		_notasController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(_traspasosDatosProvider);
		final operador = ref.watch(sesionUsuarioProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Traspasos')),
			body: datosAsync.when(
				data: (datos) {
					final origenId = _resolverOrigenId(datos, operador);
					final destinos = datos.tiendas.where((t) => t.id != origenId).toList();
					final destinoId = _tiendaDestinoId ?? destinos.firstOrNull?.id;
					final productos = datos.productosPorTienda[origenId] ?? [];
					final productoId = _productoId ?? productos.firstOrNull?.id;

					final filtrados = datos.traspasos.where((t) {
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						final origen = datos.nombresTienda[t.tiendaOrigenId] ?? '';
						final destino = datos.nombresTienda[t.tiendaDestinoId] ?? '';
						return origen.toLowerCase().contains(q) ||
							destino.toLowerCase().contains(q) ||
							t.notas.toLowerCase().contains(q);
					}).toList();

					return Column(
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar traspaso...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
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
											final linea = t.lineas.firstOrNull;
											final detalle = linea == null
												? ''
												: ' · ${linea.nombreProducto.isNotEmpty ? linea.nombreProducto : linea.productoId}'
													' ${linea.cantidadSolicitada.toStringAsFixed(0)} u.';
											final pendiente = t.estado == EstadoTraspaso.enTransito;
											return Card(
												margin: const EdgeInsets.symmetric(
													horizontal: 12.0,
													vertical: 4.0,
												),
												child: ListTile(
													title: Text('$origen → $destino'),
													subtitle: Text(
														'${etiquetaEstadoTraspaso(t.estado)}$detalle'
														'${t.notas.isNotEmpty ? ' · ${t.notas}' : ''}',
													),
													trailing: pendiente
														? FilledButton(
															onPressed: () => _recibirPendiente(t.id),
															child: const Text('Recibir'),
														)
														: Chip(
															label: Text(etiquetaEstadoTraspaso(t.estado)),
														),
												),
											);
										},
									),
							),
							const Divider(),
							Padding(
								padding: const EdgeInsets.all(12.0),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										const Text(
											'Transferir entre tiendas',
											style: TextStyle(fontWeight: FontWeight.bold),
										),
										const SizedBox(height: 4.0),
										const Text(
											'Resta existencia en origen y suma en destino al instante.',
											style: TextStyle(fontSize: 12.0, color: Colors.grey),
										),
										const SizedBox(height: 8.0),
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
													_productoId = null;
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
											onChanged: (v) => setState(() => _tiendaDestinoId = v),
											decoration: const InputDecoration(
												labelText: 'Tienda destino',
												border: OutlineInputBorder(),
											),
										),
										const SizedBox(height: 8.0),
										DropdownButtonFormField<String>(
											initialValue: productoId,
											items: productos
												.map(
													(p) => DropdownMenuItem(
														value: p.id,
														child: Text(p.nombre),
													),
												)
												.toList(),
											onChanged: productos.isEmpty
												? null
												: (v) => setState(() => _productoId = v),
											decoration: const InputDecoration(
												labelText: 'Producto',
												border: OutlineInputBorder(),
											),
										),
										const SizedBox(height: 8.0),
										TextField(
											controller: _cantidadController,
											keyboardType: TextInputType.number,
											decoration: const InputDecoration(
												labelText: 'Cantidad',
												border: OutlineInputBorder(),
											),
										),
										const SizedBox(height: 8.0),
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
												productoId != null
												? () => _transferir(
													origenId: origenId,
													destinoId: destinoId,
													productoId: productoId,
												)
												: null,
											icon: const Icon(Icons.swap_horiz),
											label: const Text('Transferir'),
										),
									],
								),
							),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	String? _resolverOrigenId(_DatosTraspasos datos, Usuario? operador) {
		if (operador != null && !PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			return operador.tiendaId;
		}
		return _tiendaOrigenId ?? datos.origenes.firstOrNull?.id;
	}

	Future<void> _transferir({
		required String origenId,
		required String destinoId,
		required String productoId,
	}) async {
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final operador = ref.read(sesionUsuarioProvider);
			await servicio.realizarTraspaso(
				tiendaOrigenId: origenId,
				tiendaDestinoId: destinoId,
				productoId: productoId,
				cantidad: double.tryParse(_cantidadController.text) ?? 0.0,
				notas: _notasController.text.trim(),
				operador: operador,
			);
			ref.invalidate(_traspasosDatosProvider);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Traspaso realizado')),
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
