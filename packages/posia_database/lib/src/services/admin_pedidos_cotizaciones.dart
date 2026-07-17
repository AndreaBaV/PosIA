/// Dominio de pedidos (entrega a domicilio) y cotizaciones: consulta,
/// asignación a empleado y cambios de estado.
///
/// Extraído de `ServicioAdmin`. `registrarPedido`/`registrarCotizacion` (las
/// altas) se quedaron ahí: dependen de `resolverPrecioComercial`, que es un
/// concern de Pricing todavía sin su propio dominio extraído — moverlas
/// aquí habría significado duplicar el motor de precios.
library;

import 'package:posia_core/posia_core.dart';

import '../repositories/cotizacion_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/usuario_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Consulta, asignación y cambios de estado de pedidos y cotizaciones.
class AdminPedidosCotizaciones {
	AdminPedidosCotizaciones({
		required AdminEmisorEventosSync emisorEventos,
		required String tiendaActivaId,
		PedidoRepository? pedidoRepository,
		CotizacionRepository? cotizacionRepository,
		UsuarioRepository? usuarioRepository,
	}) : _emisorEventos = emisorEventos,
	     _tiendaActivaId = tiendaActivaId,
	     _pedidoRepository = pedidoRepository,
	     _cotizacionRepository = cotizacionRepository,
	     _usuarioRepository = usuarioRepository;

	final AdminEmisorEventosSync _emisorEventos;
	final String _tiendaActivaId;
	final PedidoRepository? _pedidoRepository;
	final CotizacionRepository? _cotizacionRepository;
	final UsuarioRepository? _usuarioRepository;

	void _validarGestionPedidos(Usuario? operador) {
		if (operador != null && !PermisosUsuario.puedeGestionarPedidos(operador)) {
			throw StateError('Sin permiso para gestionar pedidos');
		}
	}

	void _validarPermisoTienda(Usuario? operador, String tiendaId) {
		if (operador != null &&
			!PermisosUsuario.puedeGestionarTienda(operador, tiendaId)) {
			throw StateError('Sin permiso para gestionar esta tienda');
		}
	}

	// --- Pedidos ---

