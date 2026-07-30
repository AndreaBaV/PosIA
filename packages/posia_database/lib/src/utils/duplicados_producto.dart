/// Regla compartida para decidir el producto canonico ante una colision de
/// codigo de barras (real o interno).
///
/// La usan tanto el autosanador periodico (fusiona duplicados que ya
/// quedaron activos en la base) como el guardado de un producto entrante que
/// choca con uno existente (ver `ProductoRepository.guardar`). Si cada
/// camino decidiera con su propia logica podrian discrepar sobre cual es el
/// canonico y el catalogo nunca convergeria entre dispositivos.
library;

import 'package:sqflite/sqflite.dart';

/// Tablas transaccionales que referencian un producto por `producto_id`.
const List<String> tablasReferenciaProducto = [
	'sale_lines',
	'held_ticket_lines',
	'transfer_lines',
	'purchase_lines',
	'order_lines',
	'quote_lines',
];

/// Suma referencias transaccionales que apuntan a [productoId]. La mejor
/// senal de "cual es el real": la fila con mas ventas registradas gana el
/// canonico y asi conserva su historial.
Future<int> contarReferenciasTransaccionalesProducto(
	DatabaseExecutor exec,
	String productoId,
) async {
	var total = 0;
	for (final tabla in tablasReferenciaProducto) {
		final filas = await exec.rawQuery(
			'SELECT COUNT(*) AS c FROM $tabla WHERE producto_id = ?',
			[productoId],
		);
		total += (filas.first['c'] as int?) ?? 0;
	}
	return total;
}

/// true si el producto [idA] (con [refsA] referencias) debe ganar sobre
/// [idB] (con [refsB] referencias): mas referencias transaccionales: empate
/// -> id mas chico, para que todos los dispositivos converjan a la misma
/// eleccion sin coordinarse.
bool productoGanaColision({
	required String idA,
	required int refsA,
	required String idB,
	required int refsB,
}) {
	if (refsA != refsB) {
		return refsA > refsB;
	}
	return idA.compareTo(idB) < 0;
}
