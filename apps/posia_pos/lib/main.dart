/// Punto de entrada de la aplicacion de caja POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_ui/posia_ui.dart';

import 'screens/pantalla_acceso_tienda.dart';
import 'bootstrap/inicializador_app.dart';
import 'providers/admin_providers.dart';
import 'providers/app_providers.dart';
import 'screens/pantalla_inicio.dart';

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
		final tiendaConfirmada = ref.watch(sesionTiendaProvider);
		ref.watch(sincronizadorAutomaticoProvider);
		return MaterialApp(
			title: 'POSIA',
			debugShowCheckedModeBanner: false,
			theme: PosiaTheme.construirTema(),
			home: inicializado.when(
				data: (_) => tiendaConfirmada != null
					? const PantallaInicio()
					: const PantallaAccesoTienda(),
				loading: () => const _PantallaCarga(),
				error: (error, _) => _PantallaError(mensaje: error.toString()),
			),
		);
	}
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
							'Iniciando POSIA...',
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
			body: Center(
				child: Padding(
					padding: const EdgeInsets.all(24.0),
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 420.0),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								const Icon(Icons.error_outline, size: 64.0, color: PosiaColors.cancelar),
								const SizedBox(height: 16.0),
								const Text(
									'No se pudo iniciar POSIA',
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
			),
		);
	}
}
