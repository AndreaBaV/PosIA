/// Linea persistida de un ticket en espera en caja.
library;

import '../enums/modulo_vertical.dart';
import '../enums/regla_precio.dart';
import '../enums/unidad_medida.dart';
import 'linea_carrito.dart';
import 'producto.dart';

/// Detalle de producto guardado al apartar un carrito.
class LineaTicketEspera {
	const LineaTicketEspera({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidad,
		required this.precioUnitario,
		required this.reglaPrecio,
		this.loteId,
		this.etiquetaLote,
		this.descuentoLinea = 0.0,
		this.codigoBarras = '',
		this.unidadMedida = UnidadMedida.pieza,
		this.moduloVertical = ModuloVertical.general,
		this.categoriaId,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidad;
	final double precioUnitario;
	final ReglaPrecio reglaPrecio;
	final String? loteId;
	final String? etiquetaLote;
	final double descuentoLinea;
	final String codigoBarras;
	final UnidadMedida unidadMedida;
	final ModuloVertical moduloVertical;
	final String? categoriaId;

	/// Captura snapshot desde linea activa del carrito.
	factory LineaTicketEspera.desdeLineaCarrito(LineaCarrito linea) {
		final producto = linea.producto;
		return LineaTicketEspera(
			productoId: producto.id,
			nombreProducto: producto.nombre,
			cantidad: linea.cantidad,
			precioUnitario: linea.precioUnitario,
			reglaPrecio: linea.reglaPrecio,
			loteId: linea.loteId,
			etiquetaLote: linea.etiquetaLote,
			descuentoLinea: linea.descuentoLinea,
			codigoBarras: producto.codigoBarras,
			unidadMedida: producto.unidadMedida,
			moduloVertical: producto.moduloVertical,
			categoriaId: producto.categoriaId,
		);
	}

	/// Reconstruye producto minimo si ya no existe en catalogo.
	Producto productoRespaldo(String tiendaId) {
		return Producto(
			id: productoId,
			nombre: nombreProducto,
			codigoBarras: codigoBarras,
			precioBase: precioUnitario,
			unidadMedida: unidadMedida,
			rutaImagen: '',
			activo: true,
			tiendaId: tiendaId,
			moduloVertical: moduloVertical,
			categoriaId: categoriaId,
		);
	}

	LineaCarrito aLineaCarrito(Producto producto) {
		return LineaCarrito(
			producto: producto,
			cantidad: cantidad,
			precioUnitario: precioUnitario,
			reglaPrecio: reglaPrecio,
			loteId: loteId,
			etiquetaLote: etiquetaLote,
			descuentoLinea: descuentoLinea,
		);
	}
}
