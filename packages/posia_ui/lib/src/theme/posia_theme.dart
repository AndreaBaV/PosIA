/// Tema visual accesible para interfaz de caja POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';

/// Colores semanticos del POS segun guia UI.
class PosiaColors {
	PosiaColors._();

	/// Verde para accion de cobro.
	static const Color cobrar = Color(0xFF2E7D32);

	/// Rojo para cancelar o eliminar.
	static const Color cancelar = Color(0xFFC62828);

	/// Gris neutro para acciones secundarias.
	static const Color neutro = Color(0xFF424242);

	/// Fondo principal de caja.
	static const Color fondo = Color(0xFFF5F5F5);

	/// Superficie de tarjetas de producto.
	static const Color tarjeta = Color(0xFFFFFFFF);
}

/// Provee [ThemeData] configurado para modo caja.
class PosiaTheme {
	PosiaTheme._();

	/// Construye tema Material 3 orientado a iconos grandes.
	///
	/// Retorna [ThemeData] listo para [MaterialApp].
	static ThemeData construirTema() {
		const esquema = ColorScheme(
			brightness: Brightness.light,
			primary: PosiaColors.cobrar,
			onPrimary: Colors.white,
			secondary: PosiaColors.neutro,
			onSecondary: Colors.white,
			error: PosiaColors.cancelar,
			onError: Colors.white,
			surface: PosiaColors.tarjeta,
			onSurface: PosiaColors.neutro,
		);
		return ThemeData(
			useMaterial3: true,
			colorScheme: esquema,
			scaffoldBackgroundColor: PosiaColors.fondo,
			cardTheme: CardThemeData(
				color: PosiaColors.tarjeta,
				elevation: 1.0,
				shadowColor: Colors.black.withValues(alpha: 0.06),
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
			),
			navigationBarTheme: NavigationBarThemeData(
				backgroundColor: PosiaColors.tarjeta,
				indicatorColor: PosiaColors.cobrar.withValues(alpha: 0.15),
				labelTextStyle: WidgetStateProperty.resolveWith((states) {
					if (states.contains(WidgetState.selected)) {
						return const TextStyle(
							fontWeight: FontWeight.w600,
							color: PosiaColors.cobrar,
						);
					}
					return const TextStyle(color: PosiaColors.neutro);
				}),
			),
			appBarTheme: const AppBarTheme(
				centerTitle: false,
				elevation: 0.0,
				scrolledUnderElevation: 1.0,
			),
			textTheme: const TextTheme(
				headlineLarge: TextStyle(
					fontSize: 36.0,
					fontWeight: FontWeight.bold,
					color: PosiaColors.neutro,
				),
				titleLarge: TextStyle(
					fontSize: 20.0,
					fontWeight: FontWeight.w600,
					color: PosiaColors.neutro,
				),
				bodyLarge: TextStyle(
					fontSize: 16.0,
					color: PosiaColors.neutro,
				),
			),
		);
	}
}
