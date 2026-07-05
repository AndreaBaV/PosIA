/// Wrapper de speech-to-text para iOS y Android.
library;

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Captura voz del microfono y entrega transcripcion en espanol.
class ServicioVozDispositivo {
	final SpeechToText _motor = SpeechToText();
	bool _inicializado = false;
	String? _ultimoError;

	/// Ultimo error reportado por el motor STT.
	String? get ultimoError => _ultimoError;

	/// Prepara motor STT del dispositivo.
	Future<bool> inicializar() async {
		_ultimoError = null;
		_inicializado = await _motor.initialize(
			onError: (detalle) => _ultimoError = detalle.errorMsg,
			onStatus: (_) {},
		);
		return _inicializado;
	}

	/// Indica si el microfono esta escuchando.
	bool get escuchando => _motor.isListening;

	/// Inicia escucha continua hasta pausa o detencion manual.
	Future<void> escuchar({
		required void Function(String texto, bool esFinal) onTranscripcion,
	}) async {
		if (!_inicializado) {
			final ok = await inicializar();
			if (!ok) {
				return;
			}
		}
		if (_motor.isListening) {
			await _motor.stop();
		}
		await _motor.listen(
			onResult: (SpeechRecognitionResult resultado) {
				onTranscripcion(resultado.recognizedWords, resultado.finalResult);
			},
			listenOptions: SpeechListenOptions(
				localeId: 'es_MX',
				listenMode: ListenMode.dictation,
				partialResults: true,
				listenFor: const Duration(seconds: 120),
				pauseFor: const Duration(seconds: 5),
				cancelOnError: false,
			),
		);
	}

	/// Detiene captura de voz.
	Future<void> detener() async {
		if (_motor.isListening) {
			await _motor.stop();
		}
	}
}
