/// Salud del sync en SQLite: cuarentena de eventos y ultimo error de ciclo.
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

/// Implementa [DiagnosticoSync] sobre `sync_eventos_cuarentena` y `sync_state`.
class DiagnosticoSyncRepository implements DiagnosticoSync {
	DiagnosticoSyncRepository({required Database baseDatos})
		: _baseDatos = baseDatos;

	static const String _tabla = 'sync_eventos_cuarentena';
	static const String _claveUltimoError = 'ultimo_error_sync';
	static const String _claveUltimoErrorEn = 'ultimo_error_sync_en';
	static const String _claveAuditoriaCoincide = 'auditoria_catalogo_coincide';
	static const String _claveAuditoriaProductosHub = 'auditoria_catalogo_productos_hub';
	static const String _claveAuditoriaProductosLocal = 'auditoria_catalogo_productos_local';
	static const String _claveAuditoriaCategoriasHub = 'auditoria_catalogo_categorias_hub';
	static const String _claveAuditoriaCategoriasLocal = 'auditoria_catalogo_categorias_local';
	static const String _claveAuditoriaEn = 'auditoria_catalogo_en';

	/// Recorte del mensaje de error guardado; basta para identificar la causa
	/// y evita que un stack trace enorme infle la base de cada dispositivo.
	static const int _maxLongitudError = 500;

	final Database _baseDatos;

