/// Sincroniza el registro de vendedor vinculado a una cuenta de usuario.
library;

import 'package:posia_core/posia_core.dart';

import '../repositories/vendedor_repository.dart';

/// Mantiene un vendedor por usuario para ventas y reportes.
class SincronizadorVendedorUsuario {
	const SincronizadorVendedorUsuario._();

	/// Identificador estable del vendedor asociado a un usuario.
	static String idVendedorParaUsuario(String usuarioId) => 'vend-$usuarioId';

	/// Crea o actualiza el vendedor ligado al usuario (nombre, codigo, tienda, activo).
	static Future<Vendedor> sincronizar({
		required VendedorRepository repo,
		required Usuario usuario,
	}) async {
		final vendedor = Vendedor(
			id: idVendedorParaUsuario(usuario.id),
			nombre: usuario.nombre,
			codigo: usuario.codigo,
			activo: usuario.activo,
			tiendaId: usuario.tiendaId,
		);
		await repo.guardar(vendedor);
		return vendedor;
	}
}
