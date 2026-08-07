/// Providers de asistencia (lista del dia, etc.).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';

import 'app_providers.dart';

/// Entradas de hoy (todas las tiendas). Se invalida tras sync automatico.
final entradasAsistenciaDiaProvider =
	FutureProvider<List<RegistroAsistencia>>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioAsistencia?.listarEntradasDelDia(
			todasLasTiendas: true,
		) ??
		[];
});
