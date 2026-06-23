/// Menu principal de administracion con accesos iconograficos.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import 'pantalla_categorias_admin.dart';
import 'pantalla_clientes_admin.dart';
import 'pantalla_compras_admin.dart';
import 'pantalla_corte_caja.dart';
import 'pantalla_cotizaciones_admin.dart';
import 'pantalla_creditos_pendientes.dart';
import 'pantalla_etiquetas_admin.dart';
import 'pantalla_historial_ventas.dart';
import 'pantalla_inventario_admin.dart';
import 'pantalla_listas_precios_admin.dart';
import 'pantalla_mi_cuenta.dart';
import 'pantalla_movimientos_inventario.dart';
import 'pantalla_pedidos_admin.dart';
import 'pantalla_productos_admin.dart';
import 'pantalla_proveedores_admin.dart';
import 'pantalla_reportes_admin.dart';
import 'pantalla_configuracion_admin.dart';
import 'pantalla_sync_admin.dart';
import 'pantalla_tiendas_admin.dart';
import 'pantalla_traspasos_admin.dart';
import 'pantalla_usuarios_admin.dart';
import 'pantalla_ventas_dia.dart';

/// Panel admin organizado por secciones operativas.
class PantallaAdmin extends StatelessWidget {
	const PantallaAdmin({required this.usuario, super.key});

	final Usuario usuario;

