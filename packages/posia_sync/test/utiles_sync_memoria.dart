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

	/// Huella que reporta `calcularHuellaCatalogoLocal`; sobreescribible en
	/// pruebas que necesitan simular una divergencia contra el hub.
	HuellaCatalogo huellaLocal = const HuellaCatalogo(
		productosActivos: 0,
		categoriasActivas: 0,
		huellaProductos: '',
	);

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

	@override
	Future<HuellaCatalogo> calcularHuellaCatalogoLocal() async => huellaLocal;
}

/// Diagnostico en memoria con la misma semantica que el repositorio SQLite.
class DiagnosticoMemoria implements DiagnosticoSync {
	final Map<String, EventoEnCuarentena> cuarentena = {};
	ErrorCicloSync? ultimoError;
	AuditoriaCatalogo? ultimaAuditoriaCatalogo;

	@override
	Future<void> registrarEventoFallido({
		required SyncEvent evento,
		required Object error,
	}) async {
		final previo = cuarentena[evento.id];
		cuarentena[evento.id] = EventoEnCuarentena(
			evento: evento,
			error: '$error',
			intentos: (previo?.intentos ?? 0) + 1,
			ultimoIntentoEn: DateTime.now().toUtc(),
		);
	}

	@override
	Future<void> resolverEventoFallido(String eventoId) async {
		cuarentena.remove(eventoId);
	}

	@override
	Future<List<EventoEnCuarentena>> listarCuarentena({int limite = 100}) async {
		final lista = cuarentena.values.toList()
			..sort((a, b) => a.evento.seq.compareTo(b.evento.seq));
		return lista.take(limite).toList();
	}

	@override
	Future<int> contarCuarentena() async => cuarentena.length;

	@override
	Future<void> registrarErrorCiclo(Object? error) async {
		ultimoError = error == null
			? null
			: ErrorCicloSync(mensaje: '$error', ocurridoEn: DateTime.now().toUtc());
	}

	@override
	Future<ErrorCicloSync?> leerUltimoErrorCiclo() async => ultimoError;

	@override
	Future<void> registrarAuditoriaCatalogo(AuditoriaCatalogo resultado) async {
		ultimaAuditoriaCatalogo = resultado;
	}

	@override
	Future<AuditoriaCatalogo?> leerUltimaAuditoriaCatalogo() async =>
		ultimaAuditoriaCatalogo;
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
