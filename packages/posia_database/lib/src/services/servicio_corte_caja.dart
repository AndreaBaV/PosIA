/// Servicio de apertura y cierre de turno de caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../repositories/turno_caja_repository.dart';

/// Coordina corte de caja: apertura, acumulacion y cierre.
class ServicioCorteCaja {
	ServicioCorteCaja({
		required TurnoCajaRepository turnoRepository,
		required String tiendaId,
		required String cajaId,
	}) : _turnoRepository = turnoRepository,
	     _tiendaId = tiendaId,
	     _cajaId = cajaId;

	final TurnoCajaRepository _turnoRepository;
	final String _tiendaId;
	final String _cajaId;
	final Uuid _generadorId = const Uuid();

	/// Obtiene turno abierto actual o null.
	Future<TurnoCaja?> obtenerTurnoAbierto() async {
		return _turnoRepository.obtenerTurnoAbierto(_tiendaId, _cajaId);
	}

	/// Indica si hay turno abierto para cobrar.
	Future<bool> tieneTurnoAbierto() async {
		final turno = await obtenerTurnoAbierto();
		return turno != null;
	}

	/// Abre turno con fondo inicial.
	///
	/// [fondoInicial] Efectivo inicial en caja.
	/// [vendedorId] Vendedor que abre el turno.
	Future<TurnoCaja> abrirTurno({
		required double fondoInicial,
		String? vendedorId,
	}) async {
		final existente = await obtenerTurnoAbierto();
		if (existente != null) {
			return existente;
		}
		final turno = TurnoCaja(
			id: _generadorId.v4(),
			tiendaId: _tiendaId,
			cajaId: _cajaId,
			vendedorId: vendedorId,
			fondoInicial: redondearMonto(fondoInicial),
			totalEfectivo: 0.0,
			totalTarjeta: 0.0,
			totalTransferencia: 0.0,
			totalVentas: 0.0,
			cantidadVentas: 0,
			abiertoEn: DateTime.now().toUtc(),
			cerradoEn: null,
			estado: EstadoTurnoCaja.abierto,
		);
		await _turnoRepository.guardar(turno);
		return turno;
	}

	/// Acumula venta en turno abierto.
	///
	/// [venta] Venta completada.
	Future<void> registrarVenta(TurnoCaja turno, Venta venta) async {
		var totalEfectivo = turno.totalEfectivo;
		var totalTarjeta = turno.totalTarjeta;
		var totalTransferencia = turno.totalTransferencia;
		switch (venta.metodoPago) {
			case MetodoPago.efectivo:
				totalEfectivo = totalEfectivo + venta.total;
			case MetodoPago.tarjeta:
				totalTarjeta = totalTarjeta + venta.total;
			case MetodoPago.transferencia:
				totalTransferencia = totalTransferencia + venta.total;
			case MetodoPago.mixto:
				totalEfectivo = totalEfectivo + (venta.montoEfectivo ?? 0.0);
				totalTarjeta = totalTarjeta + (venta.montoTarjeta ?? 0.0);
				totalTransferencia =
					totalTransferencia + (venta.montoTransferencia ?? 0.0);
			case MetodoPago.credito:
				break;
		}
		final actualizado = TurnoCaja(
			id: turno.id,
			tiendaId: turno.tiendaId,
			cajaId: turno.cajaId,
			vendedorId: turno.vendedorId,
			fondoInicial: turno.fondoInicial,
			totalEfectivo: redondearMonto(totalEfectivo),
			totalTarjeta: redondearMonto(totalTarjeta),
			totalTransferencia: redondearMonto(totalTransferencia),
			totalVentas: redondearMonto(turno.totalVentas + venta.total),
			cantidadVentas: turno.cantidadVentas + 1,
			abiertoEn: turno.abiertoEn,
			cerradoEn: null,
			estado: EstadoTurnoCaja.abierto,
		);
		await _turnoRepository.guardar(actualizado);
	}

