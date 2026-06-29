/// Genera pin_credencial para INSERT manual en Neon.
import 'package:posia_core/posia_core.dart';

void main(List<String> args) {
	final pin = args.isNotEmpty ? args.first : '7291';
	final credencial = HasherPin.codificar(pin);
	print('pin_credencial=$credencial');
}
