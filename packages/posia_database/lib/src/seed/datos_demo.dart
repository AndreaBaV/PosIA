/// Datos semilla de demostracion para tiendas demo POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_module_pharmacy/posia_module_pharmacy.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:sqflite/sqflite.dart';

import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_farmacia_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/turno_caja_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/venta_repository.dart';

/// Identificadores de categorias demo.
const String ID_CAT_BEBIDAS = 'cat-bebidas';
const String ID_CAT_ABARROTES = 'cat-abarrotes';
const String ID_CAT_LACTEOS = 'cat-lacteos';
const String ID_CAT_CARNICERIA = 'cat-carniceria';
const String ID_CAT_FARMACIA = 'cat-farmacia';

/// Carga catalogo demo si la base esta vacia.
class DatosDemo {
	/// Garantiza turno abierto y ventas demo para presentacion comercial.
	static Future<void> prepararPresentacion(Database baseDatos) async {
		await _sembrarTurnoYVentasDemo(baseDatos);
	}

	/// Inserta tiendas, productos, clientes y stock demo.
	///
	/// [baseDatos] Conexion SQLite activa.
	static Future<void> sembrarSiVacio(Database baseDatos) async {
		await _sembrarOperacionesSiVacio(baseDatos);
		await _sembrarUsuariosSiVacio(baseDatos);
		await _sembrarDescuentosClienteDemo(baseDatos);
		final conteo = Sqflite.firstIntValue(
			await baseDatos.rawQuery('SELECT COUNT(*) FROM products'),
		);
		if (conteo != null && conteo > 0) {
			return;
		}

		await _insertarConfiguracion(baseDatos);
		await _insertarTiendas(baseDatos);

		final productoRepo = ProductoRepository(baseDatos: baseDatos);
		final clienteRepo = ClienteRepository(baseDatos: baseDatos);
		final precioRepo = PrecioRepository(baseDatos: baseDatos);
		final inventarioRepo = InventarioRepository(baseDatos: baseDatos);
		final loteRepo = LoteFarmaciaRepository(baseDatos: baseDatos);

		final productos = _crearProductosDemo();
		for (final producto in productos) {
			await productoRepo.guardar(producto);
		}

		final productosVerticales = _crearProductosVerticalesDemo();
		for (final producto in productosVerticales) {
			await productoRepo.guardar(producto);
		}

		await _sembrarVariantesDemo(baseDatos);

		await clienteRepo.guardar(
			const Cliente(
				id: 'cliente-demo-mayorista',
				nombre: 'Restaurante La Fonda',
				listaPreciosId: 'lista-mayorista-a',
				creditoHabilitado: true,
				activo: true,
			),
		);

		await precioRepo.guardarPrecioLista('lista-mayorista-a', 'prod-coca-600', 11.50);
		await precioRepo.guardarEscalaMayoreo(
			const EscalaMayoreo(
				productoId: 'prod-coca-600',
				cantidadMinima: 12.0,
				precioUnitario: 10.50,
			),
		);
		await precioRepo.guardarEscalaMayoreo(
			const EscalaMayoreo(
				productoId: 'prod-arroz-1kg',
				cantidadMinima: 10.0,
				precioUnitario: 22.00,
			),
		);
		await precioRepo.guardarEscalaMayoreo(
			const EscalaMayoreo(
				productoId: 'prod-filete-res',
				cantidadMinima: 5.0,
				precioUnitario: 165.00,
			),
		);

		final ahora = DateTime.now().toUtc();
		final todosProductos = [...productos, ...productosVerticales];
		for (final producto in todosProductos) {
			final cantidadStock = producto.moduloVertical == ModuloVertical.carniceria
				? 250.0
				: 100.0;
			final stockMinimo = producto.moduloVertical == ModuloVertical.general ? 10.0 : 0.0;
			await inventarioRepo.guardarStock(
				StockNivel(
					productoId: producto.id,
					tiendaId: TIENDA_DEMO_CENTRO_ID,
					cantidad: cantidadStock,
					actualizadoEn: ahora,
					stockMinimo: stockMinimo,
				),
			);
			await inventarioRepo.guardarStock(
				StockNivel(
					productoId: producto.id,
					tiendaId: TIENDA_DEMO_NORTE_ID,
					cantidad: cantidadStock * 0.75,
					actualizadoEn: ahora,
				),
			);
		}

		await _sembrarStockVariantes(inventarioRepo, ahora);

		await loteRepo.guardar(
			LoteFarmacia(
				id: 'lote-paracetamol-a',
				productoId: 'prod-paracetamol',
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				numeroLote: 'LOT-2026-A',
				caducaEn: DateTime.utc(2027, 3, 31),
				cantidad: 48.0,
				activo: true,
			),
		);
		await loteRepo.guardar(
			LoteFarmacia(
				id: 'lote-paracetamol-b',
				productoId: 'prod-paracetamol',
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				numeroLote: 'LOT-2025-B',
				caducaEn: DateTime.utc(2026, 6, 20),
				cantidad: 12.0,
				activo: true,
			),
		);
		await loteRepo.guardar(
			LoteFarmacia(
				id: 'lote-ibuprofeno-a',
				productoId: 'prod-ibuprofeno',
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				numeroLote: 'LOT-IBU-01',
				caducaEn: DateTime.utc(2026, 12, 15),
				cantidad: 30.0,
				activo: true,
			),
		);

		await _sembrarTurnoYVentasDemo(baseDatos);
	}

