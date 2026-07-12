/// Repositorio de perfil de empleado.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Tarifa por hora y datos de nomina por usuario.
class EmpleadoPerfilRepository {
	EmpleadoPerfilRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<EmpleadoPerfil?> obtenerPorUsuario(String usuarioId) async {
		final filas = await _baseDatos.query(
			'empleado_perfil',
			where: 'usuario_id = ?',
			whereArgs: [usuarioId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<List<EmpleadoPerfil>> listarTodos() async {
		final filas = await _baseDatos.query('empleado_perfil');
		return filas.map(_mapear).toList();
	}

	Future<void> guardar(EmpleadoPerfil perfil) async {
		await _padresFk.asegurarUsuario(perfil.usuarioId);
		await _baseDatos.insert(
			'empleado_perfil',
			{
				'usuario_id': perfil.usuarioId,
				'tarifa_hora': perfil.tarifaHora,
				'tipo_pago': perfil.tipoPago,
				'actualizado_en': perfil.actualizadoEn.toIso8601String(),
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	EmpleadoPerfil _mapear(Map<String, Object?> fila) {
		return EmpleadoPerfil(
			usuarioId: fila['usuario_id'] as String,
			tarifaHora: (fila['tarifa_hora'] as num).toDouble(),
			tipoPago: fila['tipo_pago'] as String,
			actualizadoEn: DateTime.parse(fila['actualizado_en'] as String),
		);
	}
}
