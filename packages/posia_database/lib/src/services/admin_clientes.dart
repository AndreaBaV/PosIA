/// Dominio de clientes: catálogo, historial de compras, descuentos y
/// precios especiales por cliente-producto.
///
/// Extraído de `ServicioAdmin`.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:uuid/uuid.dart';

import '../repositories/cliente_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/venta_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';
import 'admin_catalogo_productos.dart';

/// Catálogo de clientes, su historial, descuentos y precios especiales.
class AdminClientes {
	AdminClientes({
		required ProductoRepository productoRepository,
		required VentaRepository ventaRepository,
		required AdminEmisorEventosSync emisorEventos,
		required AdminCatalogoProductos catalogoProductos,
		required String tiendaActivaId,
		ClienteRepository? clienteRepository,
		DescuentoClienteRepository? descuentoClienteRepository,
		PrecioRepository? precioRepository,
		PedidoRepository? pedidoRepository,
		CotizacionRepository? cotizacionRepository,
	}) : _productoRepository = productoRepository,
	     _ventaRepository = ventaRepository,
	     _emisorEventos = emisorEventos,
	     _catalogoProductos = catalogoProductos,
	     _tiendaActivaId = tiendaActivaId,
	     _clienteRepository = clienteRepository,
	     _descuentoClienteRepository = descuentoClienteRepository,
	     _precioRepository = precioRepository,
	     _pedidoRepository = pedidoRepository,
	     _cotizacionRepository = cotizacionRepository;

	final ProductoRepository _productoRepository;
	final VentaRepository _ventaRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final AdminCatalogoProductos _catalogoProductos;
	final String _tiendaActivaId;
	final ClienteRepository? _clienteRepository;
	final DescuentoClienteRepository? _descuentoClienteRepository;
	final PrecioRepository? _precioRepository;
	final PedidoRepository? _pedidoRepository;
	final CotizacionRepository? _cotizacionRepository;
	final Uuid _generadorId = const Uuid();

	// --- Clientes ---

	Future<List<Cliente>> listarClientes() async {
		return _clienteRepository?.listarTodos() ?? [];
	}

	Future<Cliente> registrarCliente({
		required String nombre,
		bool creditoHabilitado = false,
	}) async {
		final repo = _clienteRepository;
		if (repo == null) {
			throw StateError('Repositorio de clientes no configurado');
		}
		final cliente = Cliente(
			id: _generadorId.v4(),
			nombre: nombre,
			listaPreciosId: null,
			creditoHabilitado: creditoHabilitado,
			activo: true,
		);
		await repo.guardar(cliente);
		await _emisorEventos.cliente(cliente);
		return cliente;
	}

	Future<void> actualizarCliente(Cliente cliente) async {
		await _clienteRepository?.guardar(cliente);
		await _emisorEventos.cliente(cliente);
	}

	/// Elimina un cliente sin historial de ventas, pedidos ni cotizaciones.
	///
	/// Lanza [StateError] si el cliente tiene movimientos registrados.
	Future<void> eliminarCliente(String clienteId) async {
		final repo = _clienteRepository;
		if (repo == null) {
			throw StateError('Repositorio de clientes no configurado');
		}
		if (await _ventaRepository.contarPorCliente(clienteId) > 0) {
			throw StateError(
				'No se puede eliminar: el cliente tiene ventas registradas',
			);
		}
		if (await (_pedidoRepository?.contarPorCliente(clienteId) ??
					Future.value(0)) >
				0) {
			throw StateError(
				'No se puede eliminar: el cliente tiene pedidos registrados',
			);
		}
		if (await (_cotizacionRepository?.contarPorCliente(clienteId) ??
					Future.value(0)) >
				0) {
			throw StateError(
				'No se puede eliminar: el cliente tiene cotizaciones registradas',
			);
		}
		await repo.eliminar(clienteId);
	}

	Future<Cliente?> obtenerCliente(String clienteId) async {
		return _clienteRepository?.obtenerPorId(clienteId);
	}

	Future<List<Venta>> listarVentasCliente(
		String clienteId, {
		int dias = 90,
	}) async {
		final hasta = DateTime.now().toUtc();
		final desde = hasta.subtract(Duration(days: dias));
		return _ventaRepository.listarConFiltro(
			FiltroVentas(
				tiendaId: _tiendaActivaId,
				desde: desde,
				hasta: hasta,
				clienteId: clienteId,
			),
		);
	}

