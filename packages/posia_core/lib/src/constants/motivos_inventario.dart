/// Catalogo normalizado de motivos para movimientos de inventario.
library;

import '../enums/tipo_movimiento_inventario.dart';

/// Motivos permitidos para entradas manuales.
const List<String> MOTIVOS_ENTRADA_INVENTARIO = [
	'Compra a proveedor',
	'Devolución de cliente',
	'Traspaso recibido',
	'Ajuste por conteo',
	'Inventario inicial',
];

/// Motivos permitidos para salidas manuales.
const List<String> MOTIVOS_SALIDA_INVENTARIO = [
	'Merma o daño',
	'Caducidad',
	'Uso interno',
	'Traspaso enviado',
	'Muestra o degustación',
	'Ajuste por conteo',
];

/// Motivos permitidos para ajustes manuales.
const List<String> MOTIVOS_AJUSTE_INVENTARIO = [
	'Conteo físico',
	'Corrección de error',
	'Inventario inicial',
];

/// Lista de motivos validos segun el tipo de movimiento manual.
List<String> motivosInventarioPorTipo(TipoMovimientoInventario tipo) {
	switch (tipo) {
		case TipoMovimientoInventario.entrada:
			return MOTIVOS_ENTRADA_INVENTARIO;
		case TipoMovimientoInventario.salida:
			return MOTIVOS_SALIDA_INVENTARIO;
		case TipoMovimientoInventario.ajuste:
			return MOTIVOS_AJUSTE_INVENTARIO;
		case TipoMovimientoInventario.traspasoSalida:
		case TipoMovimientoInventario.traspasoEntrada:
		case TipoMovimientoInventario.reversionVenta:
			return const [];
	}
}

/// Motivo predeterminado al abrir un formulario manual.
String motivoInventarioPredeterminado(TipoMovimientoInventario tipo) {
	final opciones = motivosInventarioPorTipo(tipo);
	if (opciones.isEmpty) {
		return '';
	}
	return opciones.first;
}

/// Indica si el motivo pertenece al catalogo del tipo indicado.
bool esMotivoInventarioValido(TipoMovimientoInventario tipo, String motivo) {
	final opciones = motivosInventarioPorTipo(tipo);
	if (opciones.isEmpty) {
		return motivo.trim().isNotEmpty;
	}
	return opciones.contains(motivo.trim());
}
