/// Crea tenant, tienda y administrador local sin hub en la nube.
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../database/posia_local_database.dart';
import '../models/config_dispositivo.dart';
import '../repositories/config_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/usuario_repository.dart';

/// Resultado del bootstrap offline de un dispositivo.
class ResultadoAprovisionOffline {
	const ResultadoAprovisionOffline({
		required this.tenantId,
		required this.tiendaId,
		required this.codigoAdmin,
	});

	final String tenantId;
	final String tiendaId;
	final String codigoAdmin;
}

/// Inicializa SQLite local para operar sin servidor sync.
class AprovisionadorOffline {
	const AprovisionadorOffline._();

	static const _uuid = Uuid();

	/// Crea tenant, tienda principal y cuenta administrador en el dispositivo.
	static Future<ResultadoAprovisionOffline> aprovisionar({
		required ConfigRepository config,
		required String nombreNegocio,
		required String nombreTienda,
		required String nombreAdmin,
		required String codigoAdmin,
		required String pinAdmin,
	}) async {
		final codigo = codigoAdmin.trim();
		final pin = pinAdmin.trim();
		if (codigo.isEmpty) {
			throw StateError('El codigo de administrador es obligatorio');
		}
		if (pin.length != LONGITUD_PIN_ADMIN) {
			throw StateError('El PIN del administrador debe tener $LONGITUD_PIN_ADMIN digitos');
		}

		final tenantId = _uuid.v4();
		final tiendaId = _uuid.v4();
		final adminId = _uuid.v4();

		await PosiaLocalDatabase.obtenerInstancia().establecerTenant(tenantId);
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
				id: adminId,
				nombre: nombreAdmin.trim().isEmpty ? 'Administrador' : nombreAdmin.trim(),
				codigo: codigo,
				pin: pin,
				rol: RolUsuario.administrador,
				activo: true,
				tenantId: tenantId,
			),
		);

		final actual = await config.obtenerConfigDispositivo();
		await config.guardarConfigDispositivo(
			ConfigDispositivo(
				tenantId: tenantId,
				tiendaId: actual.tiendaId.isEmpty ? tiendaId : actual.tiendaId,
				cajaId: actual.cajaId,
				nombreCaja: actual.nombreCaja,
			),
		);

		return ResultadoAprovisionOffline(
			tenantId: tenantId,
			tiendaId: tiendaId,
			codigoAdmin: codigo,
		);
	}
}
