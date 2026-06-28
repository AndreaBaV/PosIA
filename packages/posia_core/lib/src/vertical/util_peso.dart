/// Utilidades de conversion y validacion de peso para venta por kg.
library;

import 'package:posia_core/src/constants/posia_constants.dart';

/// Convierte gramos provenientes de bascula a kilogramos comerciales.
double convertirGramosAKilogramos(double gramos) {
	final kilogramos = gramos / 1000.0;
	return double.parse(kilogramos.toStringAsFixed(3));
}

/// Valida que el peso en kilogramos cumpla minimo operativo.
bool validarPesoMinimoKg(double pesoKg) {
	final gramos = pesoKg * 1000.0;
	return gramos >= PESO_MINIMO_GRAMOS_CARNICERIA;
}

/// Formatea peso en kilogramos para visualizacion en caja.
String formatearPesoKg(double pesoKg) {
	return '${pesoKg.toStringAsFixed(3)} kg';
}
