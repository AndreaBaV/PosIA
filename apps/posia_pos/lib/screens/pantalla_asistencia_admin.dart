/// Panel admin: PIN de asistencia y entradas del dia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaAsistenciaAdmin extends ConsumerStatefulWidget {
	const PantallaAsistenciaAdmin({super.key});

	@override
	ConsumerState<PantallaAsistenciaAdmin> createState() =>
		_PantallaAsistenciaAdminState();
}

class _PantallaAsistenciaAdminState extends ConsumerState<PantallaAsistenciaAdmin> {
	String? _pinActivo;
	DateTime? _expiraPin;

	@override
	Widget build(BuildContext context) {
		final entradasAsync = ref.watch(_entradasDiaProvider);
		final usuariosAsync = ref.watch(_usuariosNombresProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Asistencia')),
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
										onPressed: _generarPin,
										icon: const Icon(Icons.pin),
										label: const Text('Generar PIN'),
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
							if (entradas.isEmpty) {
								return const Text('Sin registros hoy');
							}
							return Column(
								children: entradas.map((e) {
									final nombre = nombres[e.usuarioId] ?? e.usuarioId;
									return ListTile(
										leading: const Icon(Icons.person),
										title: Text(nombre),
										subtitle: Text(
											'${e.entradaEn.toLocal().toString().substring(11, 16)} · ${e.metodo}',
										),
										trailing: e.abierto
											? const Chip(label: Text('Activo'))
											: null,
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
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final asistencia = contenedor.servicioAsistencia;
		if (asistencia == null) {
			return;
		}
		try {
			final resultado = await asistencia.generarDesafioPin(usuario.id);
			setState(() {
				_pinActivo = resultado.pinPlano;
				_expiraPin = resultado.desafio.expiraEn;
			});
			ref.invalidate(_entradasDiaProvider);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}

final _entradasDiaProvider = FutureProvider<List<RegistroAsistencia>>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioAsistencia?.listarEntradasDelDia() ?? [];
});

final _usuariosNombresProvider = FutureProvider<Map<String, String>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final usuarios = await servicio.listarUsuarios();
	return {for (final u in usuarios) u.id: u.nombre};
});
