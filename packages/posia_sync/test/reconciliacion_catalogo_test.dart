/// Reconciliacion automatica de catalogo: el orquestador debe notar cuando
/// el catalogo local diverge del hub (aunque el cursor ya este al dia) y
/// repararlo, priorizando la ruta rapida (solo eventos de catalogo) sobre la
/// reconstruccion completa desde origen.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:test/test.dart';

import 'utiles_sync_memoria.dart';

void main() {
	http.Response respuestaJson(Map<String, Object?> cuerpo, {int codigo = 200}) {
		return http.Response(
			jsonEncode(cuerpo),
			codigo,
			headers: {'Content-Type': 'application/json'},
		);
	}

	test(
		'reparacion rapida aplica eventos de catalogo sin resetear el cursor',
		() async {
			final aplicador = AplicadorMemoria();
			final cursor = CursorMemoria()..cursor = 42;
			final diagnostico = DiagnosticoMemoria();
			var llamadasAuditoria = 0;

			final cliente = HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: MockClient((request) async {
					if (request.url.path.endsWith('/v1/health')) {
						return http.Response('ok', 200);
					}
					if (request.url.path.endsWith('/v1/catalog/audit')) {
						llamadasAuditoria++;
						return respuestaJson({
							'productosActivos': 5,
							'categoriasActivas': 2,
							'huellaProductos': 'hash-remoto',
						});
					}
					if (request.url.path.endsWith('/v1/catalog/events')) {
						return respuestaJson({
							'events': [
								{
									'seq': 900,
									'id': 'evento-catalogo-1',
									'storeId': 'tienda-1',
									'deviceId': 'backfill',
									'type': 'productUpserted',
									'payload': {'id': 'p1', 'nombre': 'Pistache'},
									'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
								},
							],
							'lastSeq': 900,
						});
					}
					if (request.method == 'GET' && request.url.path.endsWith('/v1/events')) {
						return respuestaJson({'events': [], 'lastSeq': 0});
					}
					if (request.method == 'POST' && request.url.path.endsWith('/v1/events')) {
						return respuestaJson({'accepted': 0, 'received': 0});
					}
					return http.Response('not found', 404);
				}),
			);

			final orquestador = SyncOrchestrator(
				colaLocal: ColaEventosMemoria(),
				clienteHub: cliente,
				clienteLan: null,
				aplicadorRemoto: aplicador,
				almacenCursor: cursor,
				diagnostico: diagnostico,
				tiendaId: 'tienda-1',
				dispositivoId: 'caja-1',
			);

			await orquestador.sincronizarCompleto();

			expect(llamadasAuditoria, 1);
			// El evento de catalogo se aplico...
			expect(aplicador.aplicados.map((e) => e.id), contains('evento-catalogo-1'));
			// ...sin pasar por una reconstruccion completa: el cursor incremental
			// normal (42) no se toco.
			expect(cursor.cursor, 42);
			// Queda registro de la auditoria para el panel de diagnostico.
			final registrada = diagnostico.ultimaAuditoriaCatalogo;
			expect(registrada, isNotNull);
			expect(registrada!.productosHub, 5);
			expect(registrada.categoriasHub, 2);
		},
	);

	test(
		'si el hub no expone la ruta rapida, cae a reconstruccion completa desde origen',
		() async {
			final aplicador = AplicadorMemoria();
			final cursor = CursorMemoria()..cursor = 42;
			final diagnostico = DiagnosticoMemoria();

			final cliente = HubSyncClient(
				urlBase: 'https://hub.test',
				clienteHttp: MockClient((request) async {
					if (request.url.path.endsWith('/v1/health')) {
						return http.Response('ok', 200);
					}
					if (request.url.path.endsWith('/v1/catalog/audit')) {
						return respuestaJson({
							'productosActivos': 5,
							'categoriasActivas': 2,
							'huellaProductos': 'hash-remoto',
						});
					}
					if (request.url.path.endsWith('/v1/catalog/events')) {
						// Hub desplegado con una version anterior: la ruta no existe.
						return respuestaJson({'error': 'no disponible'}, codigo: 503);
					}
					if (request.method == 'GET' && request.url.path.endsWith('/v1/events')) {
						return respuestaJson({'events': [], 'lastSeq': 0});
					}
					if (request.method == 'POST' && request.url.path.endsWith('/v1/events')) {
						return respuestaJson({'accepted': 0, 'received': 0});
					}
					return http.Response('not found', 404);
				}),
			);

			final orquestador = SyncOrchestrator(
				colaLocal: ColaEventosMemoria(),
				clienteHub: cliente,
				clienteLan: null,
				aplicadorRemoto: aplicador,
				almacenCursor: cursor,
				diagnostico: diagnostico,
				tiendaId: 'tienda-1',
				dispositivoId: 'caja-1',
			);

			await orquestador.sincronizarCompleto();

			// La reparacion rapida fallo (503): el ciclo recurrio a la
			// reconstruccion completa, que reinicia el cursor a 0.
			expect(cursor.cursor, 0);
			expect(diagnostico.ultimaAuditoriaCatalogo, isNotNull);
		},
	);

	test('una auditoria reciente no vuelve a golpear el hub en el siguiente ciclo', () async {
		final aplicador = AplicadorMemoria();
		final cursor = CursorMemoria();
		final diagnostico = DiagnosticoMemoria()
			..ultimaAuditoriaCatalogo = AuditoriaCatalogo(
				coincide: true,
				productosHub: 0,
				productosLocal: 0,
				categoriasHub: 0,
				categoriasLocal: 0,
				verificadoEn: DateTime.now().toUtc(),
			);
		var llamadasAuditoria = 0;

		final cliente = HubSyncClient(
			urlBase: 'https://hub.test',
			clienteHttp: MockClient((request) async {
				if (request.url.path.endsWith('/v1/health')) {
					return http.Response('ok', 200);
				}
				if (request.url.path.endsWith('/v1/catalog/audit')) {
					llamadasAuditoria++;
					return respuestaJson({
						'productosActivos': 0,
						'categoriasActivas': 0,
						'huellaProductos': '',
					});
				}
				if (request.method == 'GET' && request.url.path.endsWith('/v1/events')) {
					return respuestaJson({'events': [], 'lastSeq': 0});
				}
				if (request.method == 'POST' && request.url.path.endsWith('/v1/events')) {
					return respuestaJson({'accepted': 0, 'received': 0});
				}
				return http.Response('not found', 404);
			}),
		);

		final orquestador = SyncOrchestrator(
			colaLocal: ColaEventosMemoria(),
			clienteHub: cliente,
			clienteLan: null,
			aplicadorRemoto: aplicador,
			almacenCursor: cursor,
			diagnostico: diagnostico,
			tiendaId: 'tienda-1',
			dispositivoId: 'caja-1',
		);

		await orquestador.sincronizarCompleto();

		expect(llamadasAuditoria, 0);
	});
}
