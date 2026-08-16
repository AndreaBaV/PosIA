import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	test('build mas alto gana aunque el semver coincida', () {
		expect(
			compararVersionApp(
				const VersionApp(nombre: '2.0.0', build: 151),
				const VersionApp(nombre: '2.0.0', build: 150),
			),
			greaterThan(0),
		);
	});

	test('semver decide si no hay build', () {
		expect(
			hayActualizacionDisponible(
				instalada: const VersionApp(nombre: '2.0.0'),
				remota: const ManifestoActualizacionApp(version: '2.0.1'),
			),
			isTrue,
		);
		expect(
			hayActualizacionDisponible(
				instalada: const VersionApp(nombre: '2.0.1'),
				remota: const ManifestoActualizacionApp(version: '2.0.1'),
			),
			isFalse,
		);
	});

	test('VersionApp.desdeEtiqueta lee pubspec 2.0.0+150', () {
		final v = VersionApp.desdeEtiqueta('2.0.0+150');
		expect(v.nombre, '2.0.0');
		expect(v.build, 150);
		expect(v.etiqueta, '2.0.0+150');
	});
}
