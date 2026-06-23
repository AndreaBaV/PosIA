/// Administracion de clientes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import 'pantalla_ficha_cliente.dart';

class PantallaClientesAdmin extends ConsumerStatefulWidget {
	const PantallaClientesAdmin({super.key});

	@override
	ConsumerState<PantallaClientesAdmin> createState() => _PantallaClientesAdminState();
}

class _PantallaClientesAdminState extends ConsumerState<PantallaClientesAdmin> {
	final _nombreController = TextEditingController();
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_nombreController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final clientesAsync = ref.watch(_clientesProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Clientes')),
			body: clientesAsync.when(
				data: (clientes) {
					final filtrados = clientes.where((c) {
						if (_filtro.isEmpty) {
							return true;
						}
						return c.nombre.toLowerCase().contains(_filtro.toLowerCase());
					}).toList();
					return ListView(
					padding: const EdgeInsets.all(16.0),
					children: [
						CampoBusqueda(
							controlador: _busquedaController,
							sugerencia: 'Buscar cliente...',
							alCambiar: (v) => setState(() => _filtro = v.trim()),
						),
						if (filtrados.isEmpty)
							const Center(child: Text('Sin clientes registrados')),
						...filtrados.map(
							(c) {
								final detalle = [
									if (c.telefono.isNotEmpty) c.telefono,
									if (c.creditoHabilitado) 'Crédito',
								].join(' · ');
								return ListTile(
								title: Text(c.nombre),
								subtitle: detalle.isEmpty ? null : Text(detalle),
								trailing: IconButton(
									icon: const Icon(Icons.delete_outline),
									color: PosiaColors.cancelar,
									tooltip: 'Eliminar cliente',
									onPressed: () => _confirmarEliminar(c),
								),
								onTap: () => _abrirFicha(c),
							);
							},
						),
						const Divider(),
						TextField(
							controller: _nombreController,
							decoration: const InputDecoration(
								labelText: 'Nombre del cliente',
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 8.0),
						FilledButton(onPressed: _agregar, child: const Text('Agregar cliente')),
					],
				);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _abrirFicha(Cliente cliente) async {
		await Navigator.of(context).push<void>(
			MaterialPageRoute<void>(
				builder: (_) => PantallaFichaCliente(cliente: cliente),
			),
		);
		ref.invalidate(_clientesProvider);
	}

	Future<void> _agregar() async {
		final nombre = _nombreController.text.trim();
		if (nombre.isEmpty) return;
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarCliente(nombre: nombre);
		_nombreController.clear();
		ref.invalidate(_clientesProvider);
	}

	Future<void> _confirmarEliminar(Cliente cliente) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar cliente'),
				content: Text(
					'¿Eliminar permanentemente a "${cliente.nombre}"?\n\n'
					'Esta acción no se puede deshacer. '
					'No es posible si el cliente tiene ventas, pedidos o cotizaciones.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (confirmar != true || !mounted) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.eliminarCliente(cliente.id);
			ref.invalidate(_clientesProvider);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Cliente eliminado')),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(e.message),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}
}

final _clientesProvider = FutureProvider<List<Cliente>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarClientes();
});
