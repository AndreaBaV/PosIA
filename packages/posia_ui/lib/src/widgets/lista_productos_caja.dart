/// Lista desplegable de productos para la pantalla de caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-07-03 09:50:00 (UTC-6)
/// Ultima modificacion: 2026-09-11 13:15:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';
import 'visual_producto.dart';

/// Muestra catalogo como lista vertical compacta para seleccion rapida.
class ListaProductosCaja extends StatefulWidget {
	/// Crea lista de productos activos.
	const ListaProductosCaja({
		required this.productos,
		required this.alSeleccionar,
		this.alPresionarLargo,
		this.alVerExistencias,
		this.alSeleccionarEmpaque,
		this.empaquesPorProducto = const {},
		this.stockLocalPorProducto = const {},
		this.categoriaId,
		this.mensajeVacio = 'Sin productos',
		this.indiceSeleccionado,
		super.key,
	});

	/// Productos disponibles en catalogo.
	final List<Producto> productos;

	/// Existencia en la tienda activa por productoId.
	final Map<String, double> stockLocalPorProducto;

	/// Empaques comerciales (caja, bulto…) por productoId.
	final Map<String, List<PresentacionProducto>> empaquesPorProducto;

	/// Categoria activa (para conservar scroll al cambiar filtro).
	final String? categoriaId;

	/// Mensaje cuando no hay productos visibles.
	final String mensajeVacio;

	/// Accion al seleccionar producto (unidad base).
	final ValueChanged<Producto> alSeleccionar;

	/// Accion al mantener pulsado (dialogo de empaques).
	final ValueChanged<Producto>? alPresionarLargo;

	/// Accion al pulsar el icono de existencias.
	final ValueChanged<Producto>? alVerExistencias;

	/// Accion al pulsar un chip de empaque concreto.
	final void Function(Producto producto, PresentacionProducto empaque)?
		alSeleccionarEmpaque;

	/// Indice resaltado para navegacion con teclado (opcional).
	final int? indiceSeleccionado;

	@override
	State<ListaProductosCaja> createState() => _ListaProductosCajaState();
}

class _ListaProductosCajaState extends State<ListaProductosCaja> {
	final _clavesFilas = <int, GlobalKey>{};

	@override
	void didUpdateWidget(ListaProductosCaja oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.indiceSeleccionado != null &&
			widget.indiceSeleccionado != oldWidget.indiceSeleccionado) {
			_desplazarASeleccion(widget.indiceSeleccionado!);
		}
	}

	void _desplazarASeleccion(int indice) {
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) {
				return;
			}
			final contexto = _clavesFilas[indice]?.currentContext;
			if (contexto == null) {
				return;
			}
			Scrollable.ensureVisible(
				contexto,
				alignment: 0.25,
				duration: const Duration(milliseconds: 180),
				curve: Curves.easeOut,
			);
		});
	}

	@override
	Widget build(BuildContext context) {
		if (widget.productos.isEmpty) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(Icons.inventory_2_outlined, size: 64.0, color: Colors.grey.shade400),
						const SizedBox(height: 12.0),
						Text(
							widget.mensajeVacio,
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
								color: Colors.grey.shade600,
							),
							textAlign: TextAlign.center,
						),
					],
				),
			);
		}
		return ListView.separated(
			key: PageStorageKey<String>('lista_${widget.categoriaId ?? 'todos'}'),
			padding: const EdgeInsets.symmetric(vertical: 4.0),
			itemCount: widget.productos.length,
			separatorBuilder: (_, _) => const Divider(height: 1.0, indent: 72.0),
			itemBuilder: (context, indice) {
				final producto = widget.productos[indice];
				final seleccionado = widget.indiceSeleccionado == indice;
				final stockLocal = widget.stockLocalPorProducto[producto.id] ?? 0.0;
				final sinExistenciaLocal =
					stockLocal <= 0 && !producto.permiteStockNegativo;
				final empaques = widget.empaquesPorProducto[producto.id] ?? const [];
				final clave = _clavesFilas.putIfAbsent(indice, GlobalKey.new);
				return _FilaProducto(
					key: clave,
					producto: producto,
					empaques: empaques,
					seleccionado: seleccionado,
					sinExistenciaLocal: sinExistenciaLocal,
					alPresionar: () => widget.alSeleccionar(producto),
					alPresionarLargo: widget.alPresionarLargo == null
						? null
						: () => widget.alPresionarLargo!(producto),
					alVerExistencias: widget.alVerExistencias == null
						? null
						: () => widget.alVerExistencias!(producto),
					alSeleccionarEmpaque: widget.alSeleccionarEmpaque == null
						? null
						: (empaque) => widget.alSeleccionarEmpaque!(producto, empaque),
				);
			},
		);
	}
}

