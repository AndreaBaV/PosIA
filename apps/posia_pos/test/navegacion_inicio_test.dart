import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/providers/admin_providers.dart';

void main() {
	const empleado = Usuario(
		id: 'EMP001',
		nombre: 'Empleado',
		codigo: 'EMP001',
		rol: RolUsuario.empleado,
		tiendaId: 'tienda-1',
		activo: true,
	);

	const supervisor = Usuario(
		id: 'SUP001',
		nombre: 'Supervisor',
		codigo: 'SUP001',
		rol: RolUsuario.supervisor,
		tiendaId: 'tienda-1',
		activo: true,
	);

	const rolConAdmin = RolPersonalizado(
		id: 'rol-1',
		nombre: 'Pre-supervisor',
		permisosAdmin: [PermisosAdmin.productos],
		activo: true,
	);

	test('empleado sin admin ve caja, asistencia y pedidos', () {
		final destinos = destinosNavegacionInicio(
			usuario: empleado,
			muestraAdmin: false,
		);
		expect(destinos, [
			DestinoNavegacionInicio.caja,
			DestinoNavegacionInicio.asistencia,
			DestinoNavegacionInicio.pedidos,
		]);
	});

	test('empleado con rol personalizado conserva asistencia y pedidos', () {
		final muestraAdmin = puedeAccederPanelAdmin(
			empleado,
			rolPersonalizado: rolConAdmin,
		);
		expect(muestraAdmin, isTrue);
		final destinos = destinosNavegacionInicio(
			usuario: empleado,
			muestraAdmin: muestraAdmin,
		);
		expect(destinos, [
			DestinoNavegacionInicio.caja,
			DestinoNavegacionInicio.asistencia,
			DestinoNavegacionInicio.pedidos,
			DestinoNavegacionInicio.admin,
		]);
		expect(
			indiceDestinoNavegacionInicio(destinos, DestinoNavegacionInicio.admin),
			3,
		);
	});

	test('supervisor ve caja y admin sin asistencia ni pedidos', () {
		final destinos = destinosNavegacionInicio(
			usuario: supervisor,
			muestraAdmin: true,
		);
		expect(destinos, [
			DestinoNavegacionInicio.caja,
			DestinoNavegacionInicio.admin,
		]);
	});
}
