/// Dominio de vendedores: proyección local de usuarios para UX de caja.
///
/// Extraído de `ServicioAdmin`. La identidad canónica es `Usuario`/`users`
/// (ver `MapaTablasSync.soloLocal`); `Vendedor` es solo local, nunca se
/// sincroniza a Neon.
library;

import 'package:posia_core/posia_core.dart';

import '../repositories/vendedor_repository.dart';

/// Consulta y edición de la proyección local de vendedores.
class AdminVendedores {
	AdminVendedores({VendedorRepository? vendedorRepository})
		: _vendedorRepository = vendedorRepository;

	final VendedorRepository? _vendedorRepository;

	Future<List<Vendedor>> listarVendedores({Usuario? operador}) async {
		final repo = _vendedorRepository;
		if (repo == null) {
			return [];
		}
		if (operador == null ||
			PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			return repo.listarTodos();
		}
		return repo.listarTodos(tiendaId: operador.tiendaId);
	}

	Future<void> actualizarVendedor(Vendedor vendedor, {Usuario? operador}) async {
		final repo = _vendedorRepository;
		if (repo == null) {
			return;
		}
		final existente = await repo.obtenerPorId(vendedor.id);
		if (existente == null) {
			return;
		}
		if (operador != null &&
			!PermisosUsuario.puedeGestionarTodasLasTiendas(operador) &&
			existente.tiendaId != operador.tiendaId) {
			throw StateError('Sin permiso para editar este vendedor');
		}
		await repo.guardar(
			vendedor.copiarCon(
				nombre: vendedor.nombre.trim(),
				codigo: existente.codigo,
				tiendaId: existente.tiendaId,
			),
		);
	}
}
