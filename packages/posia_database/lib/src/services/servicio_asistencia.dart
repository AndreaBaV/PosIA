/// Servicio de asistencia con PIN y geocerca.
library;

import 'dart:async';
import 'dart:math';

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../repositories/asistencia_repository.dart';
import '../repositories/tienda_repository.dart';

/// Resultado al generar desafio PIN en admin.
class DesafioPinGenerado {
	const DesafioPinGenerado({
		required this.desafio,
		required this.pinPlano,
		this.sincronizadoConHub,
	});

	final DesafioAsistencia desafio;
	final String pinPlano;

	/// null = sin hub; true = ya en el hub; false = encolado pero no confirmado.
	final bool? sincronizadoConHub;
}

/// Coordina entrada/salida de empleados sin hardware biometrico externo.
class ServicioAsistencia {
	ServicioAsistencia({
		required AsistenciaRepository asistenciaRepository,
		required TiendaRepository tiendaRepository,
		required Database baseDatos,
		SyncOrchestrator? syncOrchestrator,
		required String tiendaId,
		required String dispositivoId,
	}) : _asistenciaRepository = asistenciaRepository,
       _tiendaRepository = tiendaRepository,
       _baseDatos = baseDatos,
       _syncOrchestrator = syncOrchestrator,
       _tiendaId = tiendaId,
       _dispositivoId = dispositivoId;

	final AsistenciaRepository _asistenciaRepository;
	final TiendaRepository _tiendaRepository;
	final Database _baseDatos;
	final SyncOrchestrator? _syncOrchestrator;
	final String _tiendaId;
	final String _dispositivoId;
	final Uuid _generadorId = const Uuid();
	final Random _random = Random.secure();

	/// Genera PIN de 4 digitos visible en laptop admin (TTL 10 min).
	///
	/// Guarda el desafio en local y devuelve el PIN de inmediato. El push al
	/// hub corre en paralelo con tope corto: el timeout HTTP de envio es de
	/// hasta 180 s y dejaba la UI en "Generando…" mientras el hub despertaba.
	Future<DesafioPinGenerado> generarDesafioPin(String creadoPor) async {
		final tienda = await _tiendaRepository.obtenerPorId(_tiendaId);
		if (tienda == null) {
			throw StateError('Tienda no encontrada');
		}
		if (tienda.latitud == null || tienda.longitud == null) {
			throw StateError(
				'Configure latitud y longitud de la tienda para asistencia',
			);
		}
		final pin = (_random.nextInt(9000) + 1000).toString();
		final credencial = HasherPin.codificar(pin);
		final desafio = DesafioAsistencia(
			id: _generadorId.v4(),
			tiendaId: _tiendaId,
			pinHash: credencial,
			expiraEn: DateTime.now().toUtc().add(const Duration(minutes: 10)),
			creadoPor: creadoPor,
			latitud: tienda.latitud,
			longitud: tienda.longitud,
			radioMetros: tienda.radioMetrosAsistencia,
			activo: true,
		);
		// Tienda ya validada arriba: dentro del tx no llamar al asegurador FK
		// (usa otra conexion y puede deadlockear con sqflite).
		try {
			await _baseDatos.transaction((tx) async {
				await _asistenciaRepository.desactivarDesafiosTienda(_tiendaId, db: tx);
				await _asistenciaRepository.guardarDesafio(desafio, db: tx);
			}).timeout(const Duration(seconds: 12));
		} on TimeoutException {
			throw StateError(
				'La base local esta ocupada (sincronizando). Espere un momento y reintente.',
			);
		}

		final sincronizado = await _empujarAsistenciaConTopeUi(
			TipoSyncEvento.attendanceChallengeCreated,
			claveEntidad: desafio.id,
			{
				'id': desafio.id,
				'tiendaId': desafio.tiendaId,
				'expiraEn': desafio.expiraEn.toUtc().toIso8601String(),
				'latitud': desafio.latitud,
				'longitud': desafio.longitud,
				'radioMetros': desafio.radioMetros,
				'pinHash': desafio.pinHash,
			},
		);
		return DesafioPinGenerado(
			desafio: desafio,
			pinPlano: pin,
			sincronizadoConHub: sincronizado,
		);
	}

	/// Registra entrada validando PIN y ubicacion del telefono.
	///
	/// Siempre intenta sync primero: el PIN se genera en la laptop admin y el
	/// hash debe llegar al celular antes de validar.
	Future<RegistroAsistencia> registrarEntradaConPin({
		required String usuarioId,
		required String pin,
		required double latitud,
		required double longitud,
	}) async {
		await _intentarSincronizarHub();
		try {
			return await _entradaConPinLocal(
				usuarioId: usuarioId,
				pin: pin,
				latitud: latitud,
				longitud: longitud,
			);
		} on StateError catch (error) {
			if (!_esErrorDesafioOPin(error)) {
				rethrow;
			}
			// Segundo intento por si el push del admin llego milisegundos despues.
			final sincronizo = await _intentarSincronizarHub();
			if (!sincronizo) {
				rethrow;
			}
			return _entradaConPinLocal(
				usuarioId: usuarioId,
				pin: pin,
				latitud: latitud,
				longitud: longitud,
			);
		}
	}

