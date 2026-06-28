/// Menu principal de administracion con accesos iconograficos.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../util/catalogo_menu_admin.dart';

/// Panel admin organizado por secciones operativas.
class PantallaAdmin extends StatefulWidget {
	const PantallaAdmin({required this.usuario, super.key});

	final Usuario usuario;

	@override
	State<PantallaAdmin> createState() => _PantallaAdminState();
}

class _PantallaAdminState extends State<PantallaAdmin> {
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final catalogo = construirCatalogoMenuAdmin(widget.usuario);
		final filtradas = filtrarCatalogoMenuAdmin(catalogo, _filtro);
		final colorRol = PresentacionRol.color(widget.usuario.rol);
		final compacto = LayoutResponsivo.de(context) == TipoPantalla.compacto;
		final buscando = _filtro.trim().isNotEmpty;

		return Scaffold(
			appBar: compacto
				? null
				: AppBar(
					title: const Text('Administración'),
				),
			body: LayoutBuilder(
				builder: (context, constraints) {
					final padding = LayoutResponsivo.padding(constraints.maxWidth);
					final columnas = LayoutResponsivo.columnasGrid(constraints.maxWidth);
					final agrupadas = agruparPorSeccion(filtradas);

					return ListView(
						padding: EdgeInsets.fromLTRB(
							padding,
							compacto ? 8.0 : padding,
							padding,
							padding,
						),
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar en administración…',
								alCambiar: (v) => setState(() => _filtro = v),
							),
							if (buscando) ...[
								Padding(
									padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
									child: Text(
										filtradas.isEmpty
											? 'Sin resultados para "$_filtro"'
											: '${filtradas.length} resultado${filtradas.length == 1 ? '' : 's'}',
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
											color: Colors.grey.shade700,
										),
									),
								),
								if (filtradas.isEmpty)
									Padding(
										padding: const EdgeInsets.symmetric(horizontal: 16.0),
										child: Text(
											'Pruebe con otra palabra: latitud, productos, crédito, sync…',
											style: TextStyle(color: Colors.grey.shade600, fontSize: 13.0),
										),
									)
								else
									...filtradas.map(
										(e) => _ResultadoBusquedaAdmin(
											entrada: e,
											alPresionar: () => _abrirEntrada(context, e),
										),
									),
							] else ...[
								if (!compacto)
									Card(
										color: colorRol.withValues(alpha: 0.08),
										child: Padding(
											padding: const EdgeInsets.all(16.0),
											child: Row(
												children: [
													CircleAvatar(
														radius: 26.0,
														backgroundColor: colorRol.withValues(alpha: 0.15),
														child: Icon(
															PresentacionRol.icono(widget.usuario.rol),
															color: colorRol,
															size: 28.0,
														),
													),
													const SizedBox(width: 14.0),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(
																	widget.usuario.nombre,
																	style: Theme.of(context)
																		.textTheme
																		.titleMedium
																		?.copyWith(fontWeight: FontWeight.bold),
																	maxLines: 1,
																	overflow: TextOverflow.ellipsis,
																),
																const SizedBox(height: 4.0),
																InsigniaRol(rol: widget.usuario.rol),
																const SizedBox(height: 6.0),
																Text(
																	PermisosUsuario.descripcionRol(widget.usuario.rol),
																	style: Theme.of(context).textTheme.bodySmall?.copyWith(
																		color: Colors.grey.shade700,
																	),
																),
															],
														),
													),
												],
											),
										),
									),
								for (final entrada in agrupadas.entries)
									_seccion(
										context,
										entrada.key,
										entrada.value,
										columnas,
									),
							],
						],
					);
				},
			),
		);
	}

	void _abrirEntrada(BuildContext context, EntradaMenuAdmin entrada) {
		Navigator.of(context).push(
			MaterialPageRoute<void>(builder: (_) => entrada.destino),
		);
	}

	Widget _seccion(
		BuildContext context,
		String titulo,
		List<EntradaMenuAdmin> entradas,
		int columnas,
	) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Padding(
					padding: const EdgeInsets.only(bottom: 10.0, top: 12.0),
					child: Row(
						children: [
							Container(
								width: 4.0,
								height: 22.0,
								decoration: BoxDecoration(
									color: PosiaColors.cobrar,
									borderRadius: BorderRadius.circular(2.0),
								),
							),
							const SizedBox(width: 10.0),
							Text(
								titulo,
								style: Theme.of(context).textTheme.titleMedium?.copyWith(
									fontWeight: FontWeight.bold,
								),
							),
						],
					),
				),
				GridView.count(
					crossAxisCount: columnas,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					mainAxisSpacing: 12.0,
					crossAxisSpacing: 12.0,
					childAspectRatio: columnas >= 4 ? 1.05 : 1.1,
					children: entradas
						.map(
							(e) => TarjetaMenuAdmin(
								icono: e.icono,
								titulo: e.titulo,
								subtitulo: e.subtitulo,
								color: e.color,
								alPresionar: () => _abrirEntrada(context, e),
							),
						)
						.toList(),
				),
				const SizedBox(height: 8.0),
			],
		);
	}
}

class _ResultadoBusquedaAdmin extends StatelessWidget {
	const _ResultadoBusquedaAdmin({
		required this.entrada,
		required this.alPresionar,
	});

	final EntradaMenuAdmin entrada;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
			child: ListTile(
				leading: CircleAvatar(
					backgroundColor: entrada.color.withValues(alpha: 0.15),
					child: Icon(entrada.icono, color: entrada.color, size: 22.0),
				),
				title: Text(
					entrada.titulo,
					maxLines: 1,
					overflow: TextOverflow.ellipsis,
				),
				subtitle: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const SizedBox(height: 2.0),
						Text(
							entrada.subtitulo,
							maxLines: 2,
							overflow: TextOverflow.ellipsis,
						),
						const SizedBox(height: 4.0),
						Text(
							entrada.seccion,
							style: Theme.of(context).textTheme.labelSmall?.copyWith(
								color: PosiaColors.cobrar,
								fontWeight: FontWeight.w600,
							),
						),
					],
				),
				trailing: const Icon(Icons.chevron_right),
				onTap: alPresionar,
			),
		);
	}
}
