/// Servicio de calculo de nomina por horas trabajadas.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../repositories/asistencia_repository.dart';
import '../repositories/empleado_perfil_repository.dart';
import '../repositories/nomina_repository.dart';
import '../repositories/usuario_repository.dart';

/// Calcula y cierra periodos de nomina.
class ServicioNomina {
	ServicioNomina({
		required NominaRepository nominaRepository,
		required AsistenciaRepository asistenciaRepository,
		required EmpleadoPerfilRepository empleadoPerfilRepository,
		required UsuarioRepository usuarioRepository,
		required Database baseDatos,
		SyncOrchestrator? syncOrchestrator,
		required String tiendaId,
		required String dispositivoId,
	}) : _nominaRepository = nominaRepository,
       _asistenciaRepository = asistenciaRepository,
       _empleadoPerfilRepository = empleadoPerfilRepository,
       _usuarioRepository = usuarioRepository,
       _baseDatos = baseDatos,
       _syncOrchestrator = syncOrchestrator,
       _tiendaId = tiendaId,
       _dispositivoId = dispositivoId;

	final NominaRepository _nominaRepository;
	final AsistenciaRepository _asistenciaRepository;
	final EmpleadoPerfilRepository _empleadoPerfilRepository;
	final UsuarioRepository _usuarioRepository;
	final Database _baseDatos;
	final SyncOrchestrator? _syncOrchestrator;
	final String _tiendaId;
	final String _dispositivoId;
	final Uuid _generadorId = const Uuid();

	Future<void> guardarTarifaHora(String usuarioId, double tarifaHora) async {
		final perfil = EmpleadoPerfil(
			usuarioId: usuarioId,
			tarifaHora: redondearMonto(tarifaHora),
			tipoPago: 'por_hora',
			actualizadoEn: DateTime.now().toUtc(),
		);
		await _empleadoPerfilRepository.guardar(perfil);
		await _publicarPerfil(perfil);
	}

	Future<EmpleadoPerfil?> obtenerPerfil(String usuarioId) {
		return _empleadoPerfilRepository.obtenerPorUsuario(usuarioId);
	}

	Future<List<EmpleadoPerfil>> listarPerfiles() {
		return _empleadoPerfilRepository.listarTodos();
	}

	/// Reencola perfiles locales para proyeccion a Neon (`employee_profiles`).
	///
	/// Solo encola; el push ocurre en el siguiente [sincronizarPendientes] /
	/// [sincronizarManual] del orquestador.
	Future<int> reencolarPerfilesParaSync() async {
		final perfiles = await _empleadoPerfilRepository.listarTodos();
		for (final perfil in perfiles) {
			await _publicarPerfil(perfil, empujarAhora: false);
		}
		return perfiles.length;
	}

