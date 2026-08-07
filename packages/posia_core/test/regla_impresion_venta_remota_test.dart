/// Reglas de autoimpresion de ventas remotas.
library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

SyncEvent _evento({
	required String tiendaId,
	required String dispositivoId,
	required DateTime creadoEn,
	TipoSyncEvento tipo = TipoSyncEvento.saleCompleted,
}) {
	return SyncEvent(
		id: 'ev-1',
		tiendaId: tiendaId,
		dispositivoId: dispositivoId,
		tipo: tipo,
		payload: const {'ventaId': 'v-1'},
		creadoEn: creadoEn,
		estado: EstadoSyncEvento.pendiente,
	);
}

void main() {
	final ahora = DateTime.utc(2026, 8, 7, 18, 0);

	test('imprime venta reciente de otra caja de la misma tienda', () {
		final evento = _evento(
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
			creadoEn: ahora.subtract(const Duration(seconds: 30)),
		);
		expect(
			debeImprimirVentaRemotaTrasSync(
				evento: evento,
				tiendaLocalId: 'tienda-1',
				dispositivoLocalId: 'caja-pc',
				ahora: ahora,
			),
			isTrue,
		);
	});

	test('NO imprime ventas de otra tienda (multi-sucursal)', () {
		final evento = _evento(
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
			creadoEn: ahora.subtract(const Duration(seconds: 10)),
		);
		expect(
			debeImprimirVentaRemotaTrasSync(
				evento: evento,
				tiendaLocalId: 'tienda-2',
				dispositivoLocalId: 'caja-pc-tienda-2',
				ahora: ahora,
			),
			isFalse,
		);
	});

	test('NO imprime eventos propios ni atrasados', () {
		final propio = _evento(
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-pc',
			creadoEn: ahora.subtract(const Duration(seconds: 5)),
		);
		expect(
			debeImprimirVentaRemotaTrasSync(
				evento: propio,
				tiendaLocalId: 'tienda-1',
				dispositivoLocalId: 'caja-pc',
				ahora: ahora,
			),
			isFalse,
		);

		final atrasado = _evento(
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
			creadoEn: ahora.subtract(const Duration(seconds: 500)),
		);
		expect(
			debeImprimirVentaRemotaTrasSync(
				evento: atrasado,
				tiendaLocalId: 'tienda-1',
				dispositivoLocalId: 'caja-pc',
				ahora: ahora,
			),
			isFalse,
		);
	});
}
