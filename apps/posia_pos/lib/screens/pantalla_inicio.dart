/// Shell principal con navegacion entre caja y administracion.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../services/gestor_sesion_persistente.dart';
import '../util/destinos_admin.dart';
import '../util/plataforma_util.dart';
import 'pantalla_admin.dart';
import 'pantalla_asistencia_movil.dart';
import 'pantalla_caja.dart';
import 'pantalla_caja_movil.dart';
import 'pantalla_mi_cuenta.dart';
import 'pantalla_mis_pedidos.dart';

/// Contenedor raiz post-inicializacion con pestañas Caja y Admin.
class PantallaInicio extends ConsumerStatefulWidget {
	const PantallaInicio({super.key});

	@override
	ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
	int _indicePestana = 0;

	@override
	void initState() {
		super.initState();
		if (!esPlataformaMovilNativa()) {
			HardwareKeyboard.instance.addHandler(_manejarAtajosGlobalesCaja);
		}
		WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarVendedorSesion());
	}

	@override
	void dispose() {
		if (!esPlataformaMovilNativa()) {
			HardwareKeyboard.instance.removeHandler(_manejarAtajosGlobalesCaja);
		}
		super.dispose();
	}

	bool _manejarAtajosGlobalesCaja(KeyEvent event) {
		if (!mounted || _indicePestana != 0 || esPlataformaMovilNativa()) {
			return false;
		}
		if (hayDialogoModalConFoco()) {
			return false;
		}
		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			return false;
		}
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return false;
		}
		final atajos = ref.read(atajosCajaConfigProvider).value ?? AtajosCajaConfig.predeterminados();
		return procesarAtajoTecladoEnCaja(
			event: event,
			context: context,
			ref: ref,
			atajos: atajos,
			alIrAdmin: puedeAccederPanelAdmin(usuario)
				? () => setState(() => _indicePestana = 1)
				: null,
			alAbrirSeccionAdmin: puedeAccederPanelAdmin(usuario)
				? (clave) => _abrirSeccionAdmin(clave, usuario)
				: null,
		);
	}

	void _abrirSeccionAdmin(String clave, Usuario usuario) {
		final destino = construirDestinoAdmin(clave, usuario);
		if (destino == null) {
			return;
		}
		setState(() => _indicePestana = 1);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) {
				return;
			}
			Navigator.of(context).push(
				MaterialPageRoute<void>(builder: (_) => destino),
			);
		});
	}

	Future<void> _sincronizarVendedorSesion() async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		final servicioCaja = await ref.read(servicioCajaProvider.future);
		await servicioCaja.asegurarVendedorDesdeUsuario(usuario);
		await ref.read(carritoNotifierProvider.notifier).recargar();
	}

	void _abrirMiCuenta(BuildContext context) {
		Navigator.of(context).push(
			MaterialPageRoute<void>(builder: (_) => const PantallaMiCuenta()),
		);
	}

	@override
	Widget build(BuildContext context) {
		ref.listen<SolicitudNavegacionDesdeCaja?>(
			solicitudNavegacionDesdeCajaProvider,
			(prev, next) {
				if (next == null) {
					return;
				}
				final usuario = ref.read(sesionUsuarioProvider);
				if (usuario == null) {
					return;
				}
				ref.read(solicitudNavegacionDesdeCajaProvider.notifier).limpiar();
				if (next.esAdmin) {
					if (puedeAccederPanelAdmin(usuario)) {
						setState(() => _indicePestana = 1);
					}
					return;
				}
				_abrirSeccionAdmin(next.clave!, usuario);
			},
		);
		final usuario = ref.watch(sesionUsuarioProvider);
		if (usuario == null) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}
		final muestraAdmin = puedeAccederPanelAdmin(usuario);
		final esEmpleado = usuario.rol == RolUsuario.empleado;
		final esMovil = esPlataformaMovilNativa();
		final caja = esMovil
			? PantallaCajaMovil(
				alAbrirMiCuenta: () => _abrirMiCuenta(context),
				alCerrarSesion: () => GestorSesionPersistente.cerrarSesion(ref),
			)
			: const PantallaCaja();
		final muestraBarraSesion = !esMovil || _indicePestana != 0;
		return Scaffold(
			body: Column(
				children: [
					if (muestraBarraSesion)
						BarraSesionUsuario(
							nombreUsuario: usuario.nombre,
							rol: usuario.rol,
							nombreTienda: _nombreTienda(context, ref),
							compacto: esMovil,
							alAbrirMiCuenta: () => _abrirMiCuenta(context),
							alCerrarSesion: () => GestorSesionPersistente.cerrarSesion(ref),
						),
					Expanded(
						child: muestraAdmin
							? IndexedStack(
								index: _indicePestana,
								children: [
									caja,
									PantallaAdmin(usuario: usuario),
								],
							)
							: esEmpleado
								? IndexedStack(
									index: _indicePestana,
									children: [
										caja,
										const PantallaAsistenciaMovil(),
										const PantallaMisPedidos(),
									],
								)
								: caja,
					),
				],
			),
			bottomNavigationBar: muestraAdmin
				? NavigationBar(
					height: 68.0,
					labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
					selectedIndex: _indicePestana,
					onDestinationSelected: (indice) => setState(() => _indicePestana = indice),
					destinations: const [
						NavigationDestination(
							icon: Icon(Icons.point_of_sale_outlined),
							selectedIcon: Icon(Icons.point_of_sale),
							label: 'Caja',
						),
						NavigationDestination(
							icon: Icon(Icons.admin_panel_settings_outlined),
							selectedIcon: Icon(Icons.admin_panel_settings),
							label: 'Admin',
						),
					],
				)
				: esEmpleado
					? NavigationBar(
						height: 68.0,
						labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
						selectedIndex: _indicePestana,
						onDestinationSelected: (indice) => setState(() => _indicePestana = indice),
						destinations: const [
							NavigationDestination(
								icon: Icon(Icons.point_of_sale_outlined),
								selectedIcon: Icon(Icons.point_of_sale),
								label: 'Caja',
							),
							NavigationDestination(
								icon: Icon(Icons.fingerprint_outlined),
								selectedIcon: Icon(Icons.fingerprint),
								label: 'Asistencia',
							),
							NavigationDestination(
								icon: Icon(Icons.assignment_outlined),
								selectedIcon: Icon(Icons.assignment),
								label: 'Pedidos',
							),
						],
					)
					: null,
		);
	}

	String _nombreTienda(BuildContext context, WidgetRef ref) {
		final tiendaAsync = ref.watch(_tiendaActivaNombreProvider);
		return tiendaAsync.when(
			data: (nombre) => nombre,
			loading: () => 'Tienda',
			error: (_, _) => 'Tienda',
		);
	}
}

final _tiendaActivaNombreProvider = FutureProvider<String>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final tienda = await servicio.obtenerTiendaActiva();
	return tienda?.nombre ?? 'Tienda';
});
