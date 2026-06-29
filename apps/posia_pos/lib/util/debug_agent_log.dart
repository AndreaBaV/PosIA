/// Instrumentacion temporal de depuracion (sesion a72769).
library;

import 'dart:convert';
import 'dart:io';

void debugAgentLog(
	String location,
	String message,
	Map<String, Object?> data, {
	String hypothesisId = '',
	String runId = 'pre-fix',
}) {
	// #region agent log
	try {
		final line = jsonEncode({
			'sessionId': 'a72769',
			'timestamp': DateTime.now().millisecondsSinceEpoch,
			'location': location,
			'message': message,
			'data': data,
			'hypothesisId': hypothesisId,
			'runId': runId,
		});
		File(r'c:\Users\andyb\ProyectosPersonales2026\POSIA\debug-a72769.log')
			.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
	} on Object {
		// Ignorar fallos de logging en depuracion.
	}
	// #endregion
}
