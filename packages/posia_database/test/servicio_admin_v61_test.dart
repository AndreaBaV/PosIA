/// Pruebas v6.1 de ServicioAdmin e inventario.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:uuid/uuid.dart';

import 'fixture_servicio_admin.dart';

void main() {
	const uuid = Uuid();

	group('ServicioAdmin v6.1', () {
		test('registrarProductoCompleto exige categoria', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			expect(
				() => servicio.registrarProductoCompleto(
					const AltaProductoRequest(
						nombre: 'Sin categoria',
						codigoBarras: '111',
						precioBase: 10.0,
						categoriaId: '',
					),
				),
				throwsA(isA<StateError>()),
			);
			await fixture.cerrar();
		});

		test('registrarProductoCompleto persiste producto con categoria', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Arroz',
					codigoBarras: '7501234567890',
					precioBase: 25.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 12.0,
				),
			);
			expect(producto.categoriaId, fixture.categoriaId);
			final stock = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaOrigenId,
			);
			expect(stock?.cantidad, 12.0);
			await fixture.cerrar();
		});

		test('eliminarProducto rechaza si stock mayor a cero', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Con stock',
					codigoBarras: '222',
					precioBase: 5.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 3.0,
				),
			);
			final eliminado = await servicio.eliminarProducto(producto.id);
			expect(eliminado, isFalse);
			await fixture.cerrar();
		});

		test('eliminarProductoPermanente borra producto sin stock', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Sin stock',
					codigoBarras: '223',
					precioBase: 5.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 0.0,
				),
			);
			final eliminado = await servicio.eliminarProductoPermanente(producto.id);
			expect(eliminado, isTrue);
			final restante = await servicio.obtenerProducto(producto.id);
			expect(restante, isNull);
			await fixture.cerrar();
		});

		test('movimiento ajuste fija cantidad absoluta', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Ajustable',
					codigoBarras: '333',
					precioBase: 8.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 10.0,
				),
			);
			await servicio.registrarMovimientoInventario(
				productoId: producto.id,
				tipo: TipoMovimientoInventario.ajuste,
				cantidad: 4.0,
				motivo: 'Conteo físico',
			);
			final stock = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaOrigenId,
			);
			expect(stock?.cantidad, 4.0);
			await fixture.cerrar();
		});

		test('traspaso actualiza stock en origen y destino', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Traspaso',
					codigoBarras: '444',
					precioBase: 15.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 20.0,
				),
			);
			await servicio.realizarTraspaso(
				tiendaOrigenId: fixture.tiendaOrigenId,
				tiendaDestinoId: fixture.tiendaDestinoId,
				productoId: producto.id,
				cantidad: 7.0,
			);
			final stockOrigen = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaOrigenId,
			);
			expect(stockOrigen?.cantidad, 13.0);
			final stockDestino = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaDestinoId,
			);
			expect(stockDestino?.cantidad, 7.0);
			await fixture.cerrar();
		});

		test('registrarCompra aumenta stock y actualiza costo', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final proveedor = await servicio.registrarProveedor(nombre: 'Distribuidora');
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Comprado',
					codigoBarras: '555',
					precioBase: 20.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 5.0,
					costoUnitario: 8.0,
				),
			);
			final compra = await servicio.registrarCompra(
				proveedorId: proveedor.id,
				fechaCompra: DateTime.utc(2026, 6, 22),
				lineas: [
					LineaCompraSolicitud(
						productoId: producto.id,
						cantidad: 10.0,
						costoUnitario: 9.5,
					),
				],
			);
			expect(compra.lineas.length, 1);
			expect(compra.total, 95.0);
			final stock = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaOrigenId,
			);
			expect(stock?.cantidad, 15.0);
			final actualizado = await servicio.obtenerProducto(producto.id);
			expect(actualizado?.costoUnitario, 9.5);
			final historial = await servicio.listarCompras();
			expect(historial.any((c) => c.id == compra.id), isTrue);
			await fixture.cerrar();
		});

		test('listarVentasCliente retorna ventas filtradas', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final cliente = await servicio.registrarCliente(nombre: 'Juan');
			final otroCliente = await servicio.registrarCliente(nombre: 'Maria');
			final ahora = DateTime.now().toUtc();
			await fixture.ventaRepository.guardar(
				Venta(
					id: uuid.v4(),
					tiendaId: fixture.tiendaOrigenId,
					cajaId: cajaPruebaId,
					clienteId: cliente.id,
					lineas: const [],
					metodoPago: MetodoPago.efectivo,
					total: 100.0,
					creadaEn: ahora,
				),
			);
			await fixture.ventaRepository.guardar(
				Venta(
					id: uuid.v4(),
					tiendaId: fixture.tiendaOrigenId,
					cajaId: cajaPruebaId,
					clienteId: otroCliente.id,
					lineas: const [],
					metodoPago: MetodoPago.efectivo,
					total: 50.0,
					creadaEn: ahora,
				),
			);
			final ventas = await servicio.listarVentasCliente(cliente.id, dias: 30);
			expect(ventas, hasLength(1));
			expect(ventas.first.clienteId, cliente.id);
			expect(ventas.first.total, 100.0);
			await fixture.cerrar();
		});
	});
}
