/// Regresion: un evento defectuoso no debe congelar el cursor del dispositivo.
///
/// El pull confirmaba el cursor solo al terminar la pagina y aplicaba los
/// eventos sin proteccion. Un unico evento que lanzaba dejaba al equipo
/// anclado en ese punto del historial: cada ciclo repetia la misma pagina,
/// moria en el mismo sitio y el catalogo se quedaba congelado en el pasado
/// aunque SQLite estuviera sano y la nube tuviera todo.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:test/test.dart';

import 'utiles_sync_memoria.dart';

/// Aplicador que revienta con los ids indicados hasta que se le indique.
class AplicadorConVeneno implements AplicadorEventosRemotos {
	AplicadorConVeneno(this.idsQueFallan);

	final Set<String> idsQueFallan;
	final List<SyncEvent> aplicados = [];

	@override
	Future<void> aplicarEvento(SyncEvent evento) async {
		if (idsQueFallan.contains(evento.id)) {
			throw StateError('FOREIGN KEY constraint failed (${evento.id})');
		}
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

/// Diagnostico en memoria con la misma semantica que el repositorio SQLite.
class DiagnosticoMemoria implements DiagnosticoSync {
	final Map<String, EventoEnCuarentena> cuarentena = {};
	ErrorCicloSync? ultimoError;

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
}

/// Serializa un evento tal como lo entrega el hub.
Map<String, Object?> eventoHub(int seq, {String tipo = 'productUpserted'}) {
	return {
		'seq': seq,
		'id': 'ev-$seq',
		'storeId': 'tienda-1',
		'deviceId': 'caja-escritorio',
		'type': tipo,
		'payload': {'id': 'prod-$seq', 'nombre': 'Producto $seq'},
		'createdAt': '2026-07-30T10:00:00Z',
	};
}

/// Hub falso que entrega una sola pagina y luego se queda vacio.
MockClient hubConPagina(List<Map<String, Object?>> pagina, List<int> desdeVistos) {
	return MockClient((request) async {
		if (request.url.path.endsWith('/v1/health')) {
			return http.Response('{"ok":true}', 200);
		}
		if (request.method == 'GET' && request.url.path.endsWith('/v1/events')) {
			final desde = int.parse(request.url.queryParameters['since'] ?? '0');
			desdeVistos.add(desde);
			final pendientes =
				pagina.where((e) => (e['seq']! as int) > desde).toList();
			return http.Response(
				jsonEncode({
					'events': pendientes,
					'lastSeq': pendientes.isEmpty
						? desde
						: pendientes.last['seq'],
				}),
				200,
				headers: {'Content-Type': 'application/json'},
			);
		}
		return http.Response(
			'{"accepted":0,"received":0}',
			200,
			headers: {'Content-Type': 'application/json'},
		);
	});
}

void main() {
	test('un evento que falla no detiene los que vienen detras', () async {
		final aplicador = AplicadorConVeneno({'ev-2'});
		final cursor = CursorMemoria();
		final diagnostico = DiagnosticoMemoria();
		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: hubConPagina(
					[eventoHub(1), eventoHub(2), eventoHub(3)],
					<int>[],
				),
			),
			clienteLan: null,
			aplicadorRemoto: aplicador,
			almacenCursor: cursor,
			diagnostico: diagnostico,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
		);

		final resultado = await orquestador.sincronizarCompleto();

		expect(
			aplicador.aplicados.map((e) => e.id),
			['ev-1', 'ev-3'],
			reason: 'el evento 3 debe entrar aunque el 2 haya fallado',
		);
		expect(resultado.eventosRecibidos, 2);
		expect(resultado.eventosFallidos, 1);
		expect(diagnostico.cuarentena.keys, ['ev-2']);
	});

	test('el cursor avanza mas alla del evento defectuoso', () async {
		final cursor = CursorMemoria();
		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: hubConPagina(
					[eventoHub(1), eventoHub(2), eventoHub(3)],
					<int>[],
				),
			),
			clienteLan: null,
			aplicadorRemoto: AplicadorConVeneno({'ev-2'}),
			almacenCursor: cursor,
			diagnostico: DiagnosticoMemoria(),
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
		);

