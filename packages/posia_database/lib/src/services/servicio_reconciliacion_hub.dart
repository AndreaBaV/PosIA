/// Reconcilia SQLite local con el hub: limpia placeholders y alinea datos.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

import '../models/resultado_reconciliacion_hub.dart';
import '../repositories/config_repository.dart';
import '../repositories/sync_state_repository.dart';
import '../repositories/tienda_repository.dart';
import '../seed/placeholders_ejemplo.dart';
import '../utils/limpiador_base_local.dart';

class ServicioReconciliacionHub {
	ServicioReconciliacionHub({
		required Database baseDatos,
		required ConfigRepository configRepository,
		required SyncOrchestrator syncOrchestrator,
		required SyncStateRepository syncStateRepository,
		required TiendaRepository tiendaRepository,
	}) : _baseDatos = baseDatos,
	     _configRepository = configRepository,
	     _syncOrchestrator = syncOrchestrator,
	     _syncStateRepository = syncStateRepository,
	     _tiendaRepository = tiendaRepository;

	final Database _baseDatos;
	final ConfigRepository _configRepository;
	final SyncOrchestrator _syncOrchestrator;
	final SyncStateRepository _syncStateRepository;
	final TiendaRepository _tiendaRepository;

	/// Reconstruye la base local desde Neon (fuente de verdad).
	///
	/// Empuja pendientes operativos, vacía datos locales, reinicia el cursor
	/// y descarga el historial completo. La salud del hub no aborta el flujo
	/// (igual que el orquestador): si hay red, se intenta el pull.
	Future<ResultadoReconciliacionHub> reconciliar({
		ReporteProgresoSync? alProgreso,
	}) async {
		if (!_syncOrchestrator.tieneHubConfigurado()) {
			return const ResultadoReconciliacionHub(
				accion: AccionReconciliacionHub.omitida,
				hubDisponible: false,
			);
		}
		final clienteHub = await _crearClienteHub();
		if (clienteHub == null) {
			return const ResultadoReconciliacionHub(
				accion: AccionReconciliacionHub.omitida,
				hubDisponible: false,
			);
		}

		final ejemploEliminado = await LimpiadorBaseLocal.eliminarDatosEjemplo(
			_baseDatos,
		);
		final tiendasRemotas = await clienteHub.obtenerTiendas();
		final tiendasLocales = await _tiendaRepository.listarTodas();
		final tiendasCoinciden = _tiendasCoinciden(tiendasRemotas, tiendasLocales);

		alProgreso?.call(
			const ProgresoSync(
				fase: FaseProgresoSync.enviar,
				indice: 0,
				total: 0,
				mensaje: 'Enviando cambios locales antes de reconstruir…',
			),
		);
		await _syncOrchestrator.sincronizarPendientes(alProgreso: alProgreso);

		alProgreso?.call(
			const ProgresoSync(
				fase: FaseProgresoSync.preparar,
				indice: 0,
				total: 0,
				mensaje: 'Limpiando base local…',
			),
		);
		await LimpiadorBaseLocal.vaciarDatosOperativos(_baseDatos);
		await _syncStateRepository.guardarCursorHub(0);

		if (tiendasRemotas.isNotEmpty) {
			for (final remota in tiendasRemotas) {
				await _tiendaRepository.fusionarRemota(
					Tienda(
						id: remota.id,
						nombre: remota.nombre,
						direccion: remota.direccion,
						activa: remota.activa,
						latitud: remota.latitud,
						longitud: remota.longitud,
						radioMetrosAsistencia: remota.radioMetrosAsistencia,
					),
				);
			}
		}

		final sync = await _syncOrchestrator.sincronizarDesdeOrigen(
			alProgreso: alProgreso,
		);

		return ResultadoReconciliacionHub(
			accion: AccionReconciliacionHub.reconstruidaDesdeNube,
			hubDisponible: sync.hubDisponible,
			datosEjemploEliminados: ejemploEliminado,
			datosOperativosLimpiados: true,
			cursorReiniciado: true,
			tiendasCoinciden: tiendasCoinciden,
			sync: sync,
		);
	}

	Future<HubSyncClient?> _crearClienteHub() async {
		final hubUrl = await _configRepository.obtenerHubUrl();
		if (hubUrl == null || hubUrl.isEmpty) {
			return null;
		}
		final claveApi = await _configRepository.obtenerValor(claveConfigHubApiKey);
		return HubSyncClient(urlBase: hubUrl, claveApi: claveApi);
	}

	bool _tiendasCoinciden(List<TiendaHub> remotas, List<Tienda> locales) {
		if (remotas.isEmpty) {
			return true;
		}
		final idsRemotos = remotas.map((t) => t.id).toSet();
		final idsLocales = locales
			.where((t) => t.id != IdsEjemplo.tienda)
			.map((t) => t.id)
			.toSet();
		if (idsLocales.isEmpty) {
			return false;
		}
		return idsRemotos.length == idsLocales.length &&
			idsRemotos.containsAll(idsLocales);
	}
}
