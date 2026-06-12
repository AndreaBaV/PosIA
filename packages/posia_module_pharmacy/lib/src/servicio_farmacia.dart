/// Servicio de control de lotes y caducidad en farmacia.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

import 'alerta_caducidad.dart';
import 'lote_farmacia.dart';
import 'repositorio_lote_farmacia.dart';

/// Resultado de validacion de lote para venta en caja.
class ResultadoValidacionLote {
	/// Crea resultado de validacion de lote.
	///
	/// [valido] Indica si el lote puede venderse.
	/// [mensajeError] Detalle cuando no es valido.
	const ResultadoValidacionLote({
		required this.valido,
		required this.mensajeError,
	});

	/// Bandera de validez para venta.
	final bool valido;

	/// Mensaje de error para UI.
	final String mensajeError;
}

/// Coordina seleccion FEFO, alertas y descuento de lotes.
class ServicioFarmacia {
	/// Crea servicio con repositorio de lotes.
	///
	/// [repositorioLote] Persistencia de lotes farmacia.
	ServicioFarmacia({required RepositorioLoteFarmacia repositorioLote})
		: _repositorioLote = repositorioLote;

	final RepositorioLoteFarmacia _repositorioLote;

	/// Lista lotes disponibles para venta ordenados FEFO.
	///
	/// [productoId] Producto farmaceutico.
	/// [tiendaId] Tienda activa.
	/// Retorna lotes con existencia positiva no vencidos.
	Future<List<LoteFarmacia>> listarLotesParaVenta(
		String productoId,
		String tiendaId,
	) async {
		final lotes = await _repositorioLote.listarDisponiblesPorProducto(
			productoId,
			tiendaId,
		);
		final lotesValidos = <LoteFarmacia>[];
		for (final lote in lotes) {
			if (!_estaLoteVencido(lote)) {
				lotesValidos.add(lote);
			}
		}
		return lotesValidos;
	}

	/// Valida lote y cantidad antes de agregar al carrito.
	///
	/// [loteId] Lote seleccionado.
	/// [cantidad] Unidades solicitadas.
	/// Retorna resultado de validacion comercial.
	Future<ResultadoValidacionLote> validarLoteParaVenta(
		String loteId,
		double cantidad,
	) async {
		final lote = await _repositorioLote.obtenerPorId(loteId);
		if (lote == null) {
			return const ResultadoValidacionLote(
				valido: false,
				mensajeError: 'Lote no encontrado',
			);
		}
		if (_estaLoteVencido(lote)) {
			return const ResultadoValidacionLote(
				valido: false,
				mensajeError: 'Lote vencido',
			);
		}
		if (cantidad <= 0.0) {
			return const ResultadoValidacionLote(
				valido: false,
				mensajeError: 'Cantidad invalida',
			);
		}
		if (cantidad > lote.cantidad) {
			return const ResultadoValidacionLote(
				valido: false,
				mensajeError: 'Stock insuficiente en lote',
			);
		}
		return const ResultadoValidacionLote(valido: true, mensajeError: '');
	}

	/// Descuenta unidades vendidas del lote tras cobro.
	///
	/// [loteId] Lote vendido.
	/// [cantidad] Unidades descontadas.
	Future<void> aplicarVentaLote(String loteId, double cantidad) async {
		await _repositorioLote.descontarCantidad(loteId, cantidad);
	}

	/// Lista lotes de tienda con alertas de caducidad para admin.
	///
	/// [tiendaId] Tienda consultada.
	/// Retorna lotes activos con existencia.
	Future<List<LoteFarmacia>> listarLotesConAlerta(String tiendaId) async {
		return _repositorioLote.listarPorTienda(tiendaId);
	}

	/// Calcula nivel de alerta visual por fecha de caducidad.
	///
	/// [lote] Lote evaluado.
	/// Retorna [NivelAlertaCaducidad] segun dias restantes.
	NivelAlertaCaducidad calcularAlertaCaducidad(LoteFarmacia lote) {
		if (_estaLoteVencido(lote)) {
			return NivelAlertaCaducidad.critico;
		}
		final diasRestantes = _calcularDiasRestantes(lote.caducaEn);
		if (diasRestantes <= DIAS_ALERTA_CADUCIDAD_ROJA) {
			return NivelAlertaCaducidad.critico;
		}
		if (diasRestantes <= DIAS_ALERTA_CADUCIDAD_AMARILLA) {
			return NivelAlertaCaducidad.advertencia;
		}
		return NivelAlertaCaducidad.normal;
	}

	/// Verifica si producto requiere seleccion de lote.
	///
	/// [producto] Producto en caja.
	/// Retorna verdadero para vertical farmacia.
	bool productoRequiereLote(Producto producto) {
		return producto.requiereLote();
	}

	/// Evalua si la fecha de caducidad ya paso.
	///
	/// [lote] Lote evaluado.
	/// Retorna verdadero si caduco.
	bool _estaLoteVencido(LoteFarmacia lote) {
		final hoy = DateTime.now().toUtc();
		final finDiaCaducidad = DateTime.utc(
			lote.caducaEn.year,
			lote.caducaEn.month,
			lote.caducaEn.day,
			23,
			59,
			59,
		);
		return hoy.isAfter(finDiaCaducidad);
	}

	/// Calcula dias naturales hasta caducidad inclusive.
	///
	/// [caducaEn] Fecha de caducidad del lote.
	/// Retorna dias restantes como entero no negativo.
	int _calcularDiasRestantes(DateTime caducaEn) {
		final hoy = DateTime.now().toUtc();
		final inicioHoy = DateTime.utc(hoy.year, hoy.month, hoy.day);
		final finCaducidad = DateTime.utc(caducaEn.year, caducaEn.month, caducaEn.day);
		final diferencia = finCaducidad.difference(inicioHoy).inDays;
		if (diferencia < 0) {
			return 0;
		}
		return diferencia;
	}
}
