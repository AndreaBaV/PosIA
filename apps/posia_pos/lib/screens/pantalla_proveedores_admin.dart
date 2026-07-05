/// Administracion de proveedores.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../widgets/tarjeta_entidad_admin.dart';
import 'pantalla_ficha_proveedor.dart';

class PantallaProveedoresAdmin extends ConsumerStatefulWidget {
	const PantallaProveedoresAdmin({super.key});

	@override
	ConsumerState<PantallaProveedoresAdmin> createState() =>
		_PantallaProveedoresAdminState();
}

class _PantallaProveedoresAdminState extends ConsumerState<PantallaProveedoresAdmin> {
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	Future<void> _refrescar() async {
		invalidarProveedores(ref);
		await ref.read(proveedoresAdminProvider.future);
	}

	List<Proveedor> _filtrar(List<Proveedor> proveedores) {
		if (_filtro.isEmpty) {
			return proveedores;
		}
		final q = _filtro.toLowerCase();
		return proveedores.where((p) {
			return p.nombre.toLowerCase().contains(q) ||
				p.contacto.toLowerCase().contains(q) ||
				p.telefono.toLowerCase().contains(q) ||
				p.email.toLowerCase().contains(q) ||
				p.rfc.toLowerCase().contains(q);
		}).toList();
	}

	@override
	Widget build(BuildContext context) {
		final proveedoresAsync = ref.watch(proveedoresAdminProvider);

		return Scaffold(
			appBar: AppBar(
				title: const Text('Proveedores'),
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
				icon: const Icon(Icons.local_shipping_outlined),
				label: const Text('Nuevo proveedor'),
			),
			body: proveedoresAsync.when(
				data: (proveedores) {
					final filtrados = _filtrar(proveedores)
					  ..sort((a, b) => a.nombre.compareTo(b.nombre));
					final conCredito = proveedores.where((p) => p.diasCredito > 0).length;

					return Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							EncabezadoListaAdmin(
								descripcion:
									'Proveedores para compras, entradas de inventario y vínculo con productos.',
								chips: [
									ChipResumenAdmin(
										icono: Icons.storefront_outlined,
										etiqueta: '${proveedores.length} total',
									),
									if (conCredito > 0)
										ChipResumenAdmin(
											icono: Icons.schedule_outlined,
											etiqueta: '$conCredito con crédito',
										),
								],
							),
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar por nombre, contacto, teléfono o RFC',
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
													icono: Icons.local_shipping_outlined,
													titulo: proveedores.isEmpty
														? 'Sin proveedores registrados'
														: 'Sin coincidencias',
													subtitulo: proveedores.isEmpty
														? 'Registre proveedores para asociarlos a compras '
															'y vincular productos del catálogo.'
														: 'Pruebe con otro término de búsqueda.',
													textoBoton:
														proveedores.isEmpty ? 'Agregar proveedor' : null,
													onAgregar:
														proveedores.isEmpty ? _mostrarDialogoNuevo : null,
												),
											],
										)
										: ListView.builder(
											padding: const EdgeInsets.only(top: 8.0, bottom: 88.0),
											itemCount: filtrados.length,
											itemBuilder: (_, i) => _tarjetaProveedor(filtrados[i]),
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

	Widget _tarjetaProveedor(Proveedor p) {
		final subtitulo = [
			if (p.contacto.isNotEmpty) p.contacto,
			if (p.telefono.isNotEmpty) p.telefono,
		].join(' · ');

		return TarjetaEntidadAdmin(
			titulo: p.nombre,
			subtitulo: subtitulo.isEmpty ? null : subtitulo,
			iconoAvatar: Icons.local_shipping_outlined,
			colorAvatar: PosiaColors.neutro,
			inactivo: !p.activo,
			onTap: () => _abrirFicha(p),
			onEliminar: () => _confirmarEliminar(p),
			chips: [
				if (p.diasCredito > 0)
					ChipDetalleEntidad(
						icono: Icons.schedule_outlined,
						texto: 'Crédito · ${p.diasCredito} días',
					),
				if (p.email.isNotEmpty)
					ChipDetalleEntidad(
						icono: Icons.email_outlined,
						texto: p.email,
					),
				if (p.rfc.isNotEmpty)
					ChipDetalleEntidad(
						icono: Icons.badge_outlined,
						texto: p.rfc,
					),
				if (!p.activo)
					const ChipDetalleEntidad(
						icono: Icons.block,
						texto: 'Inactivo',
					),
			],
		);
	}

	Future<void> _mostrarDialogoNuevo() async {
		final nombreController = TextEditingController();
		final contactoController = TextEditingController();
		final telefonoController = TextEditingController();
		final crear = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Nuevo proveedor'),
				content: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							TextField(
								controller: nombreController,
								autofocus: true,
								textCapitalization: TextCapitalization.words,
								decoration: const InputDecoration(
									labelText: 'Nombre o razón social *',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 12.0),
							TextField(
								controller: contactoController,
								decoration: const InputDecoration(
									labelText: 'Persona de contacto',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 12.0),
							TextField(
								controller: telefonoController,
								keyboardType: TextInputType.phone,
								decoration: const InputDecoration(
									labelText: 'Teléfono',
									border: OutlineInputBorder(),
								),
							),
						],
					),
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
		final contacto = contactoController.text.trim();
		final telefono = telefonoController.text.trim();
		nombreController.dispose();
		contactoController.dispose();
		telefonoController.dispose();
		if (crear != true || nombre.isEmpty || !mounted) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final proveedor = await servicio.registrarProveedor(
			nombre: nombre,
			contacto: contacto,
			telefono: telefono,
		);
		invalidarProveedores(ref);
		if (!mounted) {
			return;
		}
		await _abrirFicha(proveedor);
	}

	Future<void> _abrirFicha(Proveedor proveedor) async {
		await Navigator.of(context).push<void>(
			MaterialPageRoute<void>(
				builder: (_) => PantallaFichaProveedor(proveedor: proveedor),
			),
		);
		invalidarProveedores(ref);
	}

	Future<void> _confirmarEliminar(Proveedor proveedor) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				icon: const Icon(Icons.delete_outline, color: PosiaColors.cancelar),
				title: const Text('Eliminar proveedor'),
				content: Text(
					'¿Eliminar permanentemente a "${proveedor.nombre}"?\n\n'
					'Los productos vinculados quedarán sin proveedor. '
					'No es posible si tiene compras registradas.',
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
			await servicio.eliminarProveedor(proveedor.id);
			invalidarProveedores(ref);
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Proveedor eliminado')),
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
