/// Reglas para autoimprimir ventas llegadas por sync.
library;

import '../constants/posia_constants.dart';
import '../enums/tipo_sync_evento.dart';
import '../models/sync_event.dart';

/// Indica si una caja debe autoimprimir una venta remota al aplicarla por sync.
///
/// Solo ventas de la **misma tienda** (otra caja del mismo local), recientes y
/// no originadas en este dispositivo. Una PC de la tienda 2 jamás debe
/// reimprimir el ticket de una venta hecha en la tienda 1.
bool debeImprimirVentaRemotaTrasSync({
	required SyncEvent evento,
	required String tiendaLocalId,
	required String dispositivoLocalId,
	DateTime? ahora,
	int umbralSegundos = UMBRAL_REIMPRESION_VENTA_REMOTA_SEGUNDOS,
}) {
	if (evento.tipo != TipoSyncEvento.saleCompleted) {
		return false;
	}
	final tiendaEvento = evento.tiendaId.trim();
	final tiendaLocal = tiendaLocalId.trim();
	if (tiendaLocal.isEmpty || tiendaEvento.isEmpty || tiendaEvento != tiendaLocal) {
		return false;
	}
	if (evento.dispositivoId.trim() == dispositivoLocalId.trim()) {
		return false;
	}
	final referencia = (ahora ?? DateTime.now()).toUtc();
	final antiguedad = referencia.difference(evento.creadoEn.toUtc());
	if (antiguedad.inSeconds > umbralSegundos) {
		return false;
	}
	return true;
}
