/// Resultado de importacion masiva de productos.
library;

/// Error al importar una fila del archivo.
class ErrorImportacionProducto {
	const ErrorImportacionProducto({
		required this.numeroFila,
		required this.nombre,
		required this.mensaje,
	});

	final int numeroFila;
	final String nombre;
	final String mensaje;
}

/// Resumen de una importacion por lote.
class ResultadoImportacionProductos {
	const ResultadoImportacionProductos({
		required this.importados,
		required this.errores,
	});

	final int importados;
	final List<ErrorImportacionProducto> errores;

	int get total => importados + errores.length;

	bool get exitoTotal => errores.isEmpty;
}
