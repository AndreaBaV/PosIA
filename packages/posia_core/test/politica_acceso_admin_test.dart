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

	test('empleado sin rol personalizado no accede al admin', () {
		expect(
			PoliticaAccesoAdmin.puedeAccederPanelAdmin(empleado, null),
			isFalse,
		);
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				empleado,
				null,
				PermisosAdmin.miCuenta,
			),
			isTrue,
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
		expect(
			PoliticaAccesoAdmin.puedeVerSeccionAdmin(
				empleado,
				preSupervisor,
				PermisosAdmin.sync,
			),
			isFalse,
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
