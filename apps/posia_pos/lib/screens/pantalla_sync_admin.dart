/// Pantalla de estado, configuracion de hub y sync manual.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 16:00:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

/// Muestra cola de eventos, URL del hub y permite sync manual.
class PantallaSyncAdmin extends ConsumerStatefulWidget {
	/// Crea pantalla de sincronizacion admin.
	const PantallaSyncAdmin({super.key});

	@override
	ConsumerState<PantallaSyncAdmin> createState() => _PantallaSyncAdminState();
}

/// Estado de pantalla sync con configuracion y accion manual.
class _PantallaSyncAdminState extends ConsumerState<PantallaSyncAdmin> {
	final TextEditingController _controladorHubUrl = TextEditingController();
	final TextEditingController _controladorApiKey = TextEditingController();
	bool _sincronizando = false;
	bool _urlCargada = false;
	bool _apiKeyCargada = false;
	String? _mensajeResultado;

	@override
	void dispose() {
		_controladorHubUrl.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final estadoAsync = ref.watch(_estadoSyncProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Sincronizacion'),
			),
			body: estadoAsync.when(
				data: (estado) {
					_precargarUrl(estado.hubUrl, estado.hubApiKey);
					return _ConstruirContenidoSync(
						estado: estado,
						sincronizando: _sincronizando,
						mensajeResultado: _mensajeResultado,
						controladorHubUrl: _controladorHubUrl,
						controladorApiKey: _controladorApiKey,
						alSincronizar: _ejecutarSyncManual,
						alGuardarHubUrl: _guardarHubUrl,
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (error, _) => Center(child: Text(error.toString())),
			),
		);
	}

	/// Ejecuta ciclo completo de sincronizacion manual.
	Future<void> _ejecutarSyncManual() async {
		setState(() {
			_sincronizando = true;
			_mensajeResultado = null;
		});
		final servicio = await ref.read(servicioAdminProvider.future);
		final resultado = await servicio.sincronizarManual();
		ref.invalidate(_estadoSyncProvider);
		setState(() {
			_sincronizando = false;
			_mensajeResultado = resultado.hubDisponible
				? 'Enviados: ${resultado.eventosEnviados} · Recibidos: ${resultado.eventosRecibidos}'
				: 'Hub no configurado o sin conexion';
		});
	}

	/// Guarda URL del hub y reconstruye servicios de sync.
	Future<void> _guardarHubUrl() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarHubUrl(_controladorHubUrl.text);
		await servicio.guardarHubApiKey(_controladorApiKey.text);
		ref.invalidate(contenedorServiciosProvider);
		ref.invalidate(sincronizadorAutomaticoProvider);
		ref.invalidate(_estadoSyncProvider);
		setState(() {
			_mensajeResultado = 'URL del hub guardada';
		});
	}

	/// Carga URL configurada en el campo de texto una sola vez.
	///
	/// [urlActual] URL persistida en el dispositivo.
	void _precargarUrl(String urlActual, String apiKey) {
		if (!_urlCargada) {
			_controladorHubUrl.text = urlActual;
			_urlCargada = true;
		}
		if (!_apiKeyCargada) {
			_controladorApiKey.text = apiKey;
			_apiKeyCargada = true;
		}
	}
}

/// Provider de estado sync admin con URL configurada.
final _estadoSyncProvider = FutureProvider<_EstadoPantallaSync>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final estado = await servicio.obtenerEstadoSync();
	final hubUrl = await servicio.obtenerHubUrl();
	final hubApiKey = await servicio.obtenerHubApiKey();
	return _EstadoPantallaSync(
		estado: estado,
		hubUrl: hubUrl,
		hubApiKey: hubApiKey,
	);
});

/// Estado combinado de cola y configuracion para la pantalla.
class _EstadoPantallaSync {
	const _EstadoPantallaSync({
		required this.estado,
		required this.hubUrl,
		required this.hubApiKey,
	});

	final EstadoSyncAdmin estado;
	final String hubUrl;
	final String hubApiKey;
}

/// Contenido visual del panel de sincronizacion.
class _ConstruirContenidoSync extends StatelessWidget {
	const _ConstruirContenidoSync({
		required this.estado,
		required this.sincronizando,
		required this.mensajeResultado,
		required this.controladorHubUrl,
		required this.controladorApiKey,
		required this.alSincronizar,
		required this.alGuardarHubUrl,
	});

	final _EstadoPantallaSync estado;
	final bool sincronizando;
	final String? mensajeResultado;
	final TextEditingController controladorHubUrl;
	final TextEditingController controladorApiKey;
	final VoidCallback alSincronizar;
	final VoidCallback alGuardarHubUrl;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(24.0),
			child: Column(
				children: [
					const Icon(Icons.cloud_sync, size: 80.0, color: Colors.indigo),
					const SizedBox(height: 24.0),
					_FilaEstadoSync(
						icono: Icons.pending_actions,
						etiqueta: 'Pendientes',
						valor: '${estado.estado.eventosPendientes}',
					),
					const SizedBox(height: 12.0),
					_FilaEstadoSync(
						icono: Icons.error_outline,
						etiqueta: 'Con error',
						valor: '${estado.estado.eventosConError}',
					),
					const SizedBox(height: 12.0),
					_FilaEstadoSync(
						icono: estado.estado.hubConfigurado ? Icons.cloud_done : Icons.cloud_off,
						etiqueta: 'Hub central',
						valor: estado.estado.hubConfigurado ? 'Configurado' : 'Sin configurar',
					),
					const SizedBox(height: 24.0),
					TextField(
						controller: controladorApiKey,
						obscureText: true,
						decoration: const InputDecoration(
							labelText: 'API Key del hub',
							hintText: 'Opcional; requerida en Render/Neon',
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 12.0),
					Row(
						children: [
							Expanded(
								child: TextField(
									controller: controladorHubUrl,
									decoration: const InputDecoration(
										labelText: 'URL del hub',
										hintText: 'http://servidor:8080',
										border: OutlineInputBorder(),
									),
								),
							),
							const SizedBox(width: 12.0),
							SizedBox(
								height: 56.0,
								child: FilledButton.tonalIcon(
									onPressed: alGuardarHubUrl,
									icon: const Icon(Icons.save),
									label: const Text('Guardar'),
								),
							),
						],
					),
					const Spacer(),
					if (mensajeResultado != null) ...[
						Text(mensajeResultado!),
						const SizedBox(height: 12.0),
					],
					SizedBox(
						width: double.infinity,
						height: 56.0,
						child: FilledButton.icon(
							onPressed: sincronizando ? null : alSincronizar,
							icon: sincronizando
								? const SizedBox(
									width: 20.0,
									height: 20.0,
									child: CircularProgressIndicator(strokeWidth: 2.0),
								)
								: const Icon(Icons.sync),
							label: Text(sincronizando ? 'Sincronizando...' : 'Sincronizar ahora'),
						),
					),
				],
			),
		);
	}
}

/// Fila de metrica de estado sync.
class _FilaEstadoSync extends StatelessWidget {
	const _FilaEstadoSync({
		required this.icono,
		required this.etiqueta,
		required this.valor,
	});

	final IconData icono;
	final String etiqueta;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Card(
			child: ListTile(
				leading: Icon(icono, color: PosiaColors.neutro),
				title: Text(etiqueta),
				trailing: Text(
					valor,
					style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
				),
			),
		);
	}
}
