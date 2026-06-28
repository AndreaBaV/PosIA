/// Control de lotes y caducidad integrado en el nucleo.
library;

import 'package:posia_core/src/constants/posia_constants.dart';
import 'package:posia_core/src/enums/nivel_alerta_caducidad.dart';
import 'package:posia_core/src/models/lote_farmacia.dart';
import 'package:posia_core/src/models/producto.dart';
import 'package:posia_core/src/repositories/repositorio_lote_farmacia.dart';

/// Resultado de validacion de lote para venta en caja.
class ResultadoValidacionLote {
	const ResultadoValidacionLote({
		required this.valido,
		required this.mensajeError,
	});

	final bool valido;
	final String mensajeError;
}

/// Seleccion FEFO, alertas y descuento de lotes farmaceuticos.
class ServicioFarmacia {
	ServicioFarmacia({required RepositorioLoteFarmacia repositorioLote})
		: _repositorioLote = repositorioLote;

	final RepositorioLoteFarmacia _repositorioLote;

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

	Future<void> aplicarVentaLote(String loteId, double cantidad) async {
		await _repositorioLote.descontarCantidad(loteId, cantidad);
	}

	Future<List<LoteFarmacia>> listarLotesConAlerta(String tiendaId) async {
		return _repositorioLote.listarPorTienda(tiendaId);
	}

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

	bool productoRequiereLote(Producto producto) {
		return producto.requiereLote();
	}

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
