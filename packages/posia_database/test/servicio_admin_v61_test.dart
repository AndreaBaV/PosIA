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
						asignaciones: [
							AsignacionInventarioCompra(
								productoId: producto.id,
								destinoTipo: AsignacionInventarioCompra.destinoTienda,
								destinoId: fixture.tiendaOrigenId,
								cantidad: 10.0,
							),
						],
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

		test('registrarCompra distribuye inventario entre tienda y almacen', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final proveedor = await servicio.registrarProveedor(nombre: 'Multi destino');
			final almacen = await servicio.registrarAlmacen('CEDIS');
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Mixto',
					codigoBarras: '888',
					precioBase: 20.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 0.0,
				),
			);
			final compra = await servicio.registrarCompra(
				proveedorId: proveedor.id,
				fechaCompra: DateTime.utc(2026, 7, 1),
				lineas: [
					LineaCompraSolicitud(
						productoId: producto.id,
						cantidad: 10.0,
						costoUnitario: 8.0,
						asignaciones: [
							AsignacionInventarioCompra(
								productoId: producto.id,
								destinoTipo: AsignacionInventarioCompra.destinoTienda,
								destinoId: fixture.tiendaOrigenId,
								cantidad: 6.0,
							),
							AsignacionInventarioCompra(
								productoId: producto.id,
								destinoTipo: AsignacionInventarioCompra.destinoAlmacen,
								destinoId: almacen.id,
								cantidad: 4.0,
							),
						],
					),
				],
			);
			expect(compra.tiendaId, isNull);
			expect(compra.asignaciones, hasLength(2));
			final stockTienda = await fixture.inventarioRepository.obtenerStock(
				producto.id,
				fixture.tiendaOrigenId,
			);
			expect(stockTienda?.cantidad, 6.0);
			final stockAlmacen = await fixture.almacenRepository.obtenerStock(
				producto.id,
				almacen.id,
			);
			expect(stockAlmacen?.cantidad, 4.0);
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

		test('eliminarCliente borra cliente sin historial', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final cliente = await servicio.registrarCliente(nombre: 'Temporal');
			await servicio.eliminarCliente(cliente.id);
			expect(await servicio.obtenerCliente(cliente.id), isNull);
			await fixture.cerrar();
		});

		test('eliminarCliente rechaza si tiene ventas', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final cliente = await servicio.registrarCliente(nombre: 'Con ventas');
			await fixture.ventaRepository.guardar(
				Venta(
					id: uuid.v4(),
					tiendaId: fixture.tiendaOrigenId,
					cajaId: cajaPruebaId,
					clienteId: cliente.id,
					lineas: const [],
					metodoPago: MetodoPago.efectivo,
					total: 10.0,
					creadaEn: DateTime.now().toUtc(),
				),
			);
			expect(
				() => servicio.eliminarCliente(cliente.id),
				throwsA(isA<StateError>()),
			);
			await fixture.cerrar();
		});

		test('eliminarProveedor borra proveedor sin compras', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final proveedor = await servicio.registrarProveedor(nombre: 'Temporal');
			await servicio.eliminarProveedor(proveedor.id);
			expect(await servicio.obtenerProveedor(proveedor.id), isNull);
			await fixture.cerrar();
		});

		test('eliminarProveedor rechaza si tiene compras', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final proveedor = await servicio.registrarProveedor(nombre: 'Con compras');
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Item compra',
					codigoBarras: '777',
					precioBase: 10.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 0.0,
				),
			);
			await servicio.registrarCompra(
				proveedorId: proveedor.id,
				fechaCompra: DateTime.utc(2026, 6, 22),
				lineas: [
					LineaCompraSolicitud(
						productoId: producto.id,
						cantidad: 1.0,
						costoUnitario: 5.0,
						asignaciones: [
							AsignacionInventarioCompra(
								productoId: producto.id,
								destinoTipo: AsignacionInventarioCompra.destinoTienda,
								destinoId: fixture.tiendaOrigenId,
								cantidad: 1.0,
							),
						],
					),
				],
			);
			expect(
				() => servicio.eliminarProveedor(proveedor.id),
				throwsA(isA<StateError>()),
			);
			await fixture.cerrar();
		});

		test('resumenPorProducto fusiona mismo nombre con distinto productoId', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final ahora = DateTime.now().toUtc();
			final filtro = servicio.filtroVentasReporte(dias: 7);
			await fixture.ventaRepository.guardar(
				Venta(
					id: uuid.v4(),
					tiendaId: fixture.tiendaOrigenId,
					cajaId: cajaPruebaId,
					clienteId: null,
					lineas: [
						LineaVenta(
							productoId: uuid.v4(),
							nombreProducto: 'Refresco Cola',
							cantidad: 2.0,
							precioUnitario: 15.0,
							reglaPrecio: ReglaPrecio.precioBase,
						),
					],
					metodoPago: MetodoPago.efectivo,
					total: 30.0,
					creadaEn: ahora,
				),
			);
			await fixture.ventaRepository.guardar(
				Venta(
					id: uuid.v4(),
					tiendaId: fixture.tiendaOrigenId,
					cajaId: cajaPruebaId,
					clienteId: null,
					lineas: [
						LineaVenta(
							productoId: uuid.v4(),
							nombreProducto: 'Refresco Cola',
							cantidad: 3.0,
							precioUnitario: 15.0,
							reglaPrecio: ReglaPrecio.precioBase,
						),
					],
					metodoPago: MetodoPago.efectivo,
					total: 45.0,
					creadaEn: ahora,
				),
			);
			final resumen = await servicio.obtenerResumenPorProducto(filtro);
			expect(resumen, hasLength(1));
			expect(resumen.first.nombreProducto, 'Refresco Cola');
			expect(resumen.first.cantidadVendida, 5.0);
			expect(resumen.first.totalVendido, 75.0);
			await fixture.cerrar();
		});

		test('registrarVentaCredito crea venta pendiente de liquidar', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final cliente = await servicio.registrarCliente(nombre: 'Fiado');
			await servicio.actualizarCliente(
				cliente.copiarCon(
					creditoHabilitado: true,
					telefono: '5551234567',
					direccion: 'Calle 1',
					diasCredito: 15,
				),
			);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Fiado item',
					codigoBarras: '888',
					precioBase: 50.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 10.0,
				),
			);
			final venta = await servicio.registrarVentaCredito(
				clienteId: cliente.id,
				lineas: [
					LineaPedidoSolicitud(
						productoId: producto.id,
						cantidad: 2.0,
						precioUnitario: 50.0,
					),
				],
			);
			expect(venta.metodoPago, MetodoPago.credito);
			expect(venta.total, 100.0);
			expect(venta.creditoLiquidado, isFalse);
			final pendientes = await servicio.listarCreditosPendientes();
			expect(pendientes.any((v) => v.id == venta.id), isTrue);
			await fixture.cerrar();
		});

		test('registrarListaPrecios encola evento de sincronizacion', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final cola = SyncEventRepository(baseDatos: fixture.base);
			final lista = await servicio.registrarListaPrecios('Mayoreo');
			final pendientes = await cola.obtenerPendientes();
			expect(
				pendientes.any(
					(e) =>
						e.tipo == TipoSyncEvento.priceListUpserted &&
						e.payload['id'] == lista.id,
				),
				isTrue,
			);
			await fixture.cerrar();
		});

		test('guardarPrecioLista encola evento de sincronizacion', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final cola = SyncEventRepository(baseDatos: fixture.base);
			final producto = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Con lista',
					codigoBarras: 'lista-001',
					precioBase: 10.0,
					categoriaId: fixture.categoriaId,
				),
			);
			final lista = await servicio.registrarListaPrecios('Distribuidor');
			for (final evento in await cola.obtenerPendientes()) {
				await cola.marcarEnviado(evento.id);
			}
			await servicio.guardarPrecioLista(lista.id, producto.id, 8.5);
			final pendientes = await cola.obtenerPendientes();
			expect(
				pendientes.any(
					(e) =>
						e.tipo == TipoSyncEvento.priceListItemUpserted &&
						e.payload['listaPreciosId'] == lista.id &&
						e.payload['productoId'] == producto.id,
				),
				isTrue,
			);
			await fixture.cerrar();
		});

		test('listarClientesPorLista devuelve clientes asignados', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final lista = await servicio.registrarListaPrecios('Mayoreo');
			final cliente = await servicio.registrarCliente(nombre: 'Tienda Juan');
			await servicio.actualizarCliente(
				cliente.copiarCon(listaPreciosId: lista.id),
			);
			final asignados = await servicio.listarClientesPorLista(lista.id);
			expect(asignados, hasLength(1));
			expect(asignados.first.nombre, 'Tienda Juan');
			await fixture.cerrar();
		});

		test('eliminarListaPrecios desvincula clientes', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final lista = await servicio.registrarListaPrecios('Temporal');
			final cliente = await servicio.registrarCliente(nombre: 'Cliente lista');
			await servicio.actualizarCliente(
				cliente.copiarCon(listaPreciosId: lista.id),
			);
			await servicio.eliminarListaPrecios(lista.id);
			final actualizado = await servicio.obtenerCliente(cliente.id);
			expect(actualizado?.listaPreciosId, isNull);
			expect(await servicio.listarClientesPorLista(lista.id), isEmpty);
			await fixture.cerrar();
		});

		test('registrarProductoCompleto rechaza codigo de barras duplicado', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Original',
					codigoBarras: 'dup-001',
					precioBase: 10.0,
					categoriaId: fixture.categoriaId,
				),
			);
			await expectLater(
				servicio.registrarProductoCompleto(
					AltaProductoRequest(
						nombre: 'Duplicado',
						codigoBarras: 'dup-001',
						precioBase: 15.0,
						categoriaId: fixture.categoriaId,
					),
				),
				throwsA(
					isA<StateError>().having(
						(s) => s.message,
						'message',
						contains('Ya existe un producto activo'),
					),
				),
			);
			await fixture.cerrar();
		});

		test('actualizarProducto rechaza codigo de barras de otro producto', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Producto A',
					codigoBarras: 'aaa-111',
					precioBase: 10.0,
					categoriaId: fixture.categoriaId,
				),
			);
			final productoB = await servicio.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Producto B',
					codigoBarras: 'bbb-222',
					precioBase: 20.0,
					categoriaId: fixture.categoriaId,
				),
			);
			await expectLater(
				servicio.actualizarProducto(
					productoB.copiarCon(codigoBarras: 'aaa-111'),
				),
				throwsA(isA<StateError>()),
			);
			await fixture.cerrar();
		});
	});
}
