/// Contrato de almacenamiento del log de eventos del hub.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

import 'evento_hub.dart';

/// Define operaciones de persistencia del log append-only.
abstract class AlmacenEventos {
	/// Inicializa esquema o archivo segun implementacion.
	Future<void> inicializar();

	/// Guarda lote de eventos ignorando duplicados por id.
	///
	/// [eventos] Eventos recibidos del dispositivo.
	/// Retorna cantidad de eventos nuevos aceptados.
	Future<int> guardarLote(List<EventoHub> eventos);

	/// Obtiene eventos posteriores a un cursor.
	///
	/// [desdeSeq] Cursor exclusivo; 0 trae desde el inicio.
	/// [excluirDispositivoId] Omite eventos emitidos por este dispositivo.
	/// [limite] Maximo de eventos por respuesta.
	/// Retorna eventos ordenados por seq ascendente.
	Future<List<EventoHub>> obtenerDesde({
		required int desdeSeq,
		String? excluirDispositivoId,
		int limite = 500,
	});

	/// Libera recursos de conexion.
	Future<void> cerrar();
}
