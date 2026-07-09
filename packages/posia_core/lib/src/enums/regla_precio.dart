/// Reglas aplicadas por el motor de precios.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Describe que regla determino el precio final.
enum ReglaPrecio {
	/// Precio fijo cliente-producto.
	precioClienteProducto,

	/// Lista de precios asignada al cliente.
	listaPreciosCliente,

	/// Escala de mayoreo por cantidad.
	escalaMayoreo,

	/// Precio base del producto en la tienda.
	precioBase,

	/// Precio fijado manualmente en caja por un administrador.
	precioManual,
}
