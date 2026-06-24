/// Utilidades de distancia geografica.
library;

import 'dart:math' as math;

/// Distancia en metros entre dos coordenadas (Haversine).
double distanciaMetros({
	required double lat1,
	required double lon1,
	required double lat2,
	required double lon2,
}) {
	const radioTierra = 6371000.0;
	final dLat = _rad(lat2 - lat1);
	final dLon = _rad(lon2 - lon1);
	final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
		math.cos(_rad(lat1)) *
			math.cos(_rad(lat2)) *
			math.sin(dLon / 2) *
			math.sin(dLon / 2);
	final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
	return radioTierra * c;
}

double _rad(double grados) => grados * math.pi / 180;

/// Indica si un punto esta dentro del radio de una ubicacion.
bool dentroDeGeocerca({
	required double latitud,
	required double longitud,
	required double latCentro,
	required double lonCentro,
	required double radioMetros,
}) {
	return distanciaMetros(
		lat1: latitud,
		lon1: longitud,
		lat2: latCentro,
		lon2: lonCentro,
	) <= radioMetros;
}
