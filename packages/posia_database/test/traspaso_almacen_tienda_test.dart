/// Traspaso almacén → tienda: historial, catálogo y caja.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'fixture_servicio_admin.dart';

void main() {
	group('Traspaso almacén a tienda', () {
		test(
			'registra historial y expone producto en catálogo de tienda destino',
			() async {
				final fixture = await FixtureAdmin.abrir();
				final servicioOrigen = fixture.crearServicio(
					tiendaId: fixture.tiendaOrigenId,
				);
				final producto = await servicioOrigen.registrarProductoCompleto(
					AltaProductoRequest(
						nombre: 'Leche entera',
						codigoBarras: 'leche-001',
						precioBase: 25.0,
						categoriaId: fixture.categoriaId,
						stockInicial: 0.0,
					),
				);
				final almacenCentral = (await servicioOrigen.listarAlmacenes())
					.firstWhere((a) => a.nombre.contains('Central'));
				await servicioOrigen.ajustarStockAlmacen(
					productoId: producto.id,
					almacenId: almacenCentral.id,
					tipo: TipoMovimientoInventario.entrada,
					cantidad: 20.0,
				);

				await servicioOrigen.traspasarAlmacenATiendaMultiple(
					almacenId: almacenCentral.id,
					tiendaDestinoId: fixture.tiendaDestinoId,
					lineas: [
						LineaTraspasoSolicitud(
							productoId: producto.id,
							cantidad: 15.0,
						),
					],
				);

				final historial = await servicioOrigen.listarTraspasos();
				expect(historial, hasLength(1));
				expect(historial.first.almacenOrigenId, almacenCentral.id);
				expect(historial.first.tiendaDestinoId, fixture.tiendaDestinoId);
				expect(historial.first.lineas.first.cantidadSolicitada, 15.0);
				expect(historial.first.lineas.first.nombreProducto, 'Leche entera');

				final servicioDestino = fixture.crearServicio(
					tiendaId: fixture.tiendaDestinoId,
				);
				final catalogoDestino =
					await servicioDestino.listarProductosActivosPorTienda(
						fixture.tiendaDestinoId,
					);
				expect(
					catalogoDestino.any((p) => p.id == producto.id),
					isTrue,
					reason: 'El producto debe aparecer en productos de tienda sur',
				);

				final servicioCaja = fixture.crearServicioCaja(
					tiendaId: fixture.tiendaDestinoId,
				);
				final productosCaja = await servicioCaja.listarProductos();
				expect(
					productosCaja.any((p) => p.id == producto.id),
					isTrue,
					reason: 'El producto debe aparecer en la caja de tienda sur',
				);

				final stockDestino = await fixture.inventarioRepository.obtenerStock(
					producto.id,
					fixture.tiendaDestinoId,
				);
				expect(stockDestino?.cantidad, 15.0);

				await fixture.cerrar();
			},
		);
	});
}
