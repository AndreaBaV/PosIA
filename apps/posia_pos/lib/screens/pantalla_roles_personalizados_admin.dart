/// Administracion de roles personalizados con permisos granulares.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaRolesPersonalizadosAdmin extends ConsumerStatefulWidget {
	const PantallaRolesPersonalizadosAdmin({super.key});

	@override
	ConsumerState<PantallaRolesPersonalizadosAdmin> createState() =>
		_PantallaRolesPersonalizadosAdminState();
}

class _PantallaRolesPersonalizadosAdminState
	extends ConsumerState<PantallaRolesPersonalizadosAdmin> {
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final rolesAsync = ref.watch(rolesPersonalizadosAdminProvider);
		final categoriasAsync = ref.watch(categoriasFormularioAdminProvider);
		final operador = ref.watch(sesionUsuarioProvider);
		final puedeGestionar = operador != null &&
			PoliticaAccesoAdmin.puedeGestionarRolesPersonalizados(operador);

		return Scaffold(
			appBar: AppBar(title: const Text('Roles personalizados')),
			floatingActionButton: puedeGestionar
				? FloatingActionButton.extended(
					onPressed: () => _abrirFormulario(
						categorias: categoriasAsync.value ?? [],
					),
					icon: const Icon(Icons.add),
					label: const Text('Nuevo rol'),
				)
				: null,
			body: rolesAsync.when(
				data: (roles) {
					final filtrados = roles.where((rol) {
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						return rol.nombre.toLowerCase().contains(q) ||
							rol.descripcion.toLowerCase().contains(q);
					}).toList();
					return ListView(
						padding: const EdgeInsets.only(bottom: 88.0),
						children: [
							Padding(
								padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
								child: Card(
									child: Padding(
										padding: const EdgeInsets.all(12.0),
										child: Text(
											'Cree roles como "pre-supervisor" con acceso limitado al panel '
											'de administración. Asigne el rol al crear o editar cuentas de equipo.',
											style: Theme.of(context).textTheme.bodySmall,
										),
									),
								),
							),
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar rol...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							if (filtrados.isEmpty)
								const Padding(
									padding: EdgeInsets.all(24.0),
									child: Center(child: Text('Sin roles personalizados')),
								),
							...filtrados.map(
								(rol) => _tarjetaRol(
									rol,
									puedeGestionar: puedeGestionar,
									categorias: categoriasAsync.value ?? [],
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

	Widget _tarjetaRol(
		RolPersonalizado rol, {
		required bool puedeGestionar,
		required List<Categoria> categorias,
	}) {
		final resumenPermisos = rol.permisosAdmin
			.map((c) => PermisosAdmin.etiquetas[c] ?? c)
			.take(4)
			.join(', ');
		final extraPermisos = rol.permisosAdmin.length > 4
			? ' (+${rol.permisosAdmin.length - 4})'
			: '';
		final resumenCategorias = _resumenCategorias(rol, categorias);

		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
			child: ListTile(
				leading: CircleAvatar(
					backgroundColor: rol.activo
						? Colors.indigo.withValues(alpha: 0.15)
						: Colors.grey.shade200,
					child: Icon(
						Icons.admin_panel_settings,
						color: rol.activo ? Colors.indigo : Colors.grey,
					),
				),
				title: Text(
					rol.nombre,
					style: TextStyle(
						fontWeight: FontWeight.w600,
						decoration: rol.activo ? null : TextDecoration.lineThrough,
					),
				),
				subtitle: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						if (rol.descripcion.isNotEmpty) Text(rol.descripcion),
						const SizedBox(height: 4.0),
						Text(
							'$resumenPermisos$extraPermisos',
							style: Theme.of(context).textTheme.bodySmall,
						),
						if (resumenCategorias != null)
							Text(
								resumenCategorias,
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: Colors.deepOrange.shade700,
								),
							),
					],
				),
				trailing: puedeGestionar
					? IconButton(
						icon: const Icon(Icons.edit_outlined),
						onPressed: () => _abrirFormulario(
							editando: rol,
							categorias: categorias,
						),
					)
					: null,
				onTap: puedeGestionar
					? () => _abrirFormulario(editando: rol, categorias: categorias)
					: null,
			),
		);
	}

	String? _resumenCategorias(RolPersonalizado rol, List<Categoria> categorias) {
		if (!rol.restringeCategoriasProducto) {
			return null;
		}
		final nombres = categorias
			.where((c) => rol.categoriasPermitidas.contains(c.id))
			.map((c) => c.nombre)
			.toList();
		if (nombres.isEmpty) {
			return 'Productos: ${rol.categoriasPermitidas.length} categorías';
		}
		return 'Productos: ${nombres.join(', ')}';
	}

	Future<void> _abrirFormulario({
		RolPersonalizado? editando,
		required List<Categoria> categorias,
	}) async {
		final operador = ref.read(sesionUsuarioProvider);
		if (operador == null) {
			return;
		}
		final nombreController = TextEditingController(text: editando?.nombre ?? '');
		final descripcionController = TextEditingController(
			text: editando?.descripcion ?? '',
		);
		var permisos = Set<String>.from(editando?.permisosAdmin ?? []);
		var categoriasSeleccionadas = Set<String>.from(
			editando?.categoriasPermitidas ?? [],
		);
		var activo = editando?.activo ?? true;

		if (!mounted) {
			return;
		}

		await showDialog<void>(
			context: context,
			barrierDismissible: false,
			builder: (ctx) {
				var guardando = false;
				return StatefulBuilder(
					builder: (ctx, setLocal) {
						final muestraCategorias =
							permisos.contains(PermisosAdmin.productos) &&
							categorias.isNotEmpty;
						return PopScope(
							canPop: !guardando,
							child: AlertDialog(
								title: Text(editando == null ? 'Nuevo rol' : 'Editar rol'),
								content: SingleChildScrollView(
									child: AbsorbPointer(
										absorbing: guardando,
										child: Opacity(
											opacity: guardando ? 0.55 : 1.0,
											child: SizedBox(
												width: 420.0,
												child: Column(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.stretch,
													children: [
														TextField(
															controller: nombreController,
															textCapitalization: TextCapitalization.sentences,
															decoration: const InputDecoration(
																labelText: 'Nombre del rol',
																border: OutlineInputBorder(),
																hintText: 'Ej. Pre-supervisor',
															),
														),
														const SizedBox(height: 12.0),
														TextField(
															controller: descripcionController,
															maxLines: 2,
															decoration: const InputDecoration(
																labelText: 'Descripción (opcional)',
																border: OutlineInputBorder(),
															),
														),
														const SizedBox(height: 16.0),
														Text(
															'Permisos de administración',
															style: Theme.of(context).textTheme.titleSmall,
														),
														const SizedBox(height: 8.0),
														...PermisosAdmin.secciones.entries.map((seccion) {
															return Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	Text(
																		seccion.key,
																		style: Theme.of(context)
																			.textTheme
																			.labelLarge,
																	),
																	...seccion.value.map((clave) {
																		return CheckboxListTile(
																			contentPadding: EdgeInsets.zero,
																			dense: true,
																			title: Text(
																				PermisosAdmin.etiquetas[clave] ??
																					clave,
																			),
																			value: permisos.contains(clave),
																			onChanged: (v) => setLocal(() {
																				if (v == true) {
																					permisos.add(clave);
																				} else {
																					permisos.remove(clave);
																					if (clave ==
																						PermisosAdmin.productos) {
																						categoriasSeleccionadas
																							.clear();
																					}
																				}
																			}),
																		);
																	}),
																	const SizedBox(height: 4.0),
																],
															);
														}),
														if (muestraCategorias) ...[
															const Divider(),
															Text(
																'Categorías de productos editables',
																style: Theme.of(context).textTheme.titleSmall,
															),
															const SizedBox(height: 4.0),
															Text(
																'Si no selecciona ninguna, podrá editar '
																'todas las categorías.',
																style: Theme.of(context).textTheme.bodySmall,
															),
															const SizedBox(height: 8.0),
															...categorias.where((c) => c.activa).map((c) {
																return CheckboxListTile(
																	contentPadding: EdgeInsets.zero,
																	dense: true,
																	title: Text(c.nombre),
																	value: categoriasSeleccionadas.contains(c.id),
																	onChanged: (v) => setLocal(() {
																		if (v == true) {
																			categoriasSeleccionadas.add(c.id);
																		} else {
																			categoriasSeleccionadas.remove(c.id);
																		}
																	}),
																);
															}),
														],
														if (editando != null) ...[
															const SizedBox(height: 8.0),
															SwitchListTile(
																contentPadding: EdgeInsets.zero,
																title: const Text('Rol activo'),
																value: activo,
																onChanged: (v) => setLocal(() => activo = v),
															),
														],
													],
												),
											),
										),
									),
								),
								actions: [
									TextButton(
										onPressed: guardando ? null : () => Navigator.pop(ctx),
										child: const Text('Cancelar'),
									),
									FilledButton(
										onPressed: guardando
											? null
											: () async {
												setLocal(() => guardando = true);
												try {
													final servicio =
														await ref.read(servicioAdminProvider.future);
													final rol = (editando ??
															RolPersonalizado(
																id: '',
																nombre: '',
																permisosAdmin: const [],
																activo: true,
															))
														.copiarCon(
															nombre: nombreController.text.trim(),
															descripcion: descripcionController.text.trim(),
															permisosAdmin: permisos.toList(),
															categoriasPermitidas:
																categoriasSeleccionadas.toList(),
															activo: activo,
														);
													if (editando == null) {
														await servicio.crearRolPersonalizado(
															nombre: rol.nombre,
															descripcion: rol.descripcion,
															permisosAdmin: rol.permisosAdmin,
															categoriasPermitidas: rol.categoriasPermitidas,
															operador: operador,
														);
													} else {
														await servicio.guardarRolPersonalizado(
															rol,
															operador: operador,
														);
													}
													ref.invalidate(rolesPersonalizadosAdminProvider);
													ref.invalidate(rolesPersonalizadosActivosProvider);
													if (ctx.mounted) {
														Navigator.pop(ctx);
													}
													if (mounted) {
														PosiaNotificaciones.mostrarSnackBar(
															context,
															SnackBar(
																content: Text(
																	editando == null
																		? 'Rol creado'
																		: 'Rol actualizado',
																),
															),
														);
													}
												} on StateError catch (e) {
													if (ctx.mounted) {
														setLocal(() => guardando = false);
														PosiaNotificaciones.mostrarSnackBar(
															ctx,
															SnackBar(
																content: Text(e.message),
																backgroundColor: PosiaColors.cancelar,
															),
														);
													}
												}
											},
										child: guardando
											? const Text('Guardando...')
											: const Text('Guardar'),
									),
								],
							),
						);
					},
				);
			},
		);

		nombreController.dispose();
		descripcionController.dispose();
	}
}
