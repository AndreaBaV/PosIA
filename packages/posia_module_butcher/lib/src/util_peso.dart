/// Utilidades de conversion y validacion de peso para carniceria.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Convierte gramos provenientes de bascula a kilogramos comerciales.
///
/// [gramos] Peso estable en gramos.
/// Retorna peso en kilogramos con tres decimales.
double convertirGramosAKilogramos(double gramos) {
	final kilogramos = gramos / 1000.0;
	return double.parse(kilogramos.toStringAsFixed(3));
}

/// Valida que el peso en kilogramos cumpla minimo operativo.
///
/// [pesoKg] Peso en kilogramos a validar.
/// Retorna verdadero si supera minimo configurado.
bool validarPesoMinimoKg(double pesoKg) {
	final gramos = pesoKg * 1000.0;
	return gramos >= PESO_MINIMO_GRAMOS_CARNICERIA;
}

/// Formatea peso en kilogramos para visualizacion en caja.
///
/// [pesoKg] Peso en kilogramos.
/// Retorna cadena legible con unidad kg.
String formatearPesoKg(double pesoKg) {
	return '${pesoKg.toStringAsFixed(3)} kg';
}
