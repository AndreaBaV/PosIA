/// Dominio de reportes de ventas: resúmenes por vendedor, producto, hora
/// y método de pago.
///
/// Extraído de `ServicioAdmin`.
library;

import 'package:posia_core/posia_core.dart';

import '../models/resumen_vendedor.dart';
import '../repositories/venta_repository.dart';
import 'admin_vendedores.dart';

/// Agregaciones de ventas para el panel de reportes.
class AdminReportes {
	AdminReportes({
		required VentaRepository ventaRepository,
		required AdminVendedores vendedores,
	}) : _ventaRepository = ventaRepository,
	     _vendedores = vendedores;

	final VentaRepository _ventaRepository;
	final AdminVendedores _vendedores;

	Future<List<ResumenVendedor>> obtenerResumenPorVendedor(
		FiltroVentas filtro,
	) async {
		final ventas = await _ventaRepository.listarConFiltro(filtro);
		final vendedores = await _vendedores.listarVendedores();
		final nombres = {for (final v in vendedores) v.id: v.nombre};
		final acumulado = <String, ResumenVendedor>{};
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			final vendedorId = venta.vendedorId ?? 'sin-vendedor';
			final previo = acumulado[vendedorId];
			acumulado[vendedorId] = ResumenVendedor(
				vendedorId: vendedorId,
				nombreVendedor: nombres[vendedorId] ?? 'Sin vendedor',
				cantidadVentas: (previo?.cantidadVentas ?? 0) + 1,
				totalVendido: redondearMonto(
					(previo?.totalVendido ?? 0.0) + venta.total,
				),
			);
		}
		final lista = acumulado.values.toList()
			..sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
		return lista;
	}

	Future<List<ResumenProductoVenta>> obtenerResumenPorProducto(
		FiltroVentas filtro,
	) async {
		return _ventaRepository.resumenPorProducto(filtro);
	}

	Future<List<ResumenVentasHora>> obtenerResumenPorHora(
		FiltroVentas filtro,
	) async {
		return _ventaRepository.resumenPorHora(filtro);
	}

	Future<Map<MetodoPago, double>> obtenerTotalesPorMetodoPago(
		FiltroVentas filtro,
	) async {
		return _ventaRepository.totalesPorMetodoPago(filtro);
	}
}
