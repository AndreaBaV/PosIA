/// Estado de sincronizacion en la nube (solo lectura para operacion).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/sync_providers.dart';
import 'pantalla_instalacion_tecnico.dart';

/// Muestra cola de eventos y permite sync manual; sin editar URL del hub.
class PantallaSyncAdmin extends ConsumerWidget {
	const PantallaSyncAdmin({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final estadoAsync = ref.watch(estadoSyncPantallaProvider);
		final syncUi = ref.watch(syncProgresoProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Estado de la nube'),
			),
			body: estadoAsync.when(
				data: (datos) => _ConstruirContenidoSync(
					estado: datos.estado,
					hubUrl: datos.hubUrl,
					syncUi: syncUi,
					alSincronizar: () =>
						ref.read(syncProgresoProvider.notifier).sincronizarManual(),
					alReconciliar: () =>
						ref.read(syncProgresoProvider.notifier).reconciliarConHub(),
					alRepararEquipo: () =>
						ref.read(syncProgresoProvider.notifier).repararEquipo(),
					alResubirCatalogo: () =>
						ref.read(syncProgresoProvider.notifier).resubirCatalogo(),
					alDescartarColaCatalogo: () =>
						_confirmarDescartarColaCatalogo(context, ref),
					alReconfigurar: () => abrirInstalacionTecnica(context, ref),
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (error, _) => Center(child: Text(error.toString())),
			),
		);
	}

	Future<void> _confirmarDescartarColaCatalogo(
		BuildContext context,
		WidgetRef ref,
	) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				icon: const Icon(Icons.warning_amber, color: PosiaColors.cancelar),
				title: const Text('Descartar catálogo en cola'),
				content: const Text(
					'Elimina de la cola de este dispositivo los eventos de catálogo '
					'(productos, categorías, precios, etc.) pendientes o con error. '
					'Úsalo solo si la cola quedó atorada con reencolados masivos.\n\n'
					'No borra ventas, compras, movimientos, asistencia ni nómina sin '
					'subir. Si hiciste una edición de catálogo muy reciente que aún no '
					'se sincronizó, vuelve a hacerla después de esto.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Descartar'),
					),
				],
			),
		);
		if (confirmar == true) {
			await ref.read(syncProgresoProvider.notifier).descartarCatalogoEnCola();
		}
	}
}

class _ConstruirContenidoSync extends StatelessWidget {
	const _ConstruirContenidoSync({
		required this.estado,
		required this.hubUrl,
		required this.syncUi,
		required this.alSincronizar,
		required this.alReconciliar,
		required this.alRepararEquipo,
		required this.alResubirCatalogo,
		required this.alDescartarColaCatalogo,
		required this.alReconfigurar,
	});

	final EstadoSyncAdmin estado;
	final String hubUrl;
	final EstadoSyncUi syncUi;
	final VoidCallback alSincronizar;
	final VoidCallback alReconciliar;
	final VoidCallback alRepararEquipo;
	final VoidCallback alResubirCatalogo;
	final VoidCallback alDescartarColaCatalogo;
	final VoidCallback alReconfigurar;