		await orquestador.sincronizarCompleto();

		expect(
			cursor.cursor,
			3,
			reason: 'sin esto el equipo se queda anclado en el evento defectuoso',
		);
	});

	test('el siguiente ciclo pide lo nuevo, no repite la pagina atorada', () async {
		final desdeVistos = <int>[];
		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: hubConPagina(
					[eventoHub(1), eventoHub(2), eventoHub(3)],
					desdeVistos,
				),
			),
			clienteLan: null,
			aplicadorRemoto: AplicadorConVeneno({'ev-2'}),
			almacenCursor: CursorMemoria(),
			diagnostico: DiagnosticoMemoria(),
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
		);

		await orquestador.sincronizarCompleto();
		desdeVistos.clear();
		await orquestador.sincronizarCompleto();

		expect(
			desdeVistos.first,
			3,
			reason: 'el segundo ciclo arranca despues del evento defectuoso',
		);
	});

	test('la cuarentena se reintenta y se vacia cuando el evento ya entra', () async {
		final aplicador = AplicadorConVeneno({'ev-2'});
		final diagnostico = DiagnosticoMemoria();
		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: hubConPagina(
					[eventoHub(1), eventoHub(2), eventoHub(3)],
					<int>[],
				),
			),
			clienteLan: null,
			aplicadorRemoto: aplicador,
			almacenCursor: CursorMemoria(),
			diagnostico: diagnostico,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
		);

		await orquestador.sincronizarCompleto();
		expect(diagnostico.cuarentena, hasLength(1));

		// Desaparece la causa (llego la fila padre que faltaba, por ejemplo).
		aplicador.idsQueFallan.clear();
		final resultado = await orquestador.sincronizarCompleto();

		expect(resultado.eventosRecuperados, 1);
		expect(diagnostico.cuarentena, isEmpty);
		expect(aplicador.aplicados.map((e) => e.id), contains('ev-2'));
	});

	test('un evento con JSON invalido no tumba la pagina completa', () async {
		final aplicador = AplicadorMemoria();
		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: hubConPagina(
					[
						eventoHub(1),
						// Tipo que esta build no conoce y fecha ilegible: antes
						// `DateTime.parse('')` lanzaba y se perdia la pagina entera.
						{
							'seq': 2,
							'id': 'ev-2',
							'type': 'tipoDeUnaVersionMasNueva',
							'payload': {'id': 'x'},
							'createdAt': 'no-es-una-fecha',
						},
						eventoHub(3),
					],
					<int>[],
				),
			),
			clienteLan: null,
			aplicadorRemoto: aplicador,
			almacenCursor: CursorMemoria(),
			diagnostico: DiagnosticoMemoria(),
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
		);

		await orquestador.sincronizarCompleto();

		expect(aplicador.aplicados.map((e) => e.id), ['ev-1', 'ev-3']);
	});

	test('el error de un ciclo queda registrado y se limpia al recuperarse', () async {
		final diagnostico = DiagnosticoMemoria();
		final cola = ColaAveriable();
		final orquestador = SyncOrchestrator(
			colaLocal: cola,
			clienteHub: HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: hubConPagina(const [], <int>[]),
			),
			clienteLan: null,
			aplicadorRemoto: AplicadorMemoria(),
			almacenCursor: CursorMemoria(),
			diagnostico: diagnostico,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-movil',
		);

		cola.averiada = true;
		await expectLater(orquestador.sincronizarCompleto(), throwsStateError);
		expect(
			diagnostico.ultimoError?.mensaje,
			contains('base bloqueada'),
			reason: 'los disparadores automaticos silencian el error; sin este '
				'registro el equipo se veia sano mientras dejaba de recibir datos',
		);

		cola.averiada = false;
		await orquestador.sincronizarCompleto();
		expect(diagnostico.ultimoError, isNull);
	});
}

/// Cola que puede fallar a voluntad para simular un ciclo que revienta.
class ColaAveriable extends ColaEventosMemoria {
	bool averiada = false;

	@override
	Future<int> colapsarDuplicadosCatalogo() async {
		if (averiada) {
			throw StateError('base bloqueada');
		}
		return 0;
	}
}