	Future<ResumenCliente> obtenerResumenCliente(String clienteId) async {
		final ventas = await listarVentasCliente(clienteId, dias: 365);
		var total = 0.0;
		var cantidad = 0;
		DateTime? ultima;
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			cantidad = cantidad + 1;
			total = total + venta.total;
			if (ultima == null || venta.creadaEn.isAfter(ultima)) {
				ultima = venta.creadaEn;
			}
		}
		return ResumenCliente(
			clienteId: clienteId,
			cantidadVentas: cantidad,
			totalComprado: redondearMonto(total),
			ultimaCompraEn: ultima,
		);
	}

	// --- Descuentos de cliente ---

	Future<List<DescuentoCliente>> listarDescuentosCliente(
		String clienteId,
	) async {
		return _descuentoClienteRepository?.listarPorCliente(clienteId) ?? [];
	}

	Future<DescuentoCliente> registrarDescuentoCliente({
		required String clienteId,
		required TipoDescuentoCliente tipo,
		required double valor,
		required CondicionDescuentoCliente condicion,
		String? productoId,
		double? umbral,
		String descripcion = '',
	}) async {
		final repo = _descuentoClienteRepository;
		if (repo == null) {
			throw StateError('Repositorio de descuentos no configurado');
		}
		_validarDescuentoCliente(
			tipo: tipo,
			valor: valor,
			condicion: condicion,
			productoId: productoId,
			umbral: umbral,
		);
		final descuento = DescuentoCliente(
			id: _generadorId.v4(),
			clienteId: clienteId,
			tipo: tipo,
			valor: valor,
			condicion: condicion,
			productoId: productoId,
			umbral: umbral,
			activo: true,
			descripcion: descripcion.trim(),
		);
		await repo.guardar(descuento);
		await _emisorEventos.descuentoCliente(descuento);
		return descuento;
	}

	Future<void> actualizarDescuentoCliente(DescuentoCliente descuento) async {
		final repo = _descuentoClienteRepository;
		if (repo == null) {
			return;
		}
		_validarDescuentoCliente(
			tipo: descuento.tipo,
			valor: descuento.valor,
			condicion: descuento.condicion,
			productoId: descuento.productoId,
			umbral: descuento.umbral,
		);
		await repo.guardar(descuento);
		await _emisorEventos.descuentoCliente(descuento);
	}

	Future<void> eliminarDescuentoCliente(String descuentoId) async {
		await _descuentoClienteRepository?.eliminar(descuentoId);
		await _emisorEventos.descuentoClienteEliminado(descuentoId);
	}

	void _validarDescuentoCliente({
		required TipoDescuentoCliente tipo,
		required double valor,
		required CondicionDescuentoCliente condicion,
		String? productoId,
		double? umbral,
	}) {
		if (valor <= 0) {
			throw StateError('El valor del descuento debe ser mayor a cero');
		}
		if ((tipo == TipoDescuentoCliente.porcentajeGeneral ||
					tipo == TipoDescuentoCliente.porcentajeProducto) &&
				valor > 100) {
			throw StateError('El porcentaje no puede superar 100');
		}
		if (tipo.esPorProducto && productoId == null) {
			throw StateError('Seleccione un producto');
		}
		if (condicion != CondicionDescuentoCliente.siempre &&
				(umbral == null || umbral <= 0)) {
			throw StateError('Indique el umbral de la regla');
		}
		if (condicion == CondicionDescuentoCliente.cantidadMinima &&
				tipo.esGeneral) {
			throw StateError(
				'La cantidad minima aplica solo a descuentos por producto',
			);
		}
		if (condicion == CondicionDescuentoCliente.montoTicketMinimo &&
				tipo.esPorProducto) {
			throw StateError('El monto minimo aplica solo a descuentos generales');
		}
	}

	// --- Precios especiales de cliente ---

	Future<List<PrecioClienteProducto>> listarPreciosEspecialesCliente(
		String clienteId,
	) async {
		return _precioRepository?.listarPreciosPorCliente(clienteId) ?? [];
	}

	Future<void> guardarPrecioEspecialCliente({
		required String clienteId,
		required String productoId,
		required double precioUnitario,
	}) async {
		final repo = _precioRepository;
		if (repo == null) {
			throw StateError('Repositorio de precios no configurado');
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			throw StateError('Producto no encontrado');
		}
		_catalogoProductos.validarPrecioVenta(precioUnitario, producto.costoUnitario);
		await repo.guardarPrecioClienteProducto(
			PrecioClienteProducto(
				clienteId: clienteId,
				productoId: productoId,
				precioUnitario: redondearMonto(precioUnitario),
			),
		);
		await _emisorEventos.precioClienteProducto(
			clienteId: clienteId,
			productoId: productoId,
			precioUnitario: redondearMonto(precioUnitario),
		);
	}

	Future<void> eliminarPrecioEspecialCliente(
		String clienteId,
		String productoId,
	) async {
		await _precioRepository?.eliminarPrecioClienteProducto(
			clienteId,
			productoId,
		);
		await _emisorEventos.precioClienteProductoEliminado(
			clienteId: clienteId,
			productoId: productoId,
		);
	}
}