	/// Abre turno de caja y registra ventas de ejemplo para la presentacion.
	static Future<void> _sembrarTurnoYVentasDemo(Database baseDatos) async {
		final configFilas = await baseDatos.query(
			'app_config',
			where: 'clave IN (?, ?)',
			whereArgs: ['store_id', 'register_id'],
		);
		var tiendaId = TIENDA_DEMO_CENTRO_ID;
		var cajaId = CAJA_DEMO_1_ID;
		for (final fila in configFilas) {
			final clave = fila['clave'] as String;
			final valor = fila['valor'] as String;
			if (clave == 'store_id') {
				tiendaId = valor;
			} else if (clave == 'register_id') {
				cajaId = valor;
			}
		}
		final turnoRepo = TurnoCajaRepository(baseDatos: baseDatos);
		final ventaRepo = VentaRepository(baseDatos: baseDatos);
		final turnoExistente = await turnoRepo.obtenerTurnoAbierto(
			tiendaId,
			cajaId,
		);
		if (turnoExistente != null) {
			return;
		}

		final ahora = DateTime.now().toUtc();
		const turnoId = 'turno-demo-presentacion';
		const totalVentasDemo = 86.50;

		await turnoRepo.guardar(
			TurnoCaja(
				id: turnoId,
				tiendaId: tiendaId,
				cajaId: cajaId,
				vendedorId: 'vend-demo-maria',
				fondoInicial: 500.0,
				totalEfectivo: totalVentasDemo,
				totalTarjeta: 0.0,
				totalTransferencia: 0.0,
				totalVentas: totalVentasDemo,
				cantidadVentas: 2,
				abiertoEn: ahora.subtract(const Duration(hours: 3)),
				cerradoEn: null,
				estado: EstadoTurnoCaja.abierto,
			),
		);

		await ventaRepo.guardar(
			Venta(
				id: 'venta-demo-001',
				tiendaId: tiendaId,
				cajaId: cajaId,
				clienteId: null,
				vendedorId: 'vend-demo-maria',
				turnoCajaId: turnoId,
				metodoPago: MetodoPago.efectivo,
				total: 36.50,
				creadaEn: ahora.subtract(const Duration(hours: 2)),
				lineas: const [
					LineaVenta(
						productoId: 'prod-arroz-1kg',
						nombreProducto: 'Arroz 1kg',
						cantidad: 1,
						precioUnitario: 24.50,
						reglaPrecio: ReglaPrecio.precioBase,
					),
					LineaVenta(
						productoId: 'var-coca-600',
						nombreProducto: 'Coca-Cola - 600ml',
						cantidad: 1,
						precioUnitario: 12.00,
						reglaPrecio: ReglaPrecio.precioBase,
					),
				],
			),
		);

		await ventaRepo.guardar(
			Venta(
				id: 'venta-demo-002',
				tiendaId: tiendaId,
				cajaId: cajaId,
				clienteId: 'cliente-demo-mayorista',
				vendedorId: 'vend-demo-juan',
				turnoCajaId: turnoId,
				metodoPago: MetodoPago.efectivo,
				total: 50.00,
				creadaEn: ahora.subtract(const Duration(hours: 1)),
				lineas: const [
					LineaVenta(
						productoId: 'prod-leche-1l',
						nombreProducto: 'Leche 1L',
						cantidad: 2,
						precioUnitario: 26.00,
						reglaPrecio: ReglaPrecio.precioBase,
					),
				],
			),
		);
	}

