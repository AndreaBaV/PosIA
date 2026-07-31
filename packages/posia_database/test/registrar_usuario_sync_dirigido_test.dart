/// Regresion: dar de alta un usuario no debe reencolar el catalogo completo.
///
/// Bug real: `registrarUsuario`/`actualizarUsuario`/`cambiarPinUsuario`/
/// `guardarRolPersonalizado` llamaban `_sincronizarInmediatoConHub()`, que
/// reencolaba TODO el catalogo local pendiente (`incluirCatalogo: true`) y
/// corria un ciclo de sync completo antes de devolver el control a la UI.
/// Con un catalogo de unos cuantos cientos de productos, el boton
/// "Guardando..." se quedaba colgado varios minutos -el admin creia que la
/// app se habia congelado- y si cerraba la app antes de que terminara, el
/// usuario nuevo quedaba solo en SQLite (el evento seguia pendiente, pero
/// nunca llego a empujarse). Ahora solo se empuja el evento propio del
/// usuario/rol via `sincronizarEventosPorIds`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'fixture_servicio_admin.dart';

void main() {
	test(
		'registrarUsuario no reencola productos preexistentes que nunca se sincronizaron',
		() async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);

			// Simula un catalogo local con historial: un producto que existe en
			// SQLite pero cuyo evento de alta nunca se emitio (llegado por otra
			// via, o de una version muy vieja). Si registrarUsuario reencolara
			// el catalogo completo, este producto terminaria en la cola.
			await ProductoRepository(baseDatos: fixture.base).guardar(
				Producto(
					id: 'producto-historico-sin-evento',
					nombre: 'Producto historico',
					codigoBarras: '7501000000001',
					precioBase: 10.0,
					unidadMedida: UnidadMedida.pieza,
					rutaImagen: '',
					activo: true,
					tiendaId: fixture.tiendaOrigenId,
					categoriaId: fixture.categoriaId,
				),
			);

			await servicio.registrarUsuario(
				nombre: 'Empleada Nueva',
				rol: RolUsuario.empleado,
				pin: '1234',
				tiendaId: fixture.tiendaOrigenId,
			);

			final cola = SyncEventRepository(baseDatos: fixture.base);
			final pendientes = await cola.obtenerPendientes();
			final tipos = pendientes.map((e) => e.tipo).toSet();

			expect(
				tipos.contains(TipoSyncEvento.productUpserted),
				isFalse,
				reason: 'dar de alta un usuario no debe reencolar el catalogo completo',
			);
			expect(
				pendientes.any((e) => e.tipo == TipoSyncEvento.userUpserted),
				isTrue,
				reason: 'el evento del usuario nuevo si debe quedar encolado',
			);

			await fixture.cerrar();
		},
	);
}
