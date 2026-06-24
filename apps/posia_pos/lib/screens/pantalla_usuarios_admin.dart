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
														'Cada persona entra con su codigo y PIN desde el celular o la caja. '
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
			child: ListTile(
				contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
				leading: CircleAvatar(
					backgroundColor: colorRol.withValues(alpha: 0.15),
					child: Icon(PresentacionRol.icono(u.rol), color: colorRol, size: 22.0),
				),
				title: Row(
					children: [
						Expanded(
							child: Text(
								u.nombre,
								style: TextStyle(
									fontWeight: FontWeight.w600,
									decoration: u.activo ? null : TextDecoration.lineThrough,
								),
							),
						),
						InsigniaRol(rol: u.rol, compacto: true),
					],
				),
				subtitle: Padding(
					padding: const EdgeInsets.only(top: 6.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text('Codigo ${u.codigo} · $tiendaNombre'),
							if (u.rol != RolUsuario.administrador)
								Text(
									'Vende con codigo ${u.codigo} y PIN',
									style: Theme.of(context).textTheme.bodySmall?.copyWith(
										color: Colors.grey.shade700,
									),
								),
						],
					),
				),
				trailing: puedeEditar
					? Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Switch(
								value: u.activo,
								onChanged: (activo) => _cambiarActivo(u, activo, operador),
							),
							IconButton(
								icon: const Icon(Icons.edit_outlined),
								tooltip: 'Editar',
								onPressed: () => _abrirFormulario(
									operador: operador,
									editando: u,
								),
							),
						],
					)
					: null,
				onTap: puedeEditar
					? () => _abrirFormulario(operador: operador, editando: u)
					: null,
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
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setLocal) {
					final puedeEditarRol = _puedeEditarRol(operador, editando);
					return AlertDialog(
						title: Text(esEdicion ? 'Editar cuenta' : 'Nueva cuenta'),
						content: SingleChildScrollView(
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
										const SizedBox(height: 12.0),
										CampoSecreto(
											controller: _pinController,
											keyboardType: TextInputType.number,
											maxLength: LONGITUD_PIN_ADMIN,
											decoration: InputDecoration(
												labelText: esEdicion ? 'Nuevo PIN (opcional)' : 'PIN inicial',
												border: const OutlineInputBorder(),
												helperText: esEdicion
													? 'Deje vacio para mantener el PIN actual'
													: '4 digitos para entrar desde el celular o la caja',
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
						actions: [
							TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
							FilledButton(
								onPressed: () => _guardarFormulario(
									ctx: ctx,
									operador: operador,
									editando: editando,
									rolSeleccionado: rolSeleccionado,
									tiendaSeleccionada: tiendaSeleccionada,
									activo: activo,
								),
								child: const Text('Guardar'),
							),
						],
					);
				},
			),
		);
	}

	Future<void> _guardarFormulario({
		required BuildContext ctx,
		required Usuario operador,
		required Usuario? editando,
		required RolUsuario rolSeleccionado,
		required String? tiendaSeleccionada,
		required bool activo,
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
					),
					operador: operador,
					nuevoPin: _pinController.text,
				);
				usuarioId = actualizado.id;
				if (actualizado.id == ref.read(sesionUsuarioProvider)?.id) {
					ref.read(sesionUsuarioProvider.notifier).iniciar(actualizado);
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
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text(editando == null ? 'Cuenta creada' : 'Cuenta actualizada'),
					),
				);
			}
		} on StateError catch (e) {
			if (ctx.mounted) {
				ScaffoldMessenger.of(ctx).showSnackBar(
					SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
				);
			}
		}
	}

	Future<void> _cambiarActivo(Usuario usuario, bool activo, Usuario operador) async {
		if (usuario.id == operador.id && !activo) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No puede desactivar su propia cuenta'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.actualizarUsuario(
				usuario.copiarCon(activo: activo),
				operador: operador,
			);
			ref.invalidate(_usuariosAdminProvider);
			ref.invalidate(empleadosAsignacionProvider);
			await refrescarDatosMaestros(ref);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}

class _DatosUsuarios {
	const _DatosUsuarios({
		required this.usuarios,
		required this.tiendas,
		required this.nombresTienda,
	});

	final List<Usuario> usuarios;
	final List<Tienda> tiendas;
	final Map<String, String> nombresTienda;
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
	return _DatosUsuarios(
		usuarios: usuarios,
		tiendas: tiendas,
		nombresTienda: {for (final t in tiendas) t.id: t.nombre},
	);
});
