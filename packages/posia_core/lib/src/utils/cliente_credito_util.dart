/// Validacion y calculo de ventas a credito para clientes.
library;

import '../models/cliente.dart';
import 'moneda_util.dart';

/// Indica si el cliente tiene telefono y direccion para fiar.
bool clienteTieneDatosCredito(Cliente cliente) {
	return cliente.telefono.trim().isNotEmpty &&
		cliente.direccion.trim().isNotEmpty &&
		cliente.nombre.trim().isNotEmpty;
}

/// Cliente habilitado y con datos minimos para credito.
bool clientePuedeRecibirCredito(Cliente cliente) {
	return cliente.creditoHabilitado && cliente.activo && clienteTieneDatosCredito(cliente);
}

/// Campos faltantes para otorgar credito (telefono, direccion, etc.).
List<String> camposFaltantesCredito(Cliente cliente) {
	final faltantes = <String>[];
	if (cliente.nombre.trim().isEmpty) {
		faltantes.add('nombre');
	}
	if (cliente.telefono.trim().isEmpty) {
		faltantes.add('teléfono');
	}
	if (cliente.direccion.trim().isEmpty) {
		faltantes.add('dirección');
	}
	return faltantes;
}

/// Mensaje de error cuando no se puede fiar al cliente.
String? validarClienteParaCredito(Cliente? cliente, {int? diasCredito}) {
	if (cliente == null) {
		return 'Seleccione un cliente para venta a crédito';
	}
	if (!cliente.creditoHabilitado) {
		return 'El cliente no tiene crédito habilitado';
	}
	if (!cliente.activo) {
		return 'El cliente está inactivo';
	}
	if (!clienteTieneDatosCredito(cliente)) {
		final faltantes = camposFaltantesCredito(cliente);
		return 'Complete ${faltantes.join(', ')} del cliente para otorgar crédito';
	}
	final dias = diasCredito ?? cliente.diasCredito;
	if (dias <= 0) {
		return 'Los días de crédito deben ser mayores a cero';
	}
	return null;
}

/// Fecha limite de pago (solo fecha calendario local).
DateTime calcularFechaVencimientoCredito(DateTime desdeUtc, int diasCredito) {
	final local = desdeUtc.toLocal();
	final base = DateTime(local.year, local.month, local.day);
	return base.add(Duration(days: diasCredito));
}

/// Formato corto DD/MM/AAAA para tickets.
String formatearFechaCredito(DateTime fecha) {
	final dia = fecha.day.toString().padLeft(2, '0');
	final mes = fecha.month.toString().padLeft(2, '0');
	return '$dia/$mes/${fecha.year}';
}

/// Leyenda de compromiso de pago para ticket de credito.
String generarLeyendaCompromisoCredito({
	required double total,
	required int diasCredito,
	required DateTime fechaVencimiento,
	required String nombreCliente,
}) {
	return 'El cliente $nombreCliente se compromete a pagar '
		'${formatearMoneda(total)} en un plazo de $diasCredito dia(s), '
		'a mas tardar el ${formatearFechaCredito(fechaVencimiento)}.';
}
