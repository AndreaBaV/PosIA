/// Mapa de iconos Material disponibles para categorias POSIA.
library;

import 'package:flutter/material.dart';

/// Resuelve iconos y colores de categorias para UI.
class IconosCategoria {
	IconosCategoria._();

	/// Iconos seleccionables al crear o editar categoria.
	static const opciones = <String, IconData>{
		'shopping_basket': Icons.shopping_basket,
		'local_drink': Icons.local_drink,
		'rice_bowl': Icons.rice_bowl,
		'water_drop': Icons.water_drop,
		'set_meal': Icons.set_meal,
		'medication': Icons.medication,
		'bakery_dining': Icons.bakery_dining,
		'egg': Icons.egg,
		'cleaning_services': Icons.cleaning_services,
		'local_grocery_store': Icons.local_grocery_store,
		'fastfood': Icons.fastfood,
		'icecream': Icons.icecream,
	};

	/// Colores predefinidos para categorias.
	static const colores = <String, String>{
		'Verde': '#4CAF50',
		'Azul': '#2196F3',
		'Naranja': '#FF9800',
		'Morado': '#9C27B0',
		'Cafe': '#795548',
		'Rojo': '#F44336',
		'Teal': '#009688',
		'Indigo': '#3F51B5',
	};

	/// Resuelve [IconData] desde nombre persistido.
	static IconData resolver(String nombre) {
		return opciones[nombre] ?? Icons.category;
	}

	/// Resuelve [Color] desde hex (#RRGGBB).
	static Color resolverColor(String hex) {
		final limpio = hex.replaceFirst('#', '');
		if (limpio.length != 6) {
			return Colors.green;
		}
		return Color(int.parse('FF$limpio', radix: 16));
	}

	/// Etiqueta legible del icono (sin guiones bajos).
	static String etiquetaIcono(String nombre) {
		return nombre.replaceAll('_', ' ');
	}
}
