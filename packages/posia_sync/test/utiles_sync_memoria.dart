/// Dobles en memoria compartidos por las pruebas del orquestador de sync.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

/// Cola de eventos en memoria para pruebas.
class ColaEventosMemoria implements LocalEventQueue {
	final List<SyncEvent> eventos = [];

	@override
	Future<void> encolar(SyncEvent evento) async {
		eventos.add(evento);
	}

	@override
	Future<List<SyncEvent>> obtenerPendientes() async {
		return eventos
			.where((evento) => evento.estado != EstadoSyncEvento.enviado)
			.toList();
	}

	@override
	Future<void> marcarEnviado(String eventoId) async {
		_reemplazarEstado(eventoId, EstadoSyncEvento.enviado);
	}

	@override
	Future<void> marcarError(String eventoId) async {
		_reemplazarEstado(eventoId, EstadoSyncEvento.error);
	}

	@override
	Future<int> descartarPendientesCatalogoEspejo() async => 0;

	@override
	Future<int> colapsarDuplicadosCatalogo() async => 0;

	void _reemplazarEstado(String eventoId, EstadoSyncEvento estado) {
		final indice = eventos.indexWhere((evento) => evento.id == eventoId);
		if (indice >= 0) {
			eventos[indice] = eventos[indice].copiarConEstado(estado);
		}
	}
}

/// Aplicador en memoria que registra eventos recibidos.
class AplicadorMemoria implements AplicadorEventosRemotos {
	final List<SyncEvent> aplicados = [];

	@override
	Future<void> aplicarEvento(SyncEvent evento) async {
		aplicados.add(evento);
	}

	@override
	Future<void> aplicarLote(List<SyncEvent> eventos) async {
		for (final evento in eventos) {
			await aplicarEvento(evento);
		}
	}

	@override
	Future<void> autoSanarCatalogoLocal() async {}
}

/// Cursor en memoria para pruebas.
class CursorMemoria implements AlmacenCursorSync {
	int cursor = 0;

	@override
	Future<int> leerCursorHub() async {
		return cursor;
	}

	@override
	Future<void> guardarCursorHub(int seq) async {
		cursor = seq;
	}
}

/// Crea evento de prueba con identificador dado.
SyncEvent crearEvento(String id) {
	return SyncEvent(
		id: id,
		tiendaId: 'tienda-1',
		dispositivoId: 'caja-1',
		tipo: TipoSyncEvento.saleCompleted,
		payload: const {'ventaId': 'v1', 'total': 10.0},
		creadoEn: DateTime.utc(2026, 6, 11),
		estado: EstadoSyncEvento.pendiente,
	);
}
