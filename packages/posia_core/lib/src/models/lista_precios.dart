/// Lista comercial de precios para clientes mayoristas.
library;

/// Catalogo de listas de precios (ej. menudeo, mayoreo A, distribuidor).
class ListaPrecios {
	const ListaPrecios({
		required this.id,
		required this.nombre,
		this.activa = true,
	});

	final String id;
	final String nombre;
	final bool activa;

	ListaPrecios copiarCon({String? id, String? nombre, bool? activa}) {
		return ListaPrecios(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			activa: activa ?? this.activa,
		);
	}
}
