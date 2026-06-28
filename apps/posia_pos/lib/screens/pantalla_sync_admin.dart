/// Estado de sincronizacion en la nube (solo lectura para operacion).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import 'pantalla_instalacion_tecnico.dart';

/// Muestra cola de eventos y permite sync manual; sin editar URL del hub.
class PantallaSyncAdmin extends ConsumerStatefulWidget {
	const PantallaSyncAdmin({super.key});

	@override
	ConsumerState<PantallaSyncAdmin> createState() => _PantallaSyncAdminState();
}

class _PantallaSyncAdminState extends ConsumerState<PantallaSyncAdmin> {
	bool _sincronizando = false;
	String? _mensajeResultado;

	@override
	Widget build(BuildContext context) {
		final estadoAsync = ref.watch(_estadoSyncProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Estado de la nube'),
			),
			body: estadoAsync.when(
				data: (estado) => _ConstruirContenidoSync(
					estado: estado,
					sincronizando: _sincronizando,
					mensajeResultado: _mensajeResultado,
					alSincronizar: _ejecutarSyncManual,
					alReconciliar: _ejecutarReconciliacion,
					alRepararEquipo: _ejecutarReparacionEquipo,
					alReconfigurar: () => abrirInstalacionTecnica(context, ref),
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (error, _) => Center(child: Text(error.toString())),
			),
		);
	}

	Future<void> _ejecutarSyncManual() async {
		setState(() {
			_sincronizando = true;
			_mensajeResultado = null;
		});
		final servicio = await ref.read(servicioAdminProvider.future);
		final resultado = await servicio.sincronizarManual();
		ref.invalidate(_estadoSyncProvider);
		setState(() {
			_sincronizando = false;
			_mensajeResultado = resultado.hubDisponible
				? 'Enviados: ${resultado.eventosEnviados} · Recibidos: ${resultado.eventosRecibidos}'
				: 'Sin conexión al hub o dispositivo en modo offline';
		});
	}

	Future<void> _ejecutarReconciliacion() async {
		setState(() {
			_sincronizando = true;
			_mensajeResultado = null;
		});
		final servicio = await ref.read(servicioAdminProvider.future);
		final resultado = await servicio.reconciliarConHub();
		ref.invalidate(_estadoSyncProvider);
		setState(() {
			_sincronizando = false;
			_mensajeResultado = _mensajeReconciliacion(resultado);
		});
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

	Future<void> _ejecutarReparacionEquipo() async {
		setState(() {
			_sincronizando = true;
			_mensajeResultado = null;
		});
		final servicio = await ref.read(servicioAdminProvider.future);
		final resultado = await servicio.repararSincronizacionUsuarios();
		ref.invalidate(_estadoSyncProvider);
		setState(() {
			_sincronizando = false;
			_mensajeResultado = resultado.hubDisponible
				? 'Reparación: enviados ${resultado.eventosEnviados} · '
					'recibidos ${resultado.eventosRecibidos}. '
					'Revise Admin → Equipo en todos los dispositivos.'
				: 'Sin conexión al hub';
		});
	}
}

final _estadoSyncProvider = FutureProvider<_EstadoPantallaSync>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final estado = await servicio.obtenerEstadoSync();
	final hubUrl = await servicio.obtenerHubUrl();
	return _EstadoPantallaSync(
		estado: estado,
		hubUrl: hubUrl,
	);
});

class _EstadoPantallaSync {
	const _EstadoPantallaSync({
		required this.estado,
		required this.hubUrl,
	});

	final EstadoSyncAdmin estado;
	final String hubUrl;
}

class _ConstruirContenidoSync extends StatelessWidget {
	const _ConstruirContenidoSync({
		required this.estado,
		required this.sincronizando,
		required this.mensajeResultado,
		required this.alSincronizar,
		required this.alReconciliar,
		required this.alRepararEquipo,
		required this.alReconfigurar,
	});

	final _EstadoPantallaSync estado;
	final bool sincronizando;
	final String? mensajeResultado;
	final VoidCallback alSincronizar;
	final VoidCallback alReconciliar;
	final VoidCallback alRepararEquipo;
	final VoidCallback alReconfigurar;

	@override
	Widget build(BuildContext context) {
		final hubActivo = estado.estado.hubConfigurado;
		return Padding(
			padding: const EdgeInsets.all(24.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					const Icon(Icons.cloud_sync, size: 72.0, color: Colors.indigo),
					const SizedBox(height: 16.0),
					Text(
						hubActivo
							? 'Sincronización automática activa cada 60 s.'
							: 'Este dispositivo opera en modo offline.',
						textAlign: TextAlign.center,
						style: Theme.of(context).textTheme.bodyMedium,
					),
					const SizedBox(height: 24.0),
					_FilaEstadoSync(
						icono: Icons.pending_actions,
						etiqueta: 'Pendientes',
						valor: '${estado.estado.eventosPendientes}',
					),
					const SizedBox(height: 12.0),
					_FilaEstadoSync(
						icono: Icons.error_outline,
						etiqueta: 'Con error',
						valor: '${estado.estado.eventosConError}',
					),
					const SizedBox(height: 12.0),
					_FilaEstadoSync(
						icono: hubActivo ? Icons.cloud_done : Icons.cloud_off,
						etiqueta: 'Hub',
						valor: hubActivo ? 'Conectado' : 'No configurado',
					),
					if (estado.hubUrl.isNotEmpty) ...[
						const SizedBox(height: 12.0),
						Card(
							child: ListTile(
								leading: const Icon(Icons.link),
								title: const Text('Servidor'),
								subtitle: Text(
									estado.hubUrl,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
								),
							),
						),
					],
					const Spacer(),
					if (mensajeResultado != null) ...[
						Text(mensajeResultado!, textAlign: TextAlign.center),
						const SizedBox(height: 12.0),
					],
					if (hubActivo)
						SizedBox(
							height: 52.0,
							child: FilledButton.icon(
								onPressed: sincronizando ? null : alSincronizar,
								icon: sincronizando
									? const SizedBox(
										width: 20.0,
										height: 20.0,
										child: CircularProgressIndicator(strokeWidth: 2.0),
									)
									: const Icon(Icons.sync),
								label: Text(sincronizando ? 'Sincronizando...' : 'Sincronizar ahora'),
							),
						),
					if (hubActivo) ...[
						const SizedBox(height: 8.0),
						SizedBox(
							height: 48.0,
							child: OutlinedButton.icon(
								onPressed: sincronizando ? null : alReconciliar,
								icon: const Icon(Icons.cloud_download),
								label: const Text('Reconciliar con la nube'),
							),
						),
						const SizedBox(height: 8.0),
						SizedBox(
							height: 48.0,
							child: OutlinedButton.icon(
								onPressed: sincronizando ? null : alRepararEquipo,
								icon: const Icon(Icons.people_outline),
								label: const Text('Reparar equipo (usuarios)'),
							),
						),
					],
					const SizedBox(height: 8.0),
					TextButton.icon(
						onPressed: alReconfigurar,
						icon: const Icon(Icons.engineering, size: 18.0),
						label: const Text('Reconfigurar conexión (técnico)'),
					),
				],
			),
		);
	}
}

class _FilaEstadoSync extends StatelessWidget {
	const _FilaEstadoSync({
		required this.icono,
		required this.etiqueta,
		required this.valor,
	});

	final IconData icono;
	final String etiqueta;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Card(
			child: ListTile(
				leading: Icon(icono, color: PosiaColors.neutro),
				title: Text(etiqueta),
				trailing: Text(
					valor,
					style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
				),
			),
		);
	}
}
