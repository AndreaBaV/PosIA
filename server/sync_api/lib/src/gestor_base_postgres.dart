/// Consulta, exporta y purga historial transaccional en Neon.
library;

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

import 'esquema_pos_postgres.dart';

/// Operaciones de gestion de almacenamiento sobre el esquema POS.
class GestorBasePostgres {
	GestorBasePostgres(this._sesion);

	final Session _sesion;

	static const _eventosPorGrupo = {
		GruposHistorialNeon.ventas: [
			'saleCompleted',
			'saleVoided',
			'salePartialReturn',
		],
		GruposHistorialNeon.compras: ['purchaseCompleted'],
		GruposHistorialNeon.traspasos: [
			'transferRequested',
			'transferCompleted',
		],
		GruposHistorialNeon.asistencia: [
			'attendanceChallengeCreated',
			'attendanceCheckedIn',
			'attendanceCheckedOut',
		],
		GruposHistorialNeon.nomina: ['payrollPeriodClosed'],
		GruposHistorialNeon.turnos: ['cashShiftUpserted'],
		GruposHistorialNeon.cotizaciones: ['quoteUpserted', 'quoteDeleted'],
		GruposHistorialNeon.pedidos: ['orderUpserted'],
		GruposHistorialNeon.logSync: EsquemaPosPostgres.tiposHistorialPurgable,
	};

	static const _exportes = <String, _ConsultaHistorial>{
		GruposHistorialNeon.ventas: _ConsultaHistorial(
			tablas: [
				_TablaFecha('sales', 'creada_en'),
				_TablaFecha('sale_lines', 'venta_id', viaPadre: _PadreFecha('sales', 'id', 'creada_en')),
			],
		),
		GruposHistorialNeon.compras: _ConsultaHistorial(
			tablas: [
				_TablaFecha('purchases', 'creada_en'),
				_TablaFecha(
					'purchase_lines',
					'compra_id',
					viaPadre: _PadreFecha('purchases', 'id', 'creada_en'),
				),
				_TablaFecha(
					'purchase_allocations',
					'compra_id',
					viaPadre: _PadreFecha('purchases', 'id', 'creada_en'),
				),
			],
		),
		GruposHistorialNeon.traspasos: _ConsultaHistorial(
			tablas: [
				_TablaFecha('transfers', 'solicitado_en'),
				_TablaFecha(
					'transfer_lines',
					'transfer_id',
					viaPadre: _PadreFecha('transfers', 'id', 'solicitado_en'),
				),
			],
		),
		GruposHistorialNeon.asistencia: _ConsultaHistorial(
			tablas: [
				_TablaFecha('attendance_records', 'entrada_en'),
			],
		),
		GruposHistorialNeon.nomina: _ConsultaHistorial(
			tablas: [
				_TablaFecha('payroll_periods', 'fin_en'),
				_TablaFecha(
					'payroll_lines',
					'periodo_id',
					viaPadre: _PadreFecha('payroll_periods', 'id', 'fin_en'),
				),
			],
		),
		GruposHistorialNeon.turnos: _ConsultaHistorial(
			tablas: [
				_TablaFecha('cash_shifts', 'abierto_en'),
			],
		),
		GruposHistorialNeon.cotizaciones: _ConsultaHistorial(
			tablas: [
				_TablaFecha('quotes', 'creada_en'),
				_TablaFecha(
					'quote_lines',
					'cotizacion_id',
					viaPadre: _PadreFecha('quotes', 'id', 'creada_en'),
				),
			],
		),
		GruposHistorialNeon.pedidos: _ConsultaHistorial(
			tablas: [
				_TablaFecha(
					'orders',
					'creado_en',
					extraWhere: "estado IN ('entregado', 'cancelado')",
				),
				_TablaFecha(
					'order_lines',
					'pedido_id',
					viaPadre: _PadreFecha('orders', 'id', 'creado_en'),
					extraWhere: "p.estado IN ('entregado', 'cancelado')",
				),
			],
		),
	};

	Future<UsoBaseNeon> auditarUso() async {
		final total = await _sesion.execute(
			'SELECT pg_database_size(current_database())',
		);
		final bytesUsados = (total.first[0] as num?)?.toInt() ?? 0;
		final filas = await _sesion.execute('''
			SELECT c.relname AS tabla,
				COALESCE(s.n_live_tup, 0) AS filas,
				pg_total_relation_size(c.oid) AS bytes
			FROM pg_class c
			JOIN pg_namespace n ON n.oid = c.relnamespace
			LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
			WHERE n.nspname = 'public' AND c.relkind = 'r'
			ORDER BY pg_total_relation_size(c.oid) DESC
		''');
		final tablas = filas.map((fila) {
			final m = fila.toColumnMap();
			return FilaUsoTablaNeon(
				tabla: m['tabla'] as String? ?? '',
				filas: (m['filas'] as num?)?.toInt() ?? 0,
				bytes: (m['bytes'] as num?)?.toInt() ?? 0,
			);
		}).toList();
		return UsoBaseNeon(bytesUsados: bytesUsados, tablas: tablas);
	}

