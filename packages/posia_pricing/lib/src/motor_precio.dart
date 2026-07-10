/// Motor de resolucion de precios comerciales POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

import 'repositorio_precio.dart';

/// Resuelve precio unitario aplicando reglas de prioridad comercial.
class MotorPrecio {
	/// Crea motor con repositorio de datos de precio.
	///
	/// [repositorioPrecio] Fuente de escalas y precios preferenciales.
	MotorPrecio({required RepositorioPrecio repositorioPrecio})
		: _repositorioPrecio = repositorioPrecio;

	final RepositorioPrecio _repositorioPrecio;

	/// Resuelve precio unitario para el contexto indicado.
	///
	/// [contexto] Datos de producto, cantidad, tienda y cliente.
	/// Retorna [ResultadoPrecio] con precio redondeado y regla aplicada.
	Future<ResultadoPrecio> resolverPrecio(ContextoPrecio contexto) async {
		final precioCliente = await _resolverPrecioClienteProducto(contexto);
		if (precioCliente != null) {
			return precioCliente;
		}

		final precioLista = await _resolverPrecioListaCliente(contexto);
		if (precioLista != null) {
			return precioLista;
		}

		if (contexto.esVentaPorPresentacion) {
			return _resolverPrecioBase(contexto);
		}

		final precioMayoreo = await _resolverPrecioMayoreo(contexto);
		if (precioMayoreo != null) {
			return precioMayoreo;
		}

		return _resolverPrecioBase(contexto);
	}

	/// Indica si al fusionar lineas por peso se promedia (cortes) o recalcula.
	Future<bool> usaFusionPromedioPeso({
		required String productoId,
		required ModuloVertical moduloVertical,
	}) async {
		final escalas = await _repositorioPrecio.obtenerEscalasMayoreo(productoId);
		return productoUsaFusionPromedioPeso(
			moduloVertical: moduloVertical,
			escalas: escalas.map(
				(e) => (
					cantidadMinima: e.cantidadMinima,
					precioUnitario: e.precioUnitario,
				),
			),
		);
	}

	/// Intenta precio fijo cliente-producto.
	///
	/// [contexto] Contexto de cotizacion activo.
	/// Retorna resultado o null si no aplica regla.
	Future<ResultadoPrecio?> _resolverPrecioClienteProducto(
		ContextoPrecio contexto,
	) async {
		final cliente = contexto.cliente;
		if (cliente == null) {
			return null;
		}

		final registro = await _repositorioPrecio.obtenerPrecioClienteProducto(
			cliente.id,
			contexto.idProductoPrecio,
		);
		if (registro == null) {
			return null;
		}

		return ResultadoPrecio(
			precioUnitario: redondearMonto(registro.precioUnitario),
			reglaAplicada: ReglaPrecio.precioClienteProducto,
		);
	}

	/// Intenta precio por lista asignada al cliente.
	///
	/// [contexto] Contexto de cotizacion activo.
	/// Retorna resultado o null si no aplica regla.
	Future<ResultadoPrecio?> _resolverPrecioListaCliente(
		ContextoPrecio contexto,
	) async {
		final cliente = contexto.cliente;
		if (cliente == null) {
			return null;
		}

		final listaId = cliente.listaPreciosId;
		if (listaId == null) {
			return null;
		}

		final precioLista = await _repositorioPrecio.obtenerPrecioLista(
			listaId,
			contexto.idProductoPrecio,
		);
		if (precioLista == null) {
			return null;
		}

		return ResultadoPrecio(
			precioUnitario: redondearMonto(precioLista),
			reglaAplicada: ReglaPrecio.listaPreciosCliente,
		);
	}

	/// Intenta escala de mayoreo por cantidad.
	///
	/// [contexto] Contexto de cotizacion activo.
	/// Retorna resultado o null si no alcanza umbral.
	Future<ResultadoPrecio?> _resolverPrecioMayoreo(
		ContextoPrecio contexto,
	) async {
		final lote = await _repositorioPrecio.obtenerLotePromocionPorProducto(
			contexto.idProductoPrecio,
		);
		if (lote != null &&
			lote.activo &&
			contexto.cantidadEscala + 1e-9 >= lote.cantidadMinima) {
			return ResultadoPrecio(
				precioUnitario: redondearMonto(lote.precioUnitario),
				reglaAplicada: ReglaPrecio.lotePromocion,
			);
		}

		final escalas = await _repositorioPrecio.obtenerEscalasMayoreo(
			contexto.idProductoPrecio,
		);
		if (escalas.isEmpty) {
			return null;
		}

		final escalaAplicable = seleccionarEscalaMayoreoPorCantidad(
			escalas.map(
				(e) => (cantidadMinima: e.cantidadMinima, precioUnitario: e.precioUnitario),
			),
			contexto.cantidadEscala,
		);
		if (escalaAplicable == null) {
			return null;
		}

		return ResultadoPrecio(
			precioUnitario: redondearMonto(escalaAplicable.precioUnitario),
			reglaAplicada: ReglaPrecio.escalaMayoreo,
		);
	}

	/// Aplica precio base del producto.
	///
	/// [contexto] Contexto de cotizacion activo.
	/// Retorna resultado con regla base.
	ResultadoPrecio _resolverPrecioBase(ContextoPrecio contexto) {
		return ResultadoPrecio(
			precioUnitario: redondearMonto(contexto.producto.precioBase),
			reglaAplicada: ReglaPrecio.precioBase,
		);
	}
}
