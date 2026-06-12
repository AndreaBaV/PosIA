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
				motivo: 'Conteo fisico',
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
			final servicioOrigen = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final servicioDestino = fixture.crearServicio(tiendaId: fixture.tiendaDestinoId);
			final producto = await servicioOrigen.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Traspaso',
					codigoBarras: '444',
					precioBase: 15.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 20.0,
				),
			);
			final traspaso = await servicioOrigen.solicitarTraspaso(
				tiendaDestinoId: fixture.tiendaDestinoId,
				productoId: producto.id,
				cantidad: 7.0,
			);
			final stockOrigen = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaOrigenId,
			);
			expect(stockOrigen?.cantidad, 13.0);
			final recibido = await servicioDestino.recibirTraspaso(traspaso.id);
			expect(recibido, isTrue);
			final stockDestino = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaDestinoId,
			);
			expect(stockDestino?.cantidad, 7.0);
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
