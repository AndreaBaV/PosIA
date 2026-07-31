/// Sube la foto de un producto a la tienda en linea (Cloudflare R2, via
/// POST /v1/admin/imagenes en el despliegue de la tienda).
///
/// Autor: Equipo POSIA · Matricula: POSIA-2026-001
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:posia_core/posia_core.dart';

import 'hub_sync_client.dart';

/// Tipos de imagen que acepta el endpoint de subida.
enum TipoImagenProducto {
	jpeg('image/jpeg'),
	png('image/png'),
	webp('image/webp');

	const TipoImagenProducto(this.mime);

	final String mime;
}

/// Cliente HTTP para subir fotos de producto a la tienda en linea.
///
/// Separado de [HubSyncClient] porque habla con un despliegue distinto
/// (Cloudflare Pages de la tienda, no el hub de sync en Northflank), aunque
/// reusa la misma clave de API: es el mismo secreto que ya valida que la
/// llamada viene de la app POS.
class ServicioImagenesProducto {
	ServicioImagenesProducto({
		required String urlBase,
		String? claveApi,
		http.Client? clienteHttp,
	}) : _urlBase = HubSyncClient.normalizarUrlBase(urlBase),
	     _claveApi = claveApi,
	     _clienteHttp = clienteHttp ?? http.Client();

	final String _urlBase;
	final String? _claveApi;
	final http.Client _clienteHttp;

	/// Sube [bytes] como la foto de [productoId].
	///
	/// Retorna la URL publica en R2, o null si la subida fallo (red, servidor
	/// caido, formato rechazado). Nunca lanza: quien llama decide si avisar al
	/// usuario o simplemente conservar la foto anterior.
	Future<String?> subirFoto({
		required String productoId,
		required List<int> bytes,
		required TipoImagenProducto tipo,
	}) async {
		if (bytes.isEmpty) {
			return null;
		}
		if (bytes.length > TAMANO_MAXIMO_IMAGEN_PRODUCTO_BYTES) {
			return null;
		}
		final uri = Uri.parse('$_urlBase/v1/admin/imagenes').replace(
			queryParameters: {'productoId': productoId},
		);
		try {
			final claveApi = _claveApi;
			final respuesta = await _clienteHttp
				.post(
					uri,
					headers: {
						'Content-Type': tipo.mime,
						if (claveApi != null && claveApi.isNotEmpty) 'x-api-key': claveApi,
					},
					body: bytes,
				)
				.timeout(const Duration(seconds: TIMEOUT_SUBIDA_IMAGEN_SEGUNDOS));
			if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
				return null;
			}
			final json = jsonDecode(respuesta.body);
			if (json is! Map<String, dynamic>) {
				return null;
			}
			final url = json['url'] as String?;
			return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
		} on Object {
			return null;
		}
	}
}
