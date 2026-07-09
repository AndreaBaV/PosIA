/// Gestion de cuentas de usuario segun rol del operador.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaUsuariosAdmin extends ConsumerStatefulWidget {
	const PantallaUsuariosAdmin({super.key});

	@override
	ConsumerState<PantallaUsuariosAdmin> createState() => _PantallaUsuariosAdminState();
}

class _PantallaUsuariosAdminState extends ConsumerState<PantallaUsuariosAdmin> {
	final _nombreController = TextEditingController();
	final _pinController = TextEditingController();
	final _tarifaController = TextEditingController();
	final _busquedaController = TextEditingController();
	String _filtro = '';
	String? _actualizandoUsuarioId;

	@override
	void dispose() {
		_nombreController.dispose();
		_pinController.dispose();
		_tarifaController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final usuariosAsync = ref.watch(_usuariosAdminProvider);
		final operador = ref.watch(sesionUsuarioProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Equipo')),
			floatingActionButton: operador != null && PermisosUsuario.puedeGestionarUsuarios(operador)
				? FloatingActionButton.extended(
					onPressed: () => _abrirFormulario(operador: operador),
					icon: const Icon(Icons.person_add),
					label: const Text('Nueva cuenta'),
				)
				: null,
			body: usuariosAsync.when(
				data: (datos) {
					final filtrados = datos.usuarios.where((u) {
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						return u.nombre.toLowerCase().contains(q) ||
							u.codigo.contains(q) ||
							PermisosUsuario.etiquetaRol(u.rol).toLowerCase().contains(q);
					}).toList();
					return ListView(
						padding: const EdgeInsets.only(bottom: 88.0),
						children: [
							Padding(
								padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
								child: Card(
									child: Padding(
										padding: const EdgeInsets.all(12.0),
										child: Row(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Icon(
													Icons.phone_android,
													color: Theme.of(context).colorScheme.primary,
												),
												const SizedBox(width: 12.0),
												Expanded(
													child: Text(
														'Cada persona entra con su código y PIN desde el celular o la caja. '
														'Sus ventas y tickets quedan a su nombre. '
														'Usted puede crear cuentas y restablecer el PIN.',
														style: Theme.of(context).textTheme.bodySmall,
													),
												),
											],
										),
									),
								),
							),
							Padding(
								padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
								child: Text(
									'${datos.usuarios.where((u) => u.activo).length} de $LIMITE_MAX_USUARIOS cuentas activas',
									style: Theme.of(context).textTheme.bodySmall,
								),
							),
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar usuario...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							if (filtrados.isEmpty)
								const Padding(
									padding: EdgeInsets.all(24.0),
									child: Center(child: Text('Sin usuarios registrados')),
								),
							...filtrados.map((u) => _tarjetaUsuario(u, datos, operador)),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Widget _tarjetaUsuario(Usuario u, _DatosUsuarios datos, Usuario? operador) {
		final puedeEditar = operador != null && PermisosUsuario.puedeGestionarUsuario(operador, u);
		final tiendaNombre = u.tiendaId == null
			? 'Todas las tiendas'
			: datos.nombresTienda[u.tiendaId] ?? u.tiendaId!;
		final colorRol = PresentacionRol.color(u.rol);
		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
			child: InkWell(
				borderRadius: BorderRadius.circular(12.0),
				onTap: puedeEditar
					? () => _abrirFormulario(operador: operador, editando: u)
					: null,
				child: Padding(
				padding: const EdgeInsets.fromLTRB(12.0, 10.0, 8.0, 10.0),
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						CircleAvatar(
							backgroundColor: colorRol.withValues(alpha: 0.15),
							child: Icon(PresentacionRol.icono(u.rol), color: colorRol, size: 22.0),
						),
						const SizedBox(width: 12.0),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										u.nombre,
										style: TextStyle(
											fontWeight: FontWeight.w600,
											fontSize: 16.0,
											decoration: u.activo ? null : TextDecoration.lineThrough,
										),
										maxLines: 1,
										overflow: TextOverflow.ellipsis,
									),
									const SizedBox(height: 8.0),
									InsigniaRol(rol: u.rol, compacto: true),
									if (u.rolPersonalizadoId != null &&
										datos.nombresRolPersonalizado[u.rolPersonalizadoId] != null)
										Padding(
											padding: const EdgeInsets.only(top: 4.0),
											child: Text(
												datos.nombresRolPersonalizado[u.rolPersonalizadoId]!,
												style: Theme.of(context).textTheme.bodySmall?.copyWith(
													color: Colors.indigo.shade700,
													fontWeight: FontWeight.w500,
												),
											),
										),
									const SizedBox(height: 8.0),
									Text(
										'Código ${u.codigo} · $tiendaNombre',
										style: Theme.of(context).textTheme.bodySmall,
										maxLines: 2,
										overflow: TextOverflow.ellipsis,
									),
									if (u.rol != RolUsuario.administrador)
										Padding(
											padding: const EdgeInsets.only(top: 2.0),
											child: Text(
												'Vende con código ${u.codigo} y PIN',
												style: Theme.of(context).textTheme.bodySmall?.copyWith(
													color: Colors.grey.shade700,
												),
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
											),
										),
								],
							),
						),
						if (puedeEditar)
							Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									if (_actualizandoUsuarioId == u.id)
										const Padding(
											padding: EdgeInsets.all(12.0),
											child: SizedBox(
												width: 24.0,
												height: 24.0,
												child: CircularProgressIndicator(strokeWidth: 2.0),
											),
										)
									else
										Switch(
											value: u.activo,
											onChanged: (activo) => _cambiarActivo(u, activo, operador),
										),
									IconButton(
										icon: const Icon(Icons.edit_outlined),
										tooltip: 'Editar',
										onPressed: _actualizandoUsuarioId != null
											? null
											: () => _abrirFormulario(
												operador: operador,
												editando: u,
											),
									),
								],
							),
					],
				),
			),
			),
		);
	}

	List<RolUsuario> _rolesDisponibles(Usuario operador, {Usuario? editando}) {
		if (operador.rol == RolUsuario.administrador) {
			return RolUsuario.values;
		}
		return [RolUsuario.empleado];
	}

	bool _puedeEditarRol(Usuario operador, Usuario? editando) {
		if (editando != null && editando.id == operador.id) {
			return false;
		}
		return operador.rol != RolUsuario.empleado;
	}

	Future<void> _abrirFormulario({
		required Usuario operador,
		Usuario? editando,
	}) async {
		final datos = await ref.read(_usuariosAdminProvider.future);
		final esEdicion = editando != null;
		_nombreController.text = editando?.nombre ?? '';
		_pinController.clear();
		var rolSeleccionado = editando?.rol ?? RolUsuario.empleado;
		var tiendaSeleccionada = editando?.tiendaId ??
			operador.tiendaId ??
			datos.tiendas.firstOrNull?.id;
		var activo = editando?.activo ?? true;
		String? rolPersonalizadoSeleccionado = editando?.rolPersonalizadoId;
		final rolesDisponibles = _rolesDisponibles(operador, editando: editando);
		if (!rolesDisponibles.contains(rolSeleccionado)) {
			rolSeleccionado = rolesDisponibles.first;
		}
		_tarifaController.clear();
		if (editando != null) {
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			final perfil = await contenedor.servicioNomina?.obtenerPerfil(editando.id);
			if (perfil != null && perfil.tarifaHora > 0) {
				_tarifaController.text = perfil.tarifaHora.toStringAsFixed(2);
			}
		}
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
						final puedeEditarRol = _puedeEditarRol(operador, editando);
						return PopScope(
							canPop: !guardando,
							child: AlertDialog(
								title: Text(esEdicion ? 'Editar cuenta' : 'Nueva cuenta'),
								content: SingleChildScrollView(
									child: AbsorbPointer(
										absorbing: guardando,
										child: Opacity(
											opacity: guardando ? 0.55 : 1.0,
											child: SizedBox(
												width: 380.0,
												child: Column(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.stretch,
													children: [
														if (esEdicion) ...[
															Row(
																children: [
																	InsigniaRol(rol: editando.rol),
																	const SizedBox(width: 8.0),
																	Text('Código ${editando.codigo}'),
																],
															),
															const SizedBox(height: 12.0),
														],
														TextField(
															controller: _nombreController,
															textCapitalization: TextCapitalization.words,
															decoration: const InputDecoration(
																labelText: 'Nombre',
																border: OutlineInputBorder(),
															),
														),
														const SizedBox(height: 12.0),
														DropdownButtonFormField<RolUsuario>(
															initialValue: rolSeleccionado,
															items: rolesDisponibles
																.map(
																	(r) => DropdownMenuItem(
																		value: r,
																		child: Text(PermisosUsuario.etiquetaRol(r)),
																	),
																)
																.toList(),
															onChanged: puedeEditarRol
																? (v) => setLocal(() {
																	rolSeleccionado = v!;
																	if (rolSeleccionado == RolUsuario.administrador) {
																		tiendaSeleccionada = null;
																		rolPersonalizadoSeleccionado = null;
																	} else {
																		tiendaSeleccionada ??=
																			operador.tiendaId ?? datos.tiendas.firstOrNull?.id;
																	}
																})
																: null,
															decoration: InputDecoration(
																labelText: 'Rol',
																border: const OutlineInputBorder(),
																helperText: puedeEditarRol
																	? null
																	: 'No puede cambiar su propio rol',
															),
														),
														if (rolSeleccionado != RolUsuario.administrador) ...[
															const SizedBox(height: 12.0),
															DropdownButtonFormField<String>(
																initialValue: tiendaSeleccionada,
																items: datos.tiendas
																	.map(
																		(t) => DropdownMenuItem(
																			value: t.id,
																			child: Text(t.nombre),
																		),
																	)
																	.toList(),
																onChanged: operador.rol == RolUsuario.administrador
																	? (v) => setLocal(() => tiendaSeleccionada = v)
																	: null,
																decoration: InputDecoration(
																	labelText: 'Tienda',
																	border: const OutlineInputBorder(),
																	helperText: operador.rol == RolUsuario.administrador
																		? null
																		: 'Solo su tienda asignada',
																),
															),
														],
														if (rolSeleccionado != RolUsuario.administrador &&
															operador.rol == RolUsuario.administrador &&
															datos.rolesPersonalizados.isNotEmpty) ...[
															const SizedBox(height: 12.0),
															DropdownButtonFormField<String?>(
																initialValue: rolPersonalizadoSeleccionado,
																items: [
																	const DropdownMenuItem<String?>(
																		value: null,
																		child: Text('Sin rol personalizado'),
																	),
																	...datos.rolesPersonalizados.map(
																		(r) => DropdownMenuItem<String?>(
																			value: r.id,
																			child: Text(r.nombre),
																		),
																	),
																],
																onChanged: puedeEditarRol
																	? (v) => setLocal(
																		() => rolPersonalizadoSeleccionado = v,
																	)
																	: null,
																decoration: const InputDecoration(
																	labelText: 'Rol personalizado',
																	border: OutlineInputBorder(),
																	helperText:
																		'Opcional: limita secciones del panel admin',
																),
															),
														],
														const SizedBox(height: 12.0),
														CampoSecreto(
															controller: _pinController,
															keyboardType: TextInputType.number,
															maxLength: LONGITUD_PIN_ADMIN,
															decoration: InputDecoration(
																labelText: esEdicion ? 'Nuevo PIN (opcional)' : 'PIN inicial',
																border: const OutlineInputBorder(),
																helperText: esEdicion
																	? 'Deje vacío para mantener el PIN actual'
																	: '4 dígitos para entrar desde el celular o la caja',
															),
														),
														if (rolSeleccionado != RolUsuario.administrador) ...[
															const SizedBox(height: 12.0),
															TextField(
																controller: _tarifaController,
																keyboardType: const TextInputType.numberWithOptions(decimal: true),
																decoration: const InputDecoration(
																	labelText: 'Tarifa por hora (MXN)',
																	border: OutlineInputBorder(),
																	prefixText: '\$ ',
																),
															),
														],
														if (!esEdicion) ...[
															const SizedBox(height: 4.0),
															Text(
																PermisosUsuario.descripcionRol(rolSeleccionado),
																style: Theme.of(context).textTheme.bodySmall,
															),
														],
														if (esEdicion) ...[
															const SizedBox(height: 8.0),
															SwitchListTile(
																contentPadding: EdgeInsets.zero,
																title: const Text('Usuario activo'),
																subtitle: editando.id == operador.id
																	? const Text('No puede desactivarse a sí mismo')
																	: null,
																value: activo,
																onChanged: editando.id == operador.id
																	? null
																	: (v) => setLocal(() => activo = v),
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
												final ok = await _guardarFormulario(
													ctx: ctx,
													operador: operador,
													editando: editando,
													rolSeleccionado: rolSeleccionado,
													tiendaSeleccionada: tiendaSeleccionada,
													activo: activo,
													rolPersonalizadoId: rolPersonalizadoSeleccionado,
												);
												if (ctx.mounted && !ok) {
													setLocal(() => guardando = false);
												}
											},
										child: guardando
											? const Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													SizedBox(
														width: 18.0,
														height: 18.0,
														child: CircularProgressIndicator(strokeWidth: 2.0),
													),
													SizedBox(width: 10.0),
													Text('Guardando...'),
												],
											)
											: const Text('Guardar'),
									),
								],
							),
						);
					},
				);
			},
		);
	}

	Future<bool> _guardarFormulario({
		required BuildContext ctx,
		required Usuario operador,
		required Usuario? editando,
		required RolUsuario rolSeleccionado,
		required String? tiendaSeleccionada,
		required bool activo,
		String? rolPersonalizadoId,
	}) async {
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			late final String usuarioId;
			if (editando == null) {
				final creado = await servicio.registrarUsuario(
					nombre: _nombreController.text,
					rol: rolSeleccionado,
					pin: _pinController.text,
					tiendaId: tiendaSeleccionada,
					rolPersonalizadoId: rolPersonalizadoId,
					operador: operador,
				);
				usuarioId = creado.id;
			} else {
				final actualizado = await servicio.actualizarUsuario(
					editando.copiarCon(
						nombre: _nombreController.text.trim(),
						rol: rolSeleccionado,
						activo: activo,
						tiendaId: tiendaSeleccionada,
						limpiarTiendaId: rolSeleccionado == RolUsuario.administrador,
						rolPersonalizadoId: rolPersonalizadoId,
						limpiarRolPersonalizado: rolSeleccionado == RolUsuario.administrador &&
							rolPersonalizadoId == null,
					),
					operador: operador,
					nuevoPin: _pinController.text,
				);
				usuarioId = actualizado.id;
				if (actualizado.id == ref.read(sesionUsuarioProvider)?.id) {
					ref.read(sesionUsuarioProvider.notifier).iniciar(actualizado);
					if (actualizado.rolPersonalizadoId != null) {
						ref.invalidate(
							rolPersonalizadoPorIdProvider(actualizado.rolPersonalizadoId!),
						);
					}
				}
			}
			if (rolSeleccionado != RolUsuario.administrador) {
				final tarifa = double.tryParse(
					_tarifaController.text.replaceAll(',', '.'),
				);
				if (tarifa != null && tarifa > 0) {
					final contenedor = await ref.read(contenedorServiciosProvider.future);
					await contenedor.servicioNomina?.guardarTarifaHora(usuarioId, tarifa);
				}
			}
			ref.invalidate(_usuariosAdminProvider);
			ref.invalidate(empleadosAsignacionProvider);
			await refrescarDatosMaestros(ref);
			if (ctx.mounted) {
				Navigator.pop(ctx);
			}
			if (mounted) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text(editando == null ? 'Cuenta creada' : 'Cuenta actualizada'),
					),
				);
			}
			return true;
		} on StateError catch (e) {
			if (ctx.mounted) {
				PosiaNotificaciones.mostrarSnackBar(ctx, 
					SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
				);
			}
			return false;
		}
	}

	Future<void> _cambiarActivo(Usuario usuario, bool activo, Usuario operador) async {
		if (usuario.id == operador.id && !activo) {
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(
					content: Text('No puede desactivar su propia cuenta'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		try {
			setState(() => _actualizandoUsuarioId = usuario.id);
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.actualizarUsuario(
				usuario.copiarCon(activo: activo),
				operador: operador,
			);
			ref.invalidate(_usuariosAdminProvider);
			ref.invalidate(empleadosAsignacionProvider);
			await refrescarDatosMaestros(ref);
			if (mounted) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text(
							activo ? '${usuario.nombre} activado' : '${usuario.nombre} desactivado',
						),
					),
				);
			}
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _actualizandoUsuarioId = null);
			}
		}
	}
}

