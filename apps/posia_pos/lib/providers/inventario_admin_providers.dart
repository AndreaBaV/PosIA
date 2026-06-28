/// Providers compartidos de inventario y almacenes (admin).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'admin_providers.dart';

class DatosInventarioAgrupado {
	const DatosInventarioAgrupado({
		required this.registros,
		required this.tiendaReferenciaId,
		required this.nombresTienda,
		required this.nombresAlmacen,
	});

	final List<InventarioAgrupado> registros;
	final String tiendaReferenciaId;
	final Map<String, String> nombresTienda;
	final Map<String, String> nombresAlmacen;
}

final tiendasInventarioProvider = FutureProvider<List<Tienda>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	return servicio.obtenerTiendasPermitidas(operador: operador);
});

final inventarioAgrupadoProvider = FutureProvider.family<DatosInventarioAgrupado, String?>(
	(ref, tiendaReferenciaId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final tiendas = await servicio.obtenerTiendasPermitidas(
			operador: ref.watch(sesionUsuarioProvider),
		);
		final almacenes = await servicio.listarAlmacenes();
		final referencia = tiendaReferenciaId ?? tiendas.firstOrNull?.id ?? servicio.tiendaActivaId;
		final registros = await servicio.obtenerInventarioAgrupado(tiendaReferenciaId: referencia);
		return DatosInventarioAgrupado(
			registros: registros,
			tiendaReferenciaId: referencia,
			nombresTienda: {for (final t in tiendas) t.id: t.nombre},
			nombresAlmacen: {for (final a in almacenes) a.id: a.nombre},
		);
	},
);

final resumenAlmacenesProvider = FutureProvider<List<ResumenStockAlmacen>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerResumenAlmacenes();
});

final inventarioAlmacenProvider = FutureProvider.family<List<StockPorAlmacen>, String>(
	(ref, almacenId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		return servicio.obtenerInventarioAlmacen(almacenId);
	},
);

final productosAlmacenProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductosCatalogo();
});

final almacenesAdminProvider = FutureProvider<List<Almacen>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarAlmacenes();
});
