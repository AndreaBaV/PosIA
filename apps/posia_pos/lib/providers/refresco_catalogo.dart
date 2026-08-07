/// Relectura del catalogo en las pantallas abiertas despues de sincronizar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'app_providers.dart' show carritoNotifierProvider;
import 'asistencia_providers.dart';

/// Relee el catalogo en las pantallas abiertas tras sincronizar.
///
/// NO invalida el contenedor de servicios: eso destruye y reconstruye
/// ServicioCaja con la caja en pantalla, y ese servicio es el que guarda el
/// catalogo y el carrito en memoria. Al reconstruirlo, la caja se quedaba sin
/// productos hasta la siguiente recarga. Basta con releer desde SQLite usando
/// el mismo servicio que ya esta vivo.
Future<void> refrescarCachesProductosTrasSync(Ref ref) async {
	ref.invalidate(productosCatalogoAdminProvider);
	ref.invalidate(categoriasFormularioAdminProvider);
	ref.invalidate(proveedoresFormularioAdminProvider);
	ref.invalidate(entradasAsistenciaDiaProvider);
	if (ref.read(carritoNotifierProvider).hasValue) {
		await ref
			.read(carritoNotifierProvider.notifier)
			.recargar(invalidarCatalogo: true);
	}
}
