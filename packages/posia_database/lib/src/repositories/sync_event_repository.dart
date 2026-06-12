/// Repositorio SQLite de cola de eventos de sync.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

/// Implementa [LocalEventQueue] sobre SQLite local.
class SyncEventRepository implements LocalEventQueue {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	SyncEventRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	@override
	Future<void> encolar(SyncEvent evento) async {
		await _baseDatos.insert(
			'sync_event_queue',
			{
				'id': evento.id,
				'tenant_id': evento.tenantId,
				'tienda_id': evento.tiendaId,
				'dispositivo_id': evento.dispositivoId,
				'tipo': evento.tipo.name,
				'payload': jsonEncode(evento.payload),
				'creado_en': evento.creadoEn.toIso8601String(),
				'estado': evento.estado.name,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	@override
	Future<List<SyncEvent>> obtenerPendientes() async {
		final filas = await _baseDatos.query(
			'sync_event_queue',
			where: 'estado = ? OR estado = ?',
			whereArgs: [
				EstadoSyncEvento.pendiente.name,
				EstadoSyncEvento.error.name,
			],
			orderBy: 'creado_en ASC',
		);
		return filas.map(_mapearEvento).toList();
	}

	@override
	Future<void> marcarEnviado(String eventoId) async {
		await _actualizarEstado(eventoId, EstadoSyncEvento.enviado);
	}

	@override
	Future<void> marcarError(String eventoId) async {
		await _actualizarEstado(eventoId, EstadoSyncEvento.error);
	}

	/// Actualiza estado de evento en cola.
	///
	/// [eventoId] Identificador del evento.
	/// [estado] Nuevo estado de transmision.
	Future<void> _actualizarEstado(String eventoId, EstadoSyncEvento estado) async {
		await _baseDatos.update(
			'sync_event_queue',
			{'estado': estado.name},
			where: 'id = ?',
			whereArgs: [eventoId],
		);
	}

	/// Convierte fila SQLite a [SyncEvent].
	///
	/// [fila] Registro de cola.
	/// Retorna evento de dominio.
	SyncEvent _mapearEvento(Map<String, Object?> fila) {
		final payloadJson = jsonDecode(fila['payload'] as String) as Map<String, Object?>;
		return SyncEvent(
			id: fila['id'] as String,
			tenantId: fila['tenant_id'] as String,
			tiendaId: fila['tienda_id'] as String,
			dispositivoId: fila['dispositivo_id'] as String,
			tipo: TipoSyncEvento.values.byName(fila['tipo'] as String),
			payload: payloadJson,
			creadoEn: DateTime.parse(fila['creado_en'] as String),
			estado: EstadoSyncEvento.values.byName(fila['estado'] as String),
		);
	}
}
