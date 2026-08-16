/// Escritor minimo de XLSX (varias hojas) sin el paquete excel.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Genera un .xlsx a partir de hojas nombre → filas (la primera es encabezado).
class EscritorXlsx {
	const EscritorXlsx._();

	static Uint8List escribir(Map<String, List<List<String>>> hojas) {
		if (hojas.isEmpty) {
			throw ArgumentError('Se necesita al menos una hoja');
		}
		final cadenas = <String>[];
		final indice = <String, int>{};
		int idDe(String texto) {
			final existente = indice[texto];
			if (existente != null) {
				return existente;
			}
			final id = cadenas.length;
			cadenas.add(texto);
			indice[texto] = id;
			return id;
		}

		final zip = Archive();
		zip.addFile(
			ArchiveFile.string(
				'[Content_Types].xml',
				_tiposContenido(hojas.length),
			),
		);
		zip.addFile(ArchiveFile.string('_rels/.rels', _relsRaiz));
		zip.addFile(
			ArchiveFile.string('xl/workbook.xml', _libro(hojas.keys.toList())),
		);
		zip.addFile(
			ArchiveFile.string('xl/_rels/workbook.xml.rels', _relsLibro(hojas.length)),
		);
		var i = 1;
		for (final entrada in hojas.entries) {
			zip.addFile(
				ArchiveFile.string(
					'xl/worksheets/sheet$i.xml',
					_hoja(entrada.value, idDe),
				),
			);
			i++;
		}
		zip.addFile(
			ArchiveFile.string('xl/sharedStrings.xml', _cadenasCompartidas(cadenas)),
		);
		return Uint8List.fromList(ZipEncoder().encode(zip));
	}

	static String nombreHojaSeguro(String crudo) {
		var nombre = crudo.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_').trim();
		if (nombre.isEmpty) {
			nombre = 'Hoja';
		}
		if (nombre.length > 31) {
			nombre = nombre.substring(0, 31);
		}
		return nombre;
	}

	static String _tiposContenido(int hojas) {
		final sheets = List.generate(
			hojas,
			(i) =>
				'<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
				'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
		).join();
		return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
$sheets
</Types>''';
	}

	static const _relsRaiz = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

	static String _libro(List<String> nombres) {
		final sheets = <String>[];
		for (var i = 0; i < nombres.length; i++) {
			final nombre = _escapar(nombreHojaSeguro(nombres[i]));
			sheets.add(
				'<sheet name="$nombre" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
			);
		}
		return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${sheets.join('\n')}
</sheets>
</workbook>''';
	}

	static String _relsLibro(int hojas) {
		final rels = List.generate(
			hojas,
			(i) =>
				'<Relationship Id="rId${i + 1}" '
				'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
				'Target="worksheets/sheet${i + 1}.xml"/>',
		).join();
		final sharedId = 'rId${hojas + 1}';
		return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$rels
<Relationship Id="$sharedId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''';
	}

	static String _hoja(
		List<List<String>> filas,
		int Function(String) idDe,
	) {
		final buffer = StringBuffer()
			..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
			..writeln(
				'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
			)
			..writeln('<sheetData>');
		for (var r = 0; r < filas.length; r++) {
			final fila = filas[r];
			buffer.writeln('<row r="${r + 1}">');
			for (var c = 0; c < fila.length; c++) {
				final ref = '${_columna(c)}${r + 1}';
				final id = idDe(fila[c]);
				buffer.writeln('<c r="$ref" t="s"><v>$id</v></c>');
			}
			buffer.writeln('</row>');
		}
		buffer
			..writeln('</sheetData>')
			..writeln('</worksheet>');
		return buffer.toString();
	}

	static String _cadenasCompartidas(List<String> cadenas) {
		final items = cadenas
			.map(
				(s) => '<si><t xml:space="preserve">${_escapar(s)}</t></si>',
			)
			.join();
		return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${cadenas.length}" uniqueCount="${cadenas.length}">
$items
</sst>''';
	}

	static String _columna(int indice) {
		var n = indice;
		final chars = <int>[];
		do {
			chars.add(65 + (n % 26));
			n = n ~/ 26 - 1;
		} while (n >= 0);
		return String.fromCharCodes(chars.reversed);
	}

	static String _escapar(String texto) {
		return texto
			.replaceAll('&', '&amp;')
			.replaceAll('<', '&lt;')
			.replaceAll('>', '&gt;')
			.replaceAll('"', '&quot;');
	}
}
