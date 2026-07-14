/// Repositorio SQLite de cola de eventos de sync.
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

class SyncEventRepository implements LocalEventQueue {
	SyncEventRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Tipos espejo de catalogo: reencolar N veces genera basura, no historial.
	static const Set<String> _tiposEspejoCatalogo = {
		'productUpserted',
		'categoryUpserted',
		'customerUpserted',
		'variantUpserted',
		'storeUpserted',
		'warehouseUpserted',
		'presentationTypeUpserted',
		'productPresentationsReplaced',
		'wholesaleTiersReplaced',
		'lotePromocionReplaced',
		'userUpserted',
		'customRoleUpserted',
		'priceListUpserted',
		'priceListItemUpserted',
		'customerProductPriceUpserted',
		'customerDiscountUpserted',
		'supplierUpserted',
		'employeeProfileUpserted',
		'cashShiftUpserted',
		'quoteUpserted',
		'orderUpserted',
	};

	@override
	Future<void> encolar(SyncEvent evento) async {
		await _baseDatos.insert(
			'sync_event_queue',
			{
				'id': evento.id,
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

	/// Cuenta eventos pendientes o con error.
	Future<int> contarPendientes() async {
		final filas = await _baseDatos.rawQuery('''
			SELECT COUNT(*) AS c
			FROM sync_event_queue
			WHERE estado IN (?, ?)
		''', [
			EstadoSyncEvento.pendiente.name,
			EstadoSyncEvento.error.name,
		]);
		return (filas.first['c'] as int?) ?? 0;
	}

	/// Descarta pendientes de catalogo espejo (reencolados duplicados).
	///
	/// Evitar en el ciclo normal de sync: elimina cambios locales aun no
	/// subidos. Preferir [colapsarDuplicadosCatalogo].
	@override
	Future<int> descartarPendientesCatalogoEspejo() async {
		final placeholders =
			List.filled(_tiposEspejoCatalogo.length, '?').join(',');
		return _baseDatos.delete(
			'sync_event_queue',
			where: 'estado IN (?, ?) AND tipo IN ($placeholders)',
			whereArgs: [
				EstadoSyncEvento.pendiente.name,
				EstadoSyncEvento.error.name,
				..._tiposEspejoCatalogo,
			],
		);
	}

	/// Colapsa duplicados de catalogo: deja solo el mas reciente por tipo+entidad.
	///
	/// Util cuando ya hay miles de UUID distintos del mismo producto.
	@override
	Future<int> colapsarDuplicadosCatalogo() async {
		final filas = await _baseDatos.query(
			'sync_event_queue',
			where: 'estado = ? OR estado = ?',
			whereArgs: [
				EstadoSyncEvento.pendiente.name,
				EstadoSyncEvento.error.name,
			],
			orderBy: 'creado_en DESC',
		);
		final vistos = <String>{};
		final idsABorrar = <String>[];
		for (final fila in filas) {
			final tipo = fila['tipo'] as String? ?? '';
			if (!_tiposEspejoCatalogo.contains(tipo)) {
				continue;
			}
			final id = fila['id'] as String? ?? '';
			if (id.isEmpty) {
				continue;
			}
			final clave = _claveEntidadCatalogo(tipo, fila['payload'] as String?);
			if (clave == null) {
				continue;
			}
			final llave = '$tipo|$clave';
			if (vistos.contains(llave)) {
				idsABorrar.add(id);
			} else {
				vistos.add(llave);
			}
		}
		if (idsABorrar.isEmpty) {
			return 0;
		}
		var borrados = 0;
		const chunk = 400;
		for (var i = 0; i < idsABorrar.length; i += chunk) {
			final lote = idsABorrar.sublist(
				i,
				i + chunk > idsABorrar.length ? idsABorrar.length : i + chunk,
			);
			final ph = List.filled(lote.length, '?').join(',');
			borrados += await _baseDatos.delete(
				'sync_event_queue',
				where: 'id IN ($ph)',
				whereArgs: lote,
			);
		}
		return borrados;
	}

	String? _claveEntidadCatalogo(String tipo, String? payloadJson) {
		if (payloadJson == null || payloadJson.isEmpty) {
			return null;
		}
		try {
			final payload = jsonDecode(payloadJson) as Map<String, Object?>;
			switch (tipo) {
				case 'priceListItemUpserted':
				case 'priceListItemDeleted':
					final lista = payload['listaPreciosId']?.toString() ??
						payload['listaId']?.toString() ??
						payload['priceListId']?.toString() ??
						'';
					final producto = payload['productoId']?.toString() ??
						payload['productId']?.toString() ??
						'';
					if (lista.isEmpty || producto.isEmpty) {
						return null;
					}
					return '$lista:$producto';
				case 'customerProductPriceUpserted':
				case 'customerProductPriceDeleted':
					final cliente = payload['clienteId']?.toString() ??
						payload['customerId']?.toString() ??
						'';
					final producto = payload['productoId']?.toString() ??
						payload['productId']?.toString() ??
						'';
					if (cliente.isEmpty || producto.isEmpty) {
						return null;
					}
					return '$cliente:$producto';
				case 'wholesaleTiersReplaced':
				case 'productPresentationsReplaced':
					final producto = payload['productoId']?.toString() ??
						payload['productId']?.toString() ??
						payload['id']?.toString() ??
						'';
					return producto.isEmpty ? null : producto;
				default:
					final id = payload['id']?.toString() ?? '';
					return id.isEmpty ? null : id;
			}
		} on Object {
			return null;
		}
	}

	@override
	Future<void> marcarEnviado(String eventoId) async {
		await _actualizarEstado(eventoId, EstadoSyncEvento.enviado);
	}

	@override
	Future<void> marcarError(String eventoId) async {
		await _actualizarEstado(eventoId, EstadoSyncEvento.error);
	}

	Future<void> _actualizarEstado(String eventoId, EstadoSyncEvento estado) async {
		await _baseDatos.update(
			'sync_event_queue',
			{'estado': estado.name},
			where: 'id = ?',
			whereArgs: [eventoId],
		);
	}

	SyncEvent _mapearEvento(Map<String, Object?> fila) {
		final payloadJson = jsonDecode(fila['payload'] as String) as Map<String, Object?>;
		return SyncEvent(
			id: fila['id'] as String,
			tiendaId: fila['tienda_id'] as String,
			dispositivoId: fila['dispositivo_id'] as String,
			tipo: TipoSyncEvento.values.byName(fila['tipo'] as String),
			payload: payloadJson,
			creadoEn: DateTime.parse(fila['creado_en'] as String),
			estado: EstadoSyncEvento.values.byName(fila['estado'] as String),
		);
	}
}
