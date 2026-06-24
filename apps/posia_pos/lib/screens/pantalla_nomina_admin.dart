/// Nomina por horas trabajadas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaNominaAdmin extends ConsumerWidget {
	const PantallaNominaAdmin({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final periodosAsync = ref.watch(_periodosNominaProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Nómina'),
				actions: [
					IconButton(
						icon: const Icon(Icons.calculate),
						onPressed: () => _cerrarPeriodo(context, ref),
					),
				],
			),
			body: periodosAsync.when(
				data: (periodos) => periodos.isEmpty
					? const Center(child: Text('Sin periodos. Calcule la nómina semanal.'))
					: ListView.builder(
						itemCount: periodos.length,
						itemBuilder: (context, i) {
							final p = periodos[i];
							return ListTile(
								title: Text(
									'${p.inicioEn.toLocal().toString().substring(0, 10)} — '
									'${p.finEn.toLocal().toString().substring(0, 10)}',
								),
								subtitle: Text(p.estado),
								trailing: IconButton(
									icon: const Icon(Icons.download),
									onPressed: () => _exportar(context, ref, p.id),
								),
								onTap: () => _verDetalle(context, ref, p.id),
							);
						},
					),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _cerrarPeriodo(BuildContext context, WidgetRef ref) async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		final fin = DateTime.now().toUtc();
		final inicio = fin.subtract(const Duration(days: 7));
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final nomina = contenedor.servicioNomina;
		if (nomina == null) {
			return;
		}
		await nomina.cerrarPeriodo(
			inicio: inicio,
			fin: fin,
			cerradoPor: usuario.id,
		);
		ref.invalidate(_periodosNominaProvider);
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Periodo calculado')),
			);
		}
	}

	Future<void> _exportar(BuildContext context, WidgetRef ref, String periodoId) async {
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final csv = await contenedor.servicioNomina?.exportarPeriodoCsv(periodoId);
		if (csv == null || !context.mounted) {
			return;
		}
		await Clipboard.setData(ClipboardData(text: csv));
		if (!context.mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('CSV copiado al portapapeles')),
		);
	}

	Future<void> _verDetalle(
		BuildContext context,
		WidgetRef ref,
		String periodoId,
	) async {
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final nomina = contenedor.servicioNomina;
		if (nomina == null) {
			return;
		}
		final lineas = await nomina.listarLineasPeriodo(periodoId);
		final servicio = await ref.read(servicioAdminProvider.future);
		final usuarios = await servicio.listarUsuarios();
		final nombres = {for (final u in usuarios) u.id: u.nombre};
		if (!context.mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Detalle nómina'),
				content: SizedBox(
					width: 400,
					child: lineas.isEmpty
						? const Text('Sin líneas')
						: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: lineas.map((l) {
									return ListTile(
										title: Text(nombres[l.usuarioId] ?? l.usuarioId),
										subtitle: Text(
											'${l.horasTrabajadas.toStringAsFixed(1)} h × '
											'${formatearMoneda(l.tarifaHora)}',
										),
										trailing: Text(formatearMoneda(l.montoNeto)),
									);
								}).toList(),
							),
						),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
				],
			),
		);
	}
}

final _periodosNominaProvider = FutureProvider<List<PeriodoNomina>>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioNomina?.listarPeriodos() ?? [];
});
