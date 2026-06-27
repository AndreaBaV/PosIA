/// Credenciales locales protegidas por biometria (Face ID / huella).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const String _claveAlmacenPerfiles = 'posia_perfiles_biometricos';
const int _maxPerfilesPorDispositivo = 8;

/// Perfil de usuario vinculado a biometria en este dispositivo.
class PerfilAccesoBiometrico {
	const PerfilAccesoBiometrico({
		required this.usuarioId,
		required this.codigo,
		required this.pin,
		required this.nombre,
		required this.tenantId,
	});

	final String usuarioId;
	final String codigo;
	final String pin;
	final String nombre;
	final String tenantId;

	Map<String, dynamic> toJson() => {
		'usuarioId': usuarioId,
		'codigo': codigo,
		'pin': pin,
		'nombre': nombre,
		'tenantId': tenantId,
	};

	factory PerfilAccesoBiometrico.fromJson(Map<String, dynamic> json) {
		return PerfilAccesoBiometrico(
			usuarioId: json['usuarioId'] as String,
			codigo: json['codigo'] as String,
			pin: json['pin'] as String,
			nombre: json['nombre'] as String,
			tenantId: json['tenantId'] as String,
		);
	}
}

/// Administra perfiles biometricos por tenant en almacenamiento seguro.
class GestorAccesoBiometrico {
	GestorAccesoBiometrico({
		LocalAuthentication? autenticacionLocal,
		FlutterSecureStorage? almacen,
	}) : _auth = autenticacionLocal ?? LocalAuthentication(),
	     _almacen = almacen ??
	         const FlutterSecureStorage(
	         	aOptions: AndroidOptions(),
	         );

	final LocalAuthentication _auth;
	final FlutterSecureStorage _almacen;

	/// Indica si el dispositivo puede usar biometria.
	Future<bool> estaDisponible() async {
		try {
			final compatible = await _auth.isDeviceSupported();
			if (!compatible) {
				return false;
			}
			return await _auth.canCheckBiometrics;
		} on Object {
			return false;
		}
	}

	/// Etiqueta amigable segun el hardware (Face ID, huella, etc.).
	Future<String> etiquetaBiometria() async {
		try {
			final tipos = await _auth.getAvailableBiometrics();
			if (tipos.contains(BiometricType.face)) {
				return 'Face ID';
			}
			if (tipos.contains(BiometricType.fingerprint)) {
				return 'Huella';
			}
			if (tipos.contains(BiometricType.strong) || tipos.contains(BiometricType.weak)) {
				return 'Biometría';
			}
		} on Object {
			// Ignorar y usar etiqueta generica.
		}
		return 'Biometría';
	}

	/// Perfiles registrados para un tenant.
	Future<List<PerfilAccesoBiometrico>> listarPerfiles(String tenantId) async {
		final todos = await _leerTodos();
		return todos.where((p) => p.tenantId == tenantId).toList()
		  ..sort((a, b) => a.nombre.compareTo(b.nombre));
	}

	/// Guarda o actualiza el perfil del usuario tras un login exitoso con PIN.
	Future<void> registrarPerfil(PerfilAccesoBiometrico perfil) async {
		final todos = await _leerTodos();
		final filtrados = todos.where((p) => p.usuarioId != perfil.usuarioId).toList();
		filtrados.add(perfil);
		final porTenant = filtrados.where((p) => p.tenantId == perfil.tenantId).length;
		if (porTenant > _maxPerfilesPorDispositivo) {
			final antiguos = filtrados
				.where((p) => p.tenantId == perfil.tenantId && p.usuarioId != perfil.usuarioId)
				.toList();
			if (antiguos.isNotEmpty) {
				filtrados.remove(antiguos.first);
			}
		}
		await _guardarTodos(filtrados);
	}

	/// Elimina el perfil biometrico de un usuario.
	Future<void> eliminarPerfil(String usuarioId) async {
		final todos = await _leerTodos();
		await _guardarTodos(todos.where((p) => p.usuarioId != usuarioId).toList());
	}

	/// Solicita biometria y devuelve credenciales del usuario indicado.
	///
	/// Si [usuarioId] es null y hay un solo perfil en el tenant, usa ese.
	/// Si hay varios perfiles, [usuarioId] es obligatorio.
	Future<PerfilAccesoBiometrico?> autenticarYRecuperar({
		required String tenantId,
		String? usuarioId,
	}) async {
		final perfiles = await listarPerfiles(tenantId);
		if (perfiles.isEmpty) {
			return null;
		}
		final PerfilAccesoBiometrico? perfil;
		if (usuarioId != null) {
			final coincidencias = perfiles.where((p) => p.usuarioId == usuarioId);
			if (coincidencias.isEmpty) {
				return null;
			}
			perfil = coincidencias.first;
		} else if (perfiles.length == 1) {
			perfil = perfiles.first;
		} else {
			return null;
		}
		final disponible = await estaDisponible();
		if (!disponible) {
			return null;
		}
		final ok = await _auth.authenticate(
			localizedReason: 'Iniciar sesión como ${perfil.nombre}',
			options: const AuthenticationOptions(
				biometricOnly: true,
				stickyAuth: true,
			),
		);
		if (!ok) {
			return null;
		}
		return perfil;
	}

	Future<List<PerfilAccesoBiometrico>> _leerTodos() async {
		final raw = await _almacen.read(key: _claveAlmacenPerfiles);
		if (raw == null || raw.isEmpty) {
			return [];
		}
		try {
			final lista = jsonDecode(raw) as List<dynamic>;
			return lista
				.map((e) => PerfilAccesoBiometrico.fromJson(e as Map<String, dynamic>))
				.toList();
		} on Object {
			return [];
		}
	}

	Future<void> _guardarTodos(List<PerfilAccesoBiometrico> perfiles) async {
		final json = jsonEncode(perfiles.map((p) => p.toJson()).toList());
		await _almacen.write(key: _claveAlmacenPerfiles, value: json);
	}
}
