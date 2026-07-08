/// Lector minimo de hojas XLSX (primera hoja) sin dependencias incompatibles.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lee la primera hoja de un archivo XLSX como filas de texto.
class LectorXlsx {
	const LectorXlsx._();

	static List<List<String>> leerFilas(Uint8List bytes) {
		final archive = ZipDecoder().decodeBytes(bytes);
		final sharedStrings = _leerCadenasCompartidas(archive);
		final hoja = _buscarPrimeraHoja(archive);
		if (hoja == null) {
			throw FormatException('El archivo Excel no contiene hojas de calculo');
		}
		return _parsearHoja(hoja, sharedStrings);
	}

	static ArchiveFile? _buscarPrimeraHoja(Archive archive) {
		const prefijo = 'xl/worksheets/sheet';
		final hojas = archive.files
			.where((f) => f.name.startsWith(prefijo) && f.name.endsWith('.xml'))
			.toList()
			..sort((a, b) => a.name.compareTo(b.name));
		return hojas.isEmpty ? null : hojas.first;
	}

	static List<String> _leerCadenasCompartidas(Archive archive) {
		final archivo = archive.files.cast<ArchiveFile?>().firstWhere(
			(f) => f?.name == 'xl/sharedStrings.xml',
			orElse: () => null,
		);
		if (archivo == null) {
			return const [];
		}
		final documento = XmlDocument.parse(String.fromCharCodes(archivo.content));
		final cadenas = <String>[];
		for (final si in documento.findAllElements('si')) {
			final partes = <String>[];
			for (final t in si.findAllElements('t')) {
				partes.add(t.innerText);
			}
			cadenas.add(partes.join());
		}
		return cadenas;
	}

	static List<List<String>> _parsearHoja(
		ArchiveFile hoja,
		List<String> sharedStrings,
	) {
		final documento = XmlDocument.parse(String.fromCharCodes(hoja.content));
		final filasMapa = <int, Map<int, String>>{};

		for (final fila in documento.findAllElements('row')) {
			final numeroFila = int.tryParse(fila.getAttribute('r') ?? '') ?? 0;
			if (numeroFila <= 0) {
				continue;
			}
			final celdas = filasMapa.putIfAbsent(numeroFila, () => {});
			for (final celda in fila.findElements('c')) {
				final ref = celda.getAttribute('r') ?? '';
				final columna = _indiceColumna(ref);
				if (columna < 0) {
					continue;
				}
				celdas[columna] = _valorCelda(celda, sharedStrings);
			}
		}

		if (filasMapa.isEmpty) {
			return const [];
		}
		final maxFila = filasMapa.keys.reduce((a, b) => a > b ? a : b);
		final maxColumna = filasMapa.values
			.expand((m) => m.keys)
			.fold<int>(0, (a, b) => a > b ? a : b);
		final resultado = <List<String>>[];
		for (var f = 1; f <= maxFila; f++) {
			final celdas = filasMapa[f];
			if (celdas == null) {
				resultado.add(List.filled(maxColumna + 1, ''));
				continue;
			}
			final fila = List<String>.generate(
				maxColumna + 1,
				(c) => celdas[c] ?? '',
			);
			resultado.add(fila);
		}
		return resultado;
	}

	static String _valorCelda(XmlElement celda, List<String> sharedStrings) {
		final tipo = celda.getAttribute('t');
		final elementosValor = celda.findElements('v');
		final valor = elementosValor.isEmpty ? null : elementosValor.first.innerText;
		if (tipo == 's' && valor != null) {
			final indice = int.tryParse(valor);
			if (indice != null && indice >= 0 && indice < sharedStrings.length) {
				return sharedStrings[indice];
			}
			return '';
		}
		if (tipo == 'inlineStr') {
			return celda.findAllElements('t').map((e) => e.innerText).join();
		}
		if (tipo == 'b') {
			return valor == '1' ? 'si' : 'no';
		}
		return valor ?? '';
	}

	static int _indiceColumna(String referencia) {
		final letras = RegExp(r'^[A-Za-z]+').firstMatch(referencia)?.group(0);
		if (letras == null || letras.isEmpty) {
			return -1;
		}
		var indice = 0;
		for (var i = 0; i < letras.length; i++) {
			indice = indice * 26 + (letras.codeUnitAt(i) - 64);
		}
		return indice - 1;
	}
}