	Future<void> _publicarPerfil(
		EmpleadoPerfil perfil, {
		bool empujarAhora = true,
	}) async {
		final sync = _syncOrchestrator;
		if (sync == null || !sync.tieneHubConfigurado()) {
			return;
		}
		final eventoId = 'employeeProfileUpserted:${perfil.usuarioId}';
		await sync.registrarEvento(
			SyncEvent(
				id: eventoId,
				tiendaId: _tiendaId,
				dispositivoId: _dispositivoId,
				tipo: TipoSyncEvento.employeeProfileUpserted,
				payload: {
					'usuarioId': perfil.usuarioId,
					'tarifaHora': perfil.tarifaHora,
					'tipoPago': perfil.tipoPago,
					'actualizadoEn': perfil.actualizadoEn.toIso8601String(),
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
		if (empujarAhora) {
			await sync.sincronizarEventosPorIds([eventoId]);
		}
	}

	Future<List<PeriodoNomina>> listarPeriodos() {
		return _nominaRepository.listarPeriodos(tiendaId: _tiendaId);
	}

	/// Calcula horas desde registros de asistencia cerrados.
	double calcularHorasTrabajadas(List<RegistroAsistencia> registros) {
		var totalHoras = 0.0;
		for (final registro in registros) {
			final salida = registro.salidaEn;
			if (salida == null) {
				continue;
			}
			final duracion = salida.difference(registro.entradaEn);
			totalHoras += duracion.inMinutes / 60.0;
		}
		return totalHoras;
	}

	/// Cierra periodo y genera lineas por empleado con tarifa configurada.
	Future<PeriodoNomina> cerrarPeriodo({
		required DateTime inicio,
		required DateTime fin,
		required String cerradoPor,
	}) async {
		final periodoId = _generadorId.v4();
		final periodo = PeriodoNomina(
			id: periodoId,
			tiendaId: _tiendaId,
			inicioEn: inicio,
			finEn: fin,
			estado: 'cerrado',
			cerradoEn: DateTime.now().toUtc(),
			cerradoPor: cerradoPor,
		);
		final lineasPayload = <Map<String, Object?>>[];
		await _baseDatos.transaction((tx) async {
			await _nominaRepository.guardarPeriodo(periodo, db: tx);
			final usuarios = await _usuarioRepository.listarActivos();
			for (final usuario in usuarios) {
				if (usuario.rol == RolUsuario.administrador) {
					continue;
				}
				final perfil = await _empleadoPerfilRepository.obtenerPorUsuario(
					usuario.id,
				);
				final tarifa = perfil?.tarifaHora ?? 0.0;
				if (tarifa <= 0) {
					continue;
				}
				final registros = await _asistenciaRepository.listarPorUsuarioRango(
					usuarioId: usuario.id,
					inicio: inicio,
					fin: fin,
				);
				final horas = calcularHorasTrabajadas(registros);
				if (horas <= 0) {
					continue;
				}
				final bruto = redondearMonto(horas * tarifa);
				final linea = LineaNomina(
					id: _generadorId.v4(),
					periodoId: periodoId,
					usuarioId: usuario.id,
					horasTrabajadas: horas,
					tarifaHora: tarifa,
					montoBruto: bruto,
					montoNeto: bruto,
				);
				await _nominaRepository.guardarLinea(linea, db: tx);
				lineasPayload.add({
					'id': linea.id,
					'usuarioId': linea.usuarioId,
					'horasTrabajadas': linea.horasTrabajadas,
					'tarifaHora': linea.tarifaHora,
					'montoBruto': linea.montoBruto,
					'montoNeto': linea.montoNeto,
				});
			}
		});
		final sync = _syncOrchestrator;
		if (sync != null && sync.tieneHubConfigurado()) {
			final eventoId = 'payrollPeriodClosed:$periodoId';
			await sync.registrarEvento(
				SyncEvent(
					id: eventoId,
					tiendaId: _tiendaId,
					dispositivoId: _dispositivoId,
					tipo: TipoSyncEvento.payrollPeriodClosed,
					payload: {
						'periodoId': periodoId,
						'tiendaId': _tiendaId,
						'inicioEn': inicio.toIso8601String(),
						'finEn': fin.toIso8601String(),
						'cerradoPor': cerradoPor,
						'cerradoEn': periodo.cerradoEn?.toIso8601String(),
						'estado': periodo.estado,
						'lineas': lineasPayload,
					},
					creadoEn: DateTime.now().toUtc(),
					estado: EstadoSyncEvento.pendiente,
				),
			);
			await sync.sincronizarEventosPorIds([eventoId]);
		}
		return periodo;
	}

	/// Reencola periodos de nomina locales hacia Neon.
	Future<int> reencolarPeriodosParaSync() async {
		final periodos = await listarPeriodos();
		final sync = _syncOrchestrator;
		if (sync == null || !sync.tieneHubConfigurado()) {
			return 0;
		}
		for (final periodo in periodos) {
			final lineas = await listarLineasPeriodo(periodo.id);
			final eventoId = 'payrollPeriodClosed:${periodo.id}';
			await sync.registrarEvento(
				SyncEvent(
					id: eventoId,
					tiendaId: periodo.tiendaId ?? _tiendaId,
					dispositivoId: _dispositivoId,
					tipo: TipoSyncEvento.payrollPeriodClosed,
					payload: {
						'periodoId': periodo.id,
						'tiendaId': periodo.tiendaId ?? _tiendaId,
						'inicioEn': periodo.inicioEn.toIso8601String(),
						'finEn': periodo.finEn.toIso8601String(),
						'cerradoPor': periodo.cerradoPor,
						'cerradoEn': periodo.cerradoEn?.toIso8601String(),
						'estado': periodo.estado,
						'lineas': [
							for (final linea in lineas)
								{
									'id': linea.id,
									'usuarioId': linea.usuarioId,
									'horasTrabajadas': linea.horasTrabajadas,
									'tarifaHora': linea.tarifaHora,
									'montoBruto': linea.montoBruto,
									'montoNeto': linea.montoNeto,
								},
						],
					},
					creadoEn: DateTime.now().toUtc(),
					estado: EstadoSyncEvento.pendiente,
				),
			);
		}
		return periodos.length;
	}

	Future<List<LineaNomina>> listarLineasPeriodo(String periodoId) {
		return _nominaRepository.listarLineasPeriodo(periodoId);
	}

	/// Exporta lineas a CSV para contabilidad.
	Future<String> exportarPeriodoCsv(String periodoId) async {
		final lineas = await _nominaRepository.listarLineasPeriodo(periodoId);
		final buffer = StringBuffer('Empleado,Horas,Tarifa,Bruto,Neto\n');
		for (final linea in lineas) {
			final usuario = await _usuarioRepository.obtenerPorId(linea.usuarioId);
			final nombre = usuario?.nombre ?? linea.usuarioId;
			buffer.writeln(
				'$nombre,${linea.horasTrabajadas.toStringAsFixed(2)},'
				'${linea.tarifaHora.toStringAsFixed(2)},'
				'${linea.montoBruto.toStringAsFixed(2)},'
				'${linea.montoNeto.toStringAsFixed(2)}',
			);
		}
		return buffer.toString();
	}
}