class _DatosUsuarios {
	const _DatosUsuarios({
		required this.usuarios,
		required this.tiendas,
		required this.nombresTienda,
		required this.rolesPersonalizados,
		required this.nombresRolPersonalizado,
	});

	final List<Usuario> usuarios;
	final List<Tienda> tiendas;
	final Map<String, String> nombresTienda;
	final List<RolPersonalizado> rolesPersonalizados;
	final Map<String, String> nombresRolPersonalizado;
}

final _usuariosAdminProvider = FutureProvider<_DatosUsuarios>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final hubUrl = await servicio.obtenerHubUrl();
	if (hubUrl.isNotEmpty) {
		await servicio.repararSincronizacionUsuarios();
	}
	final operador = ref.watch(sesionUsuarioProvider);
	final usuarios = await servicio.listarUsuarios(operador: operador);
	final tiendas = await servicio.obtenerTiendasPermitidas(operador: operador);
	final rolesPersonalizados = await servicio.listarRolesPersonalizadosActivos();
	return _DatosUsuarios(
		usuarios: usuarios,
		tiendas: tiendas,
		nombresTienda: {for (final t in tiendas) t.id: t.nombre},
		rolesPersonalizados: rolesPersonalizados,
		nombresRolPersonalizado: {
			for (final r in rolesPersonalizados) r.id: r.nombre,
		},
	);
});
