/// Reglas para codigos de usuario alfanumericos.
library;

/// Valida y normaliza identificadores de usuario (login).
class ValidadorCodigoUsuario {
	ValidadorCodigoUsuario._();

	static final RegExp _patron = RegExp(r'^[A-Za-z0-9._-]{2,32}$');

	/// Convierte a mayusculas y recorta espacios.
	static String normalizar(String codigo) => codigo.trim().toUpperCase();

	/// Devuelve mensaje de error o null si el codigo es valido.
	static String? validar(String codigo) {
		final limpio = normalizar(codigo);
		if (limpio.isEmpty) {
			return 'El codigo es obligatorio';
		}
		if (!_patron.hasMatch(limpio)) {
			return 'Codigo invalido: usa 2-32 caracteres (letras, numeros, . _ -)';
		}
		return null;
	}
}