	@override
	Widget build(BuildContext context) {
		final hubActivo = estado.hubConfigurado;
		final sincronizando = syncUi.activo;
		final progreso = syncUi.progreso;
		final mensajeResultado = syncUi.mensajeResultado;

		return SingleChildScrollView(
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
					if (sincronizando && progreso != null) ...[
						const SizedBox(height: 20.0),
						_BarraProgresoSync(progreso: progreso),
					],
					const SizedBox(height: 24.0),
					_FilaEstadoSync(
						icono: Icons.pending_actions,
						etiqueta: 'Pendientes',
						valor: '${estado.eventosPendientes}',
					),
					const SizedBox(height: 12.0),
					_FilaEstadoSync(
						icono: Icons.error_outline,
						etiqueta: 'Con error',
						valor: '${estado.eventosConError}',
					),
					const SizedBox(height: 12.0),
					_FilaEstadoSync(
						icono: hubActivo ? Icons.cloud_done : Icons.cloud_off,
						etiqueta: 'Hub',
						valor: hubActivo ? 'Conectado' : 'No configurado',
					),
					if (hubUrl.isNotEmpty) ...[
						const SizedBox(height: 12.0),
						Card(
							child: ListTile(
								leading: const Icon(Icons.link),
								title: const Text('Servidor'),
								subtitle: Text(
									hubUrl,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
								),
							),
						),
					],
					const SizedBox(height: 28.0),
					if (mensajeResultado != null) ...[
						Text(mensajeResultado, textAlign: TextAlign.center),
						const SizedBox(height: 12.0),
					],
					if (sincronizando)
						Text(
							'Puede cambiar de pestaña; la sincronización continúa en segundo plano.',
							textAlign: TextAlign.center,
							style: Theme.of(context).textTheme.bodySmall?.copyWith(
								color: Colors.grey.shade700,
							),
						),
					if (sincronizando) const SizedBox(height: 12.0),
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
								label: Text(
									sincronizando ? 'Sincronizando…' : 'Sincronizar ahora',
								),
							),
						),
					if (hubActivo) ...[
						const SizedBox(height: 24.0),
						Align(
							alignment: Alignment.centerLeft,
							child: Text(
								'Herramientas de recuperación',
								style: Theme.of(context).textTheme.titleSmall?.copyWith(
									fontWeight: FontWeight.bold,
								),
							),
						),
						const SizedBox(height: 4.0),
						Text(
							'Úsalas solo si algo se ve incompleto o atorado. Para el día a día '
							'basta con "Sincronizar ahora".',
							style: Theme.of(context).textTheme.bodySmall?.copyWith(
								color: Colors.grey.shade700,
							),
						),
						const SizedBox(height: 8.0),
						Card(
							child: ListTile(
								leading: const Icon(Icons.cloud_download),
								title: const Text('Descargar todo de la nube'),
								subtitle: const Text(
									'Rehace el catálogo de este equipo desde la nube. Úsalo si aquí '
									'faltan productos o categorías.',
								),
								trailing: const Icon(Icons.chevron_right),
								isThreeLine: true,
								onTap: sincronizando ? null : alReconciliar,
							),
						),
						Card(
							child: ListTile(
								leading: const Icon(Icons.people_outline),
								title: const Text('Reparar usuarios, roles y permisos'),
								subtitle: const Text(
									'Vuelve a bajar el equipo y sus permisos desde la nube.',
								),
								trailing: const Icon(Icons.chevron_right),
								onTap: sincronizando ? null : alRepararEquipo,
							),
						),
						Card(
							child: ListTile(
								leading: const Icon(Icons.cloud_upload),
								title: const Text('Resubir MI catálogo a la nube'),
								subtitle: const Text(
									'Envía el catálogo de este equipo a la nube. Úsalo solo desde el '
									'equipo que tiene el catálogo correcto.',
								),
								trailing: const Icon(Icons.chevron_right),
								isThreeLine: true,
								onTap: sincronizando ? null : alResubirCatalogo,
							),
						),
						Card(
							child: ListTile(
								leading: Icon(
									Icons.delete_sweep_outlined,
									color: PosiaColors.cancelar,
								),
								title: const Text('Vaciar catálogo atorado en la cola'),
								subtitle: const Text(
									'Descarta catálogo pendiente o con error en la cola. No borra '
									'ventas, compras ni movimientos.',
								),
								trailing: const Icon(Icons.chevron_right),
								isThreeLine: true,
								onTap: sincronizando ? null : alDescartarColaCatalogo,
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

class _BarraProgresoSync extends StatelessWidget {
	const _BarraProgresoSync({required this.progreso});

	final ProgresoSync progreso;

	@override
	Widget build(BuildContext context) {
		final tienePorcentaje = progreso.tienePorcentaje;
		final porcentaje = progreso.porcentaje;
		return Card(
			color: Colors.indigo.withValues(alpha: 0.06),
			child: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							progreso.mensaje,
							style: Theme.of(context).textTheme.titleSmall,
						),
						const SizedBox(height: 12.0),
						if (tienePorcentaje) ...[
							LinearProgressIndicator(
								value: progreso.fraccion ?? 0,
								minHeight: 8.0,
								borderRadius: BorderRadius.circular(4.0),
							),
							const SizedBox(height: 8.0),
							Text(
								'$porcentaje %',
								textAlign: TextAlign.center,
								style: const TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 16.0,
								),
							),
						] else
							const LinearProgressIndicator(minHeight: 8.0),
					],
				),
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
