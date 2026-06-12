/// Pantalla de acceso: seleccion de tienda al iniciar sesion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import 'pantalla_inicio.dart';

/// Muestra tiendas activas para confirmar identidad operativa.
class PantallaAccesoTienda extends ConsumerStatefulWidget {
	const PantallaAccesoTienda({super.key});

	@override
	ConsumerState<PantallaAccesoTienda> createState() => _PantallaAccesoTiendaState();
}

class _PantallaAccesoTiendaState extends ConsumerState<PantallaAccesoTienda> {
	String? _tiendaSeleccionadaId;
	bool _ingresando = false;

	@override
	Widget build(BuildContext context) {
		final tiendasAsync = ref.watch(_tiendasAccesoProvider);
		final configAsync = ref.watch(configDispositivoProvider);
		return Scaffold(
			body: SafeArea(
				child: Center(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 480.0),
						child: Padding(
							padding: const EdgeInsets.all(24.0),
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									const Icon(Icons.store, size: 72.0, color: PosiaColors.cobrar),
									const SizedBox(height: 16.0),
									Text(
										'Bienvenido a POSIA',
										style: Theme.of(context).textTheme.headlineSmall?.copyWith(
											fontWeight: FontWeight.bold,
										),
									),
									const SizedBox(height: 8.0),
									const Text(
										'Selecciona la tienda desde la que operaras hoy',
										textAlign: TextAlign.center,
									),
									const SizedBox(height: 32.0),
									tiendasAsync.when(
										data: (tiendas) {
											if (tiendas.isEmpty) {
												return const Text('No hay tiendas activas configuradas');
											}
											_tiendaSeleccionadaId ??=
												configAsync.value?.tiendaId ?? tiendas.first.id;
											return Column(
												children: tiendas.map((tienda) {
													final seleccionada = _tiendaSeleccionadaId == tienda.id;
													return Card(
														color: seleccionada
															? PosiaColors.cobrar.withValues(alpha: 0.1)
															: null,
														child: ListTile(
															leading: Icon(
																Icons.storefront,
																color: seleccionada
																	? PosiaColors.cobrar
																	: Colors.grey,
															),
															title: Text(
																tienda.nombre,
																style: TextStyle(
																	fontWeight: seleccionada
																		? FontWeight.bold
																		: FontWeight.normal,
																),
															),
															subtitle: Text(tienda.direccion),
															trailing: seleccionada
																? const Icon(Icons.check_circle, color: PosiaColors.cobrar)
																: null,
															onTap: () => setState(
																() => _tiendaSeleccionadaId = tienda.id,
															),
														),
													);
												}).toList(),
											);
										},
										loading: () => const CircularProgressIndicator(),
										error: (e, _) => Text('$e'),
									),
									const SizedBox(height: 24.0),
									SizedBox(
										width: double.infinity,
										height: 48.0,
										child: FilledButton.icon(
											onPressed: _tiendaSeleccionadaId == null || _ingresando
												? null
												: _ingresar,
											icon: _ingresando
												? const SizedBox(
													width: 20.0,
													height: 20.0,
													child: CircularProgressIndicator(strokeWidth: 2.0),
												)
												: const Icon(Icons.login),
											label: Text(_ingresando ? 'Conectando...' : 'Entrar a caja'),
										),
									),
								],
							),
						),
					),
				),
			),
		);
	}

	Future<void> _ingresar() async {
		final tiendaId = _tiendaSeleccionadaId;
		if (tiendaId == null) {
			return;
		}
		setState(() => _ingresando = true);
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		await contenedor.servicioAdmin.cambiarTiendaActiva(tiendaId);
		ref.invalidate(contenedorServiciosProvider);
		await ref.read(contenedorServiciosProvider.future);
		ref.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
		if (!mounted) {
			return;
		}
		await Navigator.of(context).pushReplacement(
			MaterialPageRoute<void>(builder: (_) => const PantallaInicio()),
		);
	}
}

final _tiendasAccesoProvider = FutureProvider<List<Tienda>>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioAdmin.listarTiendasActivas();
});
