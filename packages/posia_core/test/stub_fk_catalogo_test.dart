/// Regresion: detectores de stub FK en todo el catalogo replicado a Neon.
///
/// `AseguradorPadresFk` crea placeholders cuando un evento hijo llega antes que
/// su padre. Si esos placeholders se emiten a Neon, al bajar a los demas
/// equipos reemplazan a la entidad legitima que comparte su id (los aplicadores
/// usan ConflictAlgorithm.replace). Cada entidad replicada necesita distinguir
/// su stub — y, tan importante como eso, no confundir datos reales con stubs.
library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	test('Cliente distingue stub de cliente real', () {
		const stub = Cliente(
			id: 'c1',
			nombre: 'Cliente',
			listaPreciosId: null,
			creditoHabilitado: false,
			activo: true,
			notas: '__stub_fk__',
		);
		expect(stub.esStubFk, isTrue);

		// Stub heredado de versiones previas: sin marca, se detecta por forma.
		const heredado = Cliente(
			id: 'c2',
			nombre: 'Cliente',
			listaPreciosId: null,
			creditoHabilitado: false,
			activo: true,
		);
		expect(heredado.esStubFk, isTrue);

		const real = Cliente(
			id: 'c3',
			nombre: 'Cliente',
			listaPreciosId: null,
			creditoHabilitado: false,
			activo: true,
			telefono: '5544332211',
		);
		expect(real.esStubFk, isFalse, reason: 'tiene datos de contacto');
	});

	test('Usuario distingue stub por codigo sync-', () {
		const stub = Usuario(
			id: 'u1',
			nombre: 'Usuario',
			codigo: 'sync-abc123',
			rol: RolUsuario.empleado,
			activo: true,
		);
		expect(stub.esStubFk, isTrue);

		const real = Usuario(
			id: 'u2',
			nombre: 'Usuario',
			codigo: 'EMP-014',
			rol: RolUsuario.empleado,
			activo: true,
		);
		expect(real.esStubFk, isFalse, reason: 'codigo asignado a mano');
	});

	test('Almacen distingue stub de almacen real', () {
		const stub = Almacen(id: 'a1', nombre: 'Almacén', activo: true);
		expect(stub.esStubFk, isTrue);

		const real = Almacen(
			id: 'a2',
			nombre: 'Almacén',
			activo: true,
			latitud: 19.43,
			longitud: -99.13,
		);
		expect(real.esStubFk, isFalse, reason: 'tiene geolocalizacion');
	});

	test('RolPersonalizado distingue stub de rol real', () {
		const stub = RolPersonalizado(
			id: 'r1',
			nombre: 'Rol',
			permisosAdmin: [],
			activo: true,
		);
		expect(stub.esStubFk, isTrue);

		const real = RolPersonalizado(
			id: 'r2',
			nombre: 'Rol',
			permisosAdmin: ['productos'],
			activo: true,
		);
		expect(real.esStubFk, isFalse, reason: 'tiene permisos asignados');
	});

	test('Combo distingue stub de combo real', () {
		const stub = Combo(id: 'k1', precioCombo: 0.0, nombre: 'Combo');
		expect(stub.esStubFk, isTrue);

		const real = Combo(
			id: 'k2',
			precioCombo: 99.0,
			nombre: 'Combo',
			miembros: [ComboMiembro(productoId: 'p1')],
		);
		expect(real.esStubFk, isFalse, reason: 'tiene precio y miembros');
	});

	test('LotePromocion distingue stub por codigoExterno igual al id', () {
		const stub = LotePromocion(
			id: 'l1',
			codigoExterno: 'l1',
			cantidadMinima: 1.0,
			precioUnitario: 0.0,
			nombre: 'Lote promoción',
		);
		expect(stub.esStubFk, isTrue);

		const real = LotePromocion(
			id: 'l2',
			codigoExterno: 'MAYOREO-25',
			cantidadMinima: 25.0,
			precioUnitario: 17.5,
			nombre: 'Lote promoción',
		);
		expect(real.esStubFk, isFalse, reason: 'codigo externo propio y precio');
	});

	test('TipoPresentacion distingue stub de tipo real', () {
		const stub = TipoPresentacion(
			id: 't1',
			nombre: 'Presentación',
			unidad: 'pieza',
			activo: true,
		);
		expect(stub.esStubFk, isTrue);

		const real = TipoPresentacion(
			id: 't2',
			nombre: 'Bulto',
			unidad: 'kilogramo',
			activo: true,
		);
		expect(real.esStubFk, isFalse);
	});

	test('ListaPrecios detecta el stub por nombre', () {
		const stub = ListaPrecios(id: 'lp1', nombre: 'Lista de precios');
		expect(stub.esStubFk, isTrue);

		const real = ListaPrecios(id: 'lp2', nombre: 'Mayoreo');
		expect(real.esStubFk, isFalse);
	});
}
