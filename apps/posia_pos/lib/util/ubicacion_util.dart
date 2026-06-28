/// Utilidades para permisos y lectura de ubicacion GPS.
library;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Solicita permiso de ubicacion mientras se usa la app.
Future<bool> solicitarPermisoUbicacion() async {
	final estado = await Permission.locationWhenInUse.request();
	return estado.isGranted;
}

/// Obtiene la posicion actual del dispositivo.
Future<Position> obtenerUbicacionActual() async {
	final concedido = await solicitarPermisoUbicacion();
	if (!concedido) {
		throw StateError(
			'Permita el acceso a la ubicación para usar el mapa',
		);
	}
	final gpsActivo = await Geolocator.isLocationServiceEnabled();
	if (!gpsActivo) {
		throw StateError('Active el GPS del dispositivo');
	}
	return Geolocator.getCurrentPosition(
		locationSettings: const LocationSettings(
			accuracy: LocationAccuracy.high,
			timeLimit: Duration(seconds: 20),
		),
	);
}
