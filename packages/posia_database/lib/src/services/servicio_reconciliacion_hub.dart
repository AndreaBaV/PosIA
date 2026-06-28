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
import '../utils/diagnostico_base_local.dart';
import '../utils/limpiador_base_local.dart';

/// Orquesta limpieza local y descarga desde la nube cuando corresponde.
class ServicioReconciliacionHub {
	ServicioReconciliacionHub({
		required Database baseDatos,
		required ConfigRepository configRepository,
		required SyncOrchestrator syncOrchestrator,
		required SyncStateRepository syncStateRepository,
		required TiendaRepository tiendaRepository,
		required String tenantId,
	}) : _baseDatos = baseDatos,
	     _configRepository = configRepository,
	     _syncOrchestrator = syncOrchestrator,
	     _syncStateRepository = syncStateRepository,
	     _tiendaRepository = tiendaRepository,
	     _tenantId = tenantId;

	final Database _baseDatos;
	final ConfigRepository _configRepository;
	final SyncOrchestrator _syncOrchestrator;
	final SyncStateRepository _syncStateRepository;
	final TiendaRepository _tiendaRepository;
	final String _tenantId;

	/// Limpia placeholders, compara con la nube y sincroniza.
	Future<ResultadoReconciliacionHub> reconciliar() async {
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
		final hubOk = await clienteHub.verificarSalud();
		if (!hubOk) {
			return const ResultadoReconciliacionHub(
				accion: AccionReconciliacionHub.omitida,
				hubDisponible: false,
			);
		}

		final ejemploEliminado = await LimpiadorBaseLocal.eliminarDatosEjemplo(
			_baseDatos,
		);
		var diagnostico = await DiagnosticoBaseLocal.evaluar(_baseDatos);
		final tiendasRemotas = await clienteHub.obtenerTiendasPorTenant(_tenantId);
		final tiendasLocales = await _tiendaRepository.listarTodas();
		final tiendasCoinciden = _tiendasCoinciden(tiendasRemotas, tiendasLocales);
		final hubTieneDatos = tiendasRemotas.isNotEmpty ||
			await _hubTieneEventos(clienteHub);

		var accion = AccionReconciliacionHub.incremental;
		var limpioOperativos = false;
		var cursorReiniciado = false;

		final requierePullCompleto = hubTieneDatos &&
			diagnostico.tieneDatosReales &&
			!tiendasCoinciden;

		if (requierePullCompleto) {
			final eraReconstruccion =
				diagnostico.tieneDatosReales && !tiendasCoinciden;
			await _syncOrchestrator.sincronizarPendientes();
			await LimpiadorBaseLocal.vaciarDatosOperativos(_baseDatos);
			limpioOperativos = true;
			await _syncStateRepository.guardarCursorHub(0);
			cursorReiniciado = true;
			accion = eraReconstruccion
				? AccionReconciliacionHub.reconstruidaDesdeNube
				: AccionReconciliacionHub.pullCompleto;
		}

		final sync = cursorReiniciado
			? await _syncOrchestrator.sincronizarDesdeOrigen()
			: await _syncOrchestrator.sincronizarCompleto();

		if (tiendasRemotas.isNotEmpty) {
			for (final remota in tiendasRemotas) {
				await _tiendaRepository.guardar(
					Tienda(
						id: remota.id,
						nombre: remota.nombre,
						direccion: remota.direccion,
						activa: remota.activa,
					),
				);
			}
		}

		return ResultadoReconciliacionHub(
			accion: accion,
			hubDisponible: sync.hubDisponible,
			datosEjemploEliminados: ejemploEliminado,
			datosOperativosLimpiados: limpioOperativos,
			cursorReiniciado: cursorReiniciado,
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

	Future<bool> _hubTieneEventos(HubSyncClient clienteHub) async {
		final resultado = await clienteHub.obtenerEventos(
			tenantId: _tenantId,
			desdeSeq: 0,
		);
		return resultado.exitoso &&
			(resultado.eventos.isNotEmpty || resultado.ultimoSeq > 0);
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
