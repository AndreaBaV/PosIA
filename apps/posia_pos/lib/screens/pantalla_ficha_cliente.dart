/// Ficha detallada de cliente con historial de ventas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';

import '../providers/admin_providers.dart';

class PantallaFichaCliente extends ConsumerStatefulWidget {
	const PantallaFichaCliente({required this.cliente, super.key});

	final Cliente cliente;

	@override
	ConsumerState<PantallaFichaCliente> createState() => _PantallaFichaClienteState();
}

class _PantallaFichaClienteState extends ConsumerState<PantallaFichaCliente>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	late final TextEditingController _nombreController;
	late final TextEditingController _telefonoController;
	late final TextEditingController _emailController;
	late final TextEditingController _rfcController;
	late final TextEditingController _direccionController;
	late final TextEditingController _notasController;
	late bool _credito;
	late bool _activo;
	String? _listaPreciosId;

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 2, vsync: this);
		final c = widget.cliente;
		_nombreController = TextEditingController(text: c.nombre);
		_telefonoController = TextEditingController(text: c.telefono);
		_emailController = TextEditingController(text: c.email);
		_rfcController = TextEditingController(text: c.rfc);
		_direccionController = TextEditingController(text: c.direccion);
		_notasController = TextEditingController(text: c.notas);
		_credito = c.creditoHabilitado;
		_activo = c.activo;
		_listaPreciosId = c.listaPreciosId;
	}

	@override
	void dispose() {
		_tabs.dispose();
		_nombreController.dispose();
		_telefonoController.dispose();
		_emailController.dispose();
		_rfcController.dispose();
		_direccionController.dispose();
		_notasController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final ventasAsync = ref.watch(_ventasClienteProvider(widget.cliente.id));
		final resumenAsync = ref.watch(_resumenClienteProvider(widget.cliente.id));
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.cliente.nombre),
				bottom: TabBar(
					controller: _tabs,
					tabs: const [
						Tab(text: 'Datos'),
						Tab(text: 'Ventas'),
					],
				),
				actions: [
					IconButton(icon: const Icon(Icons.save), onPressed: _guardar),
				],
			),
			body: TabBarView(
				controller: _tabs,
				children: [
					ListView(
						padding: const EdgeInsets.all(16.0),
						children: [
							TextField(
								controller: _nombreController,
								decoration: const InputDecoration(
									labelText: 'Nombre',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _telefonoController,
								decoration: const InputDecoration(
									labelText: 'Telefono',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _emailController,
								decoration: const InputDecoration(
									labelText: 'Email',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _rfcController,
								decoration: const InputDecoration(
									labelText: 'RFC',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _direccionController,
								maxLines: 2,
								decoration: const InputDecoration(
									labelText: 'Direccion',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							Consumer(
								builder: (context, ref, _) {
									final listasAsync = ref.watch(_listasClienteProvider);
									return listasAsync.when(
										data: (listas) => DropdownButtonFormField<String?>(
											value: _listaPreciosId,
											decoration: const InputDecoration(
												labelText: 'Lista de precios',
												border: OutlineInputBorder(),
											),
											items: [
												const DropdownMenuItem<String?>(
													value: null,
													child: Text('Precio normal'),
												),
												...listas.map(
													(l) => DropdownMenuItem<String?>(
														value: l.id,
														child: Text(l.nombre),
													),
												),
											],
											onChanged: (v) => setState(() => _listaPreciosId = v),
										),
										loading: () => const LinearProgressIndicator(),
										error: (e, _) => Text('$e'),
									);
								},
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _notasController,
								maxLines: 3,
								decoration: const InputDecoration(
									labelText: 'Notas',
									border: OutlineInputBorder(),
								),
							),
							SwitchListTile(
								title: const Text('Credito habilitado'),
								value: _credito,
								onChanged: (v) => setState(() => _credito = v),
							),
							SwitchListTile(
								title: const Text('Activo'),
								value: _activo,
								onChanged: (v) => setState(() => _activo = v),
							),
						],
					),
					Column(
						children: [
							resumenAsync.when(
								data: (r) => Card(
									margin: const EdgeInsets.all(12.0),
									child: Padding(
										padding: const EdgeInsets.all(16.0),
										child: Row(
											mainAxisAlignment: MainAxisAlignment.spaceAround,
											children: [
												_ColumnStat(
													'Ventas',
													'${r.cantidadVentas}',
												),
												_ColumnStat(
													'Total',
													formatearMoneda(r.totalComprado),
												),
											],
										),
									),
								),
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							Expanded(
								child: ventasAsync.when(
									data: (ventas) {
										if (ventas.isEmpty) {
											return const Center(child: Text('Sin ventas'));
										}
										return ListView.builder(
											itemCount: ventas.length,
											itemBuilder: (_, i) {
												final v = ventas[i];
												return ListTile(
													leading: const Icon(Icons.receipt),
													title: Text(formatearMoneda(v.total)),
													subtitle: Text(
														'${v.estado.name} · '
														'${v.creadaEn.toLocal().toString().substring(0, 16)}',
													),
												);
											},
										);
									},
									loading: () => const Center(child: CircularProgressIndicator()),
									error: (e, _) => Center(child: Text('$e')),
								),
							),
						],
					),
				],
			),
		);
	}

	Future<void> _guardar() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarCliente(
			widget.cliente.copiarCon(
				nombre: _nombreController.text.trim(),
				telefono: _telefonoController.text.trim(),
				email: _emailController.text.trim(),
				rfc: _rfcController.text.trim(),
				direccion: _direccionController.text.trim(),
				notas: _notasController.text.trim(),
				creditoHabilitado: _credito,
				activo: _activo,
				listaPreciosId: _listaPreciosId,
			),
		);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Cliente actualizado')),
		);
	}
}

final _listasClienteProvider = FutureProvider<List<ListaPrecios>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarListasPrecios();
});

class _ColumnStat extends StatelessWidget {
	const _ColumnStat(this.etiqueta, this.valor);

	final String etiqueta;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				Text(etiqueta, style: const TextStyle(color: Colors.grey)),
				Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0)),
			],
		);
	}
}

final _ventasClienteProvider = FutureProvider.family<List<Venta>, String>((ref, id) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarVentasCliente(id);
});

final _resumenClienteProvider = FutureProvider.family<ResumenCliente, String>((ref, id) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerResumenCliente(id);
});
