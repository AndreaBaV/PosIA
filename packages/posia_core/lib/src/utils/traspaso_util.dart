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