	/// Empleados activos elegibles para que se les asigne un pedido.
	Future<List<Usuario>> listarEmpleadosParaAsignacion({
		Usuario? operador,
	}) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			return [];
		}
		final todos = await repo.listarTodos();
		final visibles = operador == null ||
			PermisosUsuario.puedeGestionarTodasLasTiendas(operador)
			? todos
			: todos.where((u) => PermisosUsuario.puedeGestionarUsuario(operador, u)).toList();
		return visibles
			.where(
				(u) =>
					u.activo &&
					u.rol == RolUsuario.empleado &&
					(operador == null ||
						PermisosUsuario.puedeGestionarTodasLasTiendas(operador) ||
						u.tiendaId == operador.tiendaId),
			)
			.toList();
	}

	Future<List<Pedido>> listarPedidosRecibidos({
		String? tiendaId,
		Usuario? operador,
	}) async {
		_validarGestionPedidos(operador);
		final repo = _pedidoRepository;
		if (repo == null) {
			return [];
		}
		final destino = tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, destino);
		return repo.listarPorTienda(destino, soloSinAsignar: true);
	}

	Future<List<Pedido>> listarPedidosTienda({
		String? tiendaId,
		Usuario? operador,
	}) async {
		_validarGestionPedidos(operador);
		final repo = _pedidoRepository;
		if (repo == null) {
			return [];
		}
		final destino = tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, destino);
		return repo.listarPorTienda(destino);
	}

	Future<List<Pedido>> listarPedidosAsignadosA(Usuario empleado) async {
		final repo = _pedidoRepository;
		if (repo == null) {
			return [];
		}
		return repo.listarPorEmpleado(empleado.id);
	}

	/// Pedidos entregados para mostrar en historial de operaciones.
	Future<List<Pedido>> listarPedidosEntregadosHistorial({int dias = 7}) async {
		final repo = _pedidoRepository;
		if (repo == null) {
			return [];
		}
		final desde = DateTime.now().toUtc().subtract(Duration(days: dias));
		return repo.listarEntregadosPorTiendaEnPeriodo(
			_tiendaActivaId,
			desde: desde,
		);
	}

	Future<Pedido?> obtenerPedido(String pedidoId) async {
		return _pedidoRepository?.obtenerPorId(pedidoId);
	}

	Future<Pedido> asignarPedido({
		required String pedidoId,
		required String empleadoUsuarioId,
		Usuario? operador,
	}) async {
		_validarGestionPedidos(operador);
		final repo = _pedidoRepository;
		if (repo == null) {
			throw StateError('Repositorio de pedidos no configurado');
		}
		final pedido = await repo.obtenerPorId(pedidoId);
		if (pedido == null) {
			throw StateError('Pedido no encontrado');
		}
		_validarPermisoTienda(operador, pedido.tiendaId);
		if (!pedido.puedeAsignarse) {
			throw StateError('El pedido no puede asignarse en su estado actual');
		}
		final empleado = await _usuarioRepository?.obtenerPorId(empleadoUsuarioId);
		if (empleado == null || !empleado.activo) {
			throw StateError('Empleado no encontrado');
		}
		if (empleado.rol != RolUsuario.empleado) {
			throw StateError('Solo puede asignarse a empleados');
		}
		if (operador != null &&
			!PermisosUsuario.puedeGestionarTodasLasTiendas(operador) &&
			empleado.tiendaId != operador.tiendaId) {
			throw StateError('El empleado no pertenece a su tienda');
		}
		final actualizado = pedido.copiarCon(
			estado: EstadoPedido.asignado,
			asignadoAUsuarioId: empleado.id,
			asignadoAUsuarioNombre: empleado.nombre,
			asignadoEn: DateTime.now().toUtc(),
		);
		await repo.guardar(actualizado);
		return actualizado;
	}

	Future<Pedido> marcarPedidoEntregado({
		required String pedidoId,
		Usuario? operador,
	}) async {
		final repo = _pedidoRepository;
		if (repo == null) {
			throw StateError('Repositorio de pedidos no configurado');
		}
		final pedido = await repo.obtenerPorId(pedidoId);
		if (pedido == null) {
			throw StateError('Pedido no encontrado');
		}
		if (operador != null &&
			operador.rol == RolUsuario.empleado &&
			pedido.asignadoAUsuarioId != operador.id) {
			throw StateError('Este pedido no esta asignado a usted');
		}
		if (operador != null &&
			operador.rol != RolUsuario.empleado &&
			!PermisosUsuario.puedeGestionarPedidos(operador)) {
			throw StateError('Sin permiso');
		}
		if (!pedido.puedeMarcarseEntregado) {
			throw StateError('El pedido no puede marcarse como entregado');
		}
		final actualizado = pedido.copiarCon(estado: EstadoPedido.entregado);
		await repo.guardar(actualizado);
		return actualizado;
	}

	Future<Pedido> cancelarPedido({
		required String pedidoId,
		Usuario? operador,
	}) async {
		_validarGestionPedidos(operador);
		final repo = _pedidoRepository;
		if (repo == null) {
			throw StateError('Repositorio de pedidos no configurado');
		}
		final pedido = await repo.obtenerPorId(pedidoId);
		if (pedido == null) {
			throw StateError('Pedido no encontrado');
		}
		_validarPermisoTienda(operador, pedido.tiendaId);
		if (pedido.estado == EstadoPedido.entregado) {
			throw StateError('No se puede cancelar un pedido entregado');
		}
		final actualizado = pedido.copiarCon(estado: EstadoPedido.cancelado);
		await repo.guardar(actualizado);
		return actualizado;
	}

	// --- Cotizaciones ---

	Future<List<Cotizacion>> listarCotizaciones({int dias = 30}) async {
		final repo = _cotizacionRepository;
		if (repo == null) {
			return [];
		}
		final desde = DateTime.now().toUtc().subtract(Duration(days: dias));
		return repo.listarPorTienda(_tiendaActivaId, desde: desde);
	}

	Future<Cotizacion?> obtenerCotizacion(String cotizacionId) async {
		return _cotizacionRepository?.obtenerPorId(cotizacionId);
	}

	Future<bool> eliminarCotizacion(String cotizacionId) async {
		final repo = _cotizacionRepository;
		if (repo == null) {
			return false;
		}
		final cotizacion = await repo.obtenerPorId(cotizacionId);
		if (cotizacion == null) {
			return false;
		}
		await repo.eliminar(cotizacionId);
		await _emisorEventos.cotizacionEliminada(cotizacionId);
		return true;
	}
}
