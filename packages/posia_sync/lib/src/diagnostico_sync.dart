/// Contrato de salud del sync: eventos en cuarentena y ultimo error del ciclo.
///
/// El pull aplica los eventos del hub uno por uno sobre SQLite. Un evento que
/// no se puede aplicar (violacion de FOREIGN KEY, payload de una version mas
/// nueva, fila padre ausente) no debe detener a los que vienen detras: se
/// aparta aqui, el cursor sigue avanzando y se reintenta en cada ciclo hasta
/// que la causa desaparece. Antes ese evento congelaba el cursor y el
/// dispositivo se quedaba anclado en ese punto del historial para siempre.
library;

import 'package:posia_core/posia_core.dart';

/// Evento remoto apartado tras fallar al aplicarse en local.
class EventoEnCuarentena {
	const EventoEnCuarentena({
		required this.evento,
		required this.error,
		required this.intentos,
		required this.ultimoIntentoEn,
	});

	/// Evento original, listo para reintentar.
	final SyncEvent evento;

	/// Mensaje del ultimo fallo (recortado).
	final String error;

	/// Veces que se ha intentado aplicar.
	final int intentos;

	/// Momento del ultimo intento.
	final DateTime ultimoIntentoEn;
}

/// Ultimo error registrado por un ciclo de sincronizacion.
class ErrorCicloSync {
	const ErrorCicloSync({required this.mensaje, required this.ocurridoEn});

	final String mensaje;
	final DateTime ocurridoEn;
}

/// Persiste el estado de salud del sync de este dispositivo.
abstract class DiagnosticoSync {
	/// Aparta un evento que no se pudo aplicar y suma un intento.
	Future<void> registrarEventoFallido({
		required SyncEvent evento,
		required Object error,
	});

	/// Saca un evento de cuarentena tras aplicarse correctamente.
	Future<void> resolverEventoFallido(String eventoId);

	/// Eventos apartados, del mas antiguo al mas reciente.
	Future<List<EventoEnCuarentena>> listarCuarentena({int limite = 100});

	/// Cantidad de eventos apartados.
	Future<int> contarCuarentena();

	/// Guarda (o limpia, con null) el error del ultimo ciclo.
	Future<void> registrarErrorCiclo(Object? error);

	/// Ultimo error de ciclo registrado, si lo hay.
	Future<ErrorCicloSync?> leerUltimoErrorCiclo();
}
