/// Backfill de un solo uso: reproyecta a sus tablas espejo los eventos
/// purchaseCompleted/payrollPeriodClosed/employeeProfileUpserted/attendance*
/// que quedaron varados en sync_events por el bug de IDs de evento no
/// deterministas (ver docs/mantenimiento/AUDITORIA_INICIAL.md).
///
/// Idempotente: solo corre una vez (marca schema_meta), y cada evento se
/// aplica con la misma logica ON CONFLICT que usa el hub en producción.
/// Solo lectura hasta que confirma qué va a aplicar; luego escribe.
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../lib/src/evento_hub.dart';
import '../lib/src/proyector_eventos_postgres.dart';

const _claveMeta = 'mirror_backfill_ops_v1';
const _tipos = [
	'purchaseCompleted',
	'payrollPeriodClosed',
	'employeeProfileUpserted',
	'attendanceChallengeCreated',
	'attendanceCheckedIn',
	'attendanceCheckedOut',
];

Future<void> main() async {
	final envPath = File('.env');
	if (!envPath.existsSync()) {
		stderr.writeln('Falta .env con DATABASE_URL');
		exit(1);
	}
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

	final yaCorrio = await conn.execute(
		Sql.named('SELECT valor FROM schema_meta WHERE clave = @c'),
		parameters: {'c': _claveMeta},
	);
	if (yaCorrio.isNotEmpty) {
		print('Backfill $_claveMeta ya se corrio antes (${yaCorrio.first[0]}). Nada que hacer.');
		await conn.close();
		return;
	}

	final listaTipos = _tipos.map((t) => "'$t'").join(', ');
	final filas = await conn.execute('''
		SELECT seq, id, store_id, device_id, type, payload, created_at
		FROM sync_events
		WHERE type IN ($listaTipos)
		ORDER BY seq ASC
	''');
	print('Eventos varados encontrados: ${filas.length}');
	for (final fila in filas) {
		final cols = fila.toColumnMap();
		print('  seq=${cols['seq']} tipo=${cols['type']} id=${cols['id']}');
	}

	var aplicados = 0;
	var errores = 0;
	for (final fila in filas) {
		final cols = fila.toColumnMap();
		final payloadCrudo = cols['payload'];
		final payload = payloadCrudo is String
			? jsonDecode(payloadCrudo) as Map<String, Object?>
			: Map<String, Object?>.from(payloadCrudo as Map<Object?, Object?>);
		final evento = EventoHub(
			seq: cols['seq'] as int,
			id: cols['id'] as String,
			tiendaId: cols['store_id'] as String,
			dispositivoId: cols['device_id'] as String,
			tipo: cols['type'] as String,
			payload: payload,
			creadoEn: (cols['created_at'] as DateTime).toUtc(),
		);
		try {
			await conn.runTx((tx) async {
				await ProyectorEventosPostgres(tx).aplicar(evento);
			});
			aplicados++;
		} on Object catch (e) {
			errores++;
			stdout.writeln('Error en ${cols['type']} (seq=${cols['seq']}): $e');
		}
	}
	print('Aplicados: $aplicados, errores: $errores');

	await conn.execute(
		Sql.named('''
			INSERT INTO schema_meta (clave, valor)
			VALUES (@c, @v)
			ON CONFLICT (clave) DO NOTHING
		'''),
		parameters: {'c': _claveMeta, 'v': DateTime.now().toUtc().toIso8601String()},
	);
	print('Marcado $_claveMeta como corrido.');

	await conn.close();
}
