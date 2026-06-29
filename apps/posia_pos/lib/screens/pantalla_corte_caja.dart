/// Pantalla de apertura y cierre de turno de caja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaCorteCaja extends ConsumerStatefulWidget {
	const PantallaCorteCaja({super.key});

	@override
	ConsumerState<PantallaCorteCaja> createState() => _PantallaCorteCajaState();
}

class _PantallaCorteCajaState extends ConsumerState<PantallaCorteCaja> {
	final _fondoController = TextEditingController(text: '500');

	@override
	void dispose() {
		_fondoController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final turnoAsync = ref.watch(_turnoProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Corte de caja')),
			body: turnoAsync.when(
				data: (turno) {
					if (turno == null) {
						return Padding(
							padding: const EdgeInsets.all(24.0),
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									const Icon(Icons.lock_open, size: 64.0, color: PosiaColors.cobrar),
									const SizedBox(height: 16.0),
									const Text('No hay turno abierto'),
									const SizedBox(height: 24.0),
									TextField(
										controller: _fondoController,
										keyboardType: TextInputType.number,
										decoration: const InputDecoration(
											labelText: 'Fondo inicial (MXN)',
											border: OutlineInputBorder(),
										),
									),
									const SizedBox(height: 16.0),
									FilledButton.icon(
										onPressed: _abrirTurno,
										icon: const Icon(Icons.play_arrow),
										label: const Text('Abrir turno'),
									),
								],
							),
						);
					}
					return Padding(
						padding: const EdgeInsets.all(16.0),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Card(
									color: PosiaColors.cobrar.withValues(alpha: 0.1),
									child: Padding(
										padding: const EdgeInsets.all(16.0),
										child: Column(
											children: [
												const Text('Turno abierto', style: TextStyle(fontSize: 18.0)),
												Text(
													formatearMoneda(turno.totalVentas),
													style: Theme.of(context).textTheme.headlineMedium,
												),
												Text('${turno.cantidadVentas} ventas'),
											],
										),
									),
								),
								ListTile(
									title: const Text('Fondo inicial'),
									trailing: Text(formatearMoneda(turno.fondoInicial)),
								),
								ListTile(
									title: const Text('Efectivo vendido'),
									trailing: Text(formatearMoneda(turno.totalEfectivo)),
								),
								ListTile(
									title: const Text('Efectivo esperado en caja'),
									trailing: Text(formatearMoneda(turno.calcularEfectivoEsperado())),
								),
								const Spacer(),
								FilledButton.icon(
									onPressed: _cerrarTurno,
									style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
									icon: const Icon(Icons.stop),
									label: const Text('Cerrar turno'),
								),
							],
						),
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _abrirTurno() async {
		final fondo = double.tryParse(_fondoController.text) ?? 0.0;
		final servicio = await ref.read(servicioAdminProvider.future);
		final corte = servicio.obtenerServicioCorteCaja();
		if (corte == null) {
			return;
		}
		await corte.abrirTurno(fondoInicial: fondo);
		ref.invalidate(_turnoProvider);
		ref.invalidate(carritoNotifierProvider);
	}

	Future<void> _cerrarTurno() async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Cerrar turno'),
				content: const Text('Confirma el cierre de caja del turno actual.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar')),
				],
			),
		);
		if (confirmar != true) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final turnoCerrado = await servicio.obtenerServicioCorteCaja()?.cerrarTurno();
		if (turnoCerrado != null) {
			final tienda = await servicio.obtenerTiendaActiva();
			final hardware = await ref.read(hardwareRegistryProvider.future);
			final textoCorte = generarTextoCorteCaja(
				turno: turnoCerrado,
				nombreTienda: tienda?.nombre ?? 'Tienda',
				conLogoImpreso: true,
			);
			try {
				await hardware.obtenerImpresora().imprimirTicket(textoCorte);
			} catch (_) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('Corte cerrado; no se pudo imprimir ticket')),
					);
				}
			}
		}
		ref.invalidate(_turnoProvider);
		ref.invalidate(carritoNotifierProvider);
	}
}

final _turnoProvider = FutureProvider<TurnoCaja?>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerServicioCorteCaja()?.obtenerTurnoAbierto();
});
