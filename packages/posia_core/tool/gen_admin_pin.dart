import 'package:posia_core/posia_core.dart';

/// Genera pin_salt y pin_hash para INSERT manual en Neon.
/// Uso: edita [pin] y ejecuta `dart run tool/gen_admin_pin.dart` desde posia_core.
void main() {
	const pin = '1234';
	final sal = HasherPin.generarSal();
	final hash = HasherPin.hashPin(pin, sal);
	// ignore: avoid_print
	print('pin_salt=$sal');
	// ignore: avoid_print
	print('pin_hash=$hash');
}