	Future<ResultadoExportacionNeon> exportar({
		required DateTime antesDe,
		required List<String> grupos,
	}) async {
		final validos = GruposHistorialNeon.validar(grupos);
		final corte = antesDe.toUtc().toIso8601String();
		final hojas = <HojaExportacionNeon>[];
		var truncado = false;
		for (final grupo in validos) {
			if (grupo == GruposHistorialNeon.logSync) {
				final hoja = await _exportarEventos(corte);
				if (hoja.filas.length >= LIMITE_FILAS_EXPORT_NEON) {
					truncado = true;
				}
				hojas.add(hoja);
				continue;
			}
			final consulta = _exportes[grupo];
			if (consulta == null) {
				continue;
			}
			for (final tabla in consulta.tablas) {
				final hoja = await _exportarTabla(tabla, corte);
				if (hoja.filas.length >= LIMITE_FILAS_EXPORT_NEON) {
					truncado = true;
				}
				if (hoja.columnas.isNotEmpty) {
					hojas.add(hoja);
				}
			}
		}
		return ResultadoExportacionNeon(
			hojas: hojas,
			truncado: truncado,
			antesDe: antesDe.toUtc(),
		);
	}

	Future<ResultadoPurgaNeon> purgar({
		required DateTime antesDe,
		required List<String> grupos,
	}) async {
		final validos = GruposHistorialNeon.validar(grupos);
		final corte = antesDe.toUtc().toIso8601String();
		var total = 0;
		for (final grupo in validos) {
			total += await _purgarGrupo(grupo, corte);
		}
		return ResultadoPurgaNeon(filasEliminadas: total, grupos: validos);
	}

	Future<HojaExportacionNeon> _exportarTabla(
		_TablaFecha tabla,
		String corte,
	) async {
		final extra = tabla.extraWhere == null ? '' : 'AND ${tabla.extraWhere}';
		final sql = tabla.viaPadre == null
			? '''
				SELECT * FROM ${tabla.nombre}
				WHERE ${tabla.columnaFecha} < @corte
				$extra
				ORDER BY ${tabla.columnaFecha}
				LIMIT $LIMITE_FILAS_EXPORT_NEON
			'''
			: '''
				SELECT h.* FROM ${tabla.nombre} h
				INNER JOIN ${tabla.viaPadre!.tabla} p
					ON p.${tabla.viaPadre!.columnaId} = h.${tabla.columnaFecha}
				WHERE p.${tabla.viaPadre!.columnaFecha} < @corte
				$extra
				LIMIT $LIMITE_FILAS_EXPORT_NEON
			''';
		final resultado = await _sesion.execute(
			Sql.named(sql),
			parameters: {'corte': corte},
		);
		if (resultado.isEmpty) {
			return HojaExportacionNeon(
				nombre: tabla.nombre,
				columnas: const [],
				filas: const [],
			);
		}
		final columnas = resultado.first.toColumnMap().keys.map((k) => '$k').toList();
		final filas = resultado.map((fila) {
			final mapa = fila.toColumnMap();
			return columnas.map((c) => _texto(mapa[c])).toList();
		}).toList();
		return HojaExportacionNeon(
			nombre: tabla.nombre,
			columnas: columnas,
			filas: filas,
		);
	}

	Future<HojaExportacionNeon> _exportarEventos(String corte) async {
		final tipos = EsquemaPosPostgres.tiposHistorialPurgable
			.map((t) => "'$t'")
			.join(', ');
		final resultado = await _sesion.execute(
			Sql.named('''
				SELECT seq, id, store_id, device_id, type, payload, created_at
				FROM sync_events
				WHERE created_at < @corte::timestamptz
					AND type IN ($tipos)
				ORDER BY seq
				LIMIT $LIMITE_FILAS_EXPORT_NEON
			'''),
			parameters: {'corte': corte},
		);
		const columnas = [
			'seq',
			'id',
			'store_id',
			'device_id',
			'type',
			'payload',
			'created_at',
		];
		final filas = resultado.map((fila) {
			final mapa = fila.toColumnMap();
			return columnas.map((c) => _texto(mapa[c])).toList();
		}).toList();
		return HojaExportacionNeon(
			nombre: 'sync_events',
			columnas: columnas,
			filas: filas,
		);
	}

