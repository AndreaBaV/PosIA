/// Acciones comunes en detalle de tickets y documentos.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../utils/compartir_ticket_digital_util.dart';

/// Fila de acciones para compartir, imprimir y cerrar un documento.
class AccionesDocumentoTicket extends StatelessWidget {
	const AccionesDocumentoTicket({
		required this.onWhatsApp,
		this.onImprimir,
		this.etiquetaImprimir = 'Reimprimir',
		this.onCerrar,
		super.key,
	});

	final Future<void> Function() onWhatsApp;
	final Future<void> Function()? onImprimir;
	final String etiquetaImprimir;
	final VoidCallback? onCerrar;

	@override
	Widget build(BuildContext context) {
		return Row(
			children: [
				TextButton.icon(
					onPressed: () => onWhatsApp(),
					icon: const Icon(Icons.chat),
					label: const Text('WhatsApp'),
				),
				if (onImprimir != null)
					TextButton.icon(
						onPressed: () => onImprimir!(),
						icon: const Icon(Icons.print_outlined),
						label: Text(etiquetaImprimir),
					),
				const Spacer(),
				if (onCerrar != null)
					FilledButton(
						onPressed: onCerrar,
						child: const Text('Cerrar'),
					),
			],
		);
	}
}

/// Comparte ticket digital por WhatsApp (PDF o PNG).
Future<void> compartirTicketDigital(
	BuildContext context, {
	required TicketDigitalContenido contenido,
	String? telefono,
}) {
	return compartirTicketDigitalWhatsApp(
		context,
		contenido: contenido,
		telefono: telefono,
	);
}

/// Comparte documento digital por WhatsApp (PDF o PNG).
Future<void> compartirDocumentoWhatsApp(
	BuildContext context, {
	required TicketDigitalContenido contenido,
	String? telefono,
}) {
	return compartirTicketDigitalWhatsApp(
		context,
		contenido: contenido,
		telefono: telefono,
	);
}
