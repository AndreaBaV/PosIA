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
		final tiendaActivaId = ref.watch(tiendaActivaIdProvider).value;
		return Scaffold(
			appBar: AppBar(title: const Text('Traspasos')),
			body: datosAsync.when(
				data: (datos) {
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
					final tiendaActiva = datos.tiendas
						.where((t) => t.id == tiendaActivaId)
						.firstOrNull;
					return Column(
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar traspaso...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							if (tiendaActiva != null)
								ListTile(
									dense: true,
									leading: const Icon(Icons.store),
									title: Text('Origen: ${tiendaActiva.nombre}'),
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
											return Card(
												margin: const EdgeInsets.symmetric(
													horizontal: 12.0,
													vertical: 4.0,
												),
												child: ListTile(
													title: Text('$origen → $destino'),
													subtitle: Text(
														'${t.estado.name} · ${t.lineas.length} lineas'
														'${t.notas.isNotEmpty ? ' · ${t.notas}' : ''}',
													),
													trailing: t.estado == EstadoTraspaso.enTransito &&
														tiendaActivaId != null &&
														t.tiendaDestinoId == tiendaActivaId
														? FilledButton(
															onPressed: () => _recibir(t.id),
															child: const Text('Recibir'),
														)
														: Chip(
															label: Text(t.estado.name),
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
											'Nuevo traspaso',
											style: TextStyle(fontWeight: FontWeight.bold),
										),
										const SizedBox(height: 8.0),
										DropdownButtonFormField<String>(
											initialValue: _tiendaDestinoId ??
												datos.destinos.firstOrNull?.id,
											items: datos.destinos
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
											initialValue: _productoId ?? datos.productos.firstOrNull?.id,
											items: datos.productos
												.map(
													(p) => DropdownMenuItem(
														value: p.id,
														child: Text(p.nombre),
													),
												)
												.toList(),
											onChanged: (v) => setState(() => _productoId = v),
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
											onPressed: () => _solicitar(datos),
											icon: const Icon(Icons.send),
											label: const Text('Solicitar traspaso'),
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

	Future<void> _solicitar(_DatosTraspasos datos) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final destino = _tiendaDestinoId ?? datos.destinos.firstOrNull?.id;
		final producto = _productoId ?? datos.productos.firstOrNull?.id;
		if (destino == null || producto == null) {
			return;
		}
		try {
			await servicio.solicitarTraspaso(
				tiendaDestinoId: destino,
				productoId: producto,
				cantidad: double.tryParse(_cantidadController.text) ?? 0.0,
				notas: _notasController.text.trim(),
			);
			ref.invalidate(_traspasosDatosProvider);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Traspaso solicitado')),
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

	Future<void> _recibir(String traspasoId) async {
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
		required this.destinos,
		required this.productos,
		required this.nombresTienda,
	});

	final List<Traspaso> traspasos;
	final List<Tienda> tiendas;
	final List<Tienda> destinos;
	final List<Producto> productos;
	final Map<String, String> nombresTienda;
}

final _traspasosDatosProvider = FutureProvider<_DatosTraspasos>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final tiendaActivaId = servicio.tiendaActivaId;
	final traspasos = await servicio.listarTraspasos();
	final tiendas = await servicio.listarTiendasActivas();
	final productos = await servicio.listarProductos();
	final nombres = {for (final t in tiendas) t.id: t.nombre};
	return _DatosTraspasos(
		traspasos: traspasos,
		tiendas: tiendas,
		destinos: tiendas.where((t) => t.id != tiendaActivaId).toList(),
		productos: productos,
		nombresTienda: nombres,
	);
});
