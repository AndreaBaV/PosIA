/// Administracion de categorias personalizables.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaCategoriasAdmin extends ConsumerStatefulWidget {
	const PantallaCategoriasAdmin({super.key});

	@override
	ConsumerState<PantallaCategoriasAdmin> createState() =>
		_PantallaCategoriasAdminState();
}

class _PantallaCategoriasAdminState extends ConsumerState<PantallaCategoriasAdmin> {
	final _nombreController = TextEditingController();
	final _busquedaController = TextEditingController();
	String _filtro = '';
	String _iconoNuevo = 'shopping_basket';
	String _colorNuevo = '#4CAF50';
	String? _origenLote;
	String? _destinoLote;
	var _moviendo = false;

	@override
	void dispose() {
		_nombreController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	static const _claveHuerfanos = '__sin_categoria__';

	String _claveOrigen(ResumenGrupoCategoria grupo) =>
		grupo.esHuerfano ? _claveHuerfanos : grupo.origenId;

	String _idOrigen(String clave) =>
		clave == _claveHuerfanos ? '' : clave;

	@override
	Widget build(BuildContext context) {
		final vistaAsync = ref.watch(_vistaCategoriasProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Categorías')),
			body: vistaAsync.when(
				data: (vista) {
					final categorias = vista.categorias;
					final filtradas = categorias.where((c) {
						if (_filtro.isEmpty) {
							return true;
						}
						return c.nombre.toLowerCase().contains(_filtro.toLowerCase());
					}).toList();
					final conteo = {
						for (final g in vista.grupos) g.origenId: g,
					};
					return ListView(
						padding: const EdgeInsets.only(bottom: 24.0),
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar categoría...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							_tarjetaLote(vista),
							const Padding(
								padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
								child: Text(
									'Cada tarjeta muestra productos de muestra para reconocer '
									'el grupo aunque lo haya renombrado. Eliminar está en '
									'el botón rojo de cada tarjeta.',
								),
							),
							...filtradas.asMap().entries.map((entry) {
								final indice = entry.key;
								final c = entry.value;
								return _tarjetaCategoria(
									categoria: c,
									todas: categorias,
									grupo: conteo[c.id],
									indice: indice,
									total: filtradas.length,
								);
							}),
							...vista.grupos
								.where(
									(g) =>
										g.esHuerfano ||
										g.esStub ||
										g.esDesconocida ||
										!categorias.any((c) => c.id == g.origenId),
								)
								.map(
									(g) => _tarjetaGrupoExtra(g, categorias),
								),
							const Divider(height: 32.0),
							_formularioNueva(),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Widget _tarjetaLote(_VistaCategorias vista) {
		final origenes = vista.grupos;
		final destinos = vista.categorias;
		if (origenes.isEmpty || destinos.isEmpty) {
			return const SizedBox.shrink();
		}
		final origenSel = origenes
			.where((g) => _claveOrigen(g) == _origenLote)
			.firstOrNull;
		final destinoValido = destinos.any((c) => c.id == _destinoLote)
			? _destinoLote
			: null;
		return Card(
			margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
			color: Theme.of(context).colorScheme.surfaceContainerHighest,
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							'Reasignar productos por lote',
							style: Theme.of(context).textTheme.titleMedium,
						),
						const SizedBox(height: 4),
						const Text(
							'Cree primero las categorías limpias (abajo). Luego mueva '
							'cada grupo viejo hacia ellas. Use los productos de muestra '
							'para saber qué es cada grupo.',
						),
						const SizedBox(height: 12),
						InputDecorator(
							decoration: const InputDecoration(
								labelText: 'Mover productos de',
								border: OutlineInputBorder(),
							),
							child: DropdownButtonHideUnderline(
								child: DropdownButton<String>(
									value: origenes.any((g) => _claveOrigen(g) == _origenLote)
										? _origenLote
										: null,
									isExpanded: true,
									hint: const Text('Elija el grupo a vaciar'),
									items: [
										for (final g in origenes)
											DropdownMenuItem(
												value: _claveOrigen(g),
												child: Text(
													'${g.etiqueta} · ${g.productos} · ${_textoMuestras(g)}',
													overflow: TextOverflow.ellipsis,
												),
											),
									],
									onChanged: _moviendo
										? null
										: (v) => setState(() => _origenLote = v),
								),
							),
						),
						const SizedBox(height: 12),
						InputDecorator(
							decoration: const InputDecoration(
								labelText: 'Hacia la categoría',
								border: OutlineInputBorder(),
							),
							child: DropdownButtonHideUnderline(
								child: DropdownButton<String>(
									value: destinoValido,
									isExpanded: true,
									hint: const Text('Elija la categoría limpia'),
									items: [
										for (final c in destinos)
											if (c.id != _idOrigen(_origenLote ?? ''))
												DropdownMenuItem(
													value: c.id,
													child: Text(
														c.activa
															? c.nombre
															: '${c.nombre} (desactivada)',
													),
												),
									],
									onChanged: _moviendo
										? null
										: (v) => setState(() => _destinoLote = v),
								),
							),
						),
						const SizedBox(height: 12),
						FilledButton.icon(
							onPressed: _moviendo ||
									origenSel == null ||
									destinoValido == null
								? null
								: () => _moverLote(
										origenSel.origenId,
										destinoValido,
									),
							icon: _moviendo
								? const SizedBox(
										width: 18,
										height: 18,
										child: CircularProgressIndicator(strokeWidth: 2),
									)
								: const Icon(Icons.drive_file_move),
							label: Text(
								origenSel == null
									? 'Mover productos'
									: 'Mover ${origenSel.productos} productos',
							),
						),
					],
				),
			),
		);
	}

	Widget _tarjetaCategoria({
		required Categoria categoria,
		required List<Categoria> todas,
		required ResumenGrupoCategoria? grupo,
		required int indice,
		required int total,
	}) {
		final color = IconosCategoria.resolverColor(categoria.colorHex);
		final n = grupo?.productos ?? 0;
		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
			child: Padding(
				padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							children: [
								CircleAvatar(
									backgroundColor: color.withValues(alpha: 0.2),
									child: Icon(
										IconosCategoria.resolver(categoria.icono),
										color: color,
									),
								),
								const SizedBox(width: 12),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												categoria.nombre,
												style: const TextStyle(fontWeight: FontWeight.w600),
											),
											Text(
												n == 0
													? 'Sin productos · orden ${categoria.orden + 1}'
													: '$n productos · ${_textoMuestras(grupo!)}',
											),
										],
									),
								),
								IconButton(
									tooltip: 'Subir',
									icon: const Icon(Icons.arrow_upward),
									onPressed: indice > 0
										? () => _moverOrden(todas, categoria.id, -1)
										: null,
								),
								IconButton(
									tooltip: 'Bajar',
									icon: const Icon(Icons.arrow_downward),
									onPressed: indice < total - 1
										? () => _moverOrden(todas, categoria.id, 1)
										: null,
								),
							],
						),
						const SizedBox(height: 4),
						Wrap(
							spacing: 8,
							runSpacing: 4,
							crossAxisAlignment: WrapCrossAlignment.center,
							children: [
								Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										const Text('Activa'),
										Switch(
											value: categoria.activa,
											onChanged: (activa) async {
												final servicio =
													await ref.read(servicioAdminProvider.future);
												await servicio.actualizarCategoria(
													categoria.copiarCon(activa: activa),
												);
												ref.invalidate(_vistaCategoriasProvider);
											},
										),
									],
								),
								TextButton(
									onPressed: () => _editar(categoria),
									child: const Text('Editar'),
								),
								if (n > 0)
									TextButton(
										onPressed: () => _moverGrupo(grupo!, todas),
										child: const Text('Mover productos'),
									),
								TextButton(
									onPressed: () => _eliminar(categoria, todas),
									style: TextButton.styleFrom(
										foregroundColor: PosiaColors.cancelar,
									),
									child: const Text('Eliminar'),
								),
							],
						),
					],
				),
			),
		);
	}

	Widget _tarjetaGrupoExtra(
		ResumenGrupoCategoria grupo,
		List<Categoria> destinos,
	) {
		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
			child: ListTile(
				leading: const Icon(Icons.warning_amber, color: Colors.orange),
				title: Text(grupo.etiqueta),
				subtitle: Text(
					'${grupo.productos} productos · ${_textoMuestras(grupo)}',
				),
				trailing: TextButton(
					onPressed: () => _moverGrupo(grupo, destinos),
					child: const Text('Mover'),
				),
			),
		);
	}

	Widget _formularioNueva() {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 16.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						'Nueva categoría',
						style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 12.0),
					TextField(
						controller: _nombreController,
						decoration: const InputDecoration(
							labelText: 'Nombre',
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 12.0),
					const Text('Icono'),
					const SizedBox(height: 4.0),
					Wrap(
						spacing: 8.0,
						children: IconosCategoria.opciones.entries.map((e) {
							final seleccionado = _iconoNuevo == e.key;
							return ChoiceChip(
								selected: seleccionado,
								label: Icon(e.value),
								onSelected: (_) => setState(() => _iconoNuevo = e.key),
							);
						}).toList(),
					),
					const SizedBox(height: 12.0),
					const Text('Color'),
					const SizedBox(height: 4.0),
					Wrap(
						spacing: 8.0,
						children: IconosCategoria.colores.entries.map((e) {
							final seleccionado = _colorNuevo == e.value;
							return ChoiceChip(
								selected: seleccionado,
								label: Text(e.key),
								avatar: CircleAvatar(
									backgroundColor: IconosCategoria.resolverColor(e.value),
									radius: 8.0,
								),
								onSelected: (_) => setState(() => _colorNuevo = e.value),
							);
						}).toList(),
					),
					const SizedBox(height: 16.0),
					FilledButton.icon(
						onPressed: _agregarCategoria,
						icon: const Icon(Icons.add),
						label: const Text('Agregar categoría'),
					),
				],
			),
		);
	}

	String _textoMuestras(ResumenGrupoCategoria grupo) {
		if (grupo.muestras.isEmpty) {
			return 'sin nombres';
		}
		return grupo.muestras.join(', ');
	}

	Future<void> _moverLote(
		String origenId,
		String destinoId,
	) async {
		setState(() => _moviendo = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final n = await servicio.moverProductosDeCategoria(
				origenId: origenId,
				destinoId: destinoId,
			);
			ref.invalidate(_vistaCategoriasProvider);
			await refrescarDatosMaestros(ref);
			if (!mounted) {
				return;
			}
			setState(() {
				_origenLote = null;
				_destinoLote = destinoId;
			});
			_aviso('Se movieron $n productos', ok: true);
		} on Object catch (error) {
			_aviso('$error');
		} finally {
			if (mounted) {
				setState(() => _moviendo = false);
			}
		}
	}

	Future<void> _moverGrupo(
		ResumenGrupoCategoria grupo,
		List<Categoria> todas,
	) async {
		final destinos = todas.where((c) => c.id != grupo.origenId).toList();
		if (destinos.isEmpty) {
			_aviso(
				'Cree primero la categoría limpia (abajo) y luego mueva los productos.',
			);
			return;
		}
		var destinoId = destinos.length == 1 ? destinos.first.id : null;
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (context, setDialogState) => AlertDialog(
					title: const Text('Mover productos'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text(
								'${grupo.productos} productos de "${grupo.etiqueta}".\n'
								'${_textoMuestras(grupo)}',
							),
							const SizedBox(height: 16),
							InputDecorator(
								decoration: const InputDecoration(
									labelText: 'Nueva categoría',
									border: OutlineInputBorder(),
								),
								child: DropdownButtonHideUnderline(
									child: DropdownButton<String>(
										value: destinos.any((c) => c.id == destinoId)
											? destinoId
											: null,
										isExpanded: true,
										hint: const Text('Elija categoría'),
										items: [
											for (final c in destinos)
												DropdownMenuItem(
													value: c.id,
													child: Text(
														c.activa ? c.nombre : '${c.nombre} (desactivada)',
													),
												),
										],
										onChanged: (v) =>
											setDialogState(() => destinoId = v),
									),
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
							onPressed: destinoId == null
								? null
								: () => Navigator.pop(ctx, true),
							child: const Text('Mover'),
						),
					],
				),
			),
		);
		if (confirmar != true) {
			return;
		}
		final elegido = destinoId;
		if (elegido == null) {
			return;
		}
		await _moverLote(grupo.origenId, elegido);
	}

	Future<void> _moverOrden(List<Categoria> categorias, String id, int delta) async {
		final ids = categorias.map((c) => c.id).toList();
		final indice = ids.indexOf(id);
		final nuevoIndice = indice + delta;
		if (nuevoIndice < 0 || nuevoIndice >= ids.length) {
			return;
		}
		final temp = ids[indice];
		ids[indice] = ids[nuevoIndice];
		ids[nuevoIndice] = temp;
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.reordenarCategorias(ids);
		ref.invalidate(_vistaCategoriasProvider);
		await refrescarDatosMaestros(ref);
	}

	Future<void> _editar(Categoria categoria) async {
		final nombreController = TextEditingController(text: categoria.nombre);
		var icono = categoria.icono;
		var color = categoria.colorHex;
		final guardar = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (context, setDialogState) => AlertDialog(
					title: const Text('Editar categoría'),
					content: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								TextField(
									controller: nombreController,
									decoration: const InputDecoration(labelText: 'Nombre'),
								),
								const SizedBox(height: 12.0),
								Wrap(
									spacing: 6.0,
									children: IconosCategoria.opciones.entries.map((e) {
										return ChoiceChip(
											selected: icono == e.key,
											label: Icon(e.value, size: 20.0),
											onSelected: (_) => setDialogState(() => icono = e.key),
										);
									}).toList(),
								),
								const SizedBox(height: 8.0),
								Wrap(
									spacing: 6.0,
									children: IconosCategoria.colores.entries.map((e) {
										return ChoiceChip(
											selected: color == e.value,
											label: Text(e.key, style: const TextStyle(fontSize: 11.0)),
											onSelected: (_) => setDialogState(() => color = e.value),
										);
									}).toList(),
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
							child: const Text('Guardar'),
						),
					],
				),
			),
		);
		if (guardar != true) {
			nombreController.dispose();
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarCategoria(
			categoria.copiarCon(
				nombre: nombreController.text.trim(),
				icono: icono,
				colorHex: color,
			),
		);
		nombreController.dispose();
		ref.invalidate(_vistaCategoriasProvider);
		await refrescarDatosMaestros(ref);
	}

	Future<void> _eliminar(
		Categoria categoria,
		List<Categoria> todas,
	) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final productos = await servicio.contarProductosDeCategoria(categoria.id);
		if (!mounted) {
			return;
		}
		final destinos = todas.where((c) => c.id != categoria.id).toList();
		if (productos > 0 && destinos.isEmpty) {
			_aviso(
				'Cree otra categoría para pasar los productos antes de eliminar esta.',
			);
			return;
		}
		var destinoId = destinos.length == 1 ? destinos.first.id : null;
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (context, setDialogState) => AlertDialog(
					icon: const Icon(
						Icons.delete_outline,
						color: PosiaColors.cancelar,
					),
					title: const Text('Eliminar categoría'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text(
								productos == 0
									? '¿Eliminar "${categoria.nombre}"? No tiene productos.'
									: 'Hay $productos producto${productos == 1 ? '' : 's'} '
										'en "${categoria.nombre}". Hay que pasarlos a otra '
										'categoría para no dejarlos sin grupo.',
							),
							if (productos > 0) ...[
								const SizedBox(height: 16),
								InputDecorator(
									decoration: const InputDecoration(
										labelText: 'Pasar productos a',
										border: OutlineInputBorder(),
									),
									child: DropdownButtonHideUnderline(
										child: DropdownButton<String>(
											value: destinos.any((c) => c.id == destinoId)
												? destinoId
												: null,
											isExpanded: true,
											hint: const Text('Elija categoría'),
											items: [
												for (final c in destinos)
													DropdownMenuItem(
														value: c.id,
														child: Text(
															c.activa
																? c.nombre
																: '${c.nombre} (desactivada)',
														),
													),
											],
											onChanged: (v) =>
												setDialogState(() => destinoId = v),
										),
									),
								),
							],
						],
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(ctx, false),
							child: const Text('Cancelar'),
						),
						FilledButton(
							style: FilledButton.styleFrom(
								backgroundColor: PosiaColors.cancelar,
							),
							onPressed: productos > 0 && destinoId == null
								? null
								: () => Navigator.pop(ctx, true),
							child: const Text('Eliminar'),
						),
					],
				),
			),
		);
		if (confirmar != true) {
			return;
		}
		try {
			await servicio.eliminarCategoria(
				categoria.id,
				categoriaDestinoId: productos > 0 ? destinoId : null,
			);
			ref.invalidate(_vistaCategoriasProvider);
			await refrescarDatosMaestros(ref);
			if (!mounted) {
				return;
			}
			_aviso(
				productos == 0
					? 'Se eliminó "${categoria.nombre}"'
					: 'Se eliminó "${categoria.nombre}" y se pasaron $productos productos',
				ok: true,
			);
		} on Object catch (error) {
			_aviso('$error');
		}
	}

	Future<void> _agregarCategoria() async {
		final nombre = _nombreController.text.trim();
		if (nombre.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarCategoria(
			nombre: nombre,
			icono: _iconoNuevo,
			colorHex: _colorNuevo,
		);
		_nombreController.clear();
		ref.invalidate(_vistaCategoriasProvider);
		await refrescarDatosMaestros(ref);
	}

	void _aviso(String texto, {bool ok = false}) {
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(
				content: Text(texto),
				backgroundColor: ok ? PosiaColors.cobrar : null,
			),
		);
	}
}

class _VistaCategorias {
	const _VistaCategorias({
		required this.categorias,
		required this.grupos,
	});

	final List<Categoria> categorias;
	final List<ResumenGrupoCategoria> grupos;
}

final _vistaCategoriasProvider = FutureProvider<_VistaCategorias>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final categorias = await servicio.listarCategorias();
	final grupos = await servicio.listarGruposProductosCategoria();
	return _VistaCategorias(categorias: categorias, grupos: grupos);
});