class _FilaProducto extends StatelessWidget {
	const _FilaProducto({
		required this.producto,
		required this.alPresionar,
		this.empaques = const [],
		this.alPresionarLargo,
		this.alVerExistencias,
		this.alSeleccionarEmpaque,
		this.seleccionado = false,
		this.sinExistenciaLocal = false,
		super.key,
	});

	final Producto producto;
	final List<PresentacionProducto> empaques;
	final VoidCallback alPresionar;
	final VoidCallback? alPresionarLargo;
	final VoidCallback? alVerExistencias;
	final ValueChanged<PresentacionProducto>? alSeleccionarEmpaque;
	final bool seleccionado;
	final bool sinExistenciaLocal;

	@override
	Widget build(BuildContext context) {
		final colorAcento = sinExistenciaLocal ? PosiaColors.sinExistencia : PosiaColors.cobrar;
		final colorFondo = seleccionado
			? colorAcento.withValues(alpha: 0.12)
			: (sinExistenciaLocal ? PosiaColors.tarjetaSinExistencia : null);
		final precioTexto = producto.moduloVertical == ModuloVertical.carniceria
			? '${formatearMoneda(producto.precioBase)} / kg'
			: formatearMoneda(producto.precioBase);
		return Material(
			color: colorFondo ?? Colors.transparent,
			child: InkWell(
				onTap: alPresionar,
				onLongPress: alPresionarLargo,
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							ListTile(
								contentPadding: const EdgeInsets.symmetric(
									horizontal: 8.0,
									vertical: 0.0,
								),
								leading: VisualProducto(
									producto: producto,
									colorAcento: colorAcento,
									tamano: 40.0,
									padding: 0.0,
									circular: true,
								),
								title: Text(
									producto.nombre,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontWeight: FontWeight.w500,
										color: sinExistenciaLocal ? PosiaColors.neutro : null,
									),
								),
								subtitle: sinExistenciaLocal
									? Text(
										'Sin existencia · $precioTexto',
										style: TextStyle(
											color: PosiaColors.sinExistencia,
											fontSize: 12.0,
											fontWeight: FontWeight.w600,
										),
									)
									: Text(precioTexto),
								trailing: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (alVerExistencias != null)
											IconButton(
												tooltip: 'Ver existencias',
												visualDensity: VisualDensity.compact,
												icon: Icon(
													Icons.info_outline,
													size: 20.0,
													color: sinExistenciaLocal
														? PosiaColors.sinExistencia
														: PosiaColors.neutro,
												),
												onPressed: alVerExistencias,
											),
										if (seleccionado)
											Icon(Icons.keyboard_return, size: 18.0, color: colorAcento),
									],
								),
							),
							if (empaques.isNotEmpty && alSeleccionarEmpaque != null)
								Padding(
									padding: const EdgeInsets.fromLTRB(64.0, 0.0, 12.0, 8.0),
									child: Wrap(
										spacing: 6.0,
										runSpacing: 4.0,
										children: [
											for (final empaque in empaques)
												ActionChip(
													visualDensity: VisualDensity.compact,
													avatar: Icon(
														Icons.inventory_2_outlined,
														size: 16.0,
														color: colorAcento,
													),
													label: Text(
														empaque.nombre,
														style: TextStyle(
															fontWeight: FontWeight.w600,
															color: colorAcento,
															fontSize: 12.0,
														),
													),
													backgroundColor: colorAcento.withValues(alpha: 0.1),
													side: BorderSide(
														color: colorAcento.withValues(alpha: 0.35),
													),
													onPressed: () => alSeleccionarEmpaque!(empaque),
												),
										],
									),
								),
						],
					),
				),
			),
		);
	}
}
