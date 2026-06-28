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
		required String tenantId,
		required String tiendaId,
		required String dispositivoId,
	}) : _nominaRepository = nominaRepository,
       _asistenciaRepository = asistenciaRepository,
       _empleadoPerfilRepository = empleadoPerfilRepository,
       _usuarioRepository = usuarioRepository,
       _baseDatos = baseDatos,
       _syncOrchestrator = syncOrchestrator,
       _tenantId = tenantId,
       _tiendaId = tiendaId,
       _dispositivoId = dispositivoId;

	final NominaRepository _nominaRepository;
	final AsistenciaRepository _asistenciaRepository;
	final EmpleadoPerfilRepository _empleadoPerfilRepository;
	final UsuarioRepository _usuarioRepository;
	final Database _baseDatos;
	final SyncOrchestrator? _syncOrchestrator;
	final String _tenantId;
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
		final sync = _syncOrchestrator;
		if (sync != null) {
			await sync.registrarEvento(
				SyncEvent(
					id: _generadorId.v4(),
					tenantId: _tenantId,
					tiendaId: _tiendaId,
					dispositivoId: _dispositivoId,
					tipo: TipoSyncEvento.employeeProfileUpserted,
					payload: {
						'usuarioId': usuarioId,
						'tarifaHora': perfil.tarifaHora,
						'tipoPago': perfil.tipoPago,
						'actualizadoEn': perfil.actualizadoEn.toIso8601String(),
					},
					creadoEn: DateTime.now().toUtc(),
					estado: EstadoSyncEvento.pendiente,
				),
			);
		}
	}

	Future<EmpleadoPerfil?> obtenerPerfil(String usuarioId) {
		return _empleadoPerfilRepository.obtenerPorUsuario(usuarioId);
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
				await _nominaRepository.guardarLinea(
					LineaNomina(
						id: _generadorId.v4(),
						periodoId: periodoId,
						usuarioId: usuario.id,
						horasTrabajadas: horas,
						tarifaHora: tarifa,
						montoBruto: bruto,
						montoNeto: bruto,
					),
					db: tx,
				);
			}
		});
		final sync = _syncOrchestrator;
		if (sync != null) {
			await sync.registrarEvento(
				SyncEvent(
					id: _generadorId.v4(),
					tenantId: _tenantId,
					tiendaId: _tiendaId,
					dispositivoId: _dispositivoId,
					tipo: TipoSyncEvento.payrollPeriodClosed,
					payload: {
						'periodoId': periodoId,
						'inicioEn': inicio.toIso8601String(),
						'finEn': fin.toIso8601String(),
						'cerradoPor': cerradoPor,
					},
					creadoEn: DateTime.now().toUtc(),
					estado: EstadoSyncEvento.pendiente,
				),
			);
		}
		return periodo;
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
