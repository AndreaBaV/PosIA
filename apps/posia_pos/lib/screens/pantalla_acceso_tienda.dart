/// Seleccion de tienda solo para administradores tras iniciar sesion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

/// Permite al administrador elegir la tienda operativa de la sesion.
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
		final usuario = ref.watch(sesionUsuarioProvider);
		return Scaffold(
			backgroundColor: PosiaColors.fondo,
			body: MarcoAutenticacion(
				titulo: 'Selecciona tienda',
				subtitulo: usuario == null
					? 'Elige la sucursal donde operarás'
					: '${usuario.nombre}, elige la sucursal donde operarás',
				etiquetaTienda: null,
				icono: Icons.store,
				contenido: tiendasAsync.when(
					data: (tiendas) {
						if (tiendas.isEmpty) {
							return const Card(
								child: Padding(
									padding: EdgeInsets.all(24.0),
									child: Text('No hay tiendas activas configuradas'),
								),
							);
						}
						_tiendaSeleccionadaId ??=
							configAsync.value?.tiendaId ?? tiendas.first.id;
						return Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								if (usuario != null) ...[
									InsigniaRol(rol: usuario.rol),
									const SizedBox(height: 16.0),
								],
								_listaTiendas(context, tiendas),
							],
						);
					},
					loading: () => const Center(child: CircularProgressIndicator()),
					error: (e, _) => Text('$e'),
				),
				pie: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						SizedBox(
							width: double.infinity,
							height: 52.0,
							child: FilledButton.icon(
								onPressed: _tiendaSeleccionadaId == null || _ingresando ? null : _ingresar,
								icon: _ingresando
									? const SizedBox(
										width: 20.0,
										height: 20.0,
										child: CircularProgressIndicator(
											strokeWidth: 2.0,
											color: Colors.white,
										),
									)
									: const Icon(Icons.check),
								label: Text(_ingresando ? 'Conectando...' : 'Entrar a la caja'),
							),
						),
						TextButton.icon(
							onPressed: _ingresando ? null : _cerrarSesion,
							icon: const Icon(Icons.logout, size: 18.0),
							label: const Text('Cerrar sesión'),
						),
					],
				),
			),
		);
	}

	void _cerrarSesion() async {
		await PosiaLocalDatabase.obtenerInstancia().liberarTenant();
		ref.read(sesionUsuarioProvider.notifier).cerrar();
		ref.read(sesionTiendaProvider.notifier).cerrar();
		ref.invalidate(contenedorServiciosProvider);
	}

	Widget _listaTiendas(BuildContext context, List<Tienda> tiendas) {
		final ancho = MediaQuery.sizeOf(context).width;
		final columnas = ancho >= 900 ? 2 : 1;
		if (columnas == 1) {
			return Column(
				children: tiendas.map((t) => _tarjetaTienda(t)).toList(),
			);
		}
		return GridView.builder(
			shrinkWrap: true,
			physics: const NeverScrollableScrollPhysics(),
			gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
				crossAxisCount: 2,
				mainAxisSpacing: 12.0,
				crossAxisSpacing: 12.0,
				childAspectRatio: 2.4,
			),
			itemCount: tiendas.length,
			itemBuilder: (context, indice) => _tarjetaTienda(tiendas[indice]),
		);
	}

	Widget _tarjetaTienda(Tienda tienda) {
		final seleccionada = _tiendaSeleccionadaId == tienda.id;
		return Card(
			elevation: seleccionada ? 2.0 : 0.5,
			color: seleccionada ? PosiaColors.cobrar.withValues(alpha: 0.08) : null,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(14.0),
				side: BorderSide(
					color: seleccionada ? PosiaColors.cobrar : Colors.grey.shade300,
					width: seleccionada ? 2.0 : 1.0,
				),
			),
			child: InkWell(
				borderRadius: BorderRadius.circular(14.0),
				onTap: () => setState(() => _tiendaSeleccionadaId = tienda.id),
				child: Padding(
					padding: const EdgeInsets.all(16.0),
					child: Row(
						children: [
							Icon(
								Icons.storefront,
								color: seleccionada ? PosiaColors.cobrar : Colors.grey,
								size: 32.0,
							),
							const SizedBox(width: 14.0),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Text(
											tienda.nombre,
											style: TextStyle(
												fontWeight: seleccionada ? FontWeight.bold : FontWeight.w600,
												fontSize: 16.0,
											),
										),
										if (tienda.direccion.isNotEmpty) ...[
											const SizedBox(height: 4.0),
											Text(
												tienda.direccion,
												maxLines: 2,
												overflow: TextOverflow.ellipsis,
												style: TextStyle(
													fontSize: 13.0,
													color: Colors.grey.shade600,
												),
											),
										],
									],
								),
							),
							if (seleccionada)
								const Icon(Icons.check_circle, color: PosiaColors.cobrar),
						],
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
		try {
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			await contenedor.servicioAdmin.cambiarTiendaActiva(tiendaId);
			ref.invalidate(contenedorServiciosProvider);
			await ref.read(contenedorServiciosProvider.future);
			ref.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
		} finally {
			if (mounted) {
				setState(() => _ingresando = false);
			}
		}
	}
}

final _tiendasAccesoProvider = FutureProvider<List<Tienda>>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final usuario = ref.watch(sesionUsuarioProvider);
	return contenedor.servicioAdmin.obtenerTiendasPermitidas(operador: usuario);
});
