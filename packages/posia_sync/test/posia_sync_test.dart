/// Pruebas del orquestador de sincronizacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 16:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 16:10:00 (UTC-6)
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:test/test.dart';

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

void main() {
	test('sincronizarCompleto sin hub retorna resultado vacio', () async {
		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: null,
			clienteLan: null,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-1',
		);
		final resultado = await orquestador.sincronizarCompleto();
		expect(resultado.hubDisponible, isFalse);
		expect(resultado.eventosEnviados, 0);
		expect(resultado.eventosRecibidos, 0);
	});

	test('tieneHubConfigurado refleja presencia de cliente hub', () {
		final sinHub = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: null,
			clienteLan: null,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-1',
		);
		expect(sinHub.tieneHubConfigurado(), isFalse);
	});

	test('registrarEvento encola evento pendiente', () async {
		final cola = ColaEventosMemoria();
		final orquestador = SyncOrchestrator(
			colaLocal: cola,
			clienteHub: null,
			clienteLan: null,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-1',
		);
		await orquestador.registrarEvento(crearEvento('ev-1'));
		final pendientes = await cola.obtenerPendientes();
		expect(pendientes.length, 1);
		expect(pendientes.first.id, 'ev-1');
	});

	test('sincronizarCompleto empuja pendientes aunque /health falle', () async {
		final cola = ColaEventosMemoria();
		await cola.encolar(crearEvento('ev-offline'));
		final cliente = HubSyncClient(
			urlBase: 'https://hub.test',
			clienteHttp: MockClient((request) async {
				if (request.url.path.endsWith('/v1/health')) {
					return http.Response('down', 503);
				}
				if (request.method == 'POST' && request.url.path.endsWith('/v1/events')) {
					return http.Response(
						'{"accepted":1,"received":1}',
						200,
						headers: {'Content-Type': 'application/json'},
					);
				}
				if (request.method == 'GET' && request.url.path.endsWith('/v1/events')) {
					return http.Response(
						'{"events":[],"lastSeq":0}',
						200,
						headers: {'Content-Type': 'application/json'},
					);
				}
				return http.Response('not found', 404);
			}),
		);
		final orquestador = SyncOrchestrator(
			colaLocal: cola,
			clienteHub: cliente,
			clienteLan: null,
			aplicadorRemoto: AplicadorMemoria(),
			almacenCursor: CursorMemoria(),
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-1',
		);
		final resultado = await orquestador.sincronizarCompleto();
		expect(resultado.eventosEnviados, 1);
		expect(resultado.hubDisponible, isTrue);
		expect(await cola.obtenerPendientes(), isEmpty);
	});

	test('push usa storeId del evento si el orquestador tiene tienda vacia', () async {
		final cola = ColaEventosMemoria();
		await cola.encolar(crearEvento('ev-tienda'));
		String? storeIdEnviado;
		final cliente = HubSyncClient(
			urlBase: 'https://hub.test',
			clienteHttp: MockClient((request) async {
				if (request.url.path.endsWith('/v1/health')) {
					return http.Response('{"ok":true}', 200);
				}
				if (request.method == 'POST') {
					final cuerpo =
						jsonDecode(request.body) as Map<String, Object?>;
					storeIdEnviado = cuerpo['storeId'] as String?;
					return http.Response(
						'{"accepted":1,"received":1}',
						200,
						headers: {'Content-Type': 'application/json'},
					);
				}
				return http.Response(
					'{"events":[],"lastSeq":0}',
					200,
					headers: {'Content-Type': 'application/json'},
				);
			}),
		);
		final orquestador = SyncOrchestrator(
			colaLocal: cola,
			clienteHub: cliente,
			clienteLan: null,
			aplicadorRemoto: AplicadorMemoria(),
			almacenCursor: CursorMemoria(),
			tiendaId: '',
			dispositivoId: 'caja-1',
		);
		final resultado = await orquestador.sincronizarCompleto();
		expect(resultado.eventosEnviados, 1);
		expect(storeIdEnviado, 'tienda-1');
	});
}
