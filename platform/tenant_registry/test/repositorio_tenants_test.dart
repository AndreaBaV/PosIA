import 'package:posia_tenant_registry/posia_tenant_registry.dart';
import 'package:posia_tenant_registry/src/placeholders_registro_tenants.dart';
import 'package:test/test.dart';

void main() {
	group('RepositorioTenants', () {
		late BaseDatosRegistro base;
		late RepositorioTenants repo;

		setUp(() async {
			base = await BaseDatosRegistro.abrir(
				ruta: ':memory:',
			);
			repo = RepositorioTenants(base);
		});

		tearDown(() => base.cerrar());

		test('crear tenant con tienda y usuario', () async {
			final tenant = await repo.crearTenant(nombre: 'Test SA');
			final tienda = await repo.agregarTienda(
				tenantId: tenant.id,
				nombre: 'Centro',
			);
			await repo.agregarUsuario(
				tenantId: tenant.id,
				nombre: 'Admin',
				codigo: '5001',
				pinPlano: '9999',
			);
			final lista = await repo.listarTenants();
			final reales = lista
				.where((t) => t.id != PlaceholdersRegistroTenants.idTenant)
				.toList();
			expect(reales.length, 1);
			expect((await repo.listarTiendas(tenant.id)).single.id, tienda.id);
			expect((await repo.listarUsuarios(tenant.id)).single.codigo, '5001');
		});
	});
}
