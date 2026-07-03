/// Lista desplegable de productos para la pantalla de caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-07-03 09:50:00 (UTC-6)
/// Ultima modificacion: 2026-07-03 09:50:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Muestra catalogo como lista vertical compacta para seleccion rapida.
class ListaProductosCaja extends StatefulWidget {
	/// Crea lista de productos activos.
	const ListaProductosCaja({
		required this.productos,
		required this.alSeleccionar,
		this.alPresionarLargo,
		this.alVerExistencias,
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

	/// Categoria activa (para conservar scroll al cambiar filtro).
	final String? categoriaId;

	/// Mensaje cuando no hay productos visibles.
	final String mensajeVacio;

	/// Accion al seleccionar producto.
	final ValueChanged<Producto> alSeleccionar;

	/// Accion al mantener pulsado (p. ej. vender por empaque).
	final ValueChanged<Producto>? alPresionarLargo;

	/// Accion al pulsar el icono de existencias.
	final ValueChanged<Producto>? alVerExistencias;

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
				final clave = _clavesFilas.putIfAbsent(indice, GlobalKey.new);
				return _FilaProducto(
					key: clave,
					producto: producto,
					seleccionado: seleccionado,
					sinExistenciaLocal: sinExistenciaLocal,
					alPresionar: () => widget.alSeleccionar(producto),
					alPresionarLargo: widget.alPresionarLargo == null
						? null
						: () => widget.alPresionarLargo!(producto),
					alVerExistencias: widget.alVerExistencias == null
						? null
						: () => widget.alVerExistencias!(producto),
				);
			},
		);
	}
}

class _FilaProducto extends StatelessWidget {
	const _FilaProducto({
		required this.producto,
		required this.alPresionar,
		this.alPresionarLargo,
		this.alVerExistencias,
		this.seleccionado = false,
		this.sinExistenciaLocal = false,
		super.key,
	});

	final Producto producto;
	final VoidCallback alPresionar;
	final VoidCallback? alPresionarLargo;
	final VoidCallback? alVerExistencias;
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
				child: ListTile(
					contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
					leading: CircleAvatar(
						backgroundColor: colorAcento.withValues(alpha: 0.12),
						child: Icon(
							_iconoProducto(producto),
							color: colorAcento,
							size: 22.0,
						),
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
			),
		);
	}
}

IconData _iconoProducto(Producto producto) {
	final nombre = producto.nombre.toLowerCase();
	if (nombre.contains('coca')) {
		return Icons.local_drink;
	}
	if (nombre.contains('arroz')) {
		return Icons.rice_bowl;
	}
	if (nombre.contains('leche')) {
		return Icons.water_drop;
	}
	if (nombre.contains('huevo')) {
		return Icons.egg;
	}
	if (nombre.contains('aceite')) {
		return Icons.opacity;
	}
	if (nombre.contains('azucar')) {
		return Icons.grain;
	}
	if (nombre.contains('frijol')) {
		return Icons.grass;
	}
	if (nombre.contains('atun')) {
		return Icons.set_meal;
	}
	if (producto.moduloVertical == ModuloVertical.carniceria) {
		return Icons.set_meal;
	}
	if (producto.moduloVertical == ModuloVertical.farmacia) {
		return Icons.medication;
	}
	return Icons.shopping_basket;
}
