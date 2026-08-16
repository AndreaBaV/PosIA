/// Utilidades para identificar almacenes en traspasos persistidos.
library;

const prefijoAlmacenTraspaso = 'almacen:';

/// Codifica un almacen como origen/destino en [Traspaso.tiendaOrigenId] o destino.
String codificarAlmacenEnTraspaso(String almacenId) {
	return '$prefijoAlmacenTraspaso$almacenId';
}

/// Indica si el identificador de ubicacion corresponde a un almacen.
bool esAlmacenCodificadoEnTraspaso(String ubicacionId) {
	return ubicacionId.startsWith(prefijoAlmacenTraspaso);
}

/// Extrae el id de almacen si [ubicacionId] esta codificado; null si es tienda.
String? decodificarAlmacenEnTraspaso(String ubicacionId) {
	if (!esAlmacenCodificadoEnTraspaso(ubicacionId)) {
		return null;
	}
	return ubicacionId.substring(prefijoAlmacenTraspaso.length);
}

bool _nombreYaEsAlmacen(String nombre) {
	final limpio = nombre.trim().toLowerCase();
	return limpio.startsWith('almacén') || limpio.startsWith('almacen');
}

/// Nombre de ubicacion listo para ticket: distingue tienda y almacén.
String etiquetaUbicacionTraspaso({
	required String ubicacionId,
	required String nombre,
}) {
	final limpio = nombre.trim();
	if (esAlmacenCodificadoEnTraspaso(ubicacionId)) {
		if (limpio.isEmpty) {
			return 'Almacén';
		}
		return _nombreYaEsAlmacen(limpio) ? limpio : 'Almacén $limpio';
	}
	if (limpio.isEmpty) {
		return 'Tienda';
	}
	return limpio;
}

/// Titulo corto segun origen y destino del movimiento.
String tituloTicketTraspaso({
	required String origenId,
	required String destinoId,
}) {
	final origenAlmacen = esAlmacenCodificadoEnTraspaso(origenId);
	final destinoAlmacen = esAlmacenCodificadoEnTraspaso(destinoId);
	if (origenAlmacen && destinoAlmacen) {
		return 'TRASPASO ALMACÉN';
	}
	if (origenAlmacen) {
		return 'ABASTECIMIENTO';
	}
	if (destinoAlmacen) {
		return 'INGRESO A ALMACÉN';
	}
	return 'TRASPASO';
}

/// Pie descriptivo del documento de control.
String subtituloTicketTraspaso({
	required String origenId,
	required String destinoId,
}) {
	final origenAlmacen = esAlmacenCodificadoEnTraspaso(origenId);
	final destinoAlmacen = esAlmacenCodificadoEnTraspaso(destinoId);
	if (origenAlmacen && destinoAlmacen) {
		return 'Movimiento entre almacenes';
	}
	if (origenAlmacen) {
		return 'Salida de almacén a piso de venta';
	}
	if (destinoAlmacen) {
		return 'Retiro de tienda hacia almacén';
	}
	return 'Documento de control interno';
}
