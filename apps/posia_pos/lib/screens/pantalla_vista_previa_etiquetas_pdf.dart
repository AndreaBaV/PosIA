/// Vista previa de PDF de etiquetas antes de guardar en disco.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:posia_ui/posia_ui.dart';

/// Muestra el PDF generado y permite guardarlo en la carpeta elegida.
class PantallaVistaPreviaEtiquetasPdf extends StatefulWidget {
	const PantallaVistaPreviaEtiquetasPdf({
		required this.bytes,
		required this.carpetaDestino,
		super.key,
	});

	final Uint8List bytes;
	final String carpetaDestino;

	@override
	State<PantallaVistaPreviaEtiquetasPdf> createState() =>
		_PantallaVistaPreviaEtiquetasPdfState();
}

class _PantallaVistaPreviaEtiquetasPdfState extends State<PantallaVistaPreviaEtiquetasPdf> {
	var _guardando = false;

	Future<void> _guardarPdf() async {
		setState(() => _guardando = true);
		try {
			final carpeta = Directory(widget.carpetaDestino);
			if (!await carpeta.exists()) {
				await carpeta.create(recursive: true);
			}
			final nombre = 'etiquetas_${DateTime.now().millisecondsSinceEpoch}.pdf';
			final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
			await archivo.writeAsBytes(widget.bytes);
			if (!mounted) {
				return;
			}
			Navigator.pop(context, archivo.path);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _guardando = false);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Vista previa de etiquetas'),
				actions: [
					FilledButton.icon(
						onPressed: _guardando ? null : _guardarPdf,
						icon: _guardando
							? const SizedBox(
								width: 16.0,
								height: 16.0,
								child: CircularProgressIndicator(strokeWidth: 2.0),
							)
							: const Icon(Icons.save, size: 18.0),
						label: const Text('Guardar PDF'),
					),
					const SizedBox(width: 8.0),
				],
			),
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Material(
						color: Theme.of(context).colorScheme.surfaceContainerHighest,
						child: Padding(
							padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
							child: Text(
								'Destino: ${widget.carpetaDestino}',
								maxLines: 2,
								overflow: TextOverflow.ellipsis,
								style: Theme.of(context).textTheme.bodySmall,
							),
						),
					),
					Expanded(
						child: PdfPreview(
							build: (_) async => widget.bytes,
							allowPrinting: false,
							allowSharing: false,
							canChangeOrientation: false,
							canChangePageFormat: false,
							pdfFileName: 'etiquetas_posia.pdf',
						),
					),
				],
			),
		);
	}
}