	/// Resta monto devuelto parcialmente del turno abierto.
	Future<void> registrarDevolucion(Venta venta, double montoDevuelto) async {
		final turnoId = venta.turnoCajaId;
		if (turnoId == null || montoDevuelto <= 0.0) {
			return;
		}
		final turnoAbierto = await obtenerTurnoAbierto();
		if (turnoAbierto == null || turnoAbierto.id != turnoId) {
			return;
		}
		var totalEfectivo = turnoAbierto.totalEfectivo;
		if (venta.metodoPago == MetodoPago.efectivo) {
			totalEfectivo = totalEfectivo - montoDevuelto;
		}
		final actualizado = TurnoCaja(
			id: turnoAbierto.id,
			tiendaId: turnoAbierto.tiendaId,
			cajaId: turnoAbierto.cajaId,
			vendedorId: turnoAbierto.vendedorId,
			fondoInicial: turnoAbierto.fondoInicial,
			totalEfectivo: redondearMonto(totalEfectivo < 0.0 ? 0.0 : totalEfectivo),
			totalTarjeta: turnoAbierto.totalTarjeta,
			totalTransferencia: turnoAbierto.totalTransferencia,
			totalVentas: redondearMonto(
				turnoAbierto.totalVentas - montoDevuelto < 0.0
					? 0.0
					: turnoAbierto.totalVentas - montoDevuelto,
			),
			cantidadVentas: turnoAbierto.cantidadVentas,
			abiertoEn: turnoAbierto.abiertoEn,
			cerradoEn: null,
			estado: EstadoTurnoCaja.abierto,
		);
		await _turnoRepository.guardar(actualizado);
	}

	/// Resta venta anulada del turno abierto asociado.
	///
	/// [venta] Venta anulada con turno_caja_id.
	Future<void> registrarAnulacion(Venta venta) async {
		final turnoId = venta.turnoCajaId;
		if (turnoId == null) {
			return;
		}
		final turnoAbierto = await obtenerTurnoAbierto();
		if (turnoAbierto == null || turnoAbierto.id != turnoId) {
			return;
		}
		var totalEfectivo = turnoAbierto.totalEfectivo;
		if (venta.metodoPago == MetodoPago.efectivo) {
			totalEfectivo = totalEfectivo - venta.total;
		}
		final actualizado = TurnoCaja(
			id: turnoAbierto.id,
			tiendaId: turnoAbierto.tiendaId,
			cajaId: turnoAbierto.cajaId,
			vendedorId: turnoAbierto.vendedorId,
			fondoInicial: turnoAbierto.fondoInicial,
			totalEfectivo: redondearMonto(totalEfectivo < 0.0 ? 0.0 : totalEfectivo),
			totalTarjeta: turnoAbierto.totalTarjeta,
			totalTransferencia: turnoAbierto.totalTransferencia,
			totalVentas: redondearMonto(
				turnoAbierto.totalVentas - venta.total < 0.0
					? 0.0
					: turnoAbierto.totalVentas - venta.total,
			),
			cantidadVentas: turnoAbierto.cantidadVentas > 0
				? turnoAbierto.cantidadVentas - 1
				: 0,
			abiertoEn: turnoAbierto.abiertoEn,
			cerradoEn: null,
			estado: EstadoTurnoCaja.abierto,
		);
		await _turnoRepository.guardar(actualizado);
	}

	/// Cierra turno abierto.
	Future<TurnoCaja?> cerrarTurno() async {
		final turno = await obtenerTurnoAbierto();
		if (turno == null) {
			return null;
		}
		final cerrado = TurnoCaja(
			id: turno.id,
			tiendaId: turno.tiendaId,
			cajaId: turno.cajaId,
			vendedorId: turno.vendedorId,
			fondoInicial: turno.fondoInicial,
			totalEfectivo: turno.totalEfectivo,
			totalTarjeta: turno.totalTarjeta,
			totalTransferencia: turno.totalTransferencia,
			totalVentas: turno.totalVentas,
			cantidadVentas: turno.cantidadVentas,
			abiertoEn: turno.abiertoEn,
			cerradoEn: DateTime.now().toUtc(),
			estado: EstadoTurnoCaja.cerrado,
		);
		await _turnoRepository.guardar(cerrado);
		return cerrado;
	}

	/// Lista turnos recientes de la tienda.
	Future<List<TurnoCaja>> listarTurnosRecientes({int limite = 10}) async {
		return _turnoRepository.listarPorTienda(_tiendaId, limite: limite);
	}
}
