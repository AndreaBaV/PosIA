/// Pruebas unitarias del motor de precios POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:test/test.dart';

/// Repositorio en memoria para pruebas de precio.
class RepositorioPrecioMemoria implements RepositorioPrecio {
	final Map<String, double> _preciosClienteProducto = {};
	final Map<String, double> _preciosLista = {};
	final List<EscalaMayoreo> _escalas = [];
	final Map<String, LotePromocion> _lotesPorProducto = {};

	@override
	Future<PrecioClienteProducto?> obtenerPrecioClienteProducto(
		String clienteId,
		String productoId,
	) async {
		final clave = '$clienteId|$productoId';
		final precio = _preciosClienteProducto[clave];
		if (precio == null) {
			return null;
		}
		return PrecioClienteProducto(
			clienteId: clienteId,
			productoId: productoId,
			precioUnitario: precio,
		);
	}

	@override
	Future<double?> obtenerPrecioLista(String listaPreciosId, String productoId) async {
		final clave = '$listaPreciosId|$productoId';
		return _preciosLista[clave];
	}

	@override
	Future<List<EscalaMayoreo>> obtenerEscalasMayoreo(String productoId) async {
		return _escalas.where((escala) => escala.productoId == productoId).toList();
	}

	@override
	Future<LotePromocion?> obtenerLotePromocionPorProducto(String productoId) async {
		return _lotesPorProducto[productoId];
	}

	void registrarEscala(EscalaMayoreo escala) {
		_escalas.add(escala);
	}

	void registrarLote(LotePromocion lote) {
		for (final productoId in lote.productoIds) {
			_lotesPorProducto[productoId] = lote;
		}
	}
}

void main() {
	group('MotorPrecio', () {
		test('aplica escala mayoreo cuando cantidad alcanza umbral', () async {
			final repositorio = RepositorioPrecioMemoria();
			repositorio.registrarEscala(
				const EscalaMayoreo(
					productoId: 'prod-1',
					cantidadMinima: 12.0,
					precioUnitario: 10.50,
				),
			);
			final motor = MotorPrecio(repositorioPrecio: repositorio);
			const producto = Producto(
				id: 'prod-1',
				nombre: 'Producto demo',
				codigoBarras: '123',
				precioBase: 12.00,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-test',
			);
			final contexto = ContextoPrecio(
				producto: producto,
				cantidad: 12.0,
				tiendaId: 'tienda-test',
				cliente: null,
				canal: CanalVenta.mayoreo,
			);
			final resultado = await motor.resolverPrecio(contexto);
			expect(resultado.precioUnitario, 10.50);
			expect(resultado.reglaAplicada, ReglaPrecio.escalaMayoreo);
		});

		test('usa precio base cuando no hay reglas aplicables', () async {
			final repositorio = RepositorioPrecioMemoria();
			final motor = MotorPrecio(repositorioPrecio: repositorio);
			const producto = Producto(
				id: 'prod-2',
				nombre: 'Producto base',
				codigoBarras: '456',
				precioBase: 15.00,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-test',
			);
			final contexto = ContextoPrecio(
				producto: producto,
				cantidad: 1.0,
				tiendaId: 'tienda-test',
				cliente: null,
				canal: CanalVenta.mostrador,
			);
			final resultado = await motor.resolverPrecio(contexto);
			expect(resultado.precioUnitario, 15.00);
			expect(resultado.reglaAplicada, ReglaPrecio.precioBase);
		});

		test('aplica tramo de peso para fracciones menores a 1 kg', () async {
			final repositorio = RepositorioPrecioMemoria();
			repositorio.registrarEscala(
				const EscalaMayoreo(
					productoId: 'prod-kg',
					cantidadMinima: 0.0,
					precioUnitario: 80.00,
				),
			);
			repositorio.registrarEscala(
				const EscalaMayoreo(
					productoId: 'prod-kg',
					cantidadMinima: 1.0,
					precioUnitario: 70.00,
				),
			);
			final motor = MotorPrecio(repositorioPrecio: repositorio);
			const producto = Producto(
				id: 'prod-kg',
				nombre: 'Producto por kg',
				codigoBarras: '789',
				precioBase: 70.00,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-test',
			);
			final medioKilo = await motor.resolverPrecio(
				const ContextoPrecio(
					producto: producto,
					cantidad: 0.5,
					tiendaId: 'tienda-test',
					cliente: null,
					canal: CanalVenta.mostrador,
				),
			);
			expect(medioKilo.precioUnitario, 80.00);
			expect(medioKilo.reglaAplicada, ReglaPrecio.escalaMayoreo);

			final unKilo = await motor.resolverPrecio(
				const ContextoPrecio(
					producto: producto,
					cantidad: 1.0,
					tiendaId: 'tienda-test',
					cliente: null,
					canal: CanalVenta.mostrador,
				),
			);
			expect(unKilo.precioUnitario, 70.00);
		});
	});
}
