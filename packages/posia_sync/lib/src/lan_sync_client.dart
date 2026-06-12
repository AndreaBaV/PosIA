/// Cliente de sincronizacion LAN entre cajas de una tienda.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:30:00 (UTC-6)
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:posia_core/posia_core.dart';

/// Intercambia eventos entre dos cajas en la misma red local.
class LanSyncClient {
	/// Crea cliente LAN con host peer configurable.
	///
	/// [hostPeer] Direccion IP de la caja par en la tienda.
	/// [puerto] Puerto del servicio sync LAN.
	/// [clienteHttp] Cliente HTTP inyectable para pruebas.
	LanSyncClient({
		required String hostPeer,
		int puerto = PUERTO_SYNC_LAN_DEFAULT,
		http.Client? clienteHttp,
	}) : _hostPeer = hostPeer,
	     _puerto = puerto,
	     _clienteHttp = clienteHttp ?? http.Client();

	final String _hostPeer;
	final int _puerto;
	final http.Client _clienteHttp;

	/// Envia eventos a la caja par por HTTP local.
	///
	/// [eventos] Eventos a replicar en LAN.
	/// Retorna verdadero si la caja par acepto el lote.
	Future<bool> enviarEventos(List<SyncEvent> eventos) async {
		final uri = Uri.http('$_hostPeer:$_puerto', '/lan/events');
		final cuerpo = jsonEncode({
			'events': eventos.map(_serializarEvento).toList(),
		});
		try {
			final respuesta = await _clienteHttp.post(
				uri,
				headers: {'Content-Type': 'application/json'},
				body: cuerpo,
			);
			return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
		} on http.ClientException {
			return false;
		}
	}

	/// Serializa evento para transporte LAN.
	///
	/// [evento] Evento de dominio.
	/// Retorna mapa JSON.
	Map<String, Object?> _serializarEvento(SyncEvent evento) {
		return {
			'id': evento.id,
			'type': evento.tipo.name,
			'payload': evento.payload,
			'createdAt': evento.creadoEn.toIso8601String(),
		};
	}
}
