/// Lector minimo de hojas XLSX sin dependencias incompatibles.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lee hojas de un archivo XLSX como filas de texto.
class LectorXlsx {
	const LectorXlsx._();

	/// Lee la primera hoja, o [nombreHoja] si se indica.
	static List<List<String>> leerFilas(
		Uint8List bytes, {
		String? nombreHoja,
	}) {
		final archive = ZipDecoder().decodeBytes(bytes);
		final sharedStrings = _leerCadenasCompartidas(archive);
		final hojas = _listarHojas(archive);
		if (hojas.isEmpty) {
			throw FormatException('El archivo Excel no contiene hojas de calculo');
		}
		ArchiveFile? hoja;
		if (nombreHoja != null && nombreHoja.trim().isNotEmpty) {
			final clave = nombreHoja.trim().toLowerCase();
			for (final entrada in hojas) {
				if (entrada.$1.toLowerCase() == clave) {
					hoja = entrada.$2;
					break;
				}
			}
			if (hoja == null) {
				final nombres = hojas.map((h) => h.$1).join(', ');
				throw FormatException(
					'Hoja "$nombreHoja" no encontrada. Disponibles: $nombres',
				);
			}
		} else {
			hoja = hojas.first.$2;
		}
		return _parsearHoja(hoja, sharedStrings);
	}

	/// Nombres de hojas en orden del libro.
	static List<String> listarNombresHojas(Uint8List bytes) {
		final archive = ZipDecoder().decodeBytes(bytes);
		return _listarHojas(archive).map((h) => h.$1).toList();
	}

	/// [(nombre, archivo XML de la hoja), ...]
	static List<(String, ArchiveFile)> _listarHojas(Archive archive) {
		final workbook = archive.files.cast<ArchiveFile?>().firstWhere(
			(f) => f?.name == 'xl/workbook.xml',
			orElse: () => null,
		);
		final rels = archive.files.cast<ArchiveFile?>().firstWhere(
			(f) => f?.name == 'xl/_rels/workbook.xml.rels',
			orElse: () => null,
		);
		if (workbook == null || rels == null) {
			return _hojasPorPrefijo(archive);
		}
		final ridATarget = <String, String>{};
		final docRels = XmlDocument.parse(_decodificarUtf8(rels.content));
		for (final rel in docRels.findAllElements('Relationship')) {
			final id = rel.getAttribute('Id');
			final target = rel.getAttribute('Target');
			if (id == null || target == null) {
				continue;
			}
			final ruta = target.startsWith('xl/')
				? target
				: 'xl/${target.replaceFirst(RegExp(r'^/+'), '')}';
			ridATarget[id] = ruta;
		}
		final docWb = XmlDocument.parse(_decodificarUtf8(workbook.content));
		final resultado = <(String, ArchiveFile)>[];
		for (final sheet in docWb.findAllElements('sheet')) {
			final nombre = sheet.getAttribute('name') ?? '';
			final rid = sheet.getAttribute('r:id') ??
				sheet.getAttribute(
					'{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id',
				);
			if (nombre.isEmpty || rid == null) {
				continue;
			}
			final target = ridATarget[rid];
			if (target == null) {
				continue;
			}
			final archivo = archive.files.cast<ArchiveFile?>().firstWhere(
				(f) => f?.name == target,
				orElse: () => null,
			);
			if (archivo != null) {
				resultado.add((nombre, archivo));
			}
		}
		return resultado.isEmpty ? _hojasPorPrefijo(archive) : resultado;
	}

	static List<(String, ArchiveFile)> _hojasPorPrefijo(Archive archive) {
		const prefijo = 'xl/worksheets/sheet';
		final hojas = archive.files
			.where((f) => f.name.startsWith(prefijo) && f.name.endsWith('.xml'))
			.toList()
			..sort((a, b) => a.name.compareTo(b.name));
		return [
			for (var i = 0; i < hojas.length; i++) ('Hoja ${i + 1}', hojas[i]),
		];
	}

	static List<String> _leerCadenasCompartidas(Archive archive) {
		final archivo = archive.files.cast<ArchiveFile?>().firstWhere(
			(f) => f?.name == 'xl/sharedStrings.xml',
			orElse: () => null,
		);
		if (archivo == null) {
			return const [];
		}
		final documento = XmlDocument.parse(_decodificarUtf8(archivo.content));
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
		final documento = XmlDocument.parse(_decodificarUtf8(hoja.content));
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

	static String _decodificarUtf8(List<int> bytes) {
		var data = bytes;
		if (data.length >= 3 &&
			data[0] == 0xEF &&
			data[1] == 0xBB &&
			data[2] == 0xBF) {
			data = data.sublist(3);
		}
		return utf8.decode(data);
	}
}
