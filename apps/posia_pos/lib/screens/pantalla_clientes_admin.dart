/// Administracion de clientes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../widgets/tarjeta_entidad_admin.dart';
import 'pantalla_ficha_cliente.dart';

class PantallaClientesAdmin extends ConsumerStatefulWidget {
	const PantallaClientesAdmin({super.key});

	@override
	ConsumerState<PantallaClientesAdmin> createState() => _PantallaClientesAdminState();
}

class _PantallaClientesAdminState extends ConsumerState<PantallaClientesAdmin> {
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	Future<void> _refrescar() async {
		ref.invalidate(clientesAdminProvider);
		invalidarListasPrecios(ref);
		await ref.read(clientesAdminProvider.future);
	}

	List<Cliente> _filtrar(List<Cliente> clientes) {
		if (_filtro.isEmpty) {
			return clientes;
		}
		final q = _filtro.toLowerCase();
		return clientes.where((c) {
			return c.nombre.toLowerCase().contains(q) ||
				c.telefono.toLowerCase().contains(q) ||
				c.email.toLowerCase().contains(q) ||
				c.rfc.toLowerCase().contains(q);
		}).toList();
	}

	@override
	Widget build(BuildContext context) {
		final clientesAsync = ref.watch(clientesAdminProvider);
		final listasAsync = ref.watch(listasPreciosAdminProvider);
		final nombresLista = listasAsync.asData?.value == null
			? <String, String>{}
			: {for (final l in listasAsync.asData!.value) l.id: l.nombre};

		return Scaffold(
			appBar: AppBar(
				title: const Text('Clientes'),
				actions: [
					IconButton(
						icon: const Icon(Icons.refresh),
						tooltip: 'Actualizar',
						onPressed: _refrescar,
					),
				],
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: _mostrarDialogoNuevo,
				icon: const Icon(Icons.person_add_outlined),
				label: const Text('Nuevo cliente'),
			),
			body: clientesAsync.when(
				data: (clientes) {
					final filtrados = _filtrar(clientes)
					  ..sort((a, b) => a.nombre.compareTo(b.nombre));
					final conCredito = clientes.where((c) => c.creditoHabilitado).length;
					final conLista = clientes.where((c) => c.listaPreciosId != null).length;

					return Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							EncabezadoListaAdmin(
								descripcion:
									'Directorio de clientes para ventas, crédito y listas de precios.',
								chips: [
									ChipResumenAdmin(
										icono: Icons.people_outline,
										etiqueta: '${clientes.length} total',
									),
									if (conCredito > 0)
										ChipResumenAdmin(
											icono: Icons.account_balance_wallet_outlined,
											etiqueta: '$conCredito con crédito',
										),
									if (conLista > 0)
										ChipResumenAdmin(
											icono: Icons.sell_outlined,
											etiqueta: '$conLista con lista',
										),
								],
							),
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar por nombre, teléfono, email o RFC',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							if (_filtro.isNotEmpty)
								Padding(
									padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
									child: Text(
										'${filtrados.length} coincidencia${filtrados.length == 1 ? '' : 's'}',
										style: Theme.of(context).textTheme.bodySmall,
									),
								),
							Expanded(
								child: RefreshIndicator(
									onRefresh: _refrescar,
									child: filtrados.isEmpty
										? ListView(
											children: [
												SizedBox(
													height: MediaQuery.sizeOf(context).height * 0.25,
												),
												EstadoVacioListaAdmin(
													icono: Icons.person_search_outlined,
													titulo: clientes.isEmpty
														? 'Sin clientes registrados'
														: 'Sin coincidencias',
													subtitulo: clientes.isEmpty
														? 'Agregue clientes para asignarles crédito, '
															'listas de precios y ver su historial de compras.'
														: 'Pruebe con otro término de búsqueda.',
													textoBoton: clientes.isEmpty ? 'Agregar cliente' : null,
													onAgregar: clientes.isEmpty ? _mostrarDialogoNuevo : null,
												),
											],
										)
										: ListView.builder(
											padding: const EdgeInsets.only(top: 8.0, bottom: 88.0),
											itemCount: filtrados.length,
											itemBuilder: (_, i) {
												final c = filtrados[i];
												return _tarjetaCliente(c, nombresLista);
											},
										),
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

	Widget _tarjetaCliente(Cliente c, Map<String, String> nombresLista) {
		final listaId = c.listaPreciosId;
		final nombreLista = listaId == null ? null : nombresLista[listaId];
		final subtitulo = [
			if (c.telefono.isNotEmpty) c.telefono,
			if (c.email.isNotEmpty) c.email,
		].join(' · ');

		return TarjetaEntidadAdmin(
			titulo: c.nombre,
			subtitulo: subtitulo.isEmpty ? null : subtitulo,
			iconoAvatar: Icons.person_outline,
			inactivo: !c.activo,
			onTap: () => _abrirFicha(c),
			onEliminar: () => _confirmarEliminar(c),
			chips: [
				if (c.creditoHabilitado)
					ChipDetalleEntidad(
						icono: Icons.payments_outlined,
						texto: clientePuedeRecibirCredito(c)
							? 'Crédito · ${c.diasCredito} días'
							: 'Crédito · datos incompletos',
						color: clientePuedeRecibirCredito(c)
							? PosiaColors.cobrar
							: PosiaColors.cancelar,
					),
				if (nombreLista != null)
					ChipDetalleEntidad(
						icono: Icons.sell_outlined,
						texto: nombreLista,
					)
				else if (listaId != null)
					const ChipDetalleEntidad(
						icono: Icons.warning_amber_outlined,
						texto: 'Lista no disponible',
						color: PosiaColors.cancelar,
					),
				if (!c.activo)
					const ChipDetalleEntidad(
						icono: Icons.block,
						texto: 'Inactivo',
					),
			],
		);
	}

	Future<void> _mostrarDialogoNuevo() async {
		final nombreController = TextEditingController();
		final telefonoController = TextEditingController();
		final crear = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Nuevo cliente'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							controller: nombreController,
							autofocus: true,
							textCapitalization: TextCapitalization.words,
							decoration: const InputDecoration(
								labelText: 'Nombre *',
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: telefonoController,
							keyboardType: TextInputType.phone,
							decoration: const InputDecoration(
								labelText: 'Teléfono (opcional)',
								border: OutlineInputBorder(),
							),
						),
					],
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Crear'),
					),
				],
			),
		);
		final nombre = nombreController.text.trim();
		final telefono = telefonoController.text.trim();
		nombreController.dispose();
		telefonoController.dispose();
		if (crear != true || nombre.isEmpty || !mounted) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final cliente = await servicio.registrarCliente(nombre: nombre);
		if (telefono.isNotEmpty) {
			await servicio.actualizarCliente(cliente.copiarCon(telefono: telefono));
		}
		ref.invalidate(clientesAdminProvider);
		if (!mounted) {
			return;
		}
		await _abrirFicha(
			telefono.isNotEmpty ? cliente.copiarCon(telefono: telefono) : cliente,
		);
	}

	Future<void> _abrirFicha(Cliente cliente) async {
		await Navigator.of(context).push<void>(
			MaterialPageRoute<void>(
				builder: (_) => PantallaFichaCliente(cliente: cliente),
			),
		);
		ref.invalidate(clientesAdminProvider);
		invalidarListasPrecios(ref);
	}

	Future<void> _confirmarEliminar(Cliente cliente) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				icon: const Icon(Icons.delete_outline, color: PosiaColors.cancelar),
				title: const Text('Eliminar cliente'),
				content: Text(
					'¿Eliminar permanentemente a "${cliente.nombre}"?\n\n'
					'No es posible si tiene ventas, pedidos o cotizaciones registradas.',
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
			ref.invalidate(clientesAdminProvider);
			invalidarListasPrecios(ref);
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Cliente eliminado')),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text(e.message),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}
}