	@override
	Future<void> registrarEventoFallido({
		required SyncEvent evento,
		required Object error,
	}) async {
		if (evento.id.isEmpty) {
			return;
		}
		final ahora = DateTime.now().toUtc().toIso8601String();
		final mensaje = _recortar('$error');
		// Conserva el conteo de intentos si el evento ya estaba apartado: la
		// cifra distingue un tropiezo puntual de un evento que nunca va a entrar.
		final actualizadas = await _baseDatos.rawUpdate(
			'''
			UPDATE $_tabla
			SET error = ?, intentos = intentos + 1, ultimo_intento_en = ?
			WHERE evento_id = ?
			''',
			[mensaje, ahora, evento.id],
		);
		if (actualizadas > 0) {
			return;
		}
		await _baseDatos.insert(
			_tabla,
			{
				'evento_id': evento.id,
				'seq': evento.seq,
				'tipo': evento.tipo.name,
				'tienda_id': evento.tiendaId,
				'dispositivo_id': evento.dispositivoId,
				'payload_json': jsonEncode(evento.payload),
				'creado_en': evento.creadoEn.toUtc().toIso8601String(),
				'error': mensaje,
				'intentos': 1,
				'ultimo_intento_en': ahora,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	@override
	Future<void> resolverEventoFallido(String eventoId) async {
		await _baseDatos.delete(
			_tabla,
			where: 'evento_id = ?',
			whereArgs: [eventoId],
		);
	}

	@override
	Future<List<EventoEnCuarentena>> listarCuarentena({int limite = 100}) async {
		final filas = await _baseDatos.query(
			_tabla,
			orderBy: 'seq ASC',
			limit: limite,
		);
		final apartados = <EventoEnCuarentena>[];
		for (final fila in filas) {
			final evento = _reconstruirEvento(fila);
			if (evento == null) {
				continue;
			}
			apartados.add(
				EventoEnCuarentena(
					evento: evento,
					error: fila['error'] as String? ?? '',
					intentos: (fila['intentos'] as num?)?.toInt() ?? 0,
					ultimoIntentoEn:
						DateTime.tryParse(fila['ultimo_intento_en'] as String? ?? '') ??
						DateTime.now().toUtc(),
				),
			);
		}
		return apartados;
	}

	@override
	Future<int> contarCuarentena() async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM $_tabla',
		);
		return (filas.first['total'] as num?)?.toInt() ?? 0;
	}

	@override
	Future<void> registrarErrorCiclo(Object? error) async {
		if (error == null) {
			await _baseDatos.delete(
				'sync_state',
				where: 'clave IN (?, ?)',
				whereArgs: [_claveUltimoError, _claveUltimoErrorEn],
			);
			return;
		}
		await _baseDatos.insert(
			'sync_state',
			{'clave': _claveUltimoError, 'valor': _recortar('$error')},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
		await _baseDatos.insert(
			'sync_state',
			{
				'clave': _claveUltimoErrorEn,
				'valor': DateTime.now().toUtc().toIso8601String(),
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	@override
	Future<ErrorCicloSync?> leerUltimoErrorCiclo() async {
		final mensaje = await _leerEstado(_claveUltimoError);
		if (mensaje == null || mensaje.isEmpty) {
			return null;
		}
		return ErrorCicloSync(
			mensaje: mensaje,
			ocurridoEn: DateTime.tryParse(await _leerEstado(_claveUltimoErrorEn) ?? '') ??
				DateTime.now().toUtc(),
		);
	}

	@override
	Future<void> registrarAuditoriaCatalogo(AuditoriaCatalogo resultado) async {
		final valores = {
			_claveAuditoriaCoincide: resultado.coincide ? '1' : '0',
			_claveAuditoriaProductosHub: '${resultado.productosHub}',
			_claveAuditoriaProductosLocal: '${resultado.productosLocal}',
			_claveAuditoriaCategoriasHub: '${resultado.categoriasHub}',
			_claveAuditoriaCategoriasLocal: '${resultado.categoriasLocal}',
			_claveAuditoriaEn: resultado.verificadoEn.toUtc().toIso8601String(),
		};
		for (final entrada in valores.entries) {
			await _baseDatos.insert(
				'sync_state',
				{'clave': entrada.key, 'valor': entrada.value},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
		}
	}

	@override
	Future<AuditoriaCatalogo?> leerUltimaAuditoriaCatalogo() async {
		final verificadoEnTexto = await _leerEstado(_claveAuditoriaEn);
		if (verificadoEnTexto == null) {
			return null;
		}
		final verificadoEn = DateTime.tryParse(verificadoEnTexto);
		if (verificadoEn == null) {
			return null;
		}
		return AuditoriaCatalogo(
			coincide: await _leerEstado(_claveAuditoriaCoincide) == '1',
			productosHub:
				int.tryParse(await _leerEstado(_claveAuditoriaProductosHub) ?? '') ?? 0,
			productosLocal:
				int.tryParse(await _leerEstado(_claveAuditoriaProductosLocal) ?? '') ?? 0,
			categoriasHub:
				int.tryParse(await _leerEstado(_claveAuditoriaCategoriasHub) ?? '') ?? 0,
			categoriasLocal:
				int.tryParse(await _leerEstado(_claveAuditoriaCategoriasLocal) ?? '') ?? 0,
			verificadoEn: verificadoEn,
		);
	}

	Future<String?> _leerEstado(String clave) async {
		final filas = await _baseDatos.query(
			'sync_state',
			where: 'clave = ?',
			whereArgs: [clave],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return filas.first['valor'] as String?;
	}

	/// Rearma el evento apartado. Descarta la fila si esta build ya no reconoce
	/// el tipo o el payload quedo ilegible: reintentarlo eternamente no aporta.
	SyncEvent? _reconstruirEvento(Map<String, Object?> fila) {
		try {
			final payload = jsonDecode(fila['payload_json'] as String? ?? '{}');
			return SyncEvent(
				id: fila['evento_id'] as String? ?? '',
				tiendaId: fila['tienda_id'] as String? ?? '',
				dispositivoId: fila['dispositivo_id'] as String? ?? '',
				tipo: TipoSyncEvento.values.byName(fila['tipo'] as String? ?? ''),
				payload: payload is Map
					? Map<String, Object?>.from(payload)
					: <String, Object?>{},
				creadoEn: DateTime.tryParse(fila['creado_en'] as String? ?? '') ??
					DateTime.now().toUtc(),
				estado: EstadoSyncEvento.enviado,
				seq: (fila['seq'] as num?)?.toInt() ?? 0,
			);
		} on Object {
			return null;
		}
	}

	String _recortar(String texto) {
		final limpio = texto.replaceAll('\n', ' ').trim();
		if (limpio.length <= _maxLongitudError) {
			return limpio;
		}
		return limpio.substring(0, _maxLongitudError);
	}
}
