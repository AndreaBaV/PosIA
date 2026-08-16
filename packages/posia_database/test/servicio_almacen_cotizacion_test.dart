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

		test('traspasarTiendaAAlmacenMultiple mueve existencias al almacén', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Block',
					codigoBarras: 'alm-003',
					precioBase: 12.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 8.0,
				),
			);
			final almacen = (await servicio.listarAlmacenes()).first;
			final traspaso = await servicio.traspasarTiendaAAlmacenMultiple(
				tiendaOrigenId: fixture.tiendaOrigenId,
				almacenDestinoId: almacen.id,
				lineas: [
					LineaTraspasoSolicitud(productoId: producto.id, cantidad: 3.0),
				],
				notas: 'Devolución a bodega',
			);
			expect(traspaso.tiendaOrigenId, fixture.tiendaOrigenId);
			expect(
				traspaso.tiendaDestinoId,
				codificarAlmacenEnTraspaso(almacen.id),
			);
			expect(traspaso.estado, EstadoTraspaso.completado);
			expect(traspaso.notas, 'Devolución a bodega');

			final agrupado = await servicio.obtenerInventarioAgrupado(
				tiendaReferenciaId: fixture.tiendaOrigenId,
			);
			final reg = agrupado.firstWhere((r) => r.productoId == producto.id);
			expect(reg.totalGlobal, 5.0);
			expect(reg.totalAlmacenes, 3.0);
			expect(reg.cantidadEnAlmacen(almacen.id), 3.0);

			final cola = SyncEventRepository(baseDatos: fixture.base);
			final pendientes = await cola.obtenerPendientes();
			expect(
				pendientes.any(
					(e) =>
						e.tipo == TipoSyncEvento.transferCompleted &&
						e.payload['almacenDestinoId'] == almacen.id &&
						e.payload['tiendaOrigenId'] == fixture.tiendaOrigenId,
				),
				isTrue,
			);
			await fixture.cerrar();
		});

		test('ajustarStockAlmacen encola stockAdjusted con almacenId', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Cal',
					codigoBarras: 'alm-004',
					precioBase: 40.0,
					categoriaId: fixture.categoriaId,
				),
			);
			final almacen = (await servicio.listarAlmacenes()).first;
			await servicio.ajustarStockAlmacen(
				productoId: producto.id,
				almacenId: almacen.id,
				tipo: TipoMovimientoInventario.entrada,
				cantidad: 7.0,
			);
			final cola = SyncEventRepository(baseDatos: fixture.base);
			final pendientes = await cola.obtenerPendientes();
			expect(
				pendientes.any(
					(e) =>
						e.tipo == TipoSyncEvento.stockAdjusted &&
						e.payload['almacenId'] == almacen.id &&
						(e.payload['delta'] as num?)?.toDouble() == 7.0,
				),
				isTrue,
			);
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

		test('actualizarCotizacion conserva folio y reemplaza líneas', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Varilla 3/8',
					codigoBarras: 'cot-edit-001',
					precioBase: 90.0,
					categoriaId: fixture.categoriaId,
				),
			);
			final original = await servicio.registrarCotizacion(
				lineas: [
					LineaCotizacion(
						productoId: producto.id,
						nombreProducto: producto.nombre,
						cantidad: 2.0,
						precioUnitario: 90.0,
					),
				],
				nombre: 'Obra A',
				notas: 'Borrador',
			);
			final actualizada = await servicio.actualizarCotizacion(
				cotizacionId: original.id,
				lineas: [
					LineaCotizacion(
						productoId: producto.id,
						nombreProducto: producto.nombre,
						cantidad: 5.0,
						precioUnitario: 90.0,
					),
				],
				nombre: 'Obra A revisada',
				notas: 'Ajustada',
				vigenciaDias: 21,
			);
			expect(actualizada.id, original.id);
			expect(actualizada.total, 450.0);
			expect(actualizada.nombre, 'Obra A revisada');
			expect(actualizada.notas, 'Ajustada');
			expect(actualizada.vigenciaDias, 21);
			expect(actualizada.lineas.first.cantidad, 5.0);
			expect(actualizada.creadaEn, original.creadaEn);

			final recuperada = await servicio.obtenerCotizacion(original.id);
			expect(recuperada?.total, 450.0);
			expect(recuperada?.nombre, 'Obra A revisada');
			await fixture.cerrar();
		});

		test('eliminarCotizacion borra del historial', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Cemento',
					codigoBarras: 'cot-del-001',
					precioBase: 150.0,
					categoriaId: fixture.categoriaId,
				),
			);
			final cotizacion = await servicio.registrarCotizacion(
				lineas: [
					LineaCotizacion(
						productoId: producto.id,
						nombreProducto: producto.nombre,
						cantidad: 1.0,
						precioUnitario: 150.0,
					),
				],
			);
			final ok = await servicio.eliminarCotizacion(cotizacion.id);
			expect(ok, isTrue);
			expect(await servicio.obtenerCotizacion(cotizacion.id), isNull);
			expect(
				(await servicio.listarCotizaciones(dias: 1))
					.any((c) => c.id == cotizacion.id),
				isFalse,
			);
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
