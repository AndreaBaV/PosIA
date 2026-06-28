/// Evaluacion del contenido operativo en SQLite local.
library;

import 'package:sqflite/sqflite.dart';

import '../seed/placeholders_ejemplo.dart';

/// Resumen del estado de datos locales del tenant.
class DiagnosticoBaseLocal {
	const DiagnosticoBaseLocal({
		required this.tiendasReales,
		required this.productosReales,
		required this.usuariosReales,
		required this.tieneDatosEjemplo,
	});

	final int tiendasReales;
	final int productosReales;
	final int usuariosReales;
	final bool tieneDatosEjemplo;

	bool get estaVaciaOperativa =>
		tiendasReales == 0 && productosReales == 0 && usuariosReales == 0;

	bool get soloDatosEjemplo =>
		estaVaciaOperativa && tieneDatosEjemplo;

	bool get tieneDatosReales =>
		tiendasReales > 0 || productosReales > 0 || usuariosReales > 0;

	/// Cuenta registros reales excluyendo placeholders de desarrollo.
	static Future<DiagnosticoBaseLocal> evaluar(Database base) async {
		final tiendas = await _contar(
			base,
			'stores',
			excluirId: IdsEjemplo.tienda,
		);
		final productos = await _contar(
			base,
			'products',
			excluirId: IdsEjemplo.producto,
		);
		final usuarios = await _contar(
			base,
			'usuarios',
			excluirId: IdsEjemplo.usuario,
		);
		final ejemploTienda = await _contarExacto(
			base,
			'stores',
			id: IdsEjemplo.tienda,
		);
		final ejemploProducto = await _contarExacto(
			base,
			'products',
			id: IdsEjemplo.producto,
		);
		final ejemploUsuario = await _contarExacto(
			base,
			'usuarios',
			id: IdsEjemplo.usuario,
		);
		return DiagnosticoBaseLocal(
			tiendasReales: tiendas,
			productosReales: productos,
			usuariosReales: usuarios,
			tieneDatosEjemplo:
				ejemploTienda > 0 || ejemploProducto > 0 || ejemploUsuario > 0,
		);
	}

	static Future<int> _contar(
		Database base,
		String tabla, {
		required String excluirId,
	}) async {
		try {
			final filas = await base.rawQuery(
				'SELECT COUNT(*) AS total FROM $tabla WHERE id <> ?',
				[excluirId],
			);
			return (filas.first['total'] as int?) ?? 0;
		} on Object {
			return 0;
		}
	}

	static Future<int> _contarExacto(
		Database base,
		String tabla, {
		required String id,
	}) async {
		try {
			final filas = await base.rawQuery(
				'SELECT COUNT(*) AS total FROM $tabla WHERE id = ?',
				[id],
			);
			return (filas.first['total'] as int?) ?? 0;
		} on Object {
			return 0;
		}
	}
}
