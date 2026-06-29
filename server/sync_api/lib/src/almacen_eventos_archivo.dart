/// Almacen de eventos en archivo JSONL para desarrollo y self-host simple.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

import 'dart:convert';
import 'dart:io';

import 'almacen_eventos.dart';
import 'evento_hub.dart';

/// Implementa [AlmacenEventos] sobre archivo append-only en disco.
///
/// Permite correr el hub sin Postgres ni Docker; util para pruebas
/// locales y despliegues de una sola tienda.
class AlmacenEventosArchivo implements AlmacenEventos {
	/// Crea almacen con ruta del archivo de log.
	///
	/// [rutaArchivo] Ruta del archivo JSONL de eventos.
	AlmacenEventosArchivo({required String rutaArchivo})
		: _rutaArchivo = rutaArchivo;

	final String _rutaArchivo;
	final List<EventoHub> _eventos = [];
	final Set<String> _idsConocidos = {};
	int _ultimoSeq = 0;

	@override
	Future<void> inicializar() async {
		final archivo = File(_rutaArchivo);
		if (!archivo.existsSync()) {
			archivo.createSync(recursive: true);
			return;
		}
		final lineas = await archivo.readAsLines();
		final lineasValidas = lineas.where((linea) => linea.trim().isNotEmpty);
		for (final linea in lineasValidas) {
			final json = jsonDecode(linea) as Map<String, Object?>;
			final evento = _eventoDesdeLinea(json);
			_eventos.add(evento);
			_idsConocidos.add(evento.id);
			_ultimoSeq = evento.seq > _ultimoSeq ? evento.seq : _ultimoSeq;
		}
	}

	@override
	Future<int> guardarLote(List<EventoHub> eventos) async {
		final nuevos = eventos.where((evento) => !_idsConocidos.contains(evento.id));
		var aceptados = 0;
		final buffer = StringBuffer();
		for (final evento in nuevos) {
			_ultimoSeq = _ultimoSeq + 1;
			final persistido = evento.copiarConSeq(_ultimoSeq);
			_eventos.add(persistido);
			_idsConocidos.add(persistido.id);
			buffer.writeln(jsonEncode(persistido.aJson()));
			aceptados = aceptados + 1;
		}
		if (aceptados > 0) {
			await File(_rutaArchivo).writeAsString(
				buffer.toString(),
				mode: FileMode.append,
				flush: true,
			);
		}
		return aceptados;
	}

	@override
	Future<List<EventoHub>> obtenerDesde({
		required int desdeSeq,
		String? excluirDispositivoId,
		int limite = 500,
	}) async {
		return _eventos
			.where((evento) => evento.seq > desdeSeq)
			.where((evento) => excluirDispositivoId == null ||
				evento.dispositivoId != excluirDispositivoId)
			.take(limite)
			.toList();
	}

	@override
	Future<void> cerrar() async {}

	/// Reconstruye evento desde linea JSONL persistida.
	///
	/// [json] Mapa deserializado de la linea.
	/// Retorna evento con seq original.
	EventoHub _eventoDesdeLinea(Map<String, Object?> json) {
		return EventoHub(
			seq: json['seq'] as int? ?? 0,
			id: json['id'] as String? ?? '',
			tiendaId: json['storeId'] as String? ?? '',
			dispositivoId: json['deviceId'] as String? ?? '',
			tipo: json['type'] as String? ?? '',
			payload: Map<String, Object?>.from(
				json['payload'] as Map<Object?, Object?>? ?? {},
			),
			creadoEn: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
				DateTime.now().toUtc(),
		);
	}
}
