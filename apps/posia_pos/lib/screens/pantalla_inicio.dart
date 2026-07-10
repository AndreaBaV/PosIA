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
import '../widgets/banner_progreso_sync.dart';
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
		final rolPersonalizado = ref.read(rolPersonalizadoSesionProvider);
		final muestraAdmin = puedeAccederPanelAdmin(
			usuario,
			rolPersonalizado: rolPersonalizado,
		);
		final destinos = destinosNavegacionInicio(
			usuario: usuario,
			muestraAdmin: muestraAdmin,
		);
		final indiceAdmin = indiceDestinoNavegacionInicio(
			destinos,
			DestinoNavegacionInicio.admin,
		);
		return procesarAtajoTecladoEnCaja(
			event: event,
			context: context,
			ref: ref,
			atajos: atajos,
			alIrAdmin: indiceAdmin != null
				? () => setState(() => _indicePestana = indiceAdmin)
				: null,
			alAbrirSeccionAdmin: indiceAdmin != null
				? (clave) => _abrirSeccionAdmin(
					clave,
					usuario,
					indiceAdmin: indiceAdmin,
					rolPersonalizado: rolPersonalizado,
				)
				: null,
		);
	}

	void _abrirSeccionAdmin(
		String clave,
		Usuario usuario, {
		required int indiceAdmin,
		RolPersonalizado? rolPersonalizado,
	}) {
		final destino = construirDestinoAdmin(
			clave,
			usuario,
			rolPersonalizado: rolPersonalizado,
		);
		if (destino == null) {
			return;
		}
		setState(() => _indicePestana = indiceAdmin);
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
				final rolPersonalizado = ref.read(rolPersonalizadoSesionProvider);
				ref.read(solicitudNavegacionDesdeCajaProvider.notifier).limpiar();
				final muestraAdmin = puedeAccederPanelAdmin(
					usuario,
					rolPersonalizado: rolPersonalizado,
				);
				final destinos = destinosNavegacionInicio(
					usuario: usuario,
					muestraAdmin: muestraAdmin,
				);
				final indiceAdmin = indiceDestinoNavegacionInicio(
			destinos,
			DestinoNavegacionInicio.admin,
		);
				if (next.esAdmin) {
					if (indiceAdmin != null) {
						setState(() => _indicePestana = indiceAdmin);
					}
					return;
				}
				if (indiceAdmin == null) {
					return;
				}
				_abrirSeccionAdmin(
					next.clave!,
					usuario,
					indiceAdmin: indiceAdmin,
					rolPersonalizado: rolPersonalizado,
				);
			},
		);
		final usuario = ref.watch(sesionUsuarioProvider);
		if (usuario == null) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}
		final rolPersonalizado = ref.watch(rolPersonalizadoSesionProvider);
		final muestraAdmin = puedeAccederPanelAdmin(
			usuario,
			rolPersonalizado: rolPersonalizado,
		);
		final destinos = destinosNavegacionInicio(
			usuario: usuario,
			muestraAdmin: muestraAdmin,
		);
		final indiceSeleccionado = destinos.isEmpty
			? 0
			: _indicePestana.clamp(0, destinos.length - 1);
		final esMovil = esPlataformaMovilNativa();
		final caja = esMovil
			? PantallaCajaMovil(
				alAbrirMiCuenta: () => _abrirMiCuenta(context),
				alCerrarSesion: () => GestorSesionPersistente.cerrarSesion(ref),
			)
			: const PantallaCaja();
		final muestraBarraSesion = !esMovil || indiceSeleccionado != 0;
		final pantallas = destinos
			.map(
				(destino) => switch (destino) {
					DestinoNavegacionInicio.caja => caja,
					DestinoNavegacionInicio.asistencia => const PantallaAsistenciaMovil(),
					DestinoNavegacionInicio.pedidos => const PantallaMisPedidos(),
					DestinoNavegacionInicio.admin => PantallaAdmin(usuario: usuario),
				},
			)
			.toList();
		return Scaffold(
			body: Column(
				children: [
					const BannerProgresoSync(),
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
						child: destinos.length <= 1
							? caja
							: IndexedStack(
								index: indiceSeleccionado,
								children: pantallas,
							),
					),
				],
			),
			bottomNavigationBar: destinos.length <= 1
				? null
				: NavigationBar(
					height: 68.0,
					labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
					selectedIndex: indiceSeleccionado,
					onDestinationSelected: (indice) =>
						setState(() => _indicePestana = indice),
					destinations: destinos
						.map((destino) => _destinoNavegacion(destino))
						.toList(),
				),
		);
	}

	NavigationDestination _destinoNavegacion(DestinoNavegacionInicio destino) {
		return switch (destino) {
			DestinoNavegacionInicio.caja => const NavigationDestination(
				icon: Icon(Icons.point_of_sale_outlined),
				selectedIcon: Icon(Icons.point_of_sale),
				label: 'Caja',
			),
			DestinoNavegacionInicio.asistencia => const NavigationDestination(
				icon: Icon(Icons.fingerprint_outlined),
				selectedIcon: Icon(Icons.fingerprint),
				label: 'Asistencia',
			),
			DestinoNavegacionInicio.pedidos => const NavigationDestination(
				icon: Icon(Icons.assignment_outlined),
				selectedIcon: Icon(Icons.assignment),
				label: 'Pedidos',
			),
			DestinoNavegacionInicio.admin => const NavigationDestination(
				icon: Icon(Icons.admin_panel_settings_outlined),
				selectedIcon: Icon(Icons.admin_panel_settings),
				label: 'Admin',
			),
		};
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
