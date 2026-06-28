library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

class _RepositorioLoteMemoria implements RepositorioLoteFarmacia {
	final Map<String, LoteFarmacia> _lotes = {};

	void sembrar(LoteFarmacia lote) {
		_lotes[lote.id] = lote;
	}

	@override
	Future<void> descontarCantidad(String loteId, double cantidad) async {
		final lote = _lotes[loteId];
		if (lote == null) {
			return;
		}
		_lotes[loteId] = LoteFarmacia(
			id: lote.id,
			productoId: lote.productoId,
			tiendaId: lote.tiendaId,
			numeroLote: lote.numeroLote,
			caducaEn: lote.caducaEn,
			cantidad: lote.cantidad - cantidad,
			activo: lote.activo,
		);
	}

	@override
	Future<void> guardar(LoteFarmacia lote) async {
		_lotes[lote.id] = lote;
	}

	@override
	Future<List<LoteFarmacia>> listarDisponiblesPorProducto(
		String productoId,
		String tiendaId,
	) async {
		return _lotes.values
			.where((lote) => lote.productoId == productoId && lote.tiendaId == tiendaId)
			.toList();
	}

	@override
	Future<List<LoteFarmacia>> listarPorTienda(String tiendaId) async {
		return _lotes.values.where((lote) => lote.tiendaId == tiendaId).toList();
	}

	@override
	Future<LoteFarmacia?> obtenerPorId(String loteId) async {
		return _lotes[loteId];
	}
}

void main() {
	group('ServicioFarmacia', () {
		late _RepositorioLoteMemoria repositorio;
		late ServicioFarmacia servicio;

		setUp(() {
			repositorio = _RepositorioLoteMemoria();
			servicio = ServicioFarmacia(repositorioLote: repositorio);
		});

		test('valida stock insuficiente', () async {
			repositorio.sembrar(
				LoteFarmacia(
					id: 'lote-1',
					productoId: 'prod-paracetamol',
					tiendaId: 'tienda-demo',
					numeroLote: 'LOT-A',
					caducaEn: DateTime.utc(2027, 1, 1),
					cantidad: 2.0,
					activo: true,
				),
			);
			final resultado = await servicio.validarLoteParaVenta('lote-1', 5.0);
			expect(resultado.valido, false);
			expect(resultado.mensajeError, 'Stock insuficiente en lote');
		});

		test('calcula alerta critica por caducidad proxima', () {
			final lote = LoteFarmacia(
				id: 'lote-2',
				productoId: 'prod-paracetamol',
				tiendaId: 'tienda-demo',
				numeroLote: 'LOT-B',
				caducaEn: DateTime.now().toUtc().add(const Duration(days: 3)),
				cantidad: 10.0,
				activo: true,
			);
			expect(servicio.calcularAlertaCaducidad(lote), NivelAlertaCaducidad.critico);
		});

		test('excluye lotes vencidos de venta', () async {
			repositorio.sembrar(
				LoteFarmacia(
					id: 'lote-vencido',
					productoId: 'prod-paracetamol',
					tiendaId: 'tienda-demo',
					numeroLote: 'LOT-V',
					caducaEn: DateTime.now().toUtc().subtract(const Duration(days: 1)),
					cantidad: 5.0,
					activo: true,
				),
			);
			final lotes = await servicio.listarLotesParaVenta(
				'prod-paracetamol',
				'tienda-demo',
			);
			expect(lotes, isEmpty);
		});
	});
}
