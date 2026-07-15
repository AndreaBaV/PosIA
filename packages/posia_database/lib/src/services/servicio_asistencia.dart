/// Servicio de asistencia con PIN y geocerca.
library;

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
	});

	final DesafioAsistencia desafio;
	final String pinPlano;
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

	/// Genera PIN de 4 digitos visible en laptop admin (TTL 5 min).
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
			expiraEn: DateTime.now().toUtc().add(const Duration(minutes: 5)),
			creadoPor: creadoPor,
			latitud: tienda.latitud,
			longitud: tienda.longitud,
			radioMetros: tienda.radioMetrosAsistencia,
			activo: true,
		);
		await _baseDatos.transaction((tx) async {
			await _asistenciaRepository.desactivarDesafiosTienda(_tiendaId, db: tx);
			await _asistenciaRepository.guardarDesafio(desafio, db: tx);
		});
		await _emitirEvento(
			TipoSyncEvento.attendanceChallengeCreated,
			claveEntidad: desafio.id,
			{
				'id': desafio.id,
				'tiendaId': desafio.tiendaId,
				'expiraEn': desafio.expiraEn.toIso8601String(),
				'latitud': desafio.latitud,
				'longitud': desafio.longitud,
				'radioMetros': desafio.radioMetros,
				'pinHash': desafio.pinHash,
			},
		);
		return DesafioPinGenerado(desafio: desafio, pinPlano: pin);
	}

	/// Registra entrada validando PIN y ubicacion del telefono.
	Future<RegistroAsistencia> registrarEntradaConPin({
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
			throw StateError('No hay PIN de asistencia activo');
		}
		if (!_verificarPin(pin, desafio.pinHash)) {
			throw StateError('PIN incorrecto o expirado');
		}
		_validarUbicacion(
			latitud: latitud,
			longitud: longitud,
			latCentro: desafio.latitud!,
			lonCentro: desafio.longitud!,
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

	/// Registra entrada por geocerca + biometria del telefono.
	Future<RegistroAsistencia> registrarEntradaBiometrica({
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
		await _emitirEvento(
			TipoSyncEvento.attendanceCheckedOut,
			claveEntidad: salida.id,
			{
				'registroId': salida.id,
				'usuarioId': salida.usuarioId,
				'salidaEn': salida.salidaEn!.toIso8601String(),
			},
		);
		return salida;
	}

	Future<List<RegistroAsistencia>> listarEntradasDelDia([DateTime? dia]) async {
		return _asistenciaRepository.listarPorTiendaDia(
			_tiendaId,
			dia ?? DateTime.now().toUtc(),
		);
	}

	Future<DesafioAsistencia?> obtenerDesafioActivo() {
		return _asistenciaRepository.obtenerDesafioActivo(_tiendaId);
	}

	Future<RegistroAsistencia?> obtenerEntradaAbierta(String usuarioId) {
		return _asistenciaRepository.obtenerEntradaAbierta(usuarioId);
	}

	bool _verificarPin(String pin, String pinCredencial) {
		return HasherPin.verificar(pin, pinCredencial);
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
		await _emitirEvento(
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

	Future<void> _emitirEvento(
		TipoSyncEvento tipo,
		Map<String, Object?> payload, {
		required String claveEntidad,
	}) async {
		final sync = _syncOrchestrator;
		if (sync == null) {
			return;
		}
		await sync.registrarEvento(
			SyncEvent(
				id: _idEventoEspejo(tipo, claveEntidad),
				tiendaId: _tiendaId,
				dispositivoId: _dispositivoId,
				tipo: tipo,
				payload: payload,
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
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
