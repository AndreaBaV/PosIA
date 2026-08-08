/// Panel admin: PIN de asistencia y entradas del dia.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../providers/asistencia_providers.dart';

class PantallaAsistenciaAdmin extends ConsumerStatefulWidget {
	const PantallaAsistenciaAdmin({super.key});

	@override
	ConsumerState<PantallaAsistenciaAdmin> createState() =>
		_PantallaAsistenciaAdminState();
}

class _PantallaAsistenciaAdminState extends ConsumerState<PantallaAsistenciaAdmin> {
	String? _pinActivo;
	DateTime? _expiraPin;
	bool _generando = false;
	Timer? _autoRefresco;

	@override
	void initState() {
		super.initState();
		// Solo refresca listado local; el sync completo al abrir competia con
		// "Generar PIN" por el candado de SQLite y dejaba Generando… colgado.
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted) {
				ref.invalidate(entradasAsistenciaDiaProvider);
			}
		});
		_autoRefresco = Timer.periodic(const Duration(seconds: 12), (_) {
			if (mounted) {
				ref.invalidate(entradasAsistenciaDiaProvider);
			}
		});
	}

	Future<void> _sincronizarYRefrescar() async {
		try {
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			await contenedor.syncOrchestrator.sincronizarCompleto();
		} on Object {
			// El listado local sigue; el ciclo periodico reintenta.
		}
		if (mounted) {
			ref.invalidate(entradasAsistenciaDiaProvider);
		}
	}

	@override
	void dispose() {
		_autoRefresco?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final entradasAsync = ref.watch(entradasAsistenciaDiaProvider);
		final usuariosAsync = ref.watch(_usuariosNombresProvider);
		final tiendasAsync = ref.watch(_tiendasNombresProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Asistencia'),
				actions: [
					IconButton(
						tooltip: 'Actualizar',
						onPressed: _sincronizarYRefrescar,
						icon: const Icon(Icons.refresh),
					),
				],
			),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					Card(
						color: PosiaColors.cobrar.withValues(alpha: 0.1),
						child: Padding(
							padding: const EdgeInsets.all(24),
							child: Column(
								children: [
									const Text(
										'PIN de entrada (4 dígitos)',
										style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
									),
									const SizedBox(height: 8),
									const Text(
										'Válido 10 minutos. El empleado debe marcar en un '
										'dispositivo de esta misma tienda.',
										textAlign: TextAlign.center,
										style: TextStyle(color: Colors.grey, fontSize: 13),
									),
									const SizedBox(height: 12),
									Text(
										_pinActivo ?? '---',
										style: Theme.of(context).textTheme.displayLarge?.copyWith(
											letterSpacing: 8,
											fontWeight: FontWeight.bold,
										),
									),
									if (_expiraPin != null)
										Padding(
											padding: const EdgeInsets.only(top: 8),
											child: Text(
												'Expira: ${_expiraPin!.toLocal().toString().substring(11, 16)}',
												style: const TextStyle(color: Colors.grey),
											),
										),
									const SizedBox(height: 16),
									FilledButton.icon(
										onPressed: _generando ? null : _generarPin,
										icon: const Icon(Icons.pin),
										label: Text(_generando ? 'Generando…' : 'Generar PIN'),
									),
								],
							),
						),
					),
					const SizedBox(height: 24),
					const Text(
						'Entradas de hoy',
						style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 8),
					entradasAsync.when(
						data: (entradas) {
							final nombres = usuariosAsync.value ?? {};
							final tiendas = tiendasAsync.value ?? {};
							if (entradas.isEmpty) {
								return const Text(
									'Sin registros hoy. Se actualiza solo al sincronizar.',
								);
							}
							return Column(
								children: entradas.map((e) {
									final nombre = nombres[e.usuarioId] ?? e.usuarioId;
									final tienda = tiendas[e.tiendaId];
									final hora =
										e.entradaEn.toLocal().toString().substring(11, 16);
									final salida =
										e.salidaEn?.toLocal().toString().substring(11, 16);
									final horario = salida == null ? hora : '$hora–$salida';
									return ListTile(
										leading: const Icon(Icons.person),
										title: Text(nombre),
										subtitle: Text(
											'$horario · ${e.metodo}'
											'${tienda == null ? '' : ' · $tienda'}',
										),
										trailing: e.abierto
											? const Chip(label: Text('Activo'))
											: const Chip(label: Text('Salida')),
									);
								}).toList(),
							);
						},
						loading: () => const LinearProgressIndicator(),
						error: (e, _) => Text('$e'),
					),
				],
			),
		);
	}

	Future<void> _generarPin() async {
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		setState(() => _generando = true);
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final asistencia = contenedor.servicioAsistencia;
		if (asistencia == null) {
			if (mounted) {
				setState(() => _generando = false);
				PosiaNotificaciones.mostrarSnackBar(
					context,
					const SnackBar(
						content: Text('Servicio de asistencia no disponible'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
			}
			return;
		}
		try {
			final resultado = await asistencia.generarDesafioPin(usuario.id);
			if (!mounted) {
				return;
			}
			setState(() {
				_pinActivo = resultado.pinPlano;
				_expiraPin = resultado.desafio.expiraEn;
			});
			ref.invalidate(entradasAsistenciaDiaProvider);
			if (resultado.sincronizadoConHub != true) {
				PosiaNotificaciones.mostrarSnackBar(
					context,
					const SnackBar(
						content: Text(
							'PIN listo. En el otro dispositivo marque en unos '
							'segundos (se baja solo al validar).',
						),
						duration: Duration(seconds: 4),
					),
				);
			}
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(
				context,
				SnackBar(
					content: Text('$error'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		} finally {
			if (mounted) {
				setState(() => _generando = false);
			}
		}
	}
}

final _usuariosNombresProvider = FutureProvider<Map<String, String>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final usuarios = await servicio.listarUsuarios();
	return {for (final u in usuarios) u.id: u.nombre};
});

final _tiendasNombresProvider = FutureProvider<Map<String, String>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final tiendas = await servicio.listarTodasLasTiendas();
	return {for (final t in tiendas) t.id: t.nombre};
});
