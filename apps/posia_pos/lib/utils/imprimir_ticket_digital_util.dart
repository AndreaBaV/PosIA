/// Imprime tickets termicos usando PNG nativo (optimizado para impresora).
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';

import '../util/marca_la_fortuna.dart';
import '../util/renderizador_ticket_bitmap.dart';

/// Genera PNG termico y lo envia a la impresora ESC/POS.
///
/// No guarda archivos en disco; el respaldo queda al compartir por WhatsApp.
Future<void> imprimirTicketDigital({
	required ReceiptPrinter impresora,
	required TicketDigitalContenido contenido,
	int anchoRolloMm = 80,
}) async {
	final logo = await cargarLogoTicketMarca();
	final png = renderizarTicketDigitalPng(
		contenido: contenido,
		logoPng: logo,
		anchoRolloMm: anchoRolloMm,
	);
	await impresora.imprimirTicket(imagenTicketPng: png);
}

/// Imprime varios tickets digitales en secuencia.
Future<void> imprimirTicketsDigitales({
	required ReceiptPrinter impresora,
	required List<TicketDigitalContenido> contenidos,
	int anchoRolloMm = 80,
}) async {
	for (final contenido in contenidos) {
		await imprimirTicketDigital(
			impresora: impresora,
			contenido: contenido,
			anchoRolloMm: anchoRolloMm,
		);
	}
}

/// Ticket de prueba con el mismo layout que una venta real.
TicketDigitalContenido construirTicketDigitalPrueba({
	required String nombreTienda,
	String? nombreImpresoraUsb,
	int anchoRolloMm = 80,
}) {
	final ahora = DateTime.now().toUtc();
	return TicketDigitalContenido(
		tipo: TipoDocumentoTicketDigital.venta,
		folio: formatearFolioTicket('prueba-posia', ahora),
		fecha: ahora,
		nombreTienda: nombreTienda,
		nombreCliente: 'Publico en general',
		lineas: const [
			LineaTicketDigital(
				descripcion: 'Producto de prueba POSIA',
				cantidad: 1,
				precioUnitario: 10,
				subtotal: 10,
			),
			LineaTicketDigital(
				descripcion: 'Verificacion impresora termica',
				cantidad: 2,
				precioUnitario: 5,
				subtotal: 10,
			),
		],
		total: 20,
		campos: {
			'Caja': 'Prueba',
			'Atendio': 'Sistema POSIA',
			'Pago': 'Efectivo',
			if (nombreImpresoraUsb != null && nombreImpresoraUsb.trim().isNotEmpty)
				'Impresora': nombreImpresoraUsb.trim(),
			'Ancho rollo': '$anchoRolloMm mm',
		},
		montoRecibido: 50,
		cambio: 30,
		notasPie: [
			'Gracias por su compra',
			'$NOMBRE_COMERCIAL_APP - $nombreTienda',
			'Ticket de prueba - impresora OK',
		],
	);
}
