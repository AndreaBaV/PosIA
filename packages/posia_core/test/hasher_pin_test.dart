import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('HasherPin', () {
		test('credencial compacta distinta por usuario', () {
			final a = HasherPin.codificar('1234');
			final b = HasherPin.codificar('1234');
			expect(a, isNot(equals(b)));
			expect(a.length, lessThan(20));
			expect(a.contains(':'), isFalse);
		});

		test('verifica pin correcto e incorrecto', () {
			final credencial = HasherPin.codificar('3456');
			expect(HasherPin.verificar('3456', credencial), isTrue);
			expect(HasherPin.verificar('1234', credencial), isFalse);
		});

		test('rechaza formato con separador legacy', () {
			expect(HasherPin.verificar('1234', 'sal:hash'), isFalse);
		});
	});
}
