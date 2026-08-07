/// Auditoria de tablas de asistencia en Neon (solo lectura).
import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main() async {
	final envPath = File('.env');
	final line = envPath
		.readAsLinesSync()
		.firstWhere((l) => l.startsWith('DATABASE_URL='));
	final uri = Uri.parse(line.substring('DATABASE_URL='.length).trim());
	final info = uri.userInfo.split(':');
	final conn = await Connection.open(
		Endpoint(
			host: uri.host,
			port: uri.hasPort ? uri.port : 5432,
			database: uri.pathSegments.first,
			username: info[0],
			password: info.length > 1 ? info.sublist(1).join(':') : '',
		),
		settings: ConnectionSettings(sslMode: SslMode.require),
	);

	print('=== attendance_records ===');
	final countR = await conn.execute('SELECT COUNT(*) FROM attendance_records');
	print('total: ${countR.first.first}');

	final records = await conn.execute('''
		SELECT r.id, r.usuario_id, r.tienda_id, r.entrada_en, r.salida_en,
			r.metodo, r.desafio_id, r.latitud, r.longitud,
			u.nombre AS usuario_nombre, s.nombre AS tienda_nombre
		FROM attendance_records r
		LEFT JOIN users u ON u.id = r.usuario_id
		LEFT JOIN stores s ON s.id = r.tienda_id
		ORDER BY r.entrada_en DESC
		LIMIT 50
	''');
	for (final row in records) {
		print(row.toColumnMap());
	}

	print('\n=== anomalias records ===');
	final sinUsuario = await conn.execute('''
		SELECT COUNT(*) FROM attendance_records r
		LEFT JOIN users u ON u.id = r.usuario_id
		WHERE u.id IS NULL
	''');
	print('sin usuario en users: ${sinUsuario.first.first}');

	final sinTienda = await conn.execute('''
		SELECT COUNT(*) FROM attendance_records r
		LEFT JOIN stores s ON s.id = r.tienda_id
		WHERE s.id IS NULL
	''');
	print('sin tienda en stores: ${sinTienda.first.first}');

	final stubs = await conn.execute('''
		SELECT r.id, r.usuario_id, u.nombre, u.codigo, r.entrada_en, r.metodo
		FROM attendance_records r
		JOIN users u ON u.id = r.usuario_id
		WHERE u.nombre = 'Usuario' OR u.codigo LIKE 'sync-%' OR u.pin_credencial = 'sync'
		ORDER BY r.entrada_en DESC
		LIMIT 30
	''');
	print('ligados a usuario stub (${stubs.length}):');
	for (final row in stubs) {
		print(row.toColumnMap());
	}

	final dupAbiertas = await conn.execute('''
		SELECT usuario_id, COUNT(*) AS n
		FROM attendance_records
		WHERE salida_en IS NULL
		GROUP BY usuario_id
		HAVING COUNT(*) > 1
	''');
	print('usuarios con >1 entrada abierta: ${dupAbiertas.length}');
	for (final row in dupAbiertas) {
		print(row.toColumnMap());
	}

	final hoy = await conn.execute('''
		SELECT r.entrada_en, r.salida_en, r.metodo, r.tienda_id, s.nombre,
			r.usuario_id, u.nombre AS unombre
		FROM attendance_records r
		LEFT JOIN users u ON u.id = r.usuario_id
		LEFT JOIN stores s ON s.id = r.tienda_id
		WHERE r.entrada_en >= '2026-08-07'
		ORDER BY r.entrada_en
	''');
	print('\nregistros desde 2026-08-07 (${hoy.length}):');
	for (final row in hoy) {
		print(row.toColumnMap());
	}

	print('\n=== attendance_challenges ===');
	final countC = await conn.execute('SELECT COUNT(*) FROM attendance_challenges');
	print('total: ${countC.first.first}');
	final challenges = await conn.execute('''
		SELECT id, tienda_id, expira_en, creado_por, activo, latitud, longitud,
			radio_metros, LEFT(pin_hash, 12) AS pin_hash_prefijo
		FROM attendance_challenges
		ORDER BY expira_en DESC
		LIMIT 30
	''');
	for (final row in challenges) {
		print(row.toColumnMap());
	}

	final activos = await conn.execute('''
		SELECT tienda_id, COUNT(*) FROM attendance_challenges
		WHERE activo = 1 GROUP BY tienda_id
	''');
	print('activos por tienda: $activos');

	print('\n=== sync_events attendance* recientes ===');
	final events = await conn.execute('''
		SELECT seq, id, store_id, device_id, type, created_at,
			LEFT(payload::text, 180) AS payload_preview
		FROM sync_events
		WHERE type LIKE 'attendance%'
		ORDER BY seq DESC
		LIMIT 40
	''');
	for (final row in events) {
		print(row.toColumnMap());
	}

	print('\n=== preocupantes ===');
	final abiertas = await conn.execute('''
		SELECT r.id, r.usuario_id, u.nombre, r.tienda_id, r.entrada_en,
			r.salida_en, r.metodo,
			(SELECT COUNT(*) FROM sync_events e
			 WHERE e.type = 'attendanceCheckedOut'
			   AND e.payload->>'registroId' = r.id::text) AS eventos_salida
		FROM attendance_records r
		LEFT JOIN users u ON u.id = r.usuario_id
		WHERE r.salida_en IS NULL
		ORDER BY r.entrada_en
	''');
	print('entradas abiertas (${abiertas.length}):');
	for (final row in abiertas) {
		print(row.toColumnMap());
	}

	final vencidosActivos = await conn.execute('''
		SELECT id, tienda_id, expira_en, activo, length(pin_hash) AS hash_len
		FROM attendance_challenges
		WHERE activo = 1 AND expira_en < NOW()
		ORDER BY expira_en
	''');
	print('desafios activo=1 pero vencidos (${vencidosActivos.length}):');
	for (final row in vencidosActivos) {
		print(row.toColumnMap());
	}

	final hashes = await conn.execute('''
		SELECT id, tienda_id, length(pin_hash) AS hash_len, LEFT(pin_hash, 20) AS prefijo
		FROM attendance_challenges
		ORDER BY expira_en DESC
		LIMIT 8
	''');
	print('longitud pin_hash:');
	for (final row in hashes) {
		print(row.toColumnMap());
	}

	final stores = await conn.execute('''
		SELECT id, nombre, latitud, longitud, radio_metros
		FROM stores
		WHERE id IN ('tienda-norte', 'tienda-centro', 'tienda-sur')
	''');
	print('coords stores:');
	for (final row in stores) {
		print(row.toColumnMap());
	}

	final postWendy = await conn.execute('''
		SELECT seq, type, created_at, LEFT(payload::text, 220) AS payload
		FROM sync_events
		WHERE type LIKE 'attendance%' AND created_at >= '2026-08-07 23:31:00'
		ORDER BY seq
	''');
	print('eventos desde 23:31Z (${postWendy.length}):');
	for (final row in postWendy) {
		print(row.toColumnMap());
	}

	final julioLargo = await conn.execute('''
		SELECT id, usuario_id, entrada_en, salida_en,
			EXTRACT(EPOCH FROM (salida_en - entrada_en))/3600 AS horas_abierta
		FROM attendance_records
		WHERE salida_en IS NOT NULL
			AND EXTRACT(EPOCH FROM (salida_en - entrada_en)) > 12 * 3600
		ORDER BY entrada_en
	''');
	print('sesiones >12h cerradas (${julioLargo.length}):');
	for (final row in julioLargo) {
		print(row.toColumnMap());
	}

	await conn.close();
}
