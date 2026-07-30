/// Contrato de la purga del hub: jamas debe borrar estado de catalogo.
///
/// La purga de 90 dias borraba por fecha sin distinguir tipo. Un producto
/// dado de alta hace mas de 90 dias y no re-editado perdia su `productUpserted`
/// del log; cualquier "Descargar todo de la nube" (reconstruir desde origen)
/// lo hacia desaparecer para siempre de ese equipo. Esta prueba fija que la
/// purga solo alcanza historial transaccional y nunca eventos de estado.
library;

import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:test/test.dart';

void main() {
	/// Todo tipo cuyo nombre representa el estado vigente de una entidad de
	/// catalogo (o su lapida de borrado). Perder cualquiera de estos rompe la
	/// reconstruccion desde origen.
	const tiposEstadoCatalogo = <String>[
		'productUpserted',
		'productDeleted',
		'categoryUpserted',
		'categoryDeleted',
		'variantUpserted',
		'storeUpserted',
		'warehouseUpserted',
		'presentationTypeUpserted',
		'productPresentationUpserted',
		'productPresentationsReplaced',
		'wholesaleTiersReplaced',
		'lotePromocionReplaced',
		'comboReplaced',
		'customRoleUpserted',
		'userUpserted',
		'customerUpserted',
		'supplierUpserted',
		'supplierDeleted',
		'priceListUpserted',
		'priceListDeleted',
		'priceListItemUpserted',
		'priceListItemDeleted',
		'customerProductPriceUpserted',
		'customerProductPriceDeleted',
		'customerDiscountUpserted',
		'customerDiscountDeleted',
		'employeeProfileUpserted',
	];

	test('la purga NUNCA incluye un evento de estado de catalogo', () {
		for (final tipo in tiposEstadoCatalogo) {
			expect(
				EsquemaPosPostgres.tiposHistorialPurgable,
				isNot(contains(tipo)),
				reason: 'purgar "$tipo" borraria catalogo del log y lo haria '
					'irrecuperable en una reconstruccion desde origen',
			);
		}
	});

	test('la purga solo alcanza historial transaccional conocido', () {
		// Si alguien agrega un tipo nuevo a la lista, que sea una decision
		// consciente: este set es el unico historial que se acepta borrar.
		const purgablesEsperados = {
			'saleCompleted',
			'saleVoided',
			'salePartialReturn',
			'stockAdjusted',
			'transferRequested',
			'transferCompleted',
			'purchaseCompleted',
			'attendanceChallengeCreated',
			'attendanceCheckedIn',
			'attendanceCheckedOut',
			'payrollPeriodClosed',
			'cashShiftUpserted',
		};
		expect(
			EsquemaPosPostgres.tiposHistorialPurgable.toSet(),
			purgablesEsperados,
		);
	});
}