	/// Registra entrada por geocerca + biometria del telefono.
	Future<RegistroAsistencia> registrarEntradaBiometrica({
		required String usuarioId,
		required double latitud,
		required double longitud,
	}) async {
		try {
			return await _entradaBiometricaLocal(
				usuarioId: usuarioId,
				latitud: latitud,
				longitud: longitud,
			);
		} on StateError catch (error) {
			if (!error.message.contains('coordenadas')) {
				rethrow;
			}
			final sincronizo = await _intentarSincronizarHub();
			if (!sincronizo) {
				rethrow;
			}
			return _entradaBiometricaLocal(
				usuarioId: usuarioId,
				latitud: latitud,
				longitud: longitud,
			);
		}
	}

	Future<RegistroAsistencia> registrarSalida(String usuarioId) async {
		final abierta = await _asistenciaRepository.obtenerEntradaAbierta(usuarioId);
		if (abierta == null) {
			throw StateError('No hay entrada abierta');
		}
		final salida = RegistroAsistencia(
			id: abierta.id,
			usuarioId: abierta.usuarioId,
			tiendaId: abierta.tiendaId,
			entradaEn: abierta.entradaEn,
			salidaEn: DateTime.now().toUtc(),
			metodo: abierta.metodo,
			latitud: abierta.latitud,
			longitud: abierta.longitud,
			desafioId: abierta.desafioId,
		);
		await _asistenciaRepository.guardarRegistro(salida);
		await _empujarAsistenciaConTopeUi(
			TipoSyncEvento.attendanceCheckedOut,
			claveEntidad: salida.id,
			{
				'registroId': salida.id,
				'usuarioId': salida.usuarioId,
				'tiendaId': salida.tiendaId,
				'salidaEn': salida.salidaEn!.toIso8601String(),
			},
		);
		return salida;
	}

	/// Entradas del dia calendario local (Mexico UTC-6, no el dia UTC).
	///
	/// Con [sincronizarPrimero] baja del hub las entradas hechas en otros
	/// dispositivos (p. ej. biometria en el celular) antes de listar.
	/// Con [todasLasTiendas] lista el dia completo del tenant (panel admin).
	Future<List<RegistroAsistencia>> listarEntradasDelDia({
		DateTime? dia,
		bool sincronizarPrimero = false,
		bool todasLasTiendas = false,
	}) async {
		if (sincronizarPrimero) {
			await _intentarSincronizarHub();
		}
		final referencia = (dia ?? DateTime.now()).toLocal();
		final inicioLocal = DateTime(
			referencia.year,
			referencia.month,
			referencia.day,
		);
		final inicio = inicioLocal.toUtc();
		final fin = inicioLocal.add(const Duration(days: 1)).toUtc();
		if (todasLasTiendas) {
			return _asistenciaRepository.listarPorRango(inicio, fin);
		}
		return _asistenciaRepository.listarPorTiendaRango(_tiendaId, inicio, fin);
	}

	Future<DesafioAsistencia?> obtenerDesafioActivo() {
		return _asistenciaRepository.obtenerDesafioActivo(_tiendaId);
	}

	Future<RegistroAsistencia?> obtenerEntradaAbierta(String usuarioId) {
		return _asistenciaRepository.obtenerEntradaAbierta(usuarioId);
	}

	Future<RegistroAsistencia> _entradaConPinLocal({
		required String usuarioId,
		required String pin,
		required double latitud,
		required double longitud,
	}) async {
		final abierta = await _asistenciaRepository.obtenerEntradaAbierta(usuarioId);
		if (abierta != null) {
			throw StateError('Ya tiene una entrada abierta');
		}
		final desafio = await _asistenciaRepository.obtenerDesafioActivo(_tiendaId);
		if (desafio == null) {
			throw StateError(
				'No hay PIN de asistencia activo. Genérelo en Admin → Asistencia '
				'en un equipo de esta misma tienda y espere a que sincronice.',
			);
		}
		if (!_verificarPin(pin, desafio.pinHash)) {
			throw StateError('PIN incorrecto o expirado');
		}
		final latCentro = desafio.latitud;
		final lonCentro = desafio.longitud;
		if (latCentro == null || lonCentro == null) {
			throw StateError('Tienda sin coordenadas configuradas');
		}
		_validarUbicacion(
			latitud: latitud,
			longitud: longitud,
			latCentro: latCentro,
			lonCentro: lonCentro,
			radioMetros: desafio.radioMetros,
		);
		return _crearEntrada(
			usuarioId: usuarioId,
			metodo: 'pin_gps',
			latitud: latitud,
			longitud: longitud,
			desafioId: desafio.id,
		);
	}

