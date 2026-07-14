/// Contrato de cola local de eventos de sincronizacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-07-12 11:55:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Persistencia de eventos pendientes en dispositivo.
abstract class LocalEventQueue {
	/// Encola un evento para envio posterior.
	///
	/// [evento] Evento capturado en caja.
	Future<void> encolar(SyncEvent evento);

	/// Obtiene eventos pendientes de transmision.
	///
	/// Retorna lista de eventos con estado pendiente o error.
	Future<List<SyncEvent>> obtenerPendientes();

	/// Marca evento como enviado exitosamente.
	///
	/// [eventoId] Identificador del evento confirmado.
	Future<void> marcarEnviado(String eventoId);

	/// Marca evento con error de envio para reintento.
	///
	/// [eventoId] Identificador del evento fallido.
	Future<void> marcarError(String eventoId);

	/// Descarta pendientes de catalogo espejo (reencolados duplicados).
	///
	/// Peligroso en el ciclo normal de sync: borra cambios locales de catalogo
	/// (empaques, productos, etc.) que aun no se han subido a Neon.
	/// Preferir [colapsarDuplicadosCatalogo].
	Future<int> descartarPendientesCatalogoEspejo() async => 0;

	/// Deja un solo pendiente por tipo+entidad de catalogo (el mas reciente).
	///
	/// Conserva el cambio local mas nuevo para empujarlo; solo elimina
	/// versiones antiguas duplicadas en cola.
	Future<int> colapsarDuplicadosCatalogo() async => 0;
}
