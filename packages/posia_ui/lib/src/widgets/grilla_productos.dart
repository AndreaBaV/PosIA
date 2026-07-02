/// Grilla de productos con iconos grandes para seleccion tactil.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Muestra catalogo como grid de tarjetas con icono e imagen fallback.
class GrillaProductos extends StatefulWidget {
	/// Crea grilla de productos activos.
	///
	/// [productos] Lista de productos a mostrar.
	/// [alSeleccionar] Callback al tocar un producto.
	const GrillaProductos({
		required this.productos,
		required this.alSeleccionar,
		this.alPresionarLargo,
		this.alVerExistencias,
		this.stockLocalPorProducto = const {},
		this.categoriaId,
		this.mensajeVacio = 'Sin productos',
		this.indiceSeleccionado,
		this.columnas = 3,
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

	/// Numero de columnas del grid (2 en movil, 3 en escritorio).
	final int columnas;

	static const int columnasPredeterminadas = 3;

	@override
	State<GrillaProductos> createState() => _GrillaProductosState();
}

class _GrillaProductosState extends State<GrillaProductos> {
	final _clavesTarjetas = <int, GlobalKey>{};

	@override
	void didUpdateWidget(GrillaProductos oldWidget) {
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
			final contexto = _clavesTarjetas[indice]?.currentContext;
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
		return GridView.builder(
			key: PageStorageKey<String>('grilla_${widget.categoriaId ?? 'todos'}'),
			padding: const EdgeInsets.all(12.0),
			gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
				crossAxisCount: widget.columnas,
				mainAxisSpacing: 10.0,
				crossAxisSpacing: 10.0,
				childAspectRatio: 0.88,
			),
			itemCount: widget.productos.length,
			itemBuilder: (context, indice) {
				final producto = widget.productos[indice];
				final seleccionado = widget.indiceSeleccionado == indice;
				final stockLocal = widget.stockLocalPorProducto[producto.id] ?? 0.0;
				final sinExistenciaLocal =
					stockLocal <= 0 && !producto.permiteStockNegativo;
				final clave = _clavesTarjetas.putIfAbsent(indice, GlobalKey.new);
				return _TarjetaProducto(
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

/// Tarjeta individual de producto con icono fallback.
class _TarjetaProducto extends StatelessWidget {
	const _TarjetaProducto({
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
			: (sinExistenciaLocal ? PosiaColors.tarjetaSinExistencia : PosiaColors.tarjeta);
		return Material(
			color: colorFondo,
			borderRadius: BorderRadius.circular(14.0),
			elevation: seleccionado ? 3.0 : 1.0,
			shadowColor: Colors.black.withValues(alpha: 0.08),
			child: InkWell(
				onTap: alPresionar,
				onLongPress: alPresionarLargo,
				borderRadius: BorderRadius.circular(14.0),
				child: DecoratedBox(
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(14.0),
						border: seleccionado
							? Border.all(color: colorAcento, width: 2.5)
							: (sinExistenciaLocal
								? Border.all(color: PosiaColors.sinExistencia.withValues(alpha: 0.45))
								: null),
					),
					child: Stack(
						children: [
							Padding(
								padding: const EdgeInsets.all(10.0),
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Container(
											padding: const EdgeInsets.all(10.0),
											decoration: BoxDecoration(
												color: colorAcento.withValues(alpha: 0.1),
												borderRadius: BorderRadius.circular(12.0),
											),
											child: Icon(
												_resolverIconoProducto(producto),
												size: 40.0,
												color: colorAcento,
											),
										),
										const SizedBox(height: 8.0),
										Text(
											formatearMoneda(producto.precioBase),
											style: Theme.of(context).textTheme.titleMedium?.copyWith(
												color: colorAcento,
												fontWeight: FontWeight.bold,
											),
										),
										if (producto.moduloVertical == ModuloVertical.carniceria)
											Text(
												'/ kg',
												style: TextStyle(color: Colors.grey.shade600, fontSize: 11.0),
											),
										const SizedBox(height: 4.0),
										Text(
											producto.nombre,
											textAlign: TextAlign.center,
											maxLines: 2,
											overflow: TextOverflow.ellipsis,
											style: Theme.of(context).textTheme.bodyMedium?.copyWith(
												fontWeight: FontWeight.w500,
												color: sinExistenciaLocal ? PosiaColors.neutro : null,
											),
										),
										if (sinExistenciaLocal) ...[
											const SizedBox(height: 4.0),
											Text(
												'Sin existencia',
												style: Theme.of(context).textTheme.labelSmall?.copyWith(
													color: PosiaColors.sinExistencia,
													fontWeight: FontWeight.w600,
												),
											),
										],
									],
								),
							),
							if (alVerExistencias != null)
								Positioned(
									top: 2.0,
									right: 2.0,
									child: Material(
										color: Colors.transparent,
										child: IconButton(
											tooltip: 'Ver existencias',
											visualDensity: VisualDensity.compact,
											padding: EdgeInsets.zero,
											constraints: const BoxConstraints(
												minWidth: 36.0,
												minHeight: 36.0,
											),
											icon: Icon(
												Icons.info_outline,
												size: 20.0,
												color: sinExistenciaLocal
													? PosiaColors.sinExistencia
													: PosiaColors.neutro,
											),
											onPressed: alVerExistencias,
										),
									),
								),
						],
					),
				),
			),
		);
	}

	IconData _resolverIconoProducto(Producto producto) {
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
}
