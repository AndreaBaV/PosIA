/// Shell principal con navegacion entre caja y administracion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../util/plataforma_util.dart';
import '../widgets/banner_listo_demo.dart';
import 'pantalla_acceso_admin.dart';
import 'pantalla_admin.dart';
import 'pantalla_caja.dart';
import 'pantalla_caja_movil.dart';

/// Contenedor raiz post-inicializacion con pestañas Caja y Admin.
class PantallaInicio extends ConsumerWidget {
	/// Crea shell de navegacion principal.
	const PantallaInicio({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final adminDesbloqueado = ref.watch(sesionAdminProvider);
		final caja = esPlataformaMovilNativa()
			? const PantallaCajaMovil()
			: const PantallaCaja();
		return Scaffold(
			body: Column(
				children: [
					if (!adminDesbloqueado) const BannerListoDemo(),
					Expanded(
						child: IndexedStack(
							index: adminDesbloqueado ? 1 : 0,
							children: [
								caja,
								const PantallaAdmin(),
							],
						),
					),
				],
			),
			bottomNavigationBar: NavigationBar(
				selectedIndex: adminDesbloqueado ? 1 : 0,
				onDestinationSelected: (indice) {
					if (indice == 0) {
						ref.read(sesionAdminProvider.notifier).cerrar();
						return;
					}
					if (adminDesbloqueado) {
						return;
					}
					Navigator.of(context).push(
						MaterialPageRoute<void>(
							builder: (_) => const PantallaAccesoAdmin(),
						),
					);
				},
				destinations: const [
					NavigationDestination(
						icon: Icon(Icons.point_of_sale),
						label: 'Caja',
					),
					NavigationDestination(
						icon: Icon(Icons.admin_panel_settings),
						label: 'Admin',
					),
				],
			),
		);
	}
}
