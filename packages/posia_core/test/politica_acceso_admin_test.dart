import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	const admin = Usuario(
		id: 'ADM001',
		nombre: 'Admin',
		codigo: 'ADM001',
		rol: RolUsuario.administrador,
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

	const empleado = Usuario(
		id: 'EMP001',
		nombre: 'Empleado',
		codigo: 'EMP001',
		rol: RolUsuario.empleado,
		tiendaId: 'tienda-1',
		activo: true,
	);

	const preSupervisor = RolPersonalizado(
		id: 'rol-pre-sup',
		nombre: 'Pre-supervisor',
		permisosAdmin: [PermisosAdmin.productos, PermisosAdmin.categorias],
		categoriasPermitidas: ['cat-lacteos', 'cat-abarrotes'],
		activo: true,
	);

	test('administrador ve todo el panel', () {
		expect(
			PoliticaAccesoAdmin.puedeAccederPanelAdmin(admin, null),
			isTrue,
		);
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				admin,
				null,
				PermisosAdmin.sync,
			),
			isTrue,
		);
		expect(
			PoliticaAccesoAdmin.categoriasProductoPermitidas(admin, null),
			isNull,
		);
	});

	test('empleado accede al panel pero solo ve mi cuenta, sync y config', () {
		// Todos pueden abrir el panel para alcanzar sync/config del hub.
		expect(
			PoliticaAccesoAdmin.puedeAccederPanelAdmin(empleado, null),
			isTrue,
		);
		for (final clave in [
			PermisosAdmin.miCuenta,
			PermisosAdmin.sync,
			PermisosAdmin.config,
		]) {
			expect(
				PoliticaAccesoAdmin.puedeVerSeccionAdmin(empleado, null, clave),
				isTrue,
				reason: '$clave debe ser visible para todos los usuarios',
			);
		}
		// Pero no las secciones de administración propiamente dichas.
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				empleado,
				null,
				PermisosAdmin.productos,
			),
			isFalse,
		);
	});

	test('rol personalizado limita secciones visibles', () {
		expect(
			PoliticaAccesoAdmin.puedeAccederPanelAdmin(empleado, preSupervisor),
			isTrue,
		);
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				empleado,
				preSupervisor,
				PermisosAdmin.productos,
			),
			isTrue,
		);
		// Una sección que el rol no lista sigue oculta…
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				empleado,
				preSupervisor,
				PermisosAdmin.tiendas,
			),
			isFalse,
		);
		// …pero sync/config son visibles para todos, aunque el rol no los liste.
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				empleado,
				preSupervisor,
				PermisosAdmin.sync,
			),
			isTrue,
		);
	});

	test('rol personalizado restringe categorias de producto', () {
		final permitidas = PoliticaAccesoAdmin.categoriasProductoPermitidas(
			empleado,
			preSupervisor,
		);
		expect(permitidas, {'cat-lacteos', 'cat-abarrotes'});
		expect(
			PoliticaAccesoAdmin.puedeEditarProductoEnCategoria(
				empleado,
				preSupervisor,
				'cat-lacteos',
			),
			isTrue,
		);
		expect(
			PoliticaAccesoAdmin.puedeEditarProductoEnCategoria(
				empleado,
				preSupervisor,
				'cat-bebidas',
			),
			isFalse,
		);
	});

	test('supervisor base conserva restricciones sin rol personalizado', () {
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				supervisor,
				null,
				PermisosAdmin.tiendas,
			),
			isFalse,
		);
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				supervisor,
				null,
				PermisosAdmin.productos,
			),
			isTrue,
		);
	});
}