	Future<int> _purgarGrupo(String grupo, String corte) async {
		var n = 0;
		switch (grupo) {
			case GruposHistorialNeon.ventas:
				n += await _borrarHijos(
					'DELETE FROM sale_lines WHERE venta_id IN (SELECT id FROM sales WHERE creada_en < @corte)',
					corte,
				);
				n += await _borrar(
					'DELETE FROM sales WHERE creada_en < @corte',
					corte,
				);
			case GruposHistorialNeon.compras:
				n += await _borrarHijos(
					'DELETE FROM purchase_allocations WHERE compra_id IN (SELECT id FROM purchases WHERE creada_en < @corte)',
					corte,
				);
				n += await _borrarHijos(
					'DELETE FROM purchase_lines WHERE compra_id IN (SELECT id FROM purchases WHERE creada_en < @corte)',
					corte,
				);
				n += await _borrar(
					'DELETE FROM purchases WHERE creada_en < @corte',
					corte,
				);
			case GruposHistorialNeon.traspasos:
				n += await _borrarHijos(
					'DELETE FROM transfer_lines WHERE transfer_id IN (SELECT id FROM transfers WHERE solicitado_en < @corte)',
					corte,
				);
				n += await _borrar(
					'DELETE FROM transfers WHERE solicitado_en < @corte',
					corte,
				);
			case GruposHistorialNeon.asistencia:
				n += await _borrar(
					'DELETE FROM attendance_records WHERE entrada_en < @corte',
					corte,
				);
				n += await _borrar(
					'DELETE FROM attendance_challenges WHERE activo = 0 AND expira_en < @corte',
					corte,
				);
			case GruposHistorialNeon.nomina:
				n += await _borrarHijos(
					'DELETE FROM payroll_lines WHERE periodo_id IN (SELECT id FROM payroll_periods WHERE fin_en < @corte)',
					corte,
				);
				n += await _borrar(
					'DELETE FROM payroll_periods WHERE fin_en < @corte',
					corte,
				);
			case GruposHistorialNeon.turnos:
				n += await _borrar(
					'DELETE FROM cash_shifts WHERE abierto_en < @corte',
					corte,
				);
			case GruposHistorialNeon.cotizaciones:
				n += await _borrarHijos(
					'DELETE FROM quote_lines WHERE cotizacion_id IN (SELECT id FROM quotes WHERE creada_en < @corte)',
					corte,
				);
				n += await _borrar(
					'DELETE FROM quotes WHERE creada_en < @corte',
					corte,
				);
			case GruposHistorialNeon.pedidos:
				n += await _borrarHijos(
					'''
						DELETE FROM order_lines WHERE pedido_id IN (
							SELECT id FROM orders
							WHERE creado_en < @corte
								AND estado IN ('entregado', 'cancelado')
						)
					''',
					corte,
				);
				n += await _borrar(
					'''
						DELETE FROM orders
						WHERE creado_en < @corte
							AND estado IN ('entregado', 'cancelado')
					''',
					corte,
				);
			case GruposHistorialNeon.logSync:
				break;
		}
		final tipos = _eventosPorGrupo[grupo];
		if (tipos != null && tipos.isNotEmpty) {
			n += await _borrarEventos(tipos, corte);
		}
		return n;
	}

	Future<int> _borrar(String sql, String corte) async {
		final r = await _sesion.execute(
			Sql.named(sql),
			parameters: {'corte': corte},
		);
		return r.affectedRows;
	}

	Future<int> _borrarHijos(String sql, String corte) => _borrar(sql, corte);

	Future<int> _borrarEventos(List<String> tipos, String corte) async {
		final lista = tipos.map((t) => "'$t'").join(', ');
		final r = await _sesion.execute(
			Sql.named('''
				DELETE FROM sync_events
				WHERE created_at < @corte::timestamptz
					AND type IN ($lista)
			'''),
			parameters: {'corte': corte},
		);
		return r.affectedRows;
	}

	static String _texto(Object? valor) {
		if (valor == null) {
			return '';
		}
		if (valor is DateTime) {
			return valor.toUtc().toIso8601String();
		}
		return '$valor';
	}
}

class _ConsultaHistorial {
	const _ConsultaHistorial({required this.tablas});

	final List<_TablaFecha> tablas;
}

class _TablaFecha {
	const _TablaFecha(
		this.nombre,
		this.columnaFecha, {
		this.viaPadre,
		this.extraWhere,
	});

	final String nombre;
	final String columnaFecha;
	final _PadreFecha? viaPadre;
	final String? extraWhere;
}

class _PadreFecha {
	const _PadreFecha(this.tabla, this.columnaId, this.columnaFecha);

	final String tabla;
	final String columnaId;
	final String columnaFecha;
}