	/// Inserta configuracion base de tenant y caja demo.
	///
	/// [baseDatos] Conexion SQLite activa.
	static Future<void> _insertarConfiguracion(Database baseDatos) async {
		final configuracion = {
			'tenant_id': TENANT_DEMO_ID,
			'store_id': TIENDA_DEMO_CENTRO_ID,
			'register_id': CAJA_DEMO_1_ID,
			'hub_url': 'http://localhost:8080',
		};
		for (final entrada in configuracion.entries) {
			await baseDatos.insert('app_config', {
				'clave': entrada.key,
				'valor': entrada.value,
			});
		}
	}

	/// Inserta tiendas demo centro y norte.
	///
	/// [baseDatos] Conexion SQLite activa.
	static Future<void> _insertarTiendas(Database baseDatos) async {
		await baseDatos.insert('stores', {
			'id': TIENDA_DEMO_CENTRO_ID,
			'nombre': 'Tienda Centro',
			'direccion': 'Av. Principal 100, CDMX',
			'activa': 1,
		});
		await baseDatos.insert('stores', {
			'id': TIENDA_DEMO_NORTE_ID,
			'nombre': 'Tienda Norte',
			'direccion': 'Calz. Norte 250, CDMX',
			'activa': 1,
		});
	}

	/// Inserta categorias, vendedores y proveedores demo si faltan.
	static Future<void> _sembrarOperacionesSiVacio(Database baseDatos) async {
		final conteoCat = Sqflite.firstIntValue(
			await baseDatos.rawQuery('SELECT COUNT(*) FROM categories'),
		);
		if (conteoCat != null && conteoCat > 0) {
			return;
		}
		final categoriaRepo = CategoriaRepository(baseDatos: baseDatos);
		final categorias = [
			const Categoria(
				id: ID_CAT_BEBIDAS,
				nombre: 'Bebidas',
				icono: 'local_drink',
				colorHex: '#2196F3',
				orden: 0,
				activa: true,
			),
			const Categoria(
				id: ID_CAT_ABARROTES,
				nombre: 'Abarrotes',
				icono: 'rice_bowl',
				colorHex: '#FF9800',
				orden: 1,
				activa: true,
			),
			const Categoria(
				id: ID_CAT_LACTEOS,
				nombre: 'Lacteos',
				icono: 'water_drop',
				colorHex: '#9C27B0',
				orden: 2,
				activa: true,
			),
			const Categoria(
				id: ID_CAT_CARNICERIA,
				nombre: 'Carniceria',
				icono: 'set_meal',
				colorHex: '#795548',
				orden: 3,
				activa: true,
			),
			const Categoria(
				id: ID_CAT_FARMACIA,
				nombre: 'Farmacia',
				icono: 'medication',
				colorHex: '#009688',
				orden: 4,
				activa: true,
			),
		];
		for (final categoria in categorias) {
			await categoriaRepo.guardar(categoria);
		}
		final vendedorRepo = VendedorRepository(baseDatos: baseDatos);
		await vendedorRepo.guardar(
			const Vendedor(
				id: 'vend-demo-maria',
				nombre: 'Maria Lopez',
				codigo: '001',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
		);
		await vendedorRepo.guardar(
			const Vendedor(
				id: 'vend-demo-juan',
				nombre: 'Juan Perez',
				codigo: '002',
				activo: true,
				tiendaId: TIENDA_DEMO_NORTE_ID,
			),
		);
		final proveedorRepo = ProveedorRepository(baseDatos: baseDatos);
		await proveedorRepo.guardar(
			const Proveedor(
				id: 'prov-demo-centro',
				nombre: 'Distribuidora Centro',
				contacto: 'Lic. Ramirez',
				telefono: '555-0100',
				activo: true,
			),
		);
	}

	/// Crea catalogo inicial de abarrotes.
	///
	/// Retorna lista de productos demo generales.
	static List<Producto> _crearProductosDemo() {
		return [
			Producto(
				id: 'prod-coca-600',
				nombre: 'Coca-Cola',
				categoriaId: ID_CAT_BEBIDAS,
				codigoBarras: '',
				precioBase: 12.00,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: 'assets/productos/coca_600.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-arroz-1kg',
				nombre: 'Arroz 1kg',
				categoriaId: ID_CAT_ABARROTES,
				codigoBarras: '7501000100011',
				precioBase: 24.50,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: 'assets/productos/arroz_1kg.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-leche-1l',
				nombre: 'Leche 1L',
				categoriaId: ID_CAT_LACTEOS,
				codigoBarras: '7501000200022',
				precioBase: 26.00,
				unidadMedida: UnidadMedida.litro,
				piezasPorCaja: 12,
				rutaImagen: 'assets/productos/leche_1l.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-frijol-peruano',
				nombre: 'Frijol peruano',
				categoriaId: ID_CAT_ABARROTES,
				codigoBarras: '7501000600066',
				precioBase: 42.00,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: 'assets/productos/frijol_peruano.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-atun-lata',
				nombre: 'Atun lata',
				categoriaId: ID_CAT_ABARROTES,
				codigoBarras: '7501000700077',
				precioBase: 18.00,
				unidadMedida: UnidadMedida.pieza,
				piezasPorCaja: 24,
				rutaImagen: 'assets/productos/atun_lata.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-huevo-carton',
				nombre: 'Huevo carton 12',
				categoriaId: ID_CAT_LACTEOS,
				codigoBarras: '7501000300033',
				precioBase: 45.00,
				unidadMedida: UnidadMedida.caja,
				rutaImagen: 'assets/productos/huevo_12.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-aceite-1l',
				nombre: 'Aceite 1L',
				categoriaId: ID_CAT_ABARROTES,
				codigoBarras: '7501000400044',
				precioBase: 38.00,
				unidadMedida: UnidadMedida.litro,
				rutaImagen: 'assets/productos/aceite_1l.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
			Producto(
				id: 'prod-azucar-1kg',
				nombre: 'Azucar 1kg',
				categoriaId: ID_CAT_ABARROTES,
				codigoBarras: '7501000500055',
				precioBase: 28.00,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: 'assets/productos/azucar_1kg.png',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
			),
		];
	}

	/// Crea productos demo de carniceria y farmacia.
	///
	/// Retorna lista de productos verticales.
	static List<Producto> _crearProductosVerticalesDemo() {
		return [
			Producto(
				id: 'prod-filete-res',
				nombre: 'Filete de res',
				categoriaId: ID_CAT_CARNICERIA,
				codigoBarras: '7502000100011',
				precioBase: 180.00,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				moduloVertical: ModuloVertical.carniceria,
			),
			Producto(
				id: 'prod-chorizo',
				nombre: 'Chorizo casero',
				categoriaId: ID_CAT_CARNICERIA,
				codigoBarras: '7502000100022',
				precioBase: 95.00,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				moduloVertical: ModuloVertical.carniceria,
			),
			Producto(
				id: 'prod-paracetamol',
				nombre: 'Paracetamol 500mg',
				categoriaId: ID_CAT_FARMACIA,
				codigoBarras: '7503000100011',
				precioBase: 45.00,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				moduloVertical: ModuloVertical.farmacia,
			),
			Producto(
				id: 'prod-ibuprofeno',
				nombre: 'Ibuprofeno 400mg',
				categoriaId: ID_CAT_FARMACIA,
				codigoBarras: '7503000100022',
				precioBase: 58.00,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				moduloVertical: ModuloVertical.farmacia,
			),
		];
	}

	static Future<void> _sembrarStockVariantes(
		InventarioRepository inventarioRepo,
		DateTime ahora,
	) async {
		const variantes = [
			('var-coca-600', 80.0),
			('var-coca-2l', 45.0),
		];
		for (final (varianteId, cantidad) in variantes) {
			await inventarioRepo.guardarStock(
				StockNivel(
					productoId: varianteId,
					tiendaId: TIENDA_DEMO_CENTRO_ID,
					cantidad: cantidad,
					actualizadoEn: ahora,
					stockMinimo: 5.0,
				),
			);
			await inventarioRepo.guardarStock(
				StockNivel(
					productoId: varianteId,
					tiendaId: TIENDA_DEMO_NORTE_ID,
					cantidad: cantidad * 0.75,
					actualizadoEn: ahora,
				),
			);
		}
	}

	static Future<void> _sembrarVariantesDemo(Database baseDatos) async {
		final repo = VarianteRepository(baseDatos: baseDatos);
		await repo.guardar(
			const VarianteProducto(
				id: 'var-coca-600',
				productoPadreId: 'prod-coca-600',
				nombre: '600ml',
				sku: 'COCA-600',
				codigoBarras: '7501055300022',
				precioBase: 12.00,
				activo: true,
			),
		);
		await repo.guardar(
			const VarianteProducto(
				id: 'var-coca-2l',
				productoPadreId: 'prod-coca-600',
				nombre: '2 litros',
				sku: 'COCA-2L',
				codigoBarras: '7501055300799',
				precioBase: 28.00,
				activo: true,
			),
		);
	}

	static Future<void> _sembrarUsuariosSiVacio(Database baseDatos) async {
		final conteo = Sqflite.firstIntValue(
			await baseDatos.rawQuery('SELECT COUNT(*) FROM usuarios'),
		);
		if (conteo != null && conteo > 0) {
			return;
		}
		final usuarioRepo = UsuarioRepository(baseDatos: baseDatos);
		await usuarioRepo.guardar(
			const Usuario(
				id: ID_USUARIO_DEMO_ADMIN,
				nombre: 'Ana Administradora',
				codigo: CODIGO_USUARIO_DEMO_ADMIN,
				pin: PIN_ADMIN_DEMO,
				rol: RolUsuario.administrador,
				activo: true,
			),
		);
		await usuarioRepo.guardar(
			const Usuario(
				id: ID_USUARIO_DEMO_SUP_CENTRO,
				nombre: 'Carlos Supervisor Centro',
				codigo: CODIGO_USUARIO_DEMO_SUP_CENTRO,
				pin: PIN_USUARIO_DEMO_SUPERVISOR,
				rol: RolUsuario.supervisor,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				activo: true,
			),
		);
		await usuarioRepo.guardar(
			const Usuario(
				id: ID_USUARIO_DEMO_SUP_NORTE,
				nombre: 'Laura Supervisor Norte',
				codigo: CODIGO_USUARIO_DEMO_SUP_NORTE,
				pin: PIN_USUARIO_DEMO_SUPERVISOR,
				rol: RolUsuario.supervisor,
				tiendaId: TIENDA_DEMO_NORTE_ID,
				activo: true,
			),
		);
		await usuarioRepo.guardar(
			const Usuario(
				id: ID_USUARIO_DEMO_EMP_CENTRO,
				nombre: 'Pedro Empleado',
				codigo: CODIGO_USUARIO_DEMO_EMP_CENTRO,
				pin: PIN_USUARIO_DEMO_EMPLEADO,
				rol: RolUsuario.empleado,
				tiendaId: TIENDA_DEMO_CENTRO_ID,
				activo: true,
			),
		);
	}

	static Future<void> _sembrarDescuentosClienteDemo(Database baseDatos) async {
		final conteo = Sqflite.firstIntValue(
			await baseDatos.rawQuery('SELECT COUNT(*) FROM customer_discounts'),
		);
		if (conteo != null && conteo > 0) {
			return;
		}
		final repo = DescuentoClienteRepository(baseDatos: baseDatos);
		await repo.guardar(
			DescuentoCliente(
				id: 'desc-demo-may-10pct',
				clienteId: 'cliente-demo-mayorista',
				tipo: TipoDescuentoCliente.porcentajeGeneral,
				valor: 10.0,
				condicion: CondicionDescuentoCliente.montoTicketMinimo,
				umbral: 500.0,
				activo: true,
				descripcion: '10% en compras mayores a 500 pesos',
			),
		);
	}
}
