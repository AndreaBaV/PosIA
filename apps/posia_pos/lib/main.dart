/// Punto de entrada de la aplicacion de caja POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import 'screens/pantalla_acceso_tienda.dart';
import 'screens/pantalla_inicio_sesion.dart';
import 'bootstrap/inicializador_app.dart';
import 'providers/app_providers.dart';
import 'screens/pantalla_inicio.dart';
import 'screens/pantalla_instalacion_tecnico.dart';
import 'providers/admin_providers.dart';
import 'util/plataforma_util.dart';

/// Inicia runtime Flutter y arranca aplicacion POSIA.
Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await InicializadorApp.preparar();
	runApp(const ProviderScope(child: PosiaApp()));
}

/// Widget raiz de la aplicacion POSIA.
class PosiaApp extends ConsumerWidget {
	/// Crea aplicacion con tema POSIA.
	const PosiaApp({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final inicializado = ref.watch(estadoInicializacionProvider);
		final sesionRestaurada = ref.watch(restauracionSesionProvider);
		final instalacionAsync = ref.watch(instalacionCompletaProvider);
		final tiendaConfirmada = ref.watch(sesionTiendaProvider);
		final usuario = ref.watch(sesionUsuarioProvider);
		if (usuario != null) {
			ref.watch(sincronizadorAutomaticoProvider);
		}
		final home = _resolverPantallaInicio(
			inicializado: inicializado,
			sesionRestaurada: sesionRestaurada,
			instalacionAsync: instalacionAsync,
			usuario: usuario,
			tiendaConfirmada: tiendaConfirmada,
			adminListo: usuario?.rol == RolUsuario.administrador && tiendaConfirmada == null
				? ref.watch(sesionAdminListoProvider)
				: null,
		);
		return MaterialApp(
			title: NOMBRE_COMERCIAL_APP,
			debugShowCheckedModeBanner: false,
			theme: PosiaTheme.construirTema(),
			builder: (context, child) {
				if (child == null) {
					return const SizedBox.shrink();
				}
				return AccesorioTecladoMovil(
					habilitado: esPlataformaMovilNativa(),
					child: child,
				);
			},
			home: home,
		);
	}
}

Widget _resolverPantallaInicio({
	required AsyncValue<void> inicializado,
	required AsyncValue<void> sesionRestaurada,
	required AsyncValue<bool> instalacionAsync,
	required Usuario? usuario,
	required String? tiendaConfirmada,
	required bool? adminListo,
}) {
	return inicializado.when(
		data: (_) => sesionRestaurada.when(
			data: (_) => instalacionAsync.when(
				data: (instalacionLista) {
					if (!instalacionLista && usuario == null) {
						return const PantallaInstalacionTecnico();
					}
					if (usuario == null) {
						return const PantallaInicioSesion();
					}
					if (usuario.rol == RolUsuario.administrador && tiendaConfirmada == null) {
						if (adminListo == false) {
							return const _PantallaCarga();
						}
						return const PantallaAccesoTienda();
					}
					return const PantallaInicio();
				},
				loading: () => const _PantallaCarga(),
				error: (error, _) => _PantallaError(mensaje: error.toString()),
			),
			loading: () => const _PantallaCarga(),
			error: (error, _) => _PantallaError(mensaje: error.toString()),
		),
		loading: () => const _PantallaCarga(),
		error: (error, _) => _PantallaError(mensaje: error.toString()),
	);
}

/// Pantalla de carga mientras inicializa SQLite y servicios.
class _PantallaCarga extends StatelessWidget {
	const _PantallaCarga();

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						const Icon(Icons.point_of_sale, size: 80.0, color: PosiaColors.cobrar),
						const SizedBox(height: 24.0),
						const CircularProgressIndicator(color: PosiaColors.cobrar),
						const SizedBox(height: 16.0),
						Text(
							'Iniciando $NOMBRE_COMERCIAL_APP...',
							style: Theme.of(context).textTheme.titleMedium,
						),
						const SizedBox(height: 4.0),
						Text(
							'Punto de venta inteligente',
							style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
						),
					],
				),
			),
		);
	}
}

/// Pantalla de error fatal en arranque.
class _PantallaError extends StatelessWidget {
	const _PantallaError({required this.mensaje});

	final String mensaje;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: LayoutBuilder(
				builder: (context, constraints) {
					return Center(
						child: ConstrainedBox(
							constraints: BoxConstraints(
								maxWidth: LayoutResponsivo.anchoMaximoFormulario(constraints.maxWidth),
							),
							child: Padding(
								padding: LayoutResponsivo.paddingTodo(context),
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										const Icon(Icons.error_outline, size: 64.0, color: PosiaColors.cancelar),
										const SizedBox(height: 16.0),
										const Text(
											'No se pudo iniciar $NOMBRE_COMERCIAL_APP',
											style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
											textAlign: TextAlign.center,
										),
										const SizedBox(height: 12.0),
										Text(
											mensaje,
											textAlign: TextAlign.center,
											style: const TextStyle(color: Colors.grey),
										),
										const SizedBox(height: 24.0),
										const Text(
											'Cierra la app, verifica permisos de almacenamiento '
											'y vuelve a abrir. Si persiste, reinstala desde la carpeta Release.',
											textAlign: TextAlign.center,
											style: TextStyle(fontSize: 13.0),
										),
									],
								),
							),
						),
					);
				},
			),
		);
	}
}