	@override
	Widget build(BuildContext context) {
		final tiles = _construirTiles(usuario);
		final colorRol = PresentacionRol.color(usuario.rol);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Administración'),
			),
			body: LayoutBuilder(
				builder: (context, constraints) {
					final padding = LayoutResponsivo.padding(constraints.maxWidth);
					final columnas = LayoutResponsivo.columnasGrid(constraints.maxWidth);
					final secciones = <Widget>[];
					for (final entrada in tiles.entries) {
						if (entrada.value.isEmpty) {
							continue;
						}
						secciones.add(_seccion(context, entrada.key, entrada.value, columnas));
					}
					return ListView(
						padding: EdgeInsets.all(padding),
						children: [
							Card(
								color: colorRol.withValues(alpha: 0.08),
								child: Padding(
									padding: const EdgeInsets.all(16.0),
									child: Row(
										children: [
											CircleAvatar(
												radius: 26.0,
												backgroundColor: colorRol.withValues(alpha: 0.15),
												child: Icon(
													PresentacionRol.icono(usuario.rol),
													color: colorRol,
													size: 28.0,
												),
											),
											const SizedBox(width: 14.0),
											Expanded(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Text(
															usuario.nombre,
															style: Theme.of(context).textTheme.titleMedium?.copyWith(
																fontWeight: FontWeight.bold,
															),
														),
														const SizedBox(height: 4.0),
														InsigniaRol(rol: usuario.rol),
														const SizedBox(height: 6.0),
														Text(
															PermisosUsuario.descripcionRol(usuario.rol),
															style: Theme.of(context).textTheme.bodySmall?.copyWith(
																color: Colors.grey.shade700,
															),
														),
													],
												),
											),
										],
									),
								),
							),
							...secciones,
						],
					);
				},
			),
		);
	}

	Map<String, List<Widget>> _construirTiles(Usuario? usuario) {
		Widget? tile(
			String clave,
			IconData icono,
			String titulo,
			String subtitulo,
			Color color,
			Widget destino,
		) {
			if (!tileAdminVisible(usuario, clave)) {
				return null;
			}
			return _AdminTile(
				icono: icono,
				titulo: titulo,
				subtitulo: subtitulo,
				color: color,
				destino: destino,
			);
		}

		final cuenta = [
			tile('mi_cuenta', Icons.account_circle, 'Mi cuenta', 'Perfil y PIN',
				Colors.blueGrey, const PantallaMiCuenta()),
			tile('usuarios', Icons.groups, 'Equipo', 'Cuentas, PIN y ventas',
				Colors.deepPurple, const PantallaUsuariosAdmin()),
		].whereType<Widget>().toList();

		final ventas = [
			tile('ventas', Icons.attach_money, 'Ventas por tienda', 'Detalle multi-sucursal',
				PosiaColors.cobrar, const PantallaVentasDia()),
			tile('pedidos', Icons.local_shipping, 'Pedidos', 'Recibir y asignar a empleados',
				Colors.deepOrange, const PantallaPedidosAdmin()),
			tile('historial', Icons.history, 'Historial', 'Ventas y cancelaciones',
				Colors.green, const PantallaHistorialVentas()),
			tile('creditos', Icons.account_balance_wallet, 'Creditos', 'Fiar, pendientes y liquidar',
				Colors.amber.shade800, const PantallaCreditosPendientes()),
			tile('cotizaciones', Icons.request_quote, 'Cotizaciones', 'Historial guardado',
				Colors.blueGrey, const PantallaCotizacionesAdmin()),
			tile('corte', Icons.point_of_sale, 'Corte de caja', 'Abrir / cerrar turno',
				Colors.teal, const PantallaCorteCaja()),
		].whereType<Widget>().toList();

		final catalogo = [
			tile('categorias', Icons.category, 'Categorías', 'Iconos, color y orden',
				Colors.orange, const PantallaCategoriasAdmin()),
			tile('productos', Icons.inventory_2, 'Productos', 'Catálogo unificado',
				PosiaColors.neutro, const PantallaProductosAdmin()),
			tile('etiquetas', Icons.label, 'Etiquetas', 'PDF con codigo de barras',
				Colors.blueGrey, const PantallaEtiquetasAdmin()),
			tile('precios', Icons.sell, 'Listas de precios', 'Precios por lista y clientes',
				Colors.green, const PantallaListasPreciosAdmin()),
		].whereType<Widget>().toList();

		final inventario = [
			tile('existencias', Icons.warehouse, 'Existencias', 'Multi-tienda',
				Colors.blueGrey, const PantallaInventarioAdmin()),
			tile('compras', Icons.shopping_cart, 'Compras', 'Proveedor, productos y costo',
				Colors.brown, const PantallaComprasAdmin()),
			tile('movimientos', Icons.swap_vert, 'Movimientos', 'Salidas y ajustes',
				Colors.indigo, const PantallaMovimientosInventario()),
			tile('traspasos', Icons.swap_horiz, 'Traspasos', 'Entre sucursales',
				Colors.cyan, const PantallaTraspasosAdmin()),
		].whereType<Widget>().toList();

		final personas = [
			tile('clientes', Icons.people, 'Clientes', 'Gestión de clientes',
				Colors.blue, const PantallaClientesAdmin()),
			tile('proveedores', Icons.local_shipping, 'Proveedores', 'Gestión de proveedores',
				Colors.brown, const PantallaProveedoresAdmin()),
		].whereType<Widget>().toList();

		final sistema = [
			tile('tiendas', Icons.store, 'Tiendas', 'Alta, baja y límite 5',
				Colors.deepOrange, const PantallaTiendasAdmin()),
			tile('reportes', Icons.assessment, 'Reportes', 'Ventas y alertas',
				Colors.purple, const PantallaReportesAdmin()),
			tile('sync', Icons.cloud_sync, 'Estado de la nube', 'Sync automática',
				Colors.indigo, const PantallaSyncAdmin()),
			tile('config', Icons.settings, 'Configuración', 'PIN y dispositivo',
				Colors.grey, const PantallaConfiguracionAdmin()),
		].whereType<Widget>().toList();

		return {
			'Cuenta': cuenta,
			'Ventas': ventas,
			'Catálogo': catalogo,
			'Inventario': inventario,
			'Personas': personas,
			'Reportes y sistema': sistema,
		};
	}

	Widget _seccion(
		BuildContext context,
		String titulo,
		List<Widget> hijos,
		int columnas,
	) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Padding(
					padding: const EdgeInsets.only(bottom: 10.0, top: 12.0),
					child: Row(
						children: [
							Container(
								width: 4.0,
								height: 22.0,
								decoration: BoxDecoration(
									color: PosiaColors.cobrar,
									borderRadius: BorderRadius.circular(2.0),
								),
							),
							const SizedBox(width: 10.0),
							Text(
								titulo,
								style: Theme.of(context).textTheme.titleMedium?.copyWith(
									fontWeight: FontWeight.bold,
								),
							),
						],
					),
				),
				GridView.count(
					crossAxisCount: columnas,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					mainAxisSpacing: 12.0,
					crossAxisSpacing: 12.0,
					childAspectRatio: columnas >= 4 ? 1.05 : 1.1,
					children: hijos,
				),
				const SizedBox(height: 8.0),
			],
		);
	}
}

class _AdminTile extends StatelessWidget {
	const _AdminTile({
		required this.icono,
		required this.titulo,
		required this.subtitulo,
		required this.color,
		required this.destino,
	});

	final IconData icono;
	final String titulo;
	final String subtitulo;
	final Color color;
	final Widget destino;

	@override
	Widget build(BuildContext context) {
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
