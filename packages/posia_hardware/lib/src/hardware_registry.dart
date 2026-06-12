/// Registro central de drivers de hardware configurados.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'barcode_scanner.dart';
import 'cash_drawer.dart';
import 'customer_display.dart';
import 'receipt_printer.dart';
import 'scale.dart';

/// Contenedor de instancias activas de hardware por tienda.
class HardwareRegistry {
	/// Crea registro con drivers resueltos para la caja.
	///
	/// [scanner] Implementacion de lector de codigos.
	/// [impresora] Implementacion de impresora de tickets.
	/// [bascula] Implementacion de bascula opcional.
	/// [cajon] Implementacion de cajon opcional.
	/// [displayCliente] Display secundario opcional.
	HardwareRegistry({
		required BarcodeScanner scanner,
		required ReceiptPrinter impresora,
		Scale? bascula,
		CashDrawer? cajon,
		CustomerDisplay? displayCliente,
	}) : _scanner = scanner,
	     _impresora = impresora,
	     _bascula = bascula,
	     _cajon = cajon,
	     _displayCliente = displayCliente;

	final BarcodeScanner _scanner;
	final ReceiptPrinter _impresora;
	final Scale? _bascula;
	final CashDrawer? _cajon;
	final CustomerDisplay? _displayCliente;

	/// Obtiene scanner activo.
	///
	/// Retorna instancia de [BarcodeScanner].
	BarcodeScanner obtenerScanner() {
		return _scanner;
	}

	/// Obtiene impresora activa.
	///
	/// Retorna instancia de [ReceiptPrinter].
	ReceiptPrinter obtenerImpresora() {
		return _impresora;
	}

	/// Obtiene bascula si fue configurada.
	///
	/// Retorna instancia o null.
	Scale? obtenerBascula() {
		return _bascula;
	}

	/// Obtiene cajon si fue configurado.
	///
	/// Retorna instancia o null.
	CashDrawer? obtenerCajon() {
		return _cajon;
	}

	/// Obtiene display de cliente si fue configurado.
	///
	/// Retorna instancia o null.
	CustomerDisplay? obtenerDisplayCliente() {
		return _displayCliente;
	}
}
