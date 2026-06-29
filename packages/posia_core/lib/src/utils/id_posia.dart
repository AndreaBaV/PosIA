/// Identificadores legibles y compactos para entidades del POS.
library;

import 'validador_codigo_usuario.dart';

/// Slugs e IDs canonicos (sin UUID) para consultas simples.
class IdPosia {
	const IdPosia._();

	/// El codigo de usuario (ADM001) es su identificador canonico.
	static String usuario(String codigo) => ValidadorCodigoUsuario.normalizar(codigo);

	/// Slug de tienda: `tienda-centro`, `tienda-norte`.
	static String tiendaDesdeNombre(String nombre, {String prefijo = 'tienda'}) {
		final slug = nombre
			.toLowerCase()
			.trim()
			.replaceAll(RegExp(r'[áàäâ]'), 'a')
			.replaceAll(RegExp(r'[éèëê]'), 'e')
			.replaceAll(RegExp(r'[íìïî]'), 'i')
			.replaceAll(RegExp(r'[óòöô]'), 'o')
			.replaceAll(RegExp(r'[úùüû]'), 'u')
			.replaceAll('ñ', 'n')
			.replaceAll(RegExp(r'[^a-z0-9]+'), '-')
			.replaceAll(RegExp(r'^-+|-+$'), '');
		if (slug.isEmpty) {
			return '$prefijo-1';
		}
		return '$prefijo-$slug';
	}

	/// Slug de almacen: `alm-centro`.
	static String almacenDesdeNombre(String nombre) =>
		tiendaDesdeNombre(nombre, prefijo: 'alm');
}
