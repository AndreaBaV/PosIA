import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('HasherPin', () {
		test('genera hash distinto con distinta sal', () {
			final salA = HasherPin.generarSal();
			final salB = HasherPin.generarSal();
			final hashA = HasherPin.hashPin('1234', salA);
			final hashB = HasherPin.hashPin('1234', salB);
			expect(hashA, isNot(equals(hashB)));
		});

		test('verifica pin correcto e incorrecto', () {
			final sal = HasherPin.generarSal();
			final hash = HasherPin.hashPin('3456', sal);
			expect(HasherPin.verificar('3456', sal, hash), isTrue);
			expect(HasherPin.verificar('1234', sal, hash), isFalse);
		});
	});
}
