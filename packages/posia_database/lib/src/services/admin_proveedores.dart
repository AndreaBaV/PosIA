/// Dominio de proveedores: catálogo y alta/edición/baja.
///
/// Extraído de `ServicioAdmin`. `vincularProductoProveedor` se quedó ahí
/// porque muta un `Producto` (dominio de `AdminCatalogoProductos`).
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../repositories/compra_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Catálogo de proveedores.
class AdminProveedores {
	AdminProveedores({
		required AdminEmisorEventosSync emisorEventos,
		ProveedorRepository? proveedorRepository,
		CompraRepository? compraRepository,
	}) : _emisorEventos = emisorEventos,
	     _proveedorRepository = proveedorRepository,
	     _compraRepository = compraRepository;

	final AdminEmisorEventosSync _emisorEventos;
	final ProveedorRepository? _proveedorRepository;
	final CompraRepository? _compraRepository;
	final Uuid _generadorId = const Uuid();

	/// Excluye stubs FK (ver `Proveedor.esStubFk`): no son proveedores reales.
	Future<List<Proveedor>> listarProveedores() async {
		final todos = await _proveedorRepository?.listarTodos() ?? [];
		return todos.where((p) => !p.esStubFk).toList();
	}

	Future<Proveedor?> obtenerProveedor(String proveedorId) {
		return _proveedorRepository?.obtenerPorId(proveedorId) ??
			Future.value(null);
	}

	Future<Proveedor> registrarProveedor({
		required String nombre,
		String contacto = '',
		String telefono = '',
	}) async {
		final repo = _proveedorRepository;
		if (repo == null) {
			throw StateError('Repositorio de proveedores no configurado');
		}
		final proveedor = Proveedor(
			id: _generadorId.v4(),
			nombre: nombre,
			contacto: contacto,
			telefono: telefono,
			activo: true,
		);
		await repo.guardar(proveedor);
		await _emisorEventos.proveedor(proveedor);
		return proveedor;
	}

	Future<void> actualizarProveedor(Proveedor proveedor) async {
		await _proveedorRepository?.guardar(proveedor);
		await _emisorEventos.proveedor(proveedor);
	}

	/// Elimina un proveedor sin compras registradas.
	///
	/// Los productos vinculados quedan sin proveedor asignado (lo resuelve el
	/// llamador; este método solo borra el proveedor).
	/// Lanza [StateError] si el proveedor tiene compras en el historial.
	Future<void> eliminarProveedor(String proveedorId) async {
		final repo = _proveedorRepository;
		if (repo == null) {
			throw StateError('Repositorio de proveedores no configurado');
		}
		if (await (_compraRepository?.contarPorProveedor(proveedorId) ??
					Future.value(0)) >
				0) {
			throw StateError(
				'No se puede eliminar: el proveedor tiene compras registradas',
			);
		}
		await repo.eliminar(proveedorId);
		await _emisorEventos.proveedorEliminado(proveedorId);
	}
}
