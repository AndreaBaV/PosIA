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

	/// Placeholder creado por integridad FK (sync fuera de orden).
	///
	/// No es una lista de negocio; no debe proyectarse a Neon.
	///
	/// La tabla solo guarda id/nombre/activa, asi que el unico indicio es el
	/// nombre exacto del stub. Una lista real llamada literalmente "Lista de
	/// precios" quedaria excluida del sync: conviene renombrarla.
	bool get esStubFk => nombre.trim() == 'Lista de precios';

	ListaPrecios copiarCon({String? id, String? nombre, bool? activa}) {
		return ListaPrecios(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			activa: activa ?? this.activa,
		);
	}
}
