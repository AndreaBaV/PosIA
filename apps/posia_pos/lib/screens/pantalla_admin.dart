/// Menu principal de administracion con accesos iconograficos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_ui/posia_ui.dart';

import 'pantalla_categorias_admin.dart';
import 'pantalla_clientes_admin.dart';
import 'pantalla_corte_caja.dart';
import 'pantalla_historial_ventas.dart';
import 'pantalla_inventario_admin.dart';
import 'pantalla_movimientos_inventario.dart';
import 'pantalla_productos_admin.dart';
import 'pantalla_proveedores_admin.dart';
import 'pantalla_reportes_admin.dart';
import 'pantalla_configuracion_admin.dart';
import 'pantalla_sync_admin.dart';
import 'pantalla_tiendas_admin.dart';
import 'pantalla_traspasos_admin.dart';
import 'pantalla_vendedores_admin.dart';
import 'pantalla_ventas_dia.dart';

/// Panel admin organizado por secciones operativas.
class PantallaAdmin extends ConsumerWidget {
	const PantallaAdmin({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return Scaffold(
			appBar: AppBar(
				title: const Row(
					children: [
						Icon(Icons.admin_panel_settings),
						SizedBox(width: 8.0),
						Text('Administracion'),
					],
				),
			),
			body: ListView(
				padding: const EdgeInsets.all(16.0),
				children: [
					_seccion(context, 'Ventas', [
						_tile(context, Icons.attach_money, 'Ventas hoy', 'Resumen del dia',
							PosiaColors.cobrar, const PantallaVentasDia()),
						_tile(context, Icons.history, 'Historial', 'Ventas y cancelaciones',
							Colors.green, const PantallaHistorialVentas()),
						_tile(context, Icons.point_of_sale, 'Corte de caja', 'Abrir / cerrar turno',
							Colors.teal, const PantallaCorteCaja()),
						_tile(context, Icons.badge, 'Vendedores', 'Personal de venta',
							Colors.deepPurple, const PantallaVendedoresAdmin()),
					]),
					_seccion(context, 'Catalogo', [
						_tile(context, Icons.category, 'Categorias', 'Iconos, color y orden',
							Colors.orange, const PantallaCategoriasAdmin()),
						_tile(context, Icons.inventory_2, 'Productos', 'Catalogo unificado',
							PosiaColors.neutro, const PantallaProductosAdmin()),
					]),
					_seccion(context, 'Inventario', [
						_tile(context, Icons.warehouse, 'Existencias', 'Multi-tienda',
							Colors.blueGrey, const PantallaInventarioAdmin()),
						_tile(context, Icons.swap_vert, 'Movimientos', 'Entradas y salidas',
							Colors.indigo, const PantallaMovimientosInventario()),
						_tile(context, Icons.swap_horiz, 'Traspasos', 'Entre sucursales',
							Colors.cyan, const PantallaTraspasosAdmin()),
					]),
					_seccion(context, 'Personas', [
						_tile(context, Icons.people, 'Clientes', 'Gestion de clientes',
							Colors.blue, const PantallaClientesAdmin()),
						_tile(context, Icons.local_shipping, 'Proveedores', 'Gestion de proveedores',
							Colors.brown, const PantallaProveedoresAdmin()),
					]),
					_seccion(context, 'Reportes y sistema', [
						_tile(context, Icons.store, 'Tiendas', 'Alta, baja y limite 5',
							Colors.deepOrange, const PantallaTiendasAdmin()),
						_tile(context, Icons.assessment, 'Reportes', 'Ventas y alertas',
							Colors.purple, const PantallaReportesAdmin()),
						_tile(context, Icons.cloud_sync, 'Sincronizar', 'Estado de la nube',
							Colors.indigo, const PantallaSyncAdmin()),
						_tile(context, Icons.settings, 'Configuracion', 'PIN y dispositivo',
							Colors.grey, const PantallaConfiguracionAdmin()),
					]),
				],
			),
		);
	}

	Widget _seccion(BuildContext context, String titulo, List<Widget> hijos) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Padding(
					padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
					child: Text(
						titulo,
						style: Theme.of(context).textTheme.titleMedium?.copyWith(
							fontWeight: FontWeight.bold,
						),
					),
				),
				GridView.count(
					crossAxisCount: 3,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					mainAxisSpacing: 12.0,
					crossAxisSpacing: 12.0,
					childAspectRatio: 1.1,
					children: hijos,
				),
				const SizedBox(height: 8.0),
			],
		);
	}

	Widget _tile(
		BuildContext context,
		IconData icono,
		String titulo,
		String subtitulo,
		Color color,
		Widget destino,
	) {
		return TarjetaMenuAdmin(
			icono: icono,
			titulo: titulo,
			subtitulo: subtitulo,
			color: color,
			alPresionar: () {
				Navigator.of(context).push(
					MaterialPageRoute<void>(builder: (_) => destino),
				);
			},
		);
	}
}
