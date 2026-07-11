/// Repositorio SQLite de roles personalizados.
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Persiste roles personalizados y sus permisos.
class RolPersonalizadoRepository {
	RolPersonalizadoRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<List<RolPersonalizado>> listarTodos() async {
		final filas = await _baseDatos.query(
			'roles_personalizados',
			orderBy: 'nombre ASC',
		);
		final roles = <RolPersonalizado>[];
		for (final fila in filas) {
			roles.add(await _mapear(fila));
		}
		return roles;
	}

	Future<List<RolPersonalizado>> listarActivos() async {
		final filas = await _baseDatos.query(
			'roles_personalizados',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		final roles = <RolPersonalizado>[];
		for (final fila in filas) {
			roles.add(await _mapear(fila));
		}
		return roles;
	}

	Future<RolPersonalizado?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'roles_personalizados',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<void> guardar(RolPersonalizado rol) async {
		await _padresFk.asegurarTienda(rol.tiendaId);
		await _baseDatos.transaction((tx) async {
			await tx.insert(
				'roles_personalizados',
				{
					'id': rol.id,
					'nombre': rol.nombre.trim(),
					'descripcion': rol.descripcion.trim(),
					'permisos_json': jsonEncode(rol.permisosAdmin),
					'categorias_json': jsonEncode(rol.categoriasPermitidas),
					'activo': rol.activo ? 1 : 0,
					'tienda_id': rol.tiendaId,
				},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
		});
	}

	Future<void> eliminarLogico(String id) async {
		await _baseDatos.update(
			'roles_personalizados',
			{'activo': 0},
			where: 'id = ?',
			whereArgs: [id],
		);
	}

	Future<RolPersonalizado> _mapear(Map<String, Object?> fila) async {
		final permisos = _decodificarLista(fila['permisos_json'] as String?);
		final categorias = _decodificarLista(fila['categorias_json'] as String?);
		return RolPersonalizado(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			descripcion: fila['descripcion'] as String? ?? '',
			permisosAdmin: permisos,
			categoriasPermitidas: categorias,
			activo: (fila['activo'] as int) == 1,
			tiendaId: fila['tienda_id'] as String?,
		);
	}

	List<String> _decodificarLista(String? crudo) {
		if (crudo == null || crudo.isEmpty) {
			return [];
		}
		try {
			final lista = jsonDecode(crudo);
			if (lista is! List) {
				return [];
			}
			return lista.map((e) => e.toString()).toList();
		} on Object {
			return [];
		}
	}
}
