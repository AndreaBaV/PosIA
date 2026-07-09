/// Estado global de sincronizacion manual (sobrevive cambios de pantalla).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_sync/posia_sync.dart';

import 'admin_providers.dart';

/// Estado visible de una sincronizacion en curso o recien terminada.
class EstadoSyncUi {
	const EstadoSyncUi({
		required this.activo,
		this.progreso,
		this.mensajeResultado,
		this.ultimoResultado,
	});

	const EstadoSyncUi.inactivo()
		: activo = false,
		  progreso = null,
		  mensajeResultado = null,
		  ultimoResultado = null;

	final bool activo;
	final ProgresoSync? progreso;
	final String? mensajeResultado;
	final ResultadoSync? ultimoResultado;
}

/// Notifier global: el progreso persiste aunque se salga de la pantalla sync.
class SyncProgresoNotifier extends Notifier<EstadoSyncUi> {
	@override
	EstadoSyncUi build() => const EstadoSyncUi.inactivo();

	void _reportar(ProgresoSync progreso) {
		state = EstadoSyncUi(
			activo: true,
			progreso: progreso,
			mensajeResultado: null,
			ultimoResultado: state.ultimoResultado,
		);
	}

	Future<ResultadoSync> sincronizarManual() async {
		if (state.activo) {
			return state.ultimoResultado ??
				const ResultadoSync(
					eventosEnviados: 0,
					eventosRecibidos: 0,
					hubDisponible: false,
				);
		}
		_reportar(
			const ProgresoSync(
				fase: FaseProgresoSync.preparar,
				indice: 0,
				total: 0,
				mensaje: 'Iniciando sincronización…',
			),
		);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final resultado = await servicio.sincronizarManual(alProgreso: _reportar);
			final mensaje = resultado.hubDisponible
				? 'Enviados: ${resultado.eventosEnviados} · '
					'Recibidos: ${resultado.eventosRecibidos}'
				: 'Sin conexión al hub o dispositivo en modo offline';
			state = EstadoSyncUi(
				activo: false,
				progreso: null,
				mensajeResultado: mensaje,
				ultimoResultado: resultado,
			);
			ref.invalidate(_estadoSyncColaProvider);
			ref.invalidate(rolesPersonalizadosAdminProvider);
			ref.invalidate(rolesPersonalizadosActivosProvider);
			return resultado;
		} on Object catch (error) {
			state = EstadoSyncUi(
				activo: false,
				mensajeResultado: 'Error de sincronización: $error',
				ultimoResultado: state.ultimoResultado,
			);
			rethrow;
		}
	}

	Future<ResultadoReconciliacionHub> reconciliarConHub() async {
		if (state.activo) {
			throw StateError('Ya hay una sincronización en curso');
		}
		_reportar(
			const ProgresoSync(
				fase: FaseProgresoSync.preparar,
				indice: 0,
				total: 0,
				mensaje: 'Reconciliando con la nube…',
			),
		);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final resultado = await servicio.reconciliarConHub(alProgreso: _reportar);
			state = EstadoSyncUi(
				activo: false,
				mensajeResultado: _mensajeReconciliacion(resultado),
				ultimoResultado: resultado.sync,
			);
			ref.invalidate(_estadoSyncColaProvider);
			return resultado;
		} on Object catch (error) {
			state = EstadoSyncUi(
				activo: false,
				mensajeResultado: 'Error de reconciliación: $error',
			);
			rethrow;
		}
	}

	Future<ResultadoSync> repararEquipo() async {
		if (state.activo) {
			return state.ultimoResultado ??
				const ResultadoSync(
					eventosEnviados: 0,
					eventosRecibidos: 0,
					hubDisponible: false,
				);
		}
		_reportar(
			const ProgresoSync(
				fase: FaseProgresoSync.preparar,
				indice: 0,
				total: 0,
				mensaje: 'Reparando equipo y roles…',
			),
		);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final resultado = await servicio.repararSincronizacionUsuarios(
				alProgreso: _reportar,
			);
			final mensaje = resultado.hubDisponible
				? 'Reparación: enviados ${resultado.eventosEnviados} · '
					'recibidos ${resultado.eventosRecibidos}. '
					'Revise Admin → Equipo en todos los dispositivos.'
				: 'Sin conexión al hub';
			state = EstadoSyncUi(
				activo: false,
				mensajeResultado: mensaje,
				ultimoResultado: resultado,
			);
			ref.invalidate(_estadoSyncColaProvider);
			ref.invalidate(rolesPersonalizadosAdminProvider);
			ref.invalidate(rolesPersonalizadosActivosProvider);
			return resultado;
		} on Object catch (error) {
			state = EstadoSyncUi(
				activo: false,
				mensajeResultado: 'Error de reparación: $error',
			);
			rethrow;
		}
	}

	void limpiarMensaje() {
		if (state.mensajeResultado == null) {
			return;
		}
		state = EstadoSyncUi(
			activo: state.activo,
			progreso: state.progreso,
			ultimoResultado: state.ultimoResultado,
		);
	}

	String _mensajeReconciliacion(ResultadoReconciliacionHub resultado) {
		if (!resultado.hubDisponible) {
			return 'Sin conexión al hub o dispositivo en modo offline';
		}
		final accion = switch (resultado.accion) {
			AccionReconciliacionHub.pullCompleto =>
				'Base local vacía: datos descargados desde la nube.',
			AccionReconciliacionHub.reconstruidaDesdeNube =>
				'Datos locales no coincidían con la nube: base reconstruida.',
			AccionReconciliacionHub.incremental =>
				resultado.tiendasCoinciden
					? 'Datos locales verificados con la nube.'
					: 'Sincronización incremental completada.',
			AccionReconciliacionHub.omitida => 'Reconciliación omitida.',
		};
		return '$accion Enviados: ${resultado.sync.eventosEnviados} · '
			'Recibidos: ${resultado.sync.eventosRecibidos}';
	}
}

final syncProgresoProvider =
	NotifierProvider<SyncProgresoNotifier, EstadoSyncUi>(
		SyncProgresoNotifier.new,
	);

/// Cola de sync para la pantalla admin (compartida).
final estadoSyncColaProvider = FutureProvider<EstadoSyncAdmin>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerEstadoSync();
});

/// Alias interno para invalidar desde el notifier.
final _estadoSyncColaProvider = estadoSyncColaProvider;

final estadoSyncPantallaProvider =
	FutureProvider<({EstadoSyncAdmin estado, String hubUrl})>((ref) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final estado = await servicio.obtenerEstadoSync();
		final hubUrl = await servicio.obtenerHubUrl();
		return (estado: estado, hubUrl: hubUrl);
	});
