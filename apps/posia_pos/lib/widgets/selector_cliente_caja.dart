/// Selector de cliente para caja (optimizado para movil).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';
import 'dialogo_completar_datos_credito.dart';

/// Abre hoja con busqueda para elegir cliente del ticket activo.
Future<void> mostrarSelectorClienteCaja(
	BuildContext context,
	WidgetRef ref,
) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	final clientes = await servicio.listarClientes();
	if (!context.mounted) {
		return;
	}
	final clienteActivo = servicio.obtenerClienteActivo();
	await showModalBottomSheet<void>(
		context: context,
		isScrollControlled: true,
		showDragHandle: true,
		builder: (sheetContext) {
			return DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.72,
				minChildSize: 0.4,
				maxChildSize: 0.95,
				builder: (_, scrollController) {
					return _HojaSelectorCliente(
						clientes: clientes,
						clienteActivoId: clienteActivo?.id,
						scrollController: scrollController,
						alSeleccionar: (cliente) async {
							var seleccion = cliente;
							if (cliente != null &&
								cliente.creditoHabilitado &&
								!clienteTieneDatosCredito(cliente)) {
								if (!sheetContext.mounted) {
									return;
								}
								final actualizado = await mostrarDialogoCompletarDatosCredito(
									context: sheetContext,
									cliente: cliente,
								);
								if (actualizado == null) {
									return;
								}
								final contenedor =
									await ref.read(contenedorServiciosProvider.future);
								await contenedor.servicioAdmin.actualizarCliente(actualizado);
								seleccion = actualizado;
							}
							await servicio.seleccionarCliente(seleccion);
							if (sheetContext.mounted) {
								Navigator.of(sheetContext).pop();
							}
							await ref.read(carritoNotifierProvider.notifier).recargar(
								invalidarCatalogo: true,
							);
						},
					);
				},
			);
		},
	);
}

class _HojaSelectorCliente extends StatefulWidget {
	const _HojaSelectorCliente({
		required this.clientes,
		required this.clienteActivoId,
		required this.scrollController,
		required this.alSeleccionar,
	});

	final List<Cliente> clientes;
	final String? clienteActivoId;
	final ScrollController scrollController;
	final Future<void> Function(Cliente? cliente) alSeleccionar;

	@override
	State<_HojaSelectorCliente> createState() => _HojaSelectorClienteState();
}

class _HojaSelectorClienteState extends State<_HojaSelectorCliente> {
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	List<Cliente> get _filtrados {
		if (_filtro.isEmpty) {
			return widget.clientes;
		}
		final q = _filtro.toLowerCase();
		return widget.clientes.where((c) {
			return c.nombre.toLowerCase().contains(q) ||
				c.telefono.toLowerCase().contains(q);
		}).toList();
	}

	@override
	Widget build(BuildContext context) {
		final filtrados = _filtrados;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Padding(
					padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
					child: Text(
						'Cliente del ticket',
						style: Theme.of(context).textTheme.titleMedium?.copyWith(
							fontWeight: FontWeight.bold,
						),
					),
				),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16.0),
					child: TextField(
						controller: _busquedaController,
						autofocus: true,
						decoration: InputDecoration(
							hintText: 'Buscar por nombre o teléfono…',
							prefixIcon: const Icon(Icons.search),
							suffixIcon: _filtro.isNotEmpty
								? IconButton(
									icon: const Icon(Icons.clear),
									onPressed: () {
										_busquedaController.clear();
										setState(() => _filtro = '');
									},
								)
								: null,
							border: const OutlineInputBorder(),
							isDense: true,
						),
						onChanged: (v) => setState(() => _filtro = v.trim()),
					),
				),
				const SizedBox(height: 8.0),
				ListTile(
					leading: const Icon(Icons.storefront),
					title: const Text('Mostrador'),
					trailing: widget.clienteActivoId == null
						? const Icon(Icons.check, color: PosiaColors.cobrar)
						: null,
					onTap: () => widget.alSeleccionar(null),
				),
				const Divider(height: 1.0),
				Expanded(
					child: filtrados.isEmpty
						? Center(
							child: Text(
								_filtro.isEmpty ? 'Sin clientes registrados' : 'Sin resultados',
								style: TextStyle(color: Colors.grey.shade600),
							),
						)
						: ListView.builder(
							controller: widget.scrollController,
							itemCount: filtrados.length,
							itemBuilder: (context, index) {
								final cliente = filtrados[index];
								final activo = cliente.id == widget.clienteActivoId;
								return ListTile(
									leading: Icon(
										Icons.person,
										color: clientePuedeRecibirCredito(cliente)
											? PosiaColors.cobrar
											: null,
									),
									title: Text(cliente.nombre),
									subtitle: _subtituloCliente(cliente),
									trailing: activo
										? const Icon(Icons.check, color: PosiaColors.cobrar)
										: null,
									onTap: () => widget.alSeleccionar(cliente),
								);
							},
						),
				),
			],
		);
	}

	Widget? _subtituloCliente(Cliente cliente) {
		final partes = <String>[];
		if (cliente.telefono.trim().isNotEmpty) {
			partes.add(cliente.telefono.trim());
		}
		if (cliente.creditoHabilitado) {
			partes.add(
				clientePuedeRecibirCredito(cliente)
					? 'Crédito · ${cliente.diasCredito} días'
					: 'Crédito: faltan datos',
			);
		}
		if (partes.isEmpty) {
			return null;
		}
		return Text(
			partes.join(' · '),
			style: TextStyle(
				fontSize: 12.0,
				color: cliente.creditoHabilitado && !clientePuedeRecibirCredito(cliente)
					? PosiaColors.cancelar
					: Colors.grey.shade600,
			),
		);
	}
}
