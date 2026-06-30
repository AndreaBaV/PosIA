/// Integración: almacenes, inventario consolidado y cotizaciones.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'fixture_servicio_admin.dart';

void main() {
	group('Almacén e inventario consolidado', () {
		test('listarAlmacenes siembra ubicaciones iniciales', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final almacenes = await servicio.listarAlmacenes();
			expect(almacenes.length, greaterThanOrEqualTo(3));
			expect(almacenes.any((a) => a.nombre.contains('Norte')), isTrue);
			await fixture.cerrar();
		});

		test('ajustarStockAlmacen y obtenerInventarioAgrupado reflejan totales', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Grava',
					codigoBarras: 'alm-001',
					precioBase: 100.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 4.0,
				),
			);
			final almacenes = await servicio.listarAlmacenes();
			final norte = almacenes.firstWhere((a) => a.nombre.contains('Norte'));
			final sur = almacenes.firstWhere((a) => a.nombre.contains('Sur'));

			await servicio.ajustarStockAlmacen(
				productoId: producto.id,
				almacenId: norte.id,
				tipo: TipoMovimientoInventario.entrada,
				cantidad: 5.0,
			);
			await servicio.ajustarStockAlmacen(
				productoId: producto.id,
				almacenId: sur.id,
				tipo: TipoMovimientoInventario.entrada,
				cantidad: 3.0,
			);

			final agrupado = await servicio.obtenerInventarioAgrupado(
				tiendaReferenciaId: fixture.tiendaOrigenId,
			);
			final reg = agrupado.firstWhere((r) => r.productoId == producto.id);
			expect(reg.totalGlobal, 4.0);
			expect(reg.totalAlmacenes, 8.0);
			expect(reg.totalEmpresa, 12.0);
			expect(reg.cantidadEnAlmacen(norte.id), 5.0);
			expect(reg.cantidadEnAlmacen(sur.id), 3.0);

			final resumen = await servicio.obtenerResumenAlmacenes();
			final resumenNorte = resumen.firstWhere((r) => r.almacenId == norte.id);
			expect(resumenNorte.productosConStock, 1);
			expect(resumenNorte.totalUnidades, 5.0);
			await fixture.cerrar();
		});

		test('traspasarAlmacenATienda mueve existencias al piso de venta', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Arena',
					codigoBarras: 'alm-002',
					precioBase: 80.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 1.0,
				),
			);
			final almacen = (await servicio.listarAlmacenes()).first;
			await servicio.ajustarStockAlmacen(
				productoId: producto.id,
				almacenId: almacen.id,
				tipo: TipoMovimientoInventario.entrada,
				cantidad: 6.0,
			);
			await servicio.traspasarAlmacenATienda(
				almacenId: almacen.id,
				tiendaDestinoId: fixture.tiendaOrigenId,
				productoId: producto.id,
				cantidad: 2.0,
			);

			final traspasos = await servicio.listarTraspasos();
			expect(traspasos, hasLength(1));
			expect(
				traspasos.first.tiendaOrigenId,
				codificarAlmacenEnTraspaso(almacen.id),
			);
			expect(traspasos.first.tiendaDestinoId, fixture.tiendaOrigenId);
			expect(traspasos.first.estado, EstadoTraspaso.completado);
			expect(traspasos.first.lineas, hasLength(1));
			expect(traspasos.first.lineas.first.nombreProducto, 'Arena');

			final agrupado = await servicio.obtenerInventarioAgrupado(
				tiendaReferenciaId: fixture.tiendaOrigenId,
			);
			final reg = agrupado.firstWhere((r) => r.productoId == producto.id);
			expect(reg.totalGlobal, 3.0);
			expect(reg.totalAlmacenes, 4.0);
			await fixture.cerrar();
		});
	});

	group('Cotizaciones', () {
		test('listarCotizaciones vacío al inicio', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			expect(await servicio.listarCotizaciones(), isEmpty);
			await fixture.cerrar();
		});

		test('listarCreditosPendientes vacío al inicio', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			expect(await servicio.listarCreditosPendientes(), isEmpty);
			await fixture.cerrar();
		});

		test('registrarCotizacion desde administración persiste líneas', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Tubería',
					codigoBarras: 'cot-001',
					precioBase: 120.0,
					categoriaId: fixture.categoriaId,
				),
			);
			final cotizacion = await servicio.registrarCotizacion(
				lineas: [
					LineaCotizacion(
						productoId: producto.id,
						nombreProducto: producto.nombre,
						cantidad: 2.0,
						precioUnitario: 120.0,
					),
				],
				vigenciaDias: 14,
				notas: 'Entrega en obra',
			);
			expect(cotizacion.total, 240.0);
			expect(cotizacion.vigenciaDias, 14);
			expect(cotizacion.notas, 'Entrega en obra');

			final listado = await servicio.listarCotizaciones(dias: 1);
			expect(listado.any((c) => c.id == cotizacion.id), isTrue);
			await fixture.cerrar();
		});

		test('registrarCotizacionCarrito desde caja persiste folio', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final servicioCaja = fixture.crearServicioCaja(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Varilla',
					codigoBarras: 'cot-002',
					precioBase: 90.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 10.0,
				),
			);
			await servicioCaja.agregarProducto(producto, cantidad: 3.0);
			final cotizacion = await servicioCaja.registrarCotizacionCarrito(notas: 'Mostrador');
			expect(cotizacion.total, 270.0);
			expect(cotizacion.lineas, hasLength(1));

			final recuperada = await servicioAdmin.obtenerCotizacion(cotizacion.id);
			expect(recuperada?.notas, 'Mostrador');
			await fixture.cerrar();
		});
	});
}
