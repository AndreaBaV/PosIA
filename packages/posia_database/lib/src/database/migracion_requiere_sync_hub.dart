/// Excepcion: hay eventos locales sin subir a Neon antes de migrar FKs.
library;

/// Se lanza si la cola `sync_event_queue` tiene pendientes/errores.
///
/// La migracion v33 reconstruye tablas con FOREIGN KEY; exige espejo en hub.
class MigracionRequiereSyncHubException implements Exception {
	MigracionRequiereSyncHubException(this.eventosPendientes);

	final int eventosPendientes;

	@override
	String toString() =>
		'MigracionRequiereSyncHubException: hay $eventosPendientes '
		'evento(s) pendientes o en error. Sincronice con el hub Neon antes '
		'de aplicar integridad referencial local (v33).';
}
