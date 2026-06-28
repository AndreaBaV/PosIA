/// Contrato para aplicar eventos remotos a la base local.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Aplica eventos recibidos del hub sobre el almacenamiento local.
abstract class AplicadorEventosRemotos {
	/// Aplica un evento remoto de forma idempotente.
	Future<void> aplicarEvento(SyncEvent evento);

	/// Aplica varios eventos; la implementación SQLite usa una sola transacción.
	Future<void> aplicarLote(List<SyncEvent> eventos);
}
