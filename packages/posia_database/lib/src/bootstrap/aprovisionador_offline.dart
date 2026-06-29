/// Crea tienda y administrador local sin hub en la nube.
library;

import 'package:posia_core/posia_core.dart';

import '../database/posia_local_database.dart';
import '../models/config_dispositivo.dart';
import '../repositories/config_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/usuario_repository.dart';

class ResultadoAprovisionOffline {
	const ResultadoAprovisionOffline({
		required this.tiendaId,
		required this.codigoAdmin,
	});

	final String tiendaId;
	final String codigoAdmin;
}

class AprovisionadorOffline {
	const AprovisionadorOffline._();

	static Future<ResultadoAprovisionOffline> aprovisionar({
		required ConfigRepository config,
		required String nombreNegocio,
		required String nombreTienda,
		required String nombreAdmin,
		required String codigoAdmin,
		required String pinAdmin,
	}) async {
		final codigo = ValidadorCodigoUsuario.normalizar(codigoAdmin);
		final pin = pinAdmin.trim();
		if (codigo.isEmpty) {
			throw StateError('El codigo de administrador es obligatorio');
		}
		if (pin.length != LONGITUD_PIN_ADMIN) {
			throw StateError('El PIN del administrador debe tener $LONGITUD_PIN_ADMIN digitos');
		}

		final tiendaId = IdPosia.tiendaDesdeNombre(
			nombreTienda.trim().isEmpty ? 'Principal' : nombreTienda.trim(),
		);
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();

		await TiendaRepository(baseDatos: base).guardar(
			Tienda(
				id: tiendaId,
				nombre: nombreTienda.trim().isEmpty ? 'Principal' : nombreTienda.trim(),
				direccion: nombreNegocio.trim(),
				activa: true,
			),
		);

		await UsuarioRepository(baseDatos: base).guardar(
			Usuario(
				id: IdPosia.usuario(codigo),
				nombre: nombreAdmin.trim().isEmpty ? 'Administrador' : nombreAdmin.trim(),
				codigo: codigo,
				pin: pin,
				rol: RolUsuario.administrador,
				activo: true,
			),
		);

		final actual = await config.obtenerConfigDispositivo();
		await config.guardarConfigDispositivo(
			ConfigDispositivo(
				tiendaId: actual.tiendaId.isEmpty ? tiendaId : actual.tiendaId,
				cajaId: actual.cajaId,
				nombreCaja: actual.nombreCaja,
			),
		);

		return ResultadoAprovisionOffline(
			tiendaId: tiendaId,
			codigoAdmin: codigo,
		);
	}
}