	Future<RegistroAsistencia> _entradaBiometricaLocal({
		required String usuarioId,
		required double latitud,
		required double longitud,
	}) async {
		final abierta = await _asistenciaRepository.obtenerEntradaAbierta(usuarioId);
		if (abierta != null) {
			throw StateError('Ya tiene una entrada abierta');
		}
		final tienda = await _tiendaRepository.obtenerPorId(_tiendaId);
		if (tienda?.latitud == null || tienda?.longitud == null) {
			throw StateError('Tienda sin coordenadas configuradas');
		}
		_validarUbicacion(
			latitud: latitud,
			longitud: longitud,
			latCentro: tienda!.latitud!,
			lonCentro: tienda.longitud!,
			radioMetros: tienda.radioMetrosAsistencia,
		);
		return _crearEntrada(
			usuarioId: usuarioId,
			metodo: 'geocerca_biometrica',
			latitud: latitud,
			longitud: longitud,
		);
	}

	bool _verificarPin(String pin, String pinCredencial) {
		return HasherPin.verificar(pin, pinCredencial);
	}

	bool _esErrorDesafioOPin(StateError error) {
		final mensaje = error.message;
		return mensaje.contains('PIN') || mensaje.contains('desafio') ||
			mensaje.contains('No hay PIN');
	}

	void _validarUbicacion({
		required double latitud,
		required double longitud,
		required double latCentro,
		required double lonCentro,
		required double radioMetros,
	}) {
		if (!dentroDeGeocerca(
			latitud: latitud,
			longitud: longitud,
			latCentro: latCentro,
			lonCentro: lonCentro,
			radioMetros: radioMetros,
		)) {
			throw StateError(
				'Ubicacion fuera del radio permitido (${radioMetros.toInt()} m)',
			);
		}
	}

	Future<RegistroAsistencia> _crearEntrada({
		required String usuarioId,
		required String metodo,
		required double latitud,
		required double longitud,
		String? desafioId,
	}) async {
		final registro = RegistroAsistencia(
			id: _generadorId.v4(),
			usuarioId: usuarioId,
			tiendaId: _tiendaId,
			entradaEn: DateTime.now().toUtc(),
			metodo: metodo,
			latitud: latitud,
			longitud: longitud,
			desafioId: desafioId,
		);
		await _asistenciaRepository.guardarRegistro(registro);
		await _empujarAsistenciaConTopeUi(
			TipoSyncEvento.attendanceCheckedIn,
			claveEntidad: registro.id,
			{
				'id': registro.id,
				'usuarioId': registro.usuarioId,
				'tiendaId': registro.tiendaId,
				'entradaEn': registro.entradaEn.toIso8601String(),
				'metodo': registro.metodo,
				'latitud': registro.latitud,
				'longitud': registro.longitud,
				'desafioId': registro.desafioId,
			},
		);
		return registro;
	}

	/// Encola el evento y, si [empujarAhora], lo sube al hub sin esperar el ciclo.
	///
	/// Retorna null si no hay hub; true si el push confirmo envio; false si fallo.
	Future<bool?> _emitirEvento(
		TipoSyncEvento tipo,
		Map<String, Object?> payload, {
		required String claveEntidad,
		bool empujarAhora = false,
	}) async {
		final sync = _syncOrchestrator;
		if (sync == null) {
			return null;
		}
		final evento = SyncEvent(
			id: _idEventoEspejo(tipo, claveEntidad),
			tiendaId: _tiendaId,
			dispositivoId: _dispositivoId,
			tipo: tipo,
			payload: payload,
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		if (!empujarAhora || !sync.tieneHubConfigurado()) {
			await sync.registrarEvento(evento);
			return sync.tieneHubConfigurado() ? false : null;
		}
		try {
			final resultado = await sync.registrarYEmpujar(evento);
			return resultado.exitoso;
		} on Object {
			// La operacion local ya quedo guardada; el ciclo periodico reintenta.
			return false;
		}
	}

	/// Empuje inmediato con tope para la UI (entrada/salida/PIN).
	///
	/// El POST al hub puede tardar hasta [TIMEOUT_HUB_ENVIO_EVENTOS_SEGUNDOS]
	/// (180 s). Si no confirma a tiempo, devolvemos false y el Future del push
	/// sigue en background; el ciclo de 60 s reintenta si hiciera falta.
	Future<bool?> _empujarAsistenciaConTopeUi(
		TipoSyncEvento tipo,
		Map<String, Object?> payload, {
		required String claveEntidad,
	}) async {
		final push = _emitirEvento(
			tipo,
			payload,
			claveEntidad: claveEntidad,
			empujarAhora: true,
		);
		try {
			return await push.timeout(
				const Duration(seconds: 8),
				onTimeout: () => false,
			);
		} on Object {
			return false;
		}
	}

	Future<bool> _intentarSincronizarHub() async {
		final sync = _syncOrchestrator;
		if (sync == null || !sync.tieneHubConfigurado()) {
			return false;
		}
		try {
			await sync.sincronizarCompleto();
			return true;
		} on Object {
			return false;
		}
	}

	/// ID de evento determinístico: reintentos de sync no duplican el evento.
	String _idEventoEspejo(TipoSyncEvento tipo, String claveEntidad) {
		final clave = claveEntidad.trim();
		if (clave.isEmpty) {
			return _generadorId.v4();
		}
		return '${tipo.name}:$clave';
	}
}
